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
  console.log('🚚 DRIVER LOCATION UPDATE CHECK');
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

    // Get orders with location updates that drivers haven't been notified about
    const { data: ordersWithUpdates, error: queryError } = await supabaseClient
      .rpc('get_orders_with_location_updates');

    if (queryError) {
      console.error('❌ Error querying orders:', queryError);
      return new Response(
        JSON.stringify({ 
          error: 'Failed to query orders',
          details: queryError.message
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📊 Found ${ordersWithUpdates?.length || 0} orders with location updates`);

    if (ordersWithUpdates && ordersWithUpdates.length > 0) {
      console.log('📍 Orders with location updates:');
      ordersWithUpdates.forEach((order, index) => {
        console.log(`   ${index + 1}. Order ${order.order_id.substring(0, 8)}... - ${order.customer_name} (${order.customer_phone})`);
        console.log(`      Location: ${order.delivery_latitude}, ${order.delivery_longitude}`);
        console.log(`      Merchant: ${order.merchant_name}`);
        console.log(`      Status: ${order.status}`);
        console.log(`      Updated: ${order.updated_at}`);
      });
    }

    console.log('\n✅ Location update check complete');
    console.log('═══════════════════════════════════════════════════════\n');

    return new Response(
      JSON.stringify({ 
        success: true,
        orders_with_updates: ordersWithUpdates || [],
        count: ordersWithUpdates?.length || 0,
        timestamp: new Date().toISOString()
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

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
