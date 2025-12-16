/**
 * Test Login Edge Function for Hur Delivery
 * 
 * Handles test number authentication:
 * - Driver test numbers: 96478000000XX (where XX is 00-99)
 * - Merchant test numbers: 96477000000XX (where XX is 00-99)
 * 
 * Flow:
 * 1. Validate test number format
 * 2. Determine role from number prefix
 * 3. Create/update auth account
 * 4. Create/update user profile with verified status
 * 5. Return authenticated session
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

console.log("[test-login] Module loaded at:", new Date().toISOString());

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Helper: Normalize phone number
function normalizePhone(phone: string): string {
  return phone.replace(/^\+/, "").replace(/[^\d]/g, "");
}

// Helper: Check if phone is a test number
function isTestNumber(phone: string): { isTest: boolean; role?: 'driver' | 'merchant' } {
  const normalized = normalizePhone(phone);
  
  // Driver test numbers: 96478000000XX
  if (normalized.startsWith('96478000000') && normalized.length === 13) {
    const lastTwo = normalized.slice(-2);
    if (/^\d{2}$/.test(lastTwo)) {
      return { isTest: true, role: 'driver' };
    }
  }
  
  // Merchant test numbers: 96477000000XX
  if (normalized.startsWith('96477000000') && normalized.length === 13) {
    const lastTwo = normalized.slice(-2);
    if (/^\d{2}$/.test(lastTwo)) {
      return { isTest: true, role: 'merchant' };
    }
  }
  
  return { isTest: false };
}

// Helper: Generate secure random password
function generateSecurePassword(): string {
  return crypto.randomUUID() + crypto.randomUUID(); // 72 chars, highly secure
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Create admin client (for database operations)
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Create regular client (for sign-in operations)
    const supabaseClient = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { phoneNumber, code } = body;

    if (!phoneNumber) {
      return Response.json(
        { error: 'phoneNumber is required' },
        { status: 400, headers: corsHeaders }
      );
    }

    // Verify OTP is 000000 for test numbers
    if (code && code !== '000000') {
      return Response.json(
        { error: 'Invalid OTP. Test numbers use OTP: 000000' },
        { status: 400, headers: corsHeaders }
      );
    }

    const phone = normalizePhone(phoneNumber);
    console.log(`[test-login] Processing test number: ${phone}`);

    // Validate test number
    const testCheck = isTestNumber(phone);
    if (!testCheck.isTest || !testCheck.role) {
      return Response.json(
        { error: 'Invalid test number format. Test numbers must start with 96478000000XX (driver) or 96477000000XX (merchant)' },
        { status: 400, headers: corsHeaders }
      );
    }

    const role = testCheck.role;
    console.log(`[test-login] Detected role: ${role}`);

    // Generate test user name based on number
    const lastTwo = phone.slice(-2);
    const testUserName = role === 'driver' 
      ? `Test Driver ${lastTwo}`
      : `Test Merchant ${lastTwo}`;

    const email = `${phone}@hur.delivery`;
    const password = generateSecurePassword();

    // Check if user profile already exists
    const phoneWithPlus = phone.startsWith('+') ? phone : `+${phone}`;
    const phoneWithoutPlus = phone.startsWith('+') ? phone.substring(1) : phone;
    
    const { data: existingProfile, error: profileError } = await supabaseAdmin
      .from('users')
      .select('id, phone, role, name')
      .or(`phone.eq.${phoneWithoutPlus},phone.eq.${phoneWithPlus}`)
      .maybeSingle();
    
    if (profileError) {
      console.error('[test-login] Error finding profile:', profileError);
    }

    let userId: string;
    let hasProfile: boolean;

    // Check if auth user exists
    const { data: { users: authUsers }, error: listError } = await supabaseAdmin.auth.admin.listUsers();
    const orphanedAuthUser = authUsers?.find(u => 
      u.phone === phoneWithoutPlus || u.phone === phoneWithPlus || u.email === email
    );

    if (existingProfile) {
      // CASE 1: Profile exists - update it and ensure auth exists
      userId = existingProfile.id;
      hasProfile = true;

      console.log(`[test-login] ✅ Found existing profile: ${userId} (${existingProfile.role})`);

      // Update profile to ensure it's verified and has correct role
      const { error: updateError } = await supabaseAdmin
        .from('users')
        .update({
          role: role,
          manual_verified: true,
          verification_status: 'approved',
          is_active: true,
          name: existingProfile.name || testUserName,
          updated_at: new Date().toISOString(),
        })
        .eq('id', userId);

      if (updateError) {
        console.error('[test-login] Failed to update profile:', updateError);
        return Response.json(
          { error: 'Failed to update profile' },
          { status: 500, headers: corsHeaders }
        );
      }

      // Check if auth user exists with the profile's ID
      const { data: authUser, error: getUserError } = await supabaseAdmin.auth.admin.getUserById(userId);

      if (getUserError || !authUser.user) {
        // Auth user doesn't exist for this profile ID
        if (orphanedAuthUser && orphanedAuthUser.id !== userId) {
          console.log(`[test-login] 🗑️  Found mismatched auth user (${orphanedAuthUser.id}), deleting before creating correct one`);
          await supabaseAdmin.auth.admin.deleteUser(orphanedAuthUser.id);
        }
        
        // Create auth user with the profile's ID
        console.log('[test-login] Creating auth user for existing profile');
        const { error: createError } = await supabaseAdmin.auth.admin.createUser({
          id: userId,
          email,
          phone,
          password,
          email_confirm: true,
          phone_confirm: true,
          user_metadata: { phone, role, secure_password: password },
        });

        if (createError) {
          console.error('[test-login] Failed to create auth user:', createError);
          return Response.json(
            { error: 'Failed to create authentication' },
            { status: 500, headers: corsHeaders }
          );
        }
      } else {
        // Update existing auth user
        console.log('[test-login] Updating auth user password');
        const { error: updateAuthError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
          password,
          phone_confirm: true,
          email_confirm: true,
          user_metadata: { phone, role, secure_password: password },
        });

        if (updateAuthError) {
          console.error('[test-login] Failed to update auth user:', updateAuthError);
          return Response.json(
            { error: 'Failed to update authentication' },
            { status: 500, headers: corsHeaders }
          );
        }
      }
    } else if (orphanedAuthUser) {
      // CASE 2: Auth user exists but NO profile - DELETE and recreate
      console.log(`[test-login] ⚠️  Found orphaned auth user (no profile): ${orphanedAuthUser.id}`);
      console.log('[test-login] 🗑️  Deleting orphaned auth user to allow fresh signup');
      
      const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(orphanedAuthUser.id);
      
      if (deleteError) {
        console.error('[test-login] Failed to delete orphaned auth user:', deleteError);
        return Response.json(
          { error: 'Account exists but is incomplete. Please contact support.' },
          { status: 500, headers: corsHeaders }
        );
      }
      
      // Create fresh auth user
      hasProfile = false;

      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email,
        phone,
        password,
        email_confirm: true,
        phone_confirm: true,
        user_metadata: { phone, role, secure_password: password },
      });

      if (createError || !newUser.user) {
        console.error('[test-login] Failed to create user after cleanup:', createError);
        return Response.json(
          { error: 'Failed to create user' },
          { status: 500, headers: corsHeaders }
        );
      }

      userId = newUser.user.id;
      console.log(`[test-login] ✅ Created fresh user after cleanup: ${userId}`);
    } else {
      // CASE 3: Completely new user - create auth user
      hasProfile = false;

      console.log('[test-login] 📝 Creating new test user (no existing profile or auth)');

      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email,
        phone,
        password,
        email_confirm: true,
        phone_confirm: true,
        user_metadata: { phone, role, secure_password: password },
      });

      if (createError || !newUser.user) {
        console.error('[test-login] Failed to create user:', createError);
        return Response.json(
          { error: 'Failed to create user' },
          { status: 500, headers: corsHeaders }
        );
      }

      userId = newUser.user.id;
      console.log(`[test-login] ✅ Created new user: ${userId}`);
    }

    // Create or update profile if it doesn't exist
    if (!hasProfile) {
      console.log('[test-login] Creating user profile...');
      
      const profileData: any = {
        id: userId,
        phone: phoneWithoutPlus,
        name: testUserName,
        role: role,
        manual_verified: true,
        verification_status: 'approved',
        is_active: true,
        is_online: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      // Add role-specific defaults
      if (role === 'merchant') {
        profileData.store_name = `Test Store ${lastTwo}`;
        profileData.address = 'Test Address';
      } else if (role === 'driver') {
        profileData.vehicle_type = 'motorcycle'; // Default vehicle type
        profileData.has_driving_license = true;
        profileData.owns_vehicle = true;
      }

      const { error: profileCreateError } = await supabaseAdmin
        .from('users')
        .insert(profileData);

      if (profileCreateError) {
        console.error('[test-login] Failed to create profile:', profileCreateError);
        // Don't fail - profile might already exist from a race condition
        // Try to update instead
        const { error: updateError } = await supabaseAdmin
          .from('users')
          .update(profileData)
          .eq('id', userId);

        if (updateError) {
          console.error('[test-login] Failed to update profile after insert error:', updateError);
          return Response.json(
            { error: 'Failed to create profile' },
            { status: 500, headers: corsHeaders }
          );
        }
      }

      console.log('[test-login] ✅ Profile created/updated successfully');
    }

    // Sign in to get session tokens
    console.log('[test-login] Creating authenticated session');
    
    const { data: signInData, error: signInError } = await supabaseClient.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError || !signInData.session) {
      console.error('[test-login] Failed to sign in:', signInError);
      return Response.json(
        { error: 'Failed to create session' },
        { status: 500, headers: corsHeaders }
      );
    }

    console.log('[test-login] ✅ Session created successfully');

    // Return authenticated session
    return Response.json(
      {
        success: true,
        authUserId: userId,
        email,
        phone,
        role,
        hasProfile: true, // Always true after profile creation
        testMode: true,
        session: {
          access_token: signInData.session.access_token,
          refresh_token: signInData.session.refresh_token,
          expires_in: signInData.session.expires_in,
          expires_at: signInData.session.expires_at,
          token_type: signInData.session.token_type,
        },
        user: signInData.user,
      },
      { status: 200, headers: corsHeaders }
    );

  } catch (error: any) {
    console.error('[test-login] Error:', error);
    return Response.json(
      { error: 'Internal server error', message: error.message },
      { status: 500, headers: corsHeaders }
    );
  }
});

