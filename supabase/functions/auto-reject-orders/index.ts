// Auto-Reject Expired Orders - Supabase Edge Function
// This function runs every 5 seconds to check for orders that have timed out
// and automatically reassigns them to the next available driver

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
    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    console.log('Running auto-reject check...')

    // Call the PostgreSQL function to auto-reject expired orders
    const { data, error } = await supabase.rpc('auto_reject_expired_orders')

    if (error) {
      console.error('Error auto-rejecting orders:', error)
      throw error
    }

    const rejectedCount = data ?? 0
    console.log(`Auto-rejected ${rejectedCount} expired orders`)

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        rejectedCount,
        timestamp: new Date().toISOString(),
        message: `Successfully processed ${rejectedCount} expired orders`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('Error in auto-reject function:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

