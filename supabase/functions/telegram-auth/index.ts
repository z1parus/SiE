// Telegram OAuth adapter for Supabase Custom OAuth Provider.
//
// Implements the OAuth2 flow expected by Supabase Auth using the Telegram Login
// Widget as the identity source. Telegram itself does not expose standard OAuth2
// endpoints, so this Edge Function acts as a bridge:
//
//   GET  /authorize         → renders the Telegram Login Widget page.
//   GET  /telegram-callback → Telegram posts auth data here; we validate the
//                             hash, store a one-time code, and redirect to the
//                             Supabase Auth callback URL with ?code=.
//   POST /token             → Supabase exchanges the code for a signed JWT
//                             containing the Telegram identity claims.
//   GET  /userinfo          → Supabase fetches the user profile by access token.
//
// Configuration (set via `supabase secrets set ...`):
//   TELEGRAM_BOT_TOKEN      — token from @BotFather.
//   JWT_SECRET              — same value as Supabase Auth's JWT secret
//                             (Dashboard → Project Settings → API → JWT Secret)
//                             so the access tokens we mint are accepted by the
//                             Supabase Auth /userinfo call.
//
// The Telegram widget data is validated using the algorithm described in
// https://core.telegram.org/widgets/login#checking-authorization — the HMAC
// of the data-check-string keyed with the SHA256 of the bot token must equal
// the received hash.

// ─── One-time code store ───────────────────────────────────────────────────────
// Codes are stored in the `telegram_auth_codes` Postgres table so they survive
// across serverless invocations (Edge Functions are stateless — an in-memory
// Map would be lost between requests on different instances).
interface CodeEntry {
  claims: Record<string, unknown>
  exp: number
}
const CODE_TTL_MS = 5 * 60 * 1000

// ─── Env ───────────────────────────────────────────────────────────────────────
const BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN') ?? ''
const JWT_SECRET = Deno.env.get('JWT_SECRET') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const AUTH_REDIRECT =
  Deno.env.get('TELEGRAM_AUTH_REDIRECT') ??
  `${SUPABASE_URL}/auth/v1/callback`

// ─── Supabase client (lazy, service_role) ──────────────────────────────────────
import { createClient } from 'jsr:@supabase/supabase-js@2'
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

async function storeCode(code: string, entry: CodeEntry): Promise<void> {
  const c = entry.claims
  await supabase.from('telegram_auth_codes').insert({
    code,
    telegram_id: Number(c.telegram_id ?? 0),
    username: (c.username as string) ?? null,
    full_name: (c.name as string) ?? null,
    photo_url: (c.picture as string) ?? null,
    state: '',
    redirect_uri: AUTH_REDIRECT,
  })
}

async function consumeCode(code: string): Promise<CodeEntry | null> {
  const { data, error } = await supabase
    .from('telegram_auth_codes')
    .select('*')
    .eq('code', code)
    .is('consumed_at', null)
    .gt('created_at', new Date(Date.now() - CODE_TTL_MS).toISOString())
    .maybeSingle()
  if (error || !data) return null
  // Mark as consumed
  await supabase
    .from('telegram_auth_codes')
    .update({ consumed_at: new Date().toISOString() })
    .eq('code', code)
  return {
    claims: {
      sub: `telegram:${data.telegram_id}`,
      name: data.full_name ?? '',
      username: data.username ?? '',
      picture: data.photo_url ?? '',
      telegram_id: String(data.telegram_id),
    },
    exp: Date.now() + CODE_TTL_MS,
  }
}

// ─── Crypto helpers (Web Crypto API — no external deps) ────────────────────────
async function hmacSha256Hex(key: Uint8Array, data: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data))
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function sha256Bytes(data: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data))
  return new Uint8Array(digest)
}

function base64UrlEncode(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf)
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function base64UrlDecode(s: string): string {
  s = s.replace(/-/g, '+').replace(/_/g, '/')
  while (s.length % 4) s += '='
  return atob(s)
}

