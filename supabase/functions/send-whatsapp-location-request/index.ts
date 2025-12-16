import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'

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
  console.log('📱 WHATSAPP LOCATION REQUEST - EDGE FUNCTION');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Initialize Supabase client with service role
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
    const requestBody = await req.json()
    console.log('📥 Request received:');
    console.log('   Order ID:', requestBody.order_id);
    console.log('   Customer Phone:', requestBody.customer_phone);
    console.log('   Customer Name:', requestBody.customer_name);
    
    const { order_id, customer_phone, customer_name, merchant_name } = requestBody
    
    // Validate required fields
    if (!order_id || !customer_phone) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: order_id and customer_phone are required'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');

    // Format phone number for WhatsApp (ensure it starts with +964)
    let formattedPhone = customer_phone.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('964')) {
        formattedPhone = '+' + formattedPhone;
      } else if (formattedPhone.startsWith('0')) {
        formattedPhone = '+964' + formattedPhone.substring(1);
      } else {
        formattedPhone = '+964' + formattedPhone;
      }
    }

    console.log('📞 Formatted phone number:', formattedPhone);

    // Create WhatsApp message requesting location
    // Use WhatsApp profile name if available, otherwise use customer name or default
    const displayName = customer_name || 'عميلنا العزيز';
    
    const message = `مرحباً ${displayName}! 

أنا تطبيق حر للتوصيل، وأود أن أبلغك بأن لديك طلب توصيل جديد من ${merchant_name || 'متجرنا'}. 

يرجى مشاركة موقعك الحالي في هذه المحادثة لتتمكن من استلام طلبك.

📍 انقر على مرفق (📎) في الأسفل واختر "الموقع" أو "Location" لمشاركة موقعك الحالي.

سيتم تحديث عنوان التسليم تلقائياً عند استلام موقعك.

شكراً لك! 🚚`;

    console.log('📝 WhatsApp message prepared');

    // Send WhatsApp message via Railway WhatsApp server
    const whatsappResult = await sendWhatsAppMessage(formattedPhone, message);
    
    if (whatsappResult.success) {
      // Update the database record
      const { error: updateError } = await supabaseClient
        .from('whatsapp_location_requests')
        .update({
          status: 'delivered',
          delivered_at: new Date().toISOString()
        })
        .eq('order_id', order_id);

      if (updateError) {
        console.error('❌ Failed to update database:', updateError);
      } else {
        console.log('✅ Database updated successfully');
      }

      console.log('\n✅ WhatsApp message sent successfully!');
      console.log('═══════════════════════════════════════════════════════\n');

      return new Response(
        JSON.stringify({ 
          success: true,
          sent_to: formattedPhone,
          delivered_at: new Date().toISOString()
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } else {
      console.error('❌ WhatsApp message failed:', whatsappResult.error);
      
      // Update database with failure status
      await supabaseClient
        .from('whatsapp_location_requests')
        .update({ status: 'failed' })
        .eq('order_id', order_id);

      return new Response(
        JSON.stringify({ 
          error: 'WhatsApp message failed',
          details: whatsappResult.error
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

  } catch (error: any) {
    console.error('\n❌ EDGE FUNCTION ERROR:', error.message);
    console.error('═══════════════════════════════════════════════════════\n');
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// SEND WHATSAPP MESSAGE VIA RAILWAY WHATSAPP SERVER
// ═══════════════════════════════════════════════════════════════════════════════
async function sendWhatsAppMessage(phoneNumber: string, message: string) {
  const whatsappServerUrl = Deno.env.get('WHATSAPP_SERVER_URL') || 'https://striking-enthusiasm-production.up.railway.app';
  
  console.log('📱 Sending WhatsApp message via Railway server...');
  console.log('   Server:', whatsappServerUrl);
  console.log('   To:', phoneNumber);
  console.log('   Message length:', message.length);

  // Remove the + prefix for the phone number
  const cleanPhone = phoneNumber.replace('+', '');

  const response = await fetch(`${whatsappServerUrl}/send-message`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      phoneNumber: cleanPhone,
      message: message,
    }),
  });

  console.log('📨 WhatsApp server response status:', response.status);

  if (!response.ok) {
    const errorText = await response.text();
    console.error('❌ WhatsApp API error:', errorText);
    return {
      success: false,
      error: `WhatsApp API error: ${response.status} - ${errorText}`
    };
  }

  const result = await response.json();
  console.log('✅ WhatsApp response:', JSON.stringify(result));
  
  if (result.success) {
    return {
      success: true
    };
  } else {
    return {
      success: false,
      error: result.error || 'Unknown error'
    };
  }
}
