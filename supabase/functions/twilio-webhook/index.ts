import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// This function is designed to be called by Twilio without authentication
// Twilio webhooks don't send auth headers, so we handle this publicly
// We use the service role key to bypass authentication requirements

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📨 TWILIO WEBHOOK - WHATSAPP RESPONSE HANDLER');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Initialize Supabase client with service role for database access
    // This bypasses the need for authentication headers from Twilio
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

    // Parse form data from Twilio webhook
    const formData = await req.formData()
    const messageBody = formData.get('Body')?.toString() || ''
    const fromNumber = formData.get('From')?.toString() || ''
    const toNumber = formData.get('To')?.toString() || ''
    const messageSid = formData.get('MessageSid')?.toString() || ''

    console.log('📥 Twilio webhook received:');
    console.log('   From:', fromNumber);
    console.log('   To:', toNumber);
    console.log('   Message SID:', messageSid);
    console.log('   Body:', messageBody.substring(0, 100) + '...');
    
    // Debug: Log all form data
    console.log('🔍 All form data:');
    for (const [key, value] of formData.entries()) {
      console.log(`   ${key}: ${value}`);
    }

    // Extract phone number (remove whatsapp: prefix)
    const customerPhone = fromNumber.replace('whatsapp:', '');
    const profileName = formData.get('ProfileName')?.toString() || '';
    console.log('📞 Customer phone:', customerPhone);
    console.log('👤 Profile name:', profileName);

    // Check if this is a location message (WhatsApp location sharing)
    // WhatsApp location messages typically contain coordinates or location data
    const messageType = formData.get('MessageType')?.toString() || '';
    const latitude = formData.get('Latitude')?.toString() || '';
    const longitude = formData.get('Longitude')?.toString() || '';
    
    // FIXED: More restrictive location detection
    // Only consider it a location message if:
    // 1. Message type is explicitly 'location'
    // 2. OR both latitude and longitude are provided in form data
    // 3. OR message contains actual coordinate patterns (not just the word "موقع")
    const isLocationMessage = messageType === 'location' || 
                             (latitude !== '' && longitude !== '') ||
                             hasCoordinatePattern(messageBody);
    
    if (isLocationMessage) {
      console.log('📍 Location message detected');
      
      // Try to extract coordinates from message
      let coordinates = null;
      
      // First try to get coordinates directly from form data
      if (latitude && longitude) {
        coordinates = {
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude)
        };
        console.log('✅ Coordinates from form data:', coordinates);
      } else {
        // Fallback to extracting from message body
        coordinates = extractCoordinatesFromMessage(messageBody);
        if (coordinates) {
          console.log('✅ Coordinates extracted from message:', coordinates);
        }
      }
      
      if (coordinates) {
        console.log('✅ Final coordinates:', coordinates);
        
        // Find the order for this customer
        console.log('🔍 Looking for order with customer phone:', customerPhone);
        const { data: orderData, error: orderError } = await supabaseClient
          .from('orders')
          .select('id, customer_phone, status')
          .eq('customer_phone', customerPhone)
          .order('created_at', { ascending: false })
          .limit(1)
          .single();

        if (orderError) {
          console.log('❌ Order query error:', orderError);
        }

        if (orderData && !orderError) {
          console.log('✅ Order found:', orderData.id);
          
          // Update customer location
          const { error: updateError } = await supabaseClient.rpc('update_customer_location', {
            p_order_id: orderData.id,
            p_latitude: coordinates.latitude,
            p_longitude: coordinates.longitude,
            p_is_auto_update: false,
          });

          if (updateError) {
            console.error('❌ Failed to update location:', updateError);
          } else {
            console.log('✅ Location updated successfully');
            
            // Send confirmation message to customer
            try {
              const displayName = profileName || 'عميلنا العزيز';
              const confirmationMessage = `شكراً لك ${displayName}! تم استلام موقعك بنجاح.

سيتم توصيل طلبك إلى الموقع المحدد.

رقم الطلب: ${orderData.id.substring(0, 8)}...
وقت الاستلام: ${new Date().toLocaleString('ar-IQ')}`;

              await sendWhatsAppMessage(customerPhone, confirmationMessage);
              console.log('✅ Confirmation message sent to customer');
            } catch (whatsappError) {
              console.error('⚠️ Failed to send confirmation message:', whatsappError);
            }
          }
        } else {
          console.log('⚠️ No order found for customer');
          
          // Try to find order with different phone number formats
          console.log('🔍 Trying different phone number formats...');
          
          // Try without + prefix
          const phoneWithoutPlus = customerPhone.replace('+', '');
          const { data: orderData2 } = await supabaseClient
            .from('orders')
            .select('id, customer_phone, status')
            .eq('customer_phone', phoneWithoutPlus)
            .order('created_at', { ascending: false })
            .limit(1)
            .single();
            
          if (orderData2) {
            console.log('✅ Order found with alternative phone format:', orderData2.id);
            // Update customer location
            const { error: updateError } = await supabaseClient.rpc('update_customer_location', {
              p_order_id: orderData2.id,
              p_latitude: coordinates.latitude,
              p_longitude: coordinates.longitude,
              p_is_auto_update: false,
            });

            if (updateError) {
              console.error('❌ Failed to update location:', updateError);
            } else {
              console.log('✅ Location updated successfully');
            }
          } else {
            console.log('⚠️ Still no order found with alternative phone format');
          }
        }
      } else {
        console.log('⚠️ No coordinates found in message');
      }
    }

    // Check if this is a text response asking for location
    if (messageBody.toLowerCase().includes('share') || 
        messageBody.toLowerCase().includes('location') ||
        messageBody.includes('شارك') ||
        messageBody.includes('موقع')) {
      
      console.log('📱 Customer is asking for location sharing');
      
      // Send instructions for sharing location
      const instructionMessage = `لمشاركة موقعك:

1. انقر على مرفق (📎) في WhatsApp
2. اختر "الموقع" أو "Location"
3. اختر "مشاركة الموقع الحالي" أو "Share Live Location"
4. أو انقر على "إرسال موقعي الحالي"

سيتم تحديث موقع التسليم تلقائياً.`;

      await sendWhatsAppMessage(customerPhone, instructionMessage);
      console.log('✅ Location sharing instructions sent');
    }

    console.log('\n✅ Webhook processing complete');
    console.log('═══════════════════════════════════════════════════════\n');

    // Return TwiML response (empty for webhook)
    return new Response('', { status: 200 });

  } catch (error: any) {
    console.error('\n❌ WEBHOOK ERROR:', error.message);
    console.error('═══════════════════════════════════════════════════════\n');
    
    return new Response('', { status: 500 });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// CHECK FOR COORDINATE PATTERNS IN MESSAGE
// ═══════════════════════════════════════════════════════════════════════════════
function hasCoordinatePattern(message: string): boolean {
  // Only match actual coordinate patterns, not just the word "موقع"
  const coordinatePatterns = [
    /^-?\d+\.?\d*,\s*-?\d+\.?\d*$/,  // 33.3152, 44.3661
    /^-?\d+\.?\d*\s+-?\d+\.?\d*$/,   // 33.3152 44.3661
    /lat[itude]*:\s*-?\d+\.?\d*.*lng[itude]*:\s*-?\d+\.?\d*/i, // lat: 33.3152, lng: 44.3661
  ];
  
  return coordinatePatterns.some(pattern => pattern.test(message));
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACT COORDINATES FROM MESSAGE
// ═══════════════════════════════════════════════════════════════════════════════
function extractCoordinatesFromMessage(message: string): { latitude: number; longitude: number } | null {
  // Try to find coordinates in various formats
  const patterns = [
    // Decimal format: 33.3152, 44.3661
    /(-?\d+\.?\d*),\s*(-?\d+\.?\d*)/,
    // Space separated: 33.3152 44.3661
    /(-?\d+\.?\d*)\s+(-?\d+\.?\d*)/,
    // With labels: lat: 33.3152, lng: 44.3661
    /lat[itude]*:\s*(-?\d+\.?\d*).*lng[itude]*:\s*(-?\d+\.?\d*)/i,
  ];

  for (const pattern of patterns) {
    const match = message.match(pattern);
    if (match) {
      const lat = parseFloat(match[1]);
      const lng = parseFloat(match[2]);
      
      // Validate coordinates
      if (!isNaN(lat) && !isNaN(lng) && 
          lat >= -90 && lat <= 90 && 
          lng >= -180 && lng <= 180) {
        return { latitude: lat, longitude: lng };
      }
    }
  }

  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEND WHATSAPP MESSAGE VIA TWILIO
// ═══════════════════════════════════════════════════════════════════════════════
async function sendWhatsAppMessage(phoneNumber: string, message: string) {
  const accountSid = Deno.env.get('TWILIO_ACCOUNT_SID');
  const authToken = Deno.env.get('TWILIO_AUTH_TOKEN');
  const fromNumber = Deno.env.get('TWILIO_WHATSAPP_FROM');
  
  if (!accountSid || !authToken || !fromNumber) {
    throw new Error('Missing Twilio credentials');
  }

  const twilioPhone = `whatsapp:${phoneNumber}`;
  const twilioFrom = `whatsapp:${fromNumber}`;

  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`${accountSid}:${authToken}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      'From': twilioFrom,
      'To': twilioPhone,
      'Body': message,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Twilio API error: ${response.status} - ${errorText}`);
  }

  return await response.json();
}