async function signJwt(payload: Record<string, unknown>): Promise<string> {
  const header = { alg: 'HS256', typ: 'JWT' }
  const enc = new TextEncoder()
  const h = base64UrlEncode(enc.encode(JSON.stringify(header)))
  const p = base64UrlEncode(enc.encode(JSON.stringify(payload)))
  const signingInput = `${h}.${p}`
  const sig = await hmacSha256Hex(
    new TextEncoder().encode(JWT_SECRET),
    signingInput,
  )
  // sig is hex; convert to base64url
  const sigBytes = new Uint8Array(sig.match(/.{2}/g)!.map((x) => parseInt(x, 16)))
  return `${signingInput}.${base64UrlEncode(sigBytes)}`
}

async function verifyJwt(token: string): Promise<Record<string, unknown> | null> {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const [h, p, s] = parts
    const signingInput = `${h}.${p}`
    const expected = await hmacSha256Hex(new TextEncoder().encode(JWT_SECRET), signingInput)
    const expectedB64 = base64UrlEncode(
      new Uint8Array(expected.match(/.{2}/g)!.map((x: string) => parseInt(x, 16))),
    )
    if (expectedB64 !== s) return null
    const payload = JSON.parse(base64UrlDecode(p))
    const exp = (payload as Record<string, number>).exp
    if (typeof exp === 'number' && exp * 1000 < Date.now()) return null
    return payload as Record<string, unknown>
  } catch {
    return null
  }
}

// ─── Telegram hash verification ───────────────────────────────────────────────
// Per https://core.telegram.org/widgets/login#checking-authorization:
//   secret_key = SHA256(bot_token)
//   expected   = HMAC_SHA256(data_check_string, secret_key)
// Compare to the received hash (hex).
async function verifyTelegramHash(
  dataCheckString: string,
  receivedHash: string,
): Promise<boolean> {
  if (!BOT_TOKEN || !receivedHash) return false
  const secret = await sha256Bytes(BOT_TOKEN)
  const expected = await hmacSha256Hex(secret, dataCheckString)
  if (expected.length !== receivedHash.length) return false
  // constant-time compare
  let diff = 0
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ receivedHash.charCodeAt(i)
  }
  return diff === 0
}

// ─── HTTP server ───────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  const url = new URL(req.url)
  const path = url.pathname.replace(/\/$/, '')

  try {
    // Telegram-OIDC shim: a discovery doc + filtered JWKS that let Supabase use
    // Telegram's native OIDC. Telegram's own JWKS includes an ES256K
    // (secp256k1) key that GoTrue's JOSE library can't parse, which breaks
    // id_token verification for the whole set. We re-publish Telegram's
    // discovery with `jwks_uri` pointed at our proxy, which drops the
    // unparseable key.
    if (path.endsWith('/telegram-oidc-config'))
      return await telegramOidcConfig(url)
    if (path.endsWith('/telegram-jwks')) return await telegramJwks()
    if (path.endsWith('/.well-known/openid-configuration'))
      return discovery(url)
    if (path.endsWith('/authorize')) return authorize(url)
    if (path.endsWith('/telegram-callback'))
      return await telegramCallback(url)
    if (path.endsWith('/token')) return await token(req)
    if (path.endsWith('/userinfo')) return await userinfo(req)
    return new Response('Not Found', { status: 404 })
  } catch (e) {
    console.error('telegram-auth error', e)
    return new Response('Internal Server Error', { status: 500 })
  }
})

// ─── Telegram-OIDC shim ─────────────────────────────────────────────────────────
const TELEGRAM_ISSUER = 'https://oauth.telegram.org'

// Discovery override: Telegram's own OIDC metadata, but with `jwks_uri` pointed
// at our filtered proxy below. `issuer` stays `https://oauth.telegram.org` so it
// still matches the id_token's `iss` and the configured Issuer URL. Configure
// this URL as the provider's "Discovery URL" in the Supabase dashboard.
async function telegramOidcConfig(url: URL): Promise<Response> {
  const fnName = url.pathname.split('/').filter(Boolean)[0] ?? 'telegram-auth'
  const jwksUri = `https://${url.host}/functions/v1/${fnName}/telegram-jwks`

  let meta: Record<string, unknown>
  try {
    const resp = await fetch(`${TELEGRAM_ISSUER}/.well-known/openid-configuration`)
    meta = await resp.json()
  } catch (_) {
    // Fallback to the known-good shape if Telegram is briefly unreachable.
    meta = {
      issuer: TELEGRAM_ISSUER,
      authorization_endpoint: `${TELEGRAM_ISSUER}/auth`,
      token_endpoint: `${TELEGRAM_ISSUER}/token`,
      response_types_supported: ['code'],
      subject_types_supported: ['public'],
      id_token_signing_alg_values_supported: ['RS256', 'ES256'],
      scopes_supported: ['openid', 'profile'],
    }
  }
  meta.jwks_uri = jwksUri
  // Advertise only the algorithms our proxied JWKS keeps, so GoTrue won't expect
  // an ES256K / EdDSA key it can't handle.
  meta.id_token_signing_alg_values_supported = ['RS256', 'ES256']
  return json(meta)
}

