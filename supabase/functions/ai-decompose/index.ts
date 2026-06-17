import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SYSTEM_PROMPT = `
Ты — AI-стратег системы SiE (System in Evolution). Твоя задача — разбить цель пользователя на чёткий, реалистичный план.

Ответь ТОЛЬКО валидным JSON-объектом следующей структуры (без пояснений, без markdown):
{
  "sub_goals": [
    {
      "name": "Название этапа",
      "tasks": [
        { "name": "Конкретное действие", "weight": 1 }
      ]
    }
  ],
  "milestones": [
    { "name": "Название контрольной точки" }
  ]
}

Правила:
- Создавай 3-5 логических этапов (sub_goals)
- В каждом этапе 2-5 конкретных задач (tasks)
- Вес задачи (weight): 1 = простое действие (< 1 часа), 3 = сфокусированная работа (несколько часов), 5 = крупный блок (день и более)
- Создавай 2-3 контрольные точки (milestones) — ключевые результаты, не процессы
- Задачи должны быть конкретными и actionable
- Язык ответа должен СОВПАДАТЬ с языком цели пользователя
`.trim()

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Verify user is authenticated
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const groqApiKey = Deno.env.get('GROQ_API_KEY')
  if (!groqApiKey) {
    console.error('GROQ_API_KEY secret is not set')
    return new Response(JSON.stringify({ error: 'AI service not configured' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  let goalName: string
  let description: string | undefined
  try {
    const body = await req.json()
    goalName = body.goalName
    description = body.description
    if (!goalName) throw new Error('goalName is required')
  } catch (e) {
    return new Response(JSON.stringify({ error: `Bad request: ${e}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const userPrompt = `Цель: "${goalName}"${description ? `\nОписание: ${description}` : ''}`

  const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${groqApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      temperature: 0.4,
      max_tokens: 1024,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt },
      ],
      response_format: { type: 'json_object' },
    }),
  })

  if (!groqRes.ok) {
    const errBody = await groqRes.text()
    console.error('Groq API error:', groqRes.status, errBody)
    const msg = groqRes.status === 429
      ? 'Превышен лимит запросов к Groq. Попробуй позже.'
      : `Ошибка Groq API (${groqRes.status})`
    return new Response(JSON.stringify({ error: msg }), {
      status: groqRes.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const groqData = await groqRes.json()
  const content: string = groqData.choices[0].message.content

  // content is a JSON string — parse and return it directly
  try {
    const parsed = JSON.parse(content)
    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch {
    console.error('Failed to parse Groq JSON response:', content)
    return new Response(JSON.stringify({ error: 'Не удалось разобрать ответ AI' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
