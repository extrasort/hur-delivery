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
  console.log('❌ WHATSAPP ERROR HANDLER - EDGE FUNCTION');
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
    console.log('📥 Error report received:');
    console.log('   Phone:', requestBody.phone);
    console.log('   Error:', requestBody.error);
    console.log('   Context:', requestBody.context);
    
    const { phone, error, context, user_id } = requestBody
    
    // Validate required fields
    if (!phone || !error) {
      console.error('❌ Missing required fields');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: phone and error are required'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');

    // Log the error to database for monitoring
    const { error: logError } = await supabaseClient
      .from('whatsapp_errors')
      .insert({
        phone: phone,
        error_message: error,
        context: context || 'unknown',
        user_id: user_id || null,
        created_at: new Date().toISOString()
      });

    if (logError) {
      console.error('❌ Failed to log error:', logError);
    } else {
      console.log('✅ Error logged to database');
    }

    // Determine user-friendly error message
    let userMessage = 'حدث خطأ في إرسال رمز التحقق';
    let requiresWhatsApp = false;

    if (error.includes('not registered') || 
        error.includes('no account') ||
        error.includes('does not have WhatsApp') ||
        error.includes('User does not have WhatsApp account')) {
      userMessage = 'لا يوجد حساب واتساب لهذا الرقم. يجب أن يكون لديك واتساب لتسجيل الدخول.';
      requiresWhatsApp = true;
    } else if (error.includes('connection') || error.includes('timeout')) {
      userMessage = 'خطأ في الاتصال. يرجى المحاولة مرة أخرى.';
    } else if (error.includes('rate limit') || error.includes('too many requests')) {
      userMessage = 'تم إرسال طلبات كثيرة. يرجى الانتظار قليلاً والمحاولة مرة أخرى.';
    } else if (error.includes('invalid phone') || error.includes('invalid number')) {
      userMessage = 'رقم الهاتف غير صحيح. يرجى التحقق من الرقم والمحاولة مرة أخرى.';
    }

    console.log('\n✅ Error processed successfully!');
    console.log('   User message:', userMessage);
    console.log('   Requires WhatsApp:', requiresWhatsApp);
    console.log('═══════════════════════════════════════════════════════\n');

    return new Response(
      JSON.stringify({ 
        success: true,
        user_message: userMessage,
        requires_whatsapp: requiresWhatsApp,
        error_type: requiresWhatsApp ? 'no_whatsapp' : 'general_error',
        logged: !logError
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

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

