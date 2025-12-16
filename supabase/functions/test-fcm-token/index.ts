import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🧪 Test FCM Token Function started')

    // Initialize Supabase client with service role key (bypasses RLS)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get all FCM tokens
    const { data: tokens, error } = await supabaseClient
      .from('user_fcm_tokens')
      .select('*')

    if (error) {
      console.error('❌ Error fetching FCM tokens:', error)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch FCM tokens', details: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('📋 FCM Tokens found:', tokens?.length || 0)

    return new Response(
      JSON.stringify({ 
        success: true,
        count: tokens?.length || 0,
        tokens: tokens?.map(t => ({
          user_id: t.user_id,
          fcm_token: t.fcm_token?.substring(0, 20) + '...',
          platform: t.platform,
          is_test_token: t.fcm_token?.startsWith('test-'),
          created_at: t.created_at
        })) || []
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Test function error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