// JWKS proxy: fetch Telegram's keys and keep only the ones GoTrue's JOSE
// library can parse — RSA (RS256) and EC P-256 (ES256). The dropped key is the
// EC secp256k1 (ES256K) one, whose curve is unsupported and fails the whole
// set's decode.
async function telegramJwks(): Promise<Response> {
  const resp = await fetch(`${TELEGRAM_ISSUER}/.well-known/jwks.json`)
  const set = await resp.json() as { keys?: Array<Record<string, unknown>> }
  const keys = (set.keys ?? []).filter((k) => {
    if (k.kty === 'RSA') return true
    if (k.kty === 'EC' && k.crv === 'P-256') return true
    return false
  })
  return json({ keys })
}

// ─── /.well-known/openid-configuration ──────────────────────────────────────────
// Supabase's Custom OAuth provider is OIDC-discovery based: given the configured
// "Issuer URL" it fetches `${issuer}/.well-known/openid-configuration` to learn
// the authorize / token / userinfo endpoints. We advertise this bridge's own
// endpoints. `issuer` MUST exactly equal the configured Issuer URL (this
// function's public base). No `jwks_uri` / `id_token` is advertised — the flow
// is access-token + userinfo, so no asymmetric key validation is needed.
function discovery(url: URL): Response {
  const fnName = url.pathname.split('/').filter(Boolean)[0] ?? 'telegram-auth'
  const base = `https://${url.host}/functions/v1/${fnName}`
  return json({
    issuer: base,
    authorization_endpoint: `${base}/authorize`,
    token_endpoint: `${base}/token`,
    userinfo_endpoint: `${base}/userinfo`,
    response_types_supported: ['code'],
    grant_types_supported: ['authorization_code'],
    subject_types_supported: ['public'],
    id_token_signing_alg_values_supported: ['HS256'],
    scopes_supported: ['openid', 'profile'],
    token_endpoint_auth_methods_supported: [
      'client_secret_post',
      'client_secret_basic',
    ],
    claims_supported: [
      'sub',
      'name',
      'preferred_username',
      'picture',
      'email',
      'email_verified',
    ],
  })
}

// ─── /authorize ────────────────────────────────────────────────────────────────
function authorize(url: URL): Response {
  const state = url.searchParams.get('state') ?? ''
  const redirectUri = url.searchParams.get('redirect_uri') ?? AUTH_REDIRECT
  // Supabase Auth passes the bot username through `bot_username` (we configure
  // it as an authorization param in Dashboard), or we read TELEGRAM_BOT_USERNAME.
  const botUsername =
    url.searchParams.get('bot_username') ??
    Deno.env.get('TELEGRAM_BOT_USERNAME') ??
    ''
  if (!botUsername) return html(errorPage('Missing bot_username'))
  // Build the public callback URL for the widget to POST to. The edge runtime
  // strips the `/functions/v1` prefix before the handler sees it (internal
  // pathname is `/telegram-auth/authorize`), so we re-add that prefix here.
  // The previous hardcoded `/functions/telegram-auth/...` dropped the `/v1/`
  // segment, so the widget POSTed to the API gateway (401 "No API key found")
  // and the callback — and therefore the one-time code storage — never ran.
  const fnName = url.pathname.split('/').filter(Boolean)[0] ?? 'telegram-auth'
  const cbUrl =
    `https://${url.host}/functions/v1/${fnName}/telegram-callback`
  return html(widgetPage(botUsername, cbUrl, state, redirectUri))
}

