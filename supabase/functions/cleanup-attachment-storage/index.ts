// Edge Function: cleanup-attachment-storage
// Triggered via Supabase Database Webhook on DELETE events from
// public.goal_node_attachments. Removes the corresponding object from the
// goal-attachments Storage bucket so orphaned files don't accumulate.
//
// Setup in Supabase Dashboard:
//   Database → Webhooks → New Webhook
//   Table: goal_node_attachments  Events: Delete
//   URL: {project_url}/functions/v1/cleanup-attachment-storage
//   Headers: Authorization: Bearer {service_role_key}

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req: Request) => {
  try {
    const payload = await req.json()
    // Database webhook wraps the deleted row in payload.record
    const record = payload?.record
    const storagePath: string | undefined = record?.storage_path

    if (!storagePath) {
      return new Response(JSON.stringify({ ok: true, skipped: 'no storage_path' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { error } = await supabase.storage
      .from('goal-attachments')
      .remove([storagePath])

    if (error) {
      console.error('Storage delete error:', error.message)
      return new Response(JSON.stringify({ ok: false, error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ ok: true, deleted: storagePath }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
