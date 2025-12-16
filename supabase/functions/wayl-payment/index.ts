// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

console.log('[wayl-payment] Module loaded at:', new Date().toISOString());

interface CreatePaymentLinkRequest {
  merchant_id: string;
  amount: number;
  notes?: string;
}

interface WaylLinkResponse {
  id: string;
  code: string;
  url: string;
  referenceId: string;
}

interface WaylWebhookPayload {
  id: string;
  code: string;
  referenceId: string;
  status: string;
  total: number;
  paymentMethod?: string;
  customer?: {
    name?: string;
    phone?: string;
    email?: string;
  };
  lineItems?: Array<{
    name: string;
    quantity: number;
    price: number;
  }>;
}

// Wayl API Configuration
const WAYL_API_BASE = 'https://api.thewayl.com/api/v1';
const WAYL_MERCHANT_TOKEN = Deno.env.get('WAYL_MERCHANT_TOKEN') || 'K5XpGRHx/SutpUHR1/J+xQ==:xnW683RPDcI+XHyCetQkhvyz/NnEwOFwDH/J39TX8YcxH9XCn0kRkrTrCY9+PZz09sbpXNYsCgfh+EzV2R+0ZYIK/f3Df5QEHfwjxPLBpn1LhUMEDuGoOfNuWnckHNaeuFDzXxrJ7kV8BhdBR4Dc/DbtF+1gdpobXjgsn1Eho5E=';
const WAYL_SECRET = Deno.env.get('WAYL_SECRET') || WAYL_MERCHANT_TOKEN; // Use token as secret for webhook verification

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-wayl-signature-256',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  };

  console.log('[wayl-payment] ==== HANDLER CALLED ====');
  console.log('[wayl-payment] Method:', req.method);
  console.log('[wayl-payment] URL:', req.url);

  try {
    // Handle OPTIONS request for CORS
    if (req.method === 'OPTIONS') {
      console.log('[wayl-payment] OPTIONS request, returning CORS');
      return new Response('ok', { headers: corsHeaders });
    }

    const url = new URL(req.url);
    // Extract the path after the function name
    // Supabase strips /functions/v1/ prefix, so pathname will be like: /wayl-payment or /wayl-payment/webhook
    let path = url.pathname;
    
    // Remove any edge function path prefixes
    // Paths can come as: /wayl-payment, /wayl-payment/webhook, or /functions/v1/wayl-payment/webhook
    path = path
      .replace(/^\/functions\/v1\/wayl-payment/, '')
      .replace(/^\/wayl-payment/, '');
    
    // Ensure path starts with /
    if (!path || path === '') {
      path = '/';
    } else if (!path.startsWith('/')) {
      path = '/' + path;
    }
    
    console.log('[wayl-payment] Original pathname:', url.pathname);
    console.log('[wayl-payment] Extracted path:', path);
    console.log('[wayl-payment] Method:', req.method);

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !serviceRoleKey) {
      return Response.json(
        { error: 'Server not configured' },
        { status: 500, headers: corsHeaders }
      );
    }

    // Debug: Log before checking conditions
    console.log('[wayl-payment] Checking conditions - path:', path, 'method:', req.method);
    console.log('[wayl-payment] Path === "/":', path === '/');
    console.log('[wayl-payment] Path === "/create-payment-link":', path === '/create-payment-link');

    // ========== VERIFY MERCHANT TOKEN ==========
    if (path === '/verify-token' && req.method === 'GET') {
      console.log('[wayl-payment] Verifying merchant token...');
      
      try {
        const verifyRes = await fetch(`${WAYL_API_BASE}/verify-auth-key`, {
          method: 'GET',
          headers: {
            'X-WAYL-AUTHENTICATION': WAYL_MERCHANT_TOKEN,
          },
        });

        const verifyText = await verifyRes.text();
        console.log('[wayl-payment] Verify response status:', verifyRes.status);
        console.log('[wayl-payment] Verify response:', verifyText);

        return Response.json(
          {
            success: verifyRes.ok,
            status: verifyRes.status,
            response: verifyText,
            token_preview: WAYL_MERCHANT_TOKEN.substring(0, 20) + '...',
          },
          { status: 200, headers: corsHeaders }
        );
      } catch (e: any) {
        console.error('[wayl-payment] Error verifying token:', e);
        return Response.json(
          { error: 'Failed to verify token', details: e?.message ?? String(e) },
          { status: 500, headers: corsHeaders }
        );
      }
    }

    // ========== CREATE PAYMENT LINK ==========
    // Handle both '/create-payment-link' path and root path with POST
    if (req.method === 'POST' && (path === '/create-payment-link' || path === '/')) {
      console.log('[wayl-payment] Creating payment link...');
      console.log('[wayl-payment] Path matches, processing request...');
      
      try {
        // Read and parse request body
        console.log('[wayl-payment] Reading request body...');
        
        // Check if body exists
        const contentLength = req.headers.get('content-length');
        if (!contentLength || contentLength === '0') {
          console.error('[wayl-payment] No content-length or empty body');
          return new Response(
            JSON.stringify({ error: 'Request body is empty' }),
            {
              status: 400,
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            }
          );
        }
        
        let body: CreatePaymentLinkRequest;
        try {
          console.log('[wayl-payment] Attempting to parse JSON...');
          body = await req.json() as CreatePaymentLinkRequest;
          console.log('[wayl-payment] Body parsed successfully');
        } catch (jsonErr: any) {
          console.error('[wayl-payment] JSON parse error:', jsonErr);
          return new Response(
            JSON.stringify({ error: 'Invalid JSON in request body', details: jsonErr?.message ?? String(jsonErr) }),
            {
              status: 400,
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            }
          );
        }
        
        console.log('[wayl-payment] About to extract fields from body');
        const { merchant_id, amount, notes } = body;
        console.log('[wayl-payment] Fields extracted - merchant_id:', merchant_id, 'amount:', amount, 'type:', typeof amount);

        console.log('[wayl-payment] Starting validation checks');
        if (!merchant_id || !amount || amount <= 0) {
          console.log('[wayl-payment] Validation failed - missing merchant_id or invalid amount');
          return new Response(
            JSON.stringify({ error: 'merchant_id and amount (greater than 0) are required' }),
            {
              status: 400,
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            }
          );
        }
        console.log('[wayl-payment] Basic validation passed');

        // Wayl API requires minimum amount of 1000 IQD
        console.log('[wayl-payment] Checking minimum amount requirement...');
        if (amount < 1000) {
          console.log('[wayl-payment] Amount validation failed - amount:', amount, 'is less than 1000');
          console.log('[wayl-payment] Returning validation error response');
          return new Response(
            JSON.stringify({ error: 'Amount must be at least 1000 IQD' }),
            {
              status: 400,
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            }
          );
        }
        console.log('[wayl-payment] Amount validation passed');

        // Generate unique reference ID
        const referenceId = `hur_${merchant_id}_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
        
        // Get merchant info for customer details
        let merchantName = 'Merchant';
        let merchantPhone = '';
        try {
          const merchantRes = await fetch(`${supabaseUrl}/rest/v1/users?id=eq.${merchant_id}&select=name,phone`, {
            headers: {
              'apikey': serviceRoleKey,
              'Authorization': `Bearer ${serviceRoleKey}`,
            },
          });
          if (merchantRes.ok) {
            const merchants = await merchantRes.json();
            if (merchants && merchants.length > 0) {
              merchantName = merchants[0].name || merchantName;
              merchantPhone = merchants[0].phone || '';
            }
          }
        } catch (e) {
          console.log('[wayl-payment] Could not fetch merchant info:', e);
        }

        // Build webhook URL
        const webhookUrl = `${supabaseUrl}/functions/v1/wayl-payment/webhook`;
        
        // Build redirection URL (you can customize this)
        const redirectionUrl = `${supabaseUrl.replace('/supabase.co', '')}/payment-success?reference=${referenceId}`;

        // Create payment link via Wayl API
        const waylPayload = {
          referenceId: referenceId,
          total: amount,
          currency: 'IQD', // Required by Wayl API
          lineItem: [ // Note: singular "lineItem", not "lineItems"
            {
              label: 'شحن المحفظة - Wallet Top-up', // Required: string
              amount: amount, // Required: number
              type: 'increase', // Required: 'increase' | 'decrease'
              image: '', // Required: string (empty string if no image)
            },
          ],
          webhookUrl: webhookUrl,
          webhookSecret: WAYL_SECRET, // Required by Wayl API for webhook signature verification
          redirectionUrl: redirectionUrl,
          customer: {
            name: merchantName,
            phone: merchantPhone,
          },
        };

        console.log('[wayl-payment] Calling Wayl API to create link...');
        const waylRes = await fetch(`${WAYL_API_BASE}/links`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-WAYL-AUTHENTICATION': WAYL_MERCHANT_TOKEN,
          },
          body: JSON.stringify(waylPayload),
        });

        if (!waylRes.ok) {
          const errorText = await waylRes.text();
          console.error('[wayl-payment] Wayl API error:', waylRes.status, errorText);
          return Response.json(
            { error: 'Failed to create payment link', details: errorText },
            { status: 500, headers: corsHeaders }
          );
        }

        const waylDataRaw = await waylRes.json();
        console.log('[wayl-payment] Wayl API response (raw):', JSON.stringify(waylDataRaw));
        console.log('[wayl-payment] Wayl API response keys:', Object.keys(waylDataRaw || {}));
        
        // Wayl API wraps the response in a `data` property
        const waylData = (waylDataRaw as any).data || waylDataRaw;
        console.log('[wayl-payment] Extracted data object:', waylData);
        
        // Extract link information from the data object
        const linkId = waylData?.id || (waylDataRaw as any).id;
        const linkUrl = waylData?.url || (waylDataRaw as any).url;
        const linkCode = waylData?.code || (waylDataRaw as any).code;
        
        console.log('[wayl-payment] Payment link created - id:', linkId, 'code:', linkCode, 'url:', linkUrl);
        
        if (!linkId || !linkUrl) {
          console.error('[wayl-payment] Invalid Wayl response structure:', waylDataRaw);
          return Response.json(
            { error: 'Invalid response from payment gateway', details: 'Missing link ID or URL' },
            { status: 500, headers: corsHeaders }
          );
        }

        // Store pending topup in database
        const pendingTopupData = {
          merchant_id: merchant_id,
          amount: amount,
          wayl_reference_id: referenceId,
          wayl_link_id: linkId,
          wayl_link_url: linkUrl,
          status: 'pending',
          payment_method: 'wayl',
          notes: notes || null,
        };

        const insertRes = await fetch(`${supabaseUrl}/rest/v1/pending_topups`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': serviceRoleKey,
            'Authorization': `Bearer ${serviceRoleKey}`,
            'Prefer': 'return=representation',
          },
          body: JSON.stringify(pendingTopupData),
        });

        if (!insertRes.ok) {
          const errorText = await insertRes.text();
          console.error('[wayl-payment] Failed to store pending topup:', errorText);
          return Response.json(
            { error: 'Failed to store payment link', details: errorText },
            { status: 500, headers: corsHeaders }
          );
        }

        const pendingTopup = await insertRes.json();
        console.log('[wayl-payment] Pending topup stored:', pendingTopup[0]?.id);

        const responseData = {
          success: true,
          payment_url: linkUrl,
          reference_id: referenceId,
          wayl_link_id: linkId,
          wayl_link_code: linkCode,
          pending_topup_id: pendingTopup[0]?.id,
        };
        
        console.log('[wayl-payment] Preparing success response:', JSON.stringify(responseData));
        console.log('[wayl-payment] Returning response to client...');
        
        return new Response(
          JSON.stringify(responseData),
          {
            status: 200,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      } catch (e: any) {
        console.error('[wayl-payment] Error creating payment link:', e);
        console.error('[wayl-payment] Error stack:', e?.stack);
        return new Response(
          JSON.stringify({ error: 'Failed to create payment link', details: e?.message ?? String(e) }),
          {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }
    }

    // ========== WEBHOOK HANDLER ==========
    if (path === '/webhook' && req.method === 'POST') {
      console.log('[wayl-payment] Webhook received...');
      
      // Get signature from headers
      const signature = req.headers.get('x-wayl-signature-256');
      if (!signature) {
        console.error('[wayl-payment] Missing webhook signature');
        return new Response(
          JSON.stringify({ error: 'Missing signature' }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      // Read body as text for signature verification
      const bodyText = await req.text();
      console.log('[wayl-payment] Webhook body received, length:', bodyText.length);
      console.log('[wayl-payment] Webhook signature:', signature.substring(0, 20) + '...');
      console.log('[wayl-payment] Webhook body preview:', bodyText.substring(0, 200));

      // Verify signature
      const isValid = await verifyWebhookSignature(bodyText, signature, WAYL_SECRET);
      if (!isValid) {
        console.error('[wayl-payment] Invalid webhook signature');
        return new Response(
          JSON.stringify({ error: 'Invalid signature' }),
          {
            status: 401,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      console.log('[wayl-payment] Signature verified successfully');

      // Parse webhook payload
      let webhookData: WaylWebhookPayload;
      try {
        webhookData = JSON.parse(bodyText);
      } catch (e) {
        console.error('[wayl-payment] Failed to parse webhook JSON:', e);
        return new Response(
          JSON.stringify({ error: 'Invalid JSON', details: String(e) }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      console.log('[wayl-payment] Webhook data:', JSON.stringify(webhookData, null, 2));
      console.log('[wayl-payment] Webhook status:', webhookData.status);
      console.log('[wayl-payment] Webhook referenceId:', webhookData.referenceId);

      // Check if payment is completed
      if (webhookData.status !== 'completed') {
        console.log('[wayl-payment] Payment not completed yet, status:', webhookData.status);
        return new Response(
          JSON.stringify({ success: true, message: 'Payment not completed yet' }),
          {
            status: 200,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      console.log('[wayl-payment] Payment completed, processing topup...');
      console.log('[wayl-payment] Calling complete_wayl_topup with referenceId:', webhookData.referenceId);
      console.log('[wayl-payment] Payment amount from webhook:', webhookData.total);

      // Validate required fields
      if (!webhookData.referenceId) {
        console.error('[wayl-payment] Missing referenceId in webhook payload');
        return new Response(
          JSON.stringify({ error: 'Missing referenceId in webhook payload' }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      // Complete the topup - this will update the wallet balance
      const completeRes = await fetch(`${supabaseUrl}/rest/v1/rpc/complete_wayl_topup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': serviceRoleKey,
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          p_wayl_reference_id: webhookData.referenceId,
          p_webhook_data: webhookData,
        }),
      });

      console.log('[wayl-payment] complete_wayl_topup response status:', completeRes.status);

      if (!completeRes.ok) {
        const errorText = await completeRes.text();
        console.error('[wayl-payment] Failed to complete topup - Status:', completeRes.status);
        console.error('[wayl-payment] Error response:', errorText);
        return new Response(
          JSON.stringify({ error: 'Failed to complete topup', details: errorText }),
          {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      const result = await completeRes.json();
      console.log('[wayl-payment] complete_wayl_topup result:', JSON.stringify(result, null, 2));
      
      // Check if the wallet update was successful
      if (result.success === false) {
        console.error('[wayl-payment] Wallet update failed:', result.error);
        return new Response(
          JSON.stringify({ error: 'Wallet update failed', details: result.error }),
          {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      // Verify wallet_result exists and indicates success
      if (!result.wallet_result || result.wallet_result.success !== true) {
        console.error('[wayl-payment] Wallet update did not succeed:', result.wallet_result);
        return new Response(
          JSON.stringify({ 
            error: 'Wallet update did not succeed', 
            details: result.wallet_result 
          }),
          {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      // Verify wallet balance was actually updated
      const walletBalanceBefore = result.wallet_result.balance_before;
      const walletBalanceAfter = result.wallet_result.balance_after;
      const amountAdded = result.wallet_result.amount;

      console.log('[wayl-payment] Wallet balance verification:');
      console.log('[wayl-payment]   Balance before:', walletBalanceBefore);
      console.log('[wayl-payment]   Amount added:', amountAdded);
      console.log('[wayl-payment]   Balance after:', walletBalanceAfter);
      console.log('[wayl-payment]   Expected balance:', walletBalanceBefore + amountAdded);

      if (walletBalanceAfter !== walletBalanceBefore + amountAdded) {
        console.error('[wayl-payment] Balance mismatch detected!');
        console.error('[wayl-payment] Expected:', walletBalanceBefore + amountAdded, 'Got:', walletBalanceAfter);
        // Still return success since the transaction was recorded, but log the issue
      }

      console.log('[wayl-payment] ✅ Wallet balance updated successfully');
      console.log('[wayl-payment] ✅ Transaction ID:', result.wallet_result.transaction_id);
      console.log('[wayl-payment] ✅ New balance:', walletBalanceAfter, 'IQD');

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Payment processed successfully and wallet updated',
          result: {
            wallet_updated: true,
            balance_before: walletBalanceBefore,
            balance_after: walletBalanceAfter,
            amount_added: amountAdded,
            transaction_id: result.wallet_result.transaction_id,
            pending_topup_id: result.pending_topup_id,
          }
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // ========== GET PENDING TOPUP STATUS ==========
    if (path === '/status' && req.method === 'GET') {
      const referenceId = url.searchParams.get('reference_id');
      if (!referenceId) {
        return new Response(
          JSON.stringify({ error: 'reference_id is required' }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      const statusRes = await fetch(
        `${supabaseUrl}/rest/v1/pending_topups?wayl_reference_id=eq.${referenceId}&select=*`,
        {
          headers: {
            'apikey': serviceRoleKey,
            'Authorization': `Bearer ${serviceRoleKey}`,
          },
        }
      );

      if (!statusRes.ok) {
        return new Response(
          JSON.stringify({ error: 'Failed to get status' }),
          {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      const data = await statusRes.json();
      return new Response(
        JSON.stringify({ success: true, pending_topup: data[0] || null }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // ========== TEST WEBHOOK ENDPOINT (simulates webhook without payment) ==========
    if (path === '/test-webhook' && req.method === 'POST') {
      console.log('[wayl-payment] Test webhook endpoint called...');
      
      const body = await req.json();
      const referenceId = body.reference_id;
      
      if (!referenceId) {
        return new Response(
          JSON.stringify({ error: 'reference_id is required' }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      // First, check if pending topup exists
      const checkRes = await fetch(
        `${supabaseUrl}/rest/v1/pending_topups?wayl_reference_id=eq.${referenceId}&select=*`,
        {
          headers: {
            'apikey': serviceRoleKey,
            'Authorization': `Bearer ${serviceRoleKey}`,
          },
        }
      );

      const pendingData = await checkRes.json();
      if (!pendingData || pendingData.length === 0) {
        return new Response(
          JSON.stringify({ 
            error: 'Pending topup not found', 
            reference_id: referenceId,
            hint: 'Make sure you create a payment link first using the create-payment-link endpoint'
          }),
          {
            status: 404,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      const pendingTopup = pendingData[0];
      console.log('[wayl-payment] Found pending topup:', pendingTopup);

      // Simulate webhook payload
      const simulatedWebhook: WaylWebhookPayload = {
        id: pendingTopup.wayl_link_id || 'test-id',
        code: 'TEST',
        referenceId: referenceId,
        status: 'completed',
        total: pendingTopup.amount,
        paymentMethod: 'test',
        customer: {
          name: 'Test Customer',
          phone: '1234567890',
        },
      };

      console.log('[wayl-payment] Simulating webhook with payload:', JSON.stringify(simulatedWebhook, null, 2));

      // Call complete_wayl_topup function directly (bypassing signature verification)
      const completeRes = await fetch(`${supabaseUrl}/rest/v1/rpc/complete_wayl_topup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': serviceRoleKey,
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          p_wayl_reference_id: referenceId,
          p_webhook_data: simulatedWebhook,
        }),
      });

      console.log('[wayl-payment] complete_wayl_topup response status:', completeRes.status);

      if (!completeRes.ok) {
        const errorText = await completeRes.text();
        console.error('[wayl-payment] Failed to complete topup:', errorText);
        return new Response(
          JSON.stringify({ 
            success: false,
            error: 'Failed to complete topup', 
            details: errorText,
            pending_topup: pendingTopup
          }),
          {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      const result = await completeRes.json();
      console.log('[wayl-payment] Test webhook completed successfully:', JSON.stringify(result, null, 2));

      // Get updated wallet balance
      const walletRes = await fetch(
        `${supabaseUrl}/rest/v1/merchant_wallets?merchant_id=eq.${pendingTopup.merchant_id}&select=*`,
        {
          headers: {
            'apikey': serviceRoleKey,
            'Authorization': `Bearer ${serviceRoleKey}`,
          },
        }
      );

      const walletData = await walletRes.json();
      
      return new Response(
        JSON.stringify({ 
          success: true,
          message: 'Test webhook processed successfully',
          pending_topup: pendingTopup,
          result,
          wallet: walletData[0] || null,
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // ========== MANUAL TEST ENDPOINT (for debugging) ==========
    if (path === '/test-complete' && req.method === 'POST') {
      console.log('[wayl-payment] Manual test endpoint called...');
      
      const body = await req.json();
      const referenceId = body.reference_id;
      
      if (!referenceId) {
        return new Response(
          JSON.stringify({ error: 'reference_id is required' }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      console.log('[wayl-payment] Manually completing topup for referenceId:', referenceId);

      const completeRes = await fetch(`${supabaseUrl}/rest/v1/rpc/complete_wayl_topup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': serviceRoleKey,
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          p_wayl_reference_id: referenceId,
          p_webhook_data: { status: 'completed', referenceId },
        }),
      });

      const result = await completeRes.json();
      
      return new Response(
        JSON.stringify({ 
          success: completeRes.ok, 
          result,
          message: completeRes.ok ? 'Manual completion successful' : 'Manual completion failed'
        }),
        {
          status: completeRes.ok ? 200 : 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // Unknown endpoint
    console.log('[wayl-payment] Unknown endpoint - path:', path, 'method:', req.method);
    return new Response(
      JSON.stringify({ error: 'Unknown endpoint', path: path, method: req.method }),
      {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (e: any) {
    console.error('[wayl-payment] ==== UNCAUGHT ERROR ====');
    console.error('[wayl-payment] Error:', e);
    console.error('[wayl-payment] Stack:', e?.stack);
    
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: e?.message ?? String(e) }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

// Webhook signature verification function
async function verifyWebhookSignature(data: string, signature: string, secret: string): Promise<boolean> {
  try {
    // Import secret key for HMAC
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    // Sign the data
    const signatureBuffer = encoder.encode(data);
    const signedData = await crypto.subtle.sign('HMAC', cryptoKey, signatureBuffer);
    
    // Convert to hex string
    const calculatedSignatureArray = Array.from(new Uint8Array(signedData));
    const calculatedSignature = calculatedSignatureArray.map(b => b.toString(16).padStart(2, '0')).join('');

    // Compare signatures (constant-time comparison)
    const receivedSignature = signature.toLowerCase();
    const calculatedSignatureLower = calculatedSignature.toLowerCase();

    if (receivedSignature.length !== calculatedSignatureLower.length) {
      console.log('[wayl-payment] Signature length mismatch');
      return false;
    }

    // Constant-time comparison
    let isValid = true;
    for (let i = 0; i < receivedSignature.length; i++) {
      if (receivedSignature[i] !== calculatedSignatureLower[i]) {
        isValid = false;
      }
    }
    
    if (!isValid) {
      console.log('[wayl-payment] Signature mismatch');
      console.log('[wayl-payment] Received:', signature.substring(0, 20) + '...');
      console.log('[wayl-payment] Calculated:', calculatedSignature.substring(0, 20) + '...');
    }

    return isValid;
  } catch (e) {
    console.error('[wayl-payment] Signature verification error:', e);
    return false;
  }
}

