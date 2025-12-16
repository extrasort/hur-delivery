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
  console.log('🔥 EDGE FUNCTION CALLED - SEND PUSH NOTIFICATION');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Initialize Supabase client with service role (full access)
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
    console.log('   Keys:', Object.keys(requestBody));
    
    const { user_id, title, body, data } = requestBody
    
    // Validate required fields
    if (!user_id || typeof user_id !== 'string' || user_id.trim() === '') {
      console.error('❌ Invalid user_id:', user_id);
      return new Response(
        JSON.stringify({ 
          error: 'Invalid user_id',
          received: user_id
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!title || !body) {
      console.error('❌ Missing title or body');
      return new Response(
        JSON.stringify({ error: 'Missing title or body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('✅ Validation passed');
    console.log('   User ID:', user_id);
    console.log('   Title:', title);
    console.log('   Body:', body.substring(0, 50) + '...');

    // Get FCM token from database (ALWAYS fetch from DB for latest token)
    console.log('\n🔍 Fetching FCM token from database...');
    const { data: tokenData, error: tokenError } = await supabaseClient
      .from('user_fcm_tokens')
      .select('fcm_token, platform')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    
    if (tokenError) {
      console.error('❌ Database error fetching token:', tokenError);
      return new Response(
        JSON.stringify({ 
          error: 'Database error',
          details: tokenError.message
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!tokenData || !tokenData.fcm_token) {
      console.error('❌ No FCM token found for user:', user_id);
      return new Response(
        JSON.stringify({ 
          error: 'No FCM token found',
          user_id: user_id,
          hint: 'User must login to generate FCM token'
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const fcmToken = tokenData.fcm_token;
    const platform = tokenData.platform || 'android';

    console.log('✅ FCM Token retrieved from database');
    console.log('   Token (first 30 chars):', fcmToken.substring(0, 30) + '...');
    console.log('   Platform:', platform);

    // Convert data to strings for Firebase compatibility
    const convertedData: Record<string, string> = {};
    if (data && typeof data === 'object') {
      for (const [key, value] of Object.entries(data)) {
        convertedData[key] = String(value);
      }
    }

    console.log('✅ Data converted to strings');
    console.log('   Keys:', Object.keys(convertedData));

    // Send push notification via Firebase
    console.log('\n🚀 Sending Firebase notification...');
    
    let fcmResult = null;
    let pushSuccess = false;
    
    try {
      fcmResult = await sendFirebaseNotification(fcmToken, title, body, convertedData, platform);
      pushSuccess = true;
      console.log('✅ Firebase notification sent successfully!');
      console.log('   Message ID:', fcmResult?.name || 'N/A');
    } catch (firebaseError: any) {
      console.error('❌ Firebase notification failed:', firebaseError.message);
      
      // Check if token is invalid (UNREGISTERED)
      if (firebaseError.message && firebaseError.message.includes('UNREGISTERED')) {
        console.log('⚠️  FCM token is invalid/unregistered - cleaning up...');
        
        try {
          await supabaseClient
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', user_id);
          
          console.log('✅ Deleted invalid FCM token from database');
        } catch (cleanupError) {
          console.error('❌ Failed to cleanup invalid token:', cleanupError);
        }
      }
      
      // Return error response
      return new Response(
        JSON.stringify({ 
          error: 'Firebase notification failed',
          details: firebaseError.message,
          user_id: user_id
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Success response
    console.log('\n✅ Notification pipeline complete');
    console.log('═══════════════════════════════════════════════════════\n');

    return new Response(
      JSON.stringify({ 
        success: true,
        message_id: fcmResult?.name || 'success',
        delivered_at: new Date().toISOString(),
        push_delivered: pushSuccess,
        status: 'delivered'
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

// ═══════════════════════════════════════════════════════════════════════════════
// SEND FIREBASE NOTIFICATION
// ═══════════════════════════════════════════════════════════════════════════════
async function sendFirebaseNotification(
  token: string, 
  title: string, 
  body: string, 
  data: Record<string, string>,
  platform: string
) {
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID');
  
  if (!projectId) {
    throw new Error('FIREBASE_PROJECT_ID not configured');
  }

  console.log('🔐 Getting Firebase access token...');
  const accessToken = await getFirebaseAccessToken();
  console.log('✅ Access token obtained');

  // Build Firebase message payload
  const message: any = {
    token: token,
    data: data,
  };

  // Add notification payload for better delivery
  message.notification = {
    title: title,
    body: body,
  };

  // Platform-specific configuration
  if (platform === 'android') {
    message.android = {
      priority: 'high',
      notification: {
        sound: 'notification_sound',  // Custom sound (without .mp3 extension)
        channelId: 'critical_orders',
        icon: 'thumbnail',  // Use thumbnail.png from drawable
        color: '#2196F3',  // Blue color for notification icon
        defaultVibrateTimings: true,
      }
    };
  } else if (platform === 'ios') {
    message.apns = {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          alert: {
            title: title,
            body: body,
          },
          'content-available': 1,
        },
      },
    };
  }

  console.log('📦 Sending to Firebase FCM API...');
  console.log('   Project ID:', projectId);
  console.log('   Platform:', platform);
  console.log('   Data keys:', Object.keys(data));

  // Send to Firebase
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message }),
  });

  console.log('📨 Firebase response status:', response.status);

  if (!response.ok) {
    const errorText = await response.text();
    console.error('❌ Firebase API error:', errorText);
    throw new Error(`Firebase API error: ${response.status} - ${errorText}`);
  }

  const result = await response.json();
  console.log('✅ Firebase response:', JSON.stringify(result));
  
  return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GET FIREBASE ACCESS TOKEN
// ═══════════════════════════════════════════════════════════════════════════════
async function getFirebaseAccessToken(): Promise<string> {
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL');
  
  if (!privateKey || !clientEmail) {
    throw new Error('Missing Firebase credentials: FIREBASE_PRIVATE_KEY or FIREBASE_CLIENT_EMAIL');
  }

  const now = Math.floor(Date.now() / 1000);
  
  // JWT Header
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  // JWT Payload
  const payload = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  // Encode header and payload
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const signatureInput = `${encodedHeader}.${encodedPayload}`;

  // Import and sign with private key
  const keyData = privateKey.replace(/\\n/g, '\n');
  const pemHeader = '-----BEGIN PRIVATE KEY-----';
  const pemFooter = '-----END PRIVATE KEY-----';
  const pemContents = keyData
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '');

  const binaryString = atob(pemContents);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    bytes,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signatureInput)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signatureInput}.${encodedSignature}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Token request failed: ${tokenResponse.status} - ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}