// ─── /telegram-callback ────────────────────────────────────────────────────────
async function telegramCallback(url: URL): Promise<Response> {
  const params = url.searchParams
  const hash = params.get('hash') ?? ''
  const state = params.get('state') ?? ''
  const redirectUri = params.get('redirect_uri') ?? AUTH_REDIRECT

  // Build data-check-string (alphabetical, k=v, newline-separated, no hash/state/redirect_uri)
  const fields: Record<string, string> = {}
  for (const [k, v] of params.entries()) {
    if (k === 'state' || k === 'redirect_uri' || k === 'hash') continue
    fields[k] = v
  }
  const dataCheckString = Object.keys(fields)
    .sort()
    .map((k) => `${k}=${fields[k]}`)
    .join('\n')

  if (!(await verifyTelegramHash(dataCheckString, hash))) {
    return html(errorPage('Invalid Telegram signature'))
  }

  const code = randomId()
  const name = [fields['first_name'], fields['last_name']]
    .filter(Boolean)
    .join(' ')
  await storeCode(code, {
    claims: {
      sub: `telegram:${fields['id']}`,
      name,
      username: fields['username'] ?? '',
      picture: fields['photo_url'] ?? '',
      telegram_id: fields['id'],
    },
    exp: Date.now() + CODE_TTL_MS,
  })

  const sep = redirectUri.includes('?') ? '&' : '?'
  return Response.redirect(
    `${redirectUri}${sep}code=${code}&state=${encodeURIComponent(state)}`,
    302,
  )
}

// ─── /token ────────────────────────────────────────────────────────────────────
async function token(req: Request): Promise<Response> {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
  const body = new URLSearchParams(await req.text())
  const code = body.get('code') ?? ''
  const entry = await consumeCode(code)
  if (!entry) return json({ error: 'invalid_grant' }, 400)

  const iat = Math.floor(Date.now() / 1000)
  const exp = iat + 3600
  const accessToken = await signJwt({
    ...entry.claims,
    iat,
    exp,
    aud: 'supabase',
    iss: 'telegram-auth',
  })
  return json({
    access_token: accessToken,
    token_type: 'bearer',
    expires_in: 3600,
  })
}

// ─── /userinfo ─────────────────────────────────────────────────────────────────
async function userinfo(req: Request): Promise<Response> {
  const auth = req.headers.get('Authorization') ?? ''
  const token = auth.replace(/^Bearer\s+/i, '')
  const claims = await verifyJwt(token)
  if (!claims) return json({ error: 'invalid_token' }, 401)

  const username = (claims.username as string) ?? ''
  const telegramId = (claims.telegram_id as string) ?? ''
  return json({
    sub: claims.sub,
    name: claims.name ?? '',
    preferred_username: username,
    username,
    picture: claims.picture ?? '',
    // Telegram has no email; provider must be configured with email_optional=true.
    email: `${username || telegramId}@telegram.local`,
    email_verified: false,
    telegram_id: telegramId,
  })
}

// ─── helpers ───────────────────────────────────────────────────────────────────
function randomId(): string {
  return crypto.randomUUID().replace(/-/g, '') + Date.now().toString(36)
}

function html(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  })
}

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function widgetPage(
  botUsername: string,
  callbackUrl: string,
  state: string,
  redirectUri: string,
): string {
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>SiE · Telegram</title>
<script src="https://telegram.org/js/telegram-widget.js?22"
  data-telegram-login="${botUsername}"
  data-size="large"
  data-onauth="onTelegramAuth(user)"
  data-request-access="write"></script>
<script>
function onTelegramAuth(u) {
  const q = new URLSearchParams({ ...u, state: ${JSON.stringify(state)}, redirect_uri: ${JSON.stringify(redirectUri)} });
  window.location = ${JSON.stringify(callbackUrl)} + '?' + q.toString();
}
</script>
<style>body{font-family:system-ui,sans-serif;background:#0b0f1a;color:#c8a84b;display:flex;min-height:100vh;align-items:center;justify-content:center;flex-direction:column;gap:16px}h1{font-size:16px;font-weight:600;letter-spacing:.1em;margin:0}</style>
</head><body><h1>SIE · TELEGRAM AUTH</h1></body></html>`
}

function errorPage(message: string): string {
  return `<!doctype html><html><head><meta charset="utf-8"><title>SiE · Error</title>
<style>body{font-family:system-ui,sans-serif;background:#1a0b0b;color:#e85a5a;display:flex;min-height:100vh;align-items:center;justify-content:center}</style>
</head><body><p>${message}</p></body></html>`
}