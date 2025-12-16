import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

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
  console.log('🔄 WHATSAPP PROXY - EDGE FUNCTION');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    const whatsappServerUrl = Deno.env.get('WHATSAPP_SERVER_URL') || 'https://striking-enthusiasm-production.up.railway.app';
    
    // Get the path from the request URL
    const url = new URL(req.url);
    let path = url.pathname;
    
    // Remove any edge function path prefixes
    // Paths can come as: /select-path, /whatsapp-proxy/send-otp, or /functions/v1/whatsapp-proxy/send-otp
    path = path
      .replace(/^\/functions\/v1\/whatsapp-proxy/, '')
      .replace(/^\/whatsapp-proxy/, '');
    
    // Ensure path starts with /
    if (!path || path === '') {
      path = '/';
    } else if (!path.startsWith('/')) {
      path = '/' + path;
    }
    
    const targetUrl = `${whatsappServerUrl}${path}`;
    
    console.log('📡 Proxying request:');
    console.log('   From:', req.url);
    console.log('   Original pathname:', url.pathname);
    console.log('   Extracted path:', path);
    console.log('   To:', targetUrl);
    console.log('   Method:', req.method);

    // Forward the request to the WhatsApp server
    const response = await fetch(targetUrl, {
      method: req.method,
      headers: {
        'Content-Type': 'application/json',
        ...Object.fromEntries(req.headers.entries()),
      },
      body: req.method !== 'GET' ? await req.text() : undefined,
    });

    console.log('📨 Response status:', response.status);
    console.log('📨 Response headers:', Object.fromEntries(response.headers.entries()));

    // Get response body
    const responseBody = await response.text();
    console.log('📨 Response body:', responseBody);

    // Return the response with CORS headers
    return new Response(responseBody, {
      status: response.status,
      headers: {
        ...corsHeaders,
        'Content-Type': response.headers.get('Content-Type') || 'application/json',
      },
    });

  } catch (error: any) {
    console.error('\n❌ PROXY ERROR:', error.message);
    console.error('═══════════════════════════════════════════════════════\n');
    
    return new Response(
      JSON.stringify({ 
        error: 'Proxy error',
        message: error.message 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

