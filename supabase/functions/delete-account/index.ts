// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

console.log('[delete-account] Module loaded at:', new Date().toISOString());

interface DeleteAccountRequest {
  phoneNumber: string;
  code: string;
}

function normalizePhone(input: string): string {
  let cleaned = input.replace(/\D/g, '');
  if (cleaned.startsWith('0')) cleaned = `964${cleaned.slice(1)}`;
  if (!cleaned.startsWith('964')) cleaned = `964${cleaned}`;
  return cleaned;
}

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  console.log('[delete-account] ==== HANDLER CALLED ====');
  console.log('[delete-account] Method:', req.method);
  console.log('[delete-account] URL:', req.url);

  try {
    // Handle OPTIONS request for CORS
    if (req.method === 'OPTIONS') {
      return new Response('ok', { status: 200, headers: corsHeaders });
    }

    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405, headers: corsHeaders });
    }

    const bodyText = await req.text();
    console.log('[delete-account] Body text received, length:', bodyText.length);
    
    let raw: any;
    try {
      raw = JSON.parse(bodyText);
      console.log('[delete-account] JSON parsed successfully');
    } catch (jsonErr) {
      console.error('[delete-account] JSON parse error:', jsonErr);
      return Response.json(
        { error: 'Invalid JSON in request body', details: String(jsonErr) },
        { status: 400, headers: corsHeaders }
      );
    }
    
    const body = raw as DeleteAccountRequest;
    const { phoneNumber, code } = body;

    if (!phoneNumber || !code) {
      return Response.json(
        { error: 'phoneNumber and code are required' },
        { status: 400, headers: corsHeaders }
      );
    }

    const phone = normalizePhone(phoneNumber);
    console.log('[delete-account] Normalized phone:', phone);

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !serviceRoleKey) {
      return Response.json(
        { error: 'Server not configured' },
        { status: 500, headers: corsHeaders }
      );
    }

    // Step 1: Verify OTP
    console.log('[delete-account] Verifying OTP...');
    const queryUrl = new URL(`${supabaseUrl}/rest/v1/otp_verifications`);
    queryUrl.searchParams.set('phone', `eq.${phone}`);
    queryUrl.searchParams.set('purpose', `eq.delete_account`);
    queryUrl.searchParams.set('consumed', `eq.false`);
    queryUrl.searchParams.set('order', 'created_at.desc');
    queryUrl.searchParams.set('limit', '1');

    const fetchRes = await fetch(queryUrl.toString(), {
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
    });

    if (!fetchRes.ok) {
      const t = await fetchRes.text();
      console.error('[delete-account] Failed to query OTP', fetchRes.status, t);
      return Response.json(
        { error: 'Failed to verify OTP', details: t },
        { status: 500, headers: corsHeaders }
      );
    }

    const rows = await fetchRes.json();
    const otp = rows?.[0];

    if (!otp) {
      console.error('[delete-account] No OTP found for phone', phone);
      return Response.json(
        { error: 'No OTP found for this phone number. Please request a new OTP.' },
        { status: 400, headers: corsHeaders }
      );
    }

    const expiresAt = new Date(otp.expires_at).getTime();
    const now = Date.now();
    if (expiresAt < now) {
      console.error('[delete-account] OTP expired', { expiresAt, now, diff: now - expiresAt });
      return Response.json(
        { error: 'OTP expired. Please request a new OTP.' },
        { status: 400, headers: corsHeaders }
      );
    }

    const codeMatch = String(otp.code) === String(code);
    if (!codeMatch) {
      console.error('[delete-account] Invalid OTP code', { expected: otp.code, received: code });
      return Response.json(
        { error: 'Invalid OTP code' },
        { status: 400, headers: corsHeaders }
      );
    }
    console.log('[delete-account] OTP verified successfully');

    // Consume OTP
    await fetch(`${supabaseUrl}/rest/v1/otp_verifications?id=eq.${otp.id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({ consumed: true }),
    });

    // Step 2: Find auth user by phone
    const emailPrimary = `${phone}@hur.delivery`;
    
    let authUser: any = null;
    
    // Try primary email
    try {
      const getUserRes = await fetch(`${supabaseUrl}/auth/v1/admin/users?email=${encodeURIComponent(emailPrimary)}`, {
        method: 'GET',
        headers: {
          'apikey': serviceRoleKey,
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
      });

      if (getUserRes.ok) {
        const userData = await getUserRes.json();
        if (userData && userData.users && Array.isArray(userData.users) && userData.users.length > 0) {
          const foundUser = userData.users[0];
          
          // CRITICAL: Verify phone matches before allowing account deletion
          const foundUserPhone = foundUser.user_metadata?.phone || foundUser.phone;
          const phoneMatches = foundUserPhone && (
            foundUserPhone === phone || 
            foundUserPhone === `+${phone}` || 
            foundUserPhone === phone.replace(/^\+/, "")
          );
          
          if (!foundUserPhone) {
            console.log('[delete-account] ⚠️ Found auth user but NO phone in metadata!');
            console.log('[delete-account] Cannot verify this is the correct user');
            console.log('[delete-account] Skipping - will not delete unverified account');
            // Don't use this user - we can't verify it's the same person
          } else if (!phoneMatches) {
            console.log('[delete-account] ⚠️ Found auth user but phone doesn\'t match!');
            console.log('[delete-account] Found user phone:', foundUserPhone, 'Current phone:', phone);
            console.log('[delete-account] Skipping - will not delete wrong account');
            // Don't use this user - it's for a different phone number
          } else {
            // Phone matches - safe to delete this user
            authUser = foundUser;
            console.log('[delete-account] ✅ Found user by primary email (phone verified):', authUser.id, 'Phone:', foundUserPhone);
          }
        }
      }
    } catch (e) {
      console.log('[delete-account] Error querying primary email:', e);
    }

    if (!authUser) {
      console.error('[delete-account] User not found in auth system');
      return Response.json(
        { error: 'User not found. Account may have already been deleted.' },
        { status: 404, headers: corsHeaders }
      );
    }

    const userId = authUser.id;
    console.log('[delete-account] Found user ID:', userId);

    // Step 3: Delete user data from public.users table
    console.log('[delete-account] Deleting user data from users table...');
    const deleteUserRes = await fetch(`${supabaseUrl}/rest/v1/users?id=eq.${userId}`, {
      method: 'DELETE',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Prefer': 'return=minimal',
      },
    });

    if (!deleteUserRes.ok) {
      const text = await deleteUserRes.text();
      console.error('[delete-account] Failed to delete user data:', text);
      // Continue anyway - try to delete auth user
    } else {
      console.log('[delete-account] ✅ User data deleted from users table');
    }

    // Step 4: Delete device sessions
    console.log('[delete-account] Deleting device sessions...');
    const deleteSessionsRes = await fetch(`${supabaseUrl}/rest/v1/device_sessions?user_id=eq.${userId}`, {
      method: 'DELETE',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Prefer': 'return=minimal',
      },
    });
    if (deleteSessionsRes.ok) {
      console.log('[delete-account] ✅ Device sessions deleted');
    }

    // Step 5: Delete auth user (this will cascade to related data)
    console.log('[delete-account] Deleting auth user...');
    const deleteAuthRes = await fetch(`${supabaseUrl}/auth/v1/admin/users/${userId}`, {
      method: 'DELETE',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
    });

    if (!deleteAuthRes.ok) {
      const text = await deleteAuthRes.text();
      console.error('[delete-account] Failed to delete auth user:', text);
      return Response.json(
        { error: 'Failed to delete account', details: text },
        { status: 500, headers: corsHeaders }
      );
    }

    console.log('[delete-account] ✅ Account deleted successfully');

    return Response.json(
      { success: true, message: 'Account deleted successfully' },
      { status: 200, headers: corsHeaders }
    );
  } catch (e: any) {
    console.error('[delete-account] ==== UNCAUGHT ERROR ====');
    console.error('[delete-account] Error type:', e?.constructor?.name ?? typeof e);
    console.error('[delete-account] Error message:', e?.message ?? String(e));
    console.error('[delete-account] Error stack:', e?.stack);
    
    return Response.json(
      { error: e?.message ?? 'Unknown error', details: String(e) },
      { status: 500, headers: corsHeaders }
    );
  }
});

