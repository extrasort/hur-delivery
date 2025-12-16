// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { timingSafeEqual } from "https://deno.land/std@0.168.0/crypto/timing_safe_equal.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function toHex(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return toHex(hash);
}

function safeCompare(a: string | undefined | null, b: string | undefined | null): boolean {
  if (!a || !b) return false;
  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);

  if (aBytes.length !== bBytes.length) {
    return false;
  }

  return timingSafeEqual(aBytes, bBytes);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only allow POST method
  if (req.method !== "POST") {
    return Response.json(
      { success: false, error: "Method not allowed. Use POST." },
      { status: 405, headers: corsHeaders }
    );
  }

  try {
    const bodyText = await req.text();
    let payload: any = {};

    try {
      payload = JSON.parse(bodyText);
    } catch (error) {
      console.error("[admin-login] Invalid JSON", error);
      return Response.json({ success: false, error: "Invalid JSON payload" }, { status: 400, headers: corsHeaders });
    }

    const username = typeof payload.username === "string" ? payload.username.trim() : "";
    const password = typeof payload.password === "string" ? payload.password : "";

    if (!username || !password) {
      return Response.json({ success: false, error: "Username and password are required" }, { status: 400, headers: corsHeaders });
    }

    // Only require username and password secrets - no user management needed
    const expectedUsername = Deno.env.get("ADMIN_LOGIN_USERNAME")?.trim();
    const expectedPassword = Deno.env.get("ADMIN_LOGIN_PASSWORD");
    const expectedPasswordHash = Deno.env.get("ADMIN_LOGIN_PASSWORD_HASH")?.trim();
    const displayName = Deno.env.get("ADMIN_DISPLAY_NAME")?.trim() || "Admin";

    const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    const missingSecrets: string[] = [];
    if (!expectedUsername) missingSecrets.push("ADMIN_LOGIN_USERNAME");
    if (!expectedPassword && !expectedPasswordHash) {
      missingSecrets.push("ADMIN_LOGIN_PASSWORD or ADMIN_LOGIN_PASSWORD_HASH");
    }
    if (!supabaseUrl) missingSecrets.push("SUPABASE_URL");
    if (!serviceRoleKey) missingSecrets.push("SERVICE_ROLE_KEY");

    if (missingSecrets.length > 0) {
      console.error(`[admin-login] Missing secrets: ${missingSecrets.join(", ")}`);
      return Response.json({ success: false, error: "Server misconfiguration" }, { status: 500, headers: corsHeaders });
    }

    // Validate credentials against secrets only
    const usernameValid = safeCompare(username, expectedUsername);

    let passwordValid = false;
    if (expectedPasswordHash) {
      const providedHash = await sha256Hex(password);
      passwordValid = safeCompare(providedHash.toLowerCase(), expectedPasswordHash.toLowerCase());
    } else if (expectedPassword) {
      passwordValid = safeCompare(password, expectedPassword);
    }

    if (!usernameValid || !passwordValid) {
      await new Promise((resolve) => setTimeout(resolve, 250));
      return Response.json({ success: false, error: "Invalid credentials" }, { status: 401, headers: corsHeaders });
    }

    // Credentials are valid - create/use system admin user for proper session
    // We need a real user in auth.users to generate a valid session token
    // But we won't create anything in public.users
    const adminHeaders = {
      "apikey": serviceRoleKey,
      "Authorization": `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    };

    // System admin email (not stored anywhere, just for auth session)
    const systemAdminEmail = `admin-${expectedUsername}@system.hur.delivery`;
    // Use deterministic password based on username and service role (so it's always the same)
    // Ensure it meets Supabase password requirements: min 6 chars, has uppercase, lowercase, number, special char
    const systemAdminPasswordHash = await sha256Hex(`${expectedUsername}-${serviceRoleKey}-admin-system`);
    // Create a valid password: uppercase + lowercase + numbers + special char, min 12 chars
    // Use only alphanumeric from hash to avoid special char issues
    const basePassword = systemAdminPasswordHash.substring(0, 10).replace(/[^a-f0-9]/g, 'a'); // Only hex chars
    const systemAdminPassword = `Admin${basePassword}123!`; // 12+ chars: Admin + 10 hex + 123!
    
    console.log(`[admin-login] System admin email: ${systemAdminEmail}`);
    console.log(`[admin-login] Password length: ${systemAdminPassword.length}`);

    let adminUserId: string | null = null;

    // Check if system admin user exists, create if not
    try {
      const getUserRes = await fetch(`${supabaseUrl}/auth/v1/admin/users?email=${encodeURIComponent(systemAdminEmail)}`, {
        method: "GET",
        headers: adminHeaders,
      });

      if (getUserRes.ok) {
        const getUserData = await getUserRes.json();
        const existingUser = Array.isArray(getUserData?.users) ? getUserData.users[0] : null;

        // Always delete existing user if found, then create fresh one
        // This ensures password is always correct
        if (existingUser) {
          console.log(`[admin-login] Found existing system admin user: ${existingUser.id}, deleting...`);
          const deleteRes = await fetch(`${supabaseUrl}/auth/v1/admin/users/${existingUser.id}`, {
            method: "DELETE",
            headers: adminHeaders,
          });
          
          if (deleteRes.ok) {
            console.log("[admin-login] Existing user deleted successfully");
            await new Promise((resolve) => setTimeout(resolve, 2000)); // Wait for deletion to complete
          } else {
            const deleteError = await deleteRes.text();
            console.warn("[admin-login] Failed to delete existing user:", deleteError);
            // Continue anyway - will try to create (might fail if user still exists)
          }
        }
        
        // Always create fresh user with correct password
        console.log("[admin-login] Creating system admin user with correct password...");
        const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
          method: "POST",
          headers: adminHeaders,
          body: JSON.stringify({
            email: systemAdminEmail,
            password: systemAdminPassword,
            email_confirm: true,
            user_metadata: {
              role: "admin",
              username: expectedUsername,
              name: displayName,
            },
          }),
        });

        if (createRes.ok) {
          const created = await createRes.json();
          adminUserId = created?.user?.id ?? created?.id ?? null;
          console.log(`[admin-login] Created system admin user: ${adminUserId}`);
          // Wait longer for user creation to fully complete
          await new Promise((resolve) => setTimeout(resolve, 3000));
        } else {
          const errorText = await createRes.text();
          console.error("[admin-login] Failed to create system admin user", createRes.status, errorText);
          // If user already exists error, try to get the existing user ID
          if (createRes.status === 422 || errorText.includes("already exists")) {
            console.log("[admin-login] User already exists, fetching ID...");
            const retryGetRes = await fetch(`${supabaseUrl}/auth/v1/admin/users?email=${encodeURIComponent(systemAdminEmail)}`, {
              method: "GET",
              headers: adminHeaders,
            });
            if (retryGetRes.ok) {
              const retryData = await retryGetRes.json();
              const retryUser = Array.isArray(retryData?.users) ? retryData.users[0] : null;
              if (retryUser) {
                adminUserId = retryUser.id;
                console.log(`[admin-login] Using existing user ID: ${adminUserId}`);
              }
            }
          }
          
          if (!adminUserId) {
            throw new Error("Failed to create or find system admin user");
          }
        }
      } else {
        const errorText = await getUserRes.text();
        console.error("[admin-login] Failed to check system admin user", getUserRes.status, errorText);
        throw new Error("Failed to check system admin user");
      }
    } catch (userError) {
      console.error("[admin-login] Error managing system admin user", userError);
      return Response.json(
        { success: false, error: "Failed to create admin session", details: String(userError) },
        { status: 500, headers: corsHeaders },
      );
    }

    if (!adminUserId) {
      return Response.json(
        { success: false, error: "Failed to get admin user ID" },
        { status: 500, headers: corsHeaders },
      );
    }

    // Use Supabase admin client to generate a session token
    // This is more reliable than raw API calls
    console.log(`[admin-login] Generating session token for user: ${adminUserId}`);
    
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // User was just created with correct password, no need to update
    // Just wait a bit more for everything to propagate
    console.log("[admin-login] User created with correct password, waiting for propagation...");
    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Generate session using regular client
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
    
    if (!anonKey) {
      return Response.json(
        { success: false, error: "Missing SUPABASE_ANON_KEY" },
        { status: 500, headers: corsHeaders },
      );
    }

    // Use regular client to sign in (not admin client)
    const supabaseClient = createClient(supabaseUrl, anonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Try signing in - with multiple retries and increasing delays
    let session: any = null;
    let lastError: any = null;
    
    for (let attempt = 1; attempt <= 3; attempt++) {
      console.log(`[admin-login] Sign-in attempt ${attempt}/3...`);
      
      const { data: authData, error: authError } = await supabaseClient.auth.signInWithPassword({
        email: systemAdminEmail,
        password: systemAdminPassword,
      });

      if (!authError && authData?.session) {
        session = authData.session;
        console.log(`[admin-login] Sign-in successful on attempt ${attempt}`);
        break;
      }

      lastError = authError;
      console.error(`[admin-login] Attempt ${attempt} failed:`, authError?.message);
      
      if (attempt < 3) {
        const delay = attempt * 2000; // 2s, 4s delays
        console.log(`[admin-login] Waiting ${delay}ms before retry...`);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }

    if (!session || !session.access_token) {
      console.error("[admin-login] All sign-in attempts failed");
      return Response.json(
        { success: false, error: "Failed to generate session", details: lastError?.message || "All attempts failed" },
        { status: 500, headers: corsHeaders },
      );
    }

    const responsePayload = {
      success: true,
      session: {
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_in: session.expires_in,
        expires_at: session.expires_at,
        token_type: session.token_type,
      },
      user: {
        id: adminUserId,
        email: systemAdminEmail,
        username: expectedUsername,
        name: displayName,
        role: "admin",
      },
    };

    console.log("[admin-login] Admin login successful");
    return Response.json(responsePayload, { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("[admin-login] Unexpected error", error);
    return Response.json(
      { success: false, error: "Unexpected server error", details: String(error) },
      { status: 500, headers: corsHeaders },
    );
  }
});
