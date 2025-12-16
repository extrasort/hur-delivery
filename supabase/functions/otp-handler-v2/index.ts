// Optimized OTP Handler with proper Supabase Admin Auth API usage
// This eliminates the password workaround and uses direct session creation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("[otp-handler-v2] Module loaded at:", new Date().toISOString());

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface SendOtpRequest {
  action: "send";
  phoneNumber: string;
  purpose?: "signup" | "reset_password" | "delete_account";
}

interface AuthenticateRequest {
  action: "authenticate";
  phoneNumber: string;
  code: string;
}

type OtpRequest = SendOtpRequest | AuthenticateRequest;

function normalizePhone(phone: string): string {
  return phone.replace(/^\+/, "").replace(/[^\d]/g, "");
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const otpiqApiKey = Deno.env.get('OTPIQ_API_KEY')!;

    // Create admin client
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

    const body = await req.json() as OtpRequest;
    const action = body.action;

    console.log(`[otp-handler-v2] Action: ${action}`);

    // ========== SEND OTP ==========
    if (action === "send") {
      const { phoneNumber, purpose = "signup" } = body as SendOtpRequest;
      const phone = normalizePhone(phoneNumber);

      console.log(`[otp-handler-v2] Sending OTP to: ${phone}, purpose: ${purpose}`);

      // Generate OTP code
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 3 * 60 * 1000); // 3 minutes

      // Store in database
      const { error: dbError } = await supabaseAdmin
        .from('otp_verifications')
        .insert({
          phone,
          code,
          purpose,
          expires_at: expiresAt.toISOString(),
          consumed: false,
        });

      if (dbError) {
        console.error('[otp-handler-v2] Failed to store OTP:', dbError);
        return Response.json(
          { error: 'Failed to generate OTP' },
          { status: 500, headers: corsHeaders }
        );
      }

      console.log('[otp-handler-v2] OTP stored in database');

      // Send via Otpiq
      try {
        const otpiqResponse = await fetch('https://otpiq.com/api/v1/sms', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${otpiqApiKey}`,
          },
          body: JSON.stringify({
            recipient: phone,
            message: `Your Hur Delivery verification code is: ${code}`,
          }),
        });

        if (!otpiqResponse.ok) {
          const errorText = await otpiqResponse.text();
          console.error('[otp-handler-v2] Otpiq API error:', errorText);
          return Response.json(
            { error: 'Failed to send OTP' },
            { status: 500, headers: corsHeaders }
          );
        }

        console.log('[otp-handler-v2] ✅ OTP sent successfully');
        return Response.json(
          { success: true, message: 'OTP sent successfully' },
          { status: 200, headers: corsHeaders }
        );
      } catch (error) {
        console.error('[otp-handler-v2] Error sending OTP:', error);
        return Response.json(
          { error: 'Failed to send OTP' },
          { status: 500, headers: corsHeaders }
        );
      }
    }

    // ========== AUTHENTICATE (Verify OTP & Create Session) ==========
    if (action === "authenticate") {
      const { phoneNumber, code } = body as AuthenticateRequest;
      const phone = normalizePhone(phoneNumber);

      console.log(`[otp-handler-v2] Authenticating phone: ${phone}`);

      // 1. Verify OTP
      const { data: otpRecords, error: otpError } = await supabaseAdmin
        .from('otp_verifications')
        .select('*')
        .eq('phone', phone)
        .eq('consumed', false)
        .order('created_at', { ascending: false })
        .limit(1);

      if (otpError || !otpRecords || otpRecords.length === 0) {
        console.error('[otp-handler-v2] No valid OTP found');
        return Response.json(
          { error: 'No valid OTP found. Please request a new code.' },
          { status: 400, headers: corsHeaders }
        );
      }

      const otpRecord = otpRecords[0];

      // Check if expired
      if (new Date(otpRecord.expires_at) < new Date()) {
        console.error('[otp-handler-v2] OTP expired');
        return Response.json(
          { error: 'OTP expired. Please request a new code.' },
          { status: 400, headers: corsHeaders }
        );
      }

      // Verify code
      if (String(otpRecord.code) !== String(code)) {
        console.error('[otp-handler-v2] Invalid OTP code');
        return Response.json(
          { error: 'Invalid OTP code' },
          { status: 400, headers: corsHeaders }
        );
      }

      console.log('[otp-handler-v2] ✅ OTP verified successfully');

      // 2. Mark OTP as consumed
      await supabaseAdmin
        .from('otp_verifications')
        .update({ consumed: true })
        .eq('id', otpRecord.id);

      // 3. Find or create user profile
      const { data: existingProfile } = await supabaseAdmin
        .from('users')
        .select('id, phone, email, role, name')
        .or(`phone.eq.${phone},phone.eq.+${phone}`)
        .maybeSingle();

      let userId: string;
      let email: string;
      let role: string;
      let hasProfile: boolean;

      if (existingProfile) {
        // Existing user
        userId = existingProfile.id;
        email = existingProfile.email || `${phone}@hur.delivery`;
        role = existingProfile.role || 'user';
        hasProfile = true;

        console.log(`[otp-handler-v2] ✅ Found existing profile: ${userId}`);

        // Check if auth user exists
        const { data: authUser } = await supabaseAdmin.auth.admin.getUserById(userId);

        if (!authUser.user) {
          // Profile exists but no auth user - create auth user
          console.log('[otp-handler-v2] Creating auth user for existing profile');
          const { data: newAuthUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
            id: userId, // Use same ID as profile
            email,
            phone,
            email_confirm: true,
            phone_confirm: true,
            user_metadata: {
              phone,
              role,
            },
          });

          if (createError) {
            console.error('[otp-handler-v2] Failed to create auth user:', createError);
            return Response.json(
              { error: 'Failed to create authentication' },
              { status: 500, headers: corsHeaders }
            );
          }
        } else {
          // Update phone confirmation if needed
          if (!authUser.user.phone_confirmed_at) {
            await supabaseAdmin.auth.admin.updateUserById(userId, {
              phone_confirm: true,
            });
          }
        }
      } else {
        // New user - create profile first
        email = `${phone}@hur.delivery`;
        role = 'user';
        hasProfile = false;

        console.log('[otp-handler-v2] Creating new user profile');

        // Create auth user first to get UUID
        const { data: newAuthUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email,
          phone,
          email_confirm: true,
          phone_confirm: true,
          user_metadata: {
            phone,
            role,
          },
        });

        if (createError || !newAuthUser.user) {
          console.error('[otp-handler-v2] Failed to create auth user:', createError);
          return Response.json(
            { error: 'Failed to create user' },
            { status: 500, headers: corsHeaders }
          );
        }

        userId = newAuthUser.user.id;
        console.log(`[otp-handler-v2] ✅ Created new auth user: ${userId}`);
      }

      // 4. Create an authenticated session for the user
      // Use Admin API to sign in as this user and get session tokens
      console.log('[otp-handler-v2] Creating authenticated session...');
      
      // Create a session by signing in with the admin client
      // This is the proper way: update user to confirmed, then use signInWithPassword with a temporary password
      // OR use the OTP table to store a one-time session token
      
      // Best approach: Use admin API to create a session token directly
      try {
        // Option 1: Generate a magic link token
        const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
          type: 'magiclink',
          email,
        });

        if (linkError || !linkData) {
          console.error('[otp-handler-v2] Failed to generate link:', linkError);
          return Response.json(
            { error: 'Failed to create session' },
            { status: 500, headers: corsHeaders }
          );
        }

        // Extract the hashed token from the action link
        const actionLink = linkData.properties.action_link;
        const tokenMatch = actionLink.match(/[?&]token=([^&]+)/);
        const hashedToken = tokenMatch ? tokenMatch[1] : null;

        if (!hashedToken) {
          console.error('[otp-handler-v2] No token found in magic link');
          return Response.json(
            { error: 'Failed to generate auth token' },
            { status: 500, headers: corsHeaders }
          );
        }

        console.log('[otp-handler-v2] ✅ Auth token generated');

        // Option 2: Use admin client to directly exchange the token for a session
        // Verify the OTP token using the generated hashed token
        const { data: sessionData, error: verifyError } = await supabaseAdmin.auth.verifyOtp({
          token_hash: hashedToken,
          type: 'email',
        });

        if (verifyError || !sessionData.session) {
          console.error('[otp-handler-v2] Failed to create session from token:', verifyError);
          
          // Fallback: Return userId and let client create session
          return Response.json(
            {
              success: true,
              authUserId: userId,
              email,
              phone,
              role,
              hasProfile,
              // Client will need to sign in
              requiresSignIn: true,
            },
            { status: 200, headers: corsHeaders }
          );
        }

        console.log('[otp-handler-v2] ✅ Session created successfully');

        // Return full session data
        return Response.json(
          {
            success: true,
            authUserId: userId,
            email,
            phone,
            role,
            hasProfile,
            // Return session tokens
            session: {
              access_token: sessionData.session.access_token,
              refresh_token: sessionData.session.refresh_token,
              expires_in: sessionData.session.expires_in,
              expires_at: sessionData.session.expires_at,
              token_type: sessionData.session.token_type,
            },
            user: sessionData.user,
          },
          { status: 200, headers: corsHeaders }
        );
      } catch (sessionError) {
        console.error('[otp-handler-v2] Error creating session:', sessionError);
        
        // Return user data and let client handle sign in
        return Response.json(
          {
            success: true,
            authUserId: userId,
            email,
            phone,
            role,
            hasProfile,
            requiresSignIn: true,
          },
          { status: 200, headers: corsHeaders }
        );
      }
    }

    return Response.json(
      { error: 'Invalid action' },
      { status: 400, headers: corsHeaders }
    );

  } catch (error) {
    console.error('[otp-handler-v2] Error:', error);
    return Response.json(
      { error: 'Internal server error', message: error.message },
      { status: 500, headers: corsHeaders }
    );
  }
});

