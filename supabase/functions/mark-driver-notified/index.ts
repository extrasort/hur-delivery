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

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('✅ MARK DRIVER NOTIFIED');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Parse request body
    const { order_id } = await req.json();

    if (!order_id) {
      console.error('❌ Missing order_id');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required field: order_id'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('📋 Marking driver as notified for order:', order_id);

    // Mark driver as notified
    const { data: result, error: markError } = await supabaseClient
      .rpc('mark_driver_notified_location', { p_order_id: order_id });

    if (markError) {
      console.error('❌ Error marking driver as notified:', markError);
      return new Response(
        JSON.stringify({ 
          error: 'Failed to mark driver as notified',
          details: markError.message
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (result) {
      console.log('✅ Driver marked as notified successfully');
      
      console.log('\n✅ Driver notification complete');
      console.log('═══════════════════════════════════════════════════════\n');

      return new Response(
        JSON.stringify({ 
          success: true,
          message: 'Driver marked as notified',
          order_id: order_id,
          timestamp: new Date().toISOString()
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } else {
      console.log('⚠️ No order found or location not provided');
      
      return new Response(
        JSON.stringify({ 
          success: false,
          message: 'No order found or customer location not provided',
          order_id: order_id
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

  } catch (error: any) {
    console.error('\n❌ ERROR:', error.message);
    console.error('═══════════════════════════════════════════════════════\n');
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
