// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Module-level logging to verify the file loads
console.log("[otp-handler] Module loaded at:", new Date().toISOString());

interface SendOtpRequest {
  action: "send";
  phoneNumber: string;
  purpose?: "signup" | "reset_password" | "delete_account";
}

interface VerifyOtpRequest {
  action: "verify";
  phoneNumber: string;
  code: string;
  purpose?: "signup" | "reset_password" | "delete_account";
}

interface AuthenticateRequest {
  action: "authenticate";
  phoneNumber: string;
  code: string;
}

interface ResetPasswordRequest {
  action: "reset_password";
  phoneNumber: string;
  code: string;
  newPassword?: string; // Optional, ignored - we generate deterministic password
}

type OtpRequest =
  | SendOtpRequest
  | VerifyOtpRequest
  | AuthenticateRequest
  | ResetPasswordRequest;

async function verifyAuthCredentials(
  supabaseUrl: string,
  serviceRoleKey: string,
  email: string,
  password: string,
): Promise<boolean> {
  try {
    const tokenRes = await fetch(
      `${supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceRoleKey,
        },
        body: JSON.stringify({ email, password }),
      },
    );

    if (tokenRes.ok) {
      return true;
    }

    const errText = await tokenRes.text();
    console.error(
      "[otp-handler] verifyAuthCredentials: Supabase rejected credentials:",
      tokenRes.status,
      errText.substring(0, 200),
    );
    return false;
  } catch (err) {
    console.error(
      "[otp-handler] verifyAuthCredentials: Error verifying credentials:",
      err,
    );
    return false;
  }
}

async function deleteAuthUserById(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
): Promise<boolean> {
  try {
    const deleteRes = await fetch(
      `${supabaseUrl}/auth/v1/admin/users/${userId}`,
      {
        method: "DELETE",
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      },
    );

    if (!deleteRes.ok) {
      const text = await deleteRes.text();
      console.error(
        "[otp-handler] deleteAuthUserById: Failed to delete user",
        userId,
        deleteRes.status,
        text.substring(0, 200),
      );
      return false;
    }

    console.log(
      "[otp-handler] deleteAuthUserById: Deleted stale auth user:",
      userId,
    );
    return true;
  } catch (err) {
    console.error(
      "[otp-handler] deleteAuthUserById: Error deleting user",
      userId,
      err,
    );
    return false;
  }
}

function normalizePhone(input: string): string {
  let n = (input || "").toString().replace(/\D/g, "");
  // Strip leading 00 (international)
  if (n.startsWith("00")) n = n.slice(2);
  // Local starting with 0
  if (n.startsWith("0") && n.length >= 11) n = `964${n.slice(1)}`;
  // If exactly 10 digits and starts with 7, prefix 964
  if (n.length === 10 && n[0] === "7") n = `964${n}`;
  // If 9640xxxx... drop the 0 after 964
  if (n.startsWith("9640")) n = `964${n.slice(4)}`;
  // If longer than expected but starts with 964, keep last 10 digits
  if (n.startsWith("964") && n.length > 13) n = `964${n.slice(-10)}`;
  // Final guard
  if (!n.startsWith("964") && n.length > 0) {
    if (n.length === 10 && n[0] === "7") n = `964${n}`;
    else if (n.length === 11 && n[0] === "0") n = `964${n.slice(1)}`;
  }
  return n;
}

function generateSixDigitCode(): string {
  const n = Math.floor(100000 + Math.random() * 900000);
  return String(n);
}

function emailFromPhone(phone: string): string {
  return `${phone}@hur.delivery`;
}

function isValidPassword(pw: string): boolean {
  // Letters and numbers only, min 8 chars
  return /^[A-Za-z0-9]{8,}$/.test(pw);
}

serve(async (req) => {
  // CORS headers for browser requests
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  console.log("[otp-handler] ==== HANDLER CALLED ====");
  console.log("[otp-handler] Method:", req.method);
  console.log("[otp-handler] URL:", req.url);

  try {
    // Handle OPTIONS request for CORS
    if (req.method === "OPTIONS") {
      console.log("[otp-handler] OPTIONS request, returning CORS");
      return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "POST") {
      console.log("[otp-handler] Method not allowed:", req.method);
      return new Response("Method Not Allowed", {
        status: 405,
        headers: corsHeaders,
      });
    }

    console.log("[otp-handler] Reading request body...");
    // Read body as text first to avoid hanging on json()
    const bodyText = await req.text();
    console.log("[otp-handler] Body text received, length:", bodyText.length);
    
    let raw: any;
    try {
      raw = JSON.parse(bodyText);
      console.log("[otp-handler] JSON parsed successfully");
    } catch (jsonErr) {
      console.error("[otp-handler] JSON parse error:", jsonErr);
      return Response.json(
        { error: "Invalid JSON in request body", details: String(jsonErr) },
        { status: 400, headers: corsHeaders },
      );
    }
    
    const body = raw as any;
    const { action } = body as OtpRequest & { action?: string };
    console.log("[otp-handler] Action:", action);
    console.log("[otp-handler] Body keys:", Object.keys(body));
    console.log("[otp-handler] Full body:", JSON.stringify(body, null, 2));

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY") ||
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    if (!supabaseUrl || !serviceRoleKey) {
      return Response.json(
        { error: "Server not configured" },
        { status: 500, headers: corsHeaders },
      );
    }

    // ========== PING/HEALTH ==========
    if (action === "ping" || !action) {
      console.log("[otp-handler] ping/health check received");
      return Response.json(
        {
        success: true, 
        pong: true,
        timestamp: new Date().toISOString(),
        env: {
          hasSupabaseUrl: !!supabaseUrl,
          hasServiceRoleKey: !!serviceRoleKey,
            hasOtpiqKey: !!Deno.env.get("OTPIQ_API_KEY"),
          },
        },
        { status: 200, headers: corsHeaders },
      );
    }

    // ========== SEND OTP ==========
    if (action === "send") {
      console.log("[otp-handler] SEND action received");
      const { phoneNumber, purpose = "signup" } = body as SendOtpRequest;
      
      if (!phoneNumber) {
        console.error("[otp-handler] Missing phoneNumber");
        return Response.json(
          { error: "phoneNumber is required" },
          { status: 400, headers: corsHeaders },
        );
      }

      const phone = normalizePhone(phoneNumber);
      console.log(
        "[otp-handler] Normalized phone:",
        phone,
        "Purpose:",
        purpose,
      );
      
      const ttlMinutes = 10;
      const expiresAt = new Date(
        Date.now() + ttlMinutes * 60 * 1000,
      ).toISOString();
      const nowMs = Date.now();

      // Skip cooldown check to avoid database query delay
      // Generate new code immediately
      // TEST MODE: Fixed OTP for specific test numbers only
      // Only these test numbers get OTP 999999 and skip actual SMS/WhatsApp sending
      const testNumbers = ["9647814104097", "9647816820964"];
      // Also include numbers starting with 964999 (legacy test users)
      const isTestNumber =
        testNumbers.includes(phone) || phone.startsWith("964999");
      const testOtp = "999999";
      const code = isTestNumber ? testOtp : generateSixDigitCode();
      console.log(
        "[otp-handler] Generated new OTP code:",
        phone,
        isTestNumber ? "(TEST MODE - OTP: 999999)" : "(NORMAL)",
      );
      
      // Store OTP in database with timeout
      try {
        console.log("[otp-handler] Storing OTP in database...");
        const insertController = new AbortController();
        const insertTimeout = setTimeout(() => insertController.abort(), 3000); // 3 second timeout
        
        const insertRes = await fetch(
          `${supabaseUrl}/rest/v1/otp_verifications`,
          {
            method: "POST",
          headers: {
              "Content-Type": "application/json",
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
              Prefer: "return=minimal",
          },
          body: JSON.stringify({
            phone: phone,
            code: code,
            purpose: purpose,
            expires_at: expiresAt,
            attempts: 0,
            consumed: false,
          }),
          signal: insertController.signal,
          },
        );
        
        clearTimeout(insertTimeout);

        if (!insertRes.ok) {
          const text = await insertRes.text();
          console.log("[otp-handler] DB insert failed:", text);
          return Response.json(
            { error: "Failed to store OTP", details: text },
            { status: 500, headers: corsHeaders },
          );
        }
        console.log("[otp-handler] ✅ OTP stored in database");
      } catch (dbErr) {
        console.log("[otp-handler] DB INSERT error:", dbErr);
        if (dbErr instanceof Error && dbErr.name === "AbortError") {
          console.log("[otp-handler] ⚠️ DB insert timeout, continuing anyway");
        } else {
          return Response.json(
            { error: "Failed to store OTP", details: String(dbErr) },
            { status: 500, headers: corsHeaders },
          );
        }
      }

      // TEST MODE: Skip actual SMS/WhatsApp sending for test numbers
      if (isTestNumber) {
        console.log(
          "[otp-handler] 🧪 TEST MODE: Skipping SMS/WhatsApp for test number",
        );
        console.log(
          "[otp-handler] 🧪 TEST MODE: OTP code is 999999 (use this to login)",
        );
        return Response.json(
          { 
            success: true, 
            expiresAt,
            testMode: true,
            otpCode: "999999", // Return OTP in response for test numbers
            message: "Test mode: OTP is 999999 (not sent via SMS)",
          },
          { status: 200, headers: corsHeaders },
        );
      }

      // Verify OTPIQ_API_KEY is configured for real numbers
      const OTPIQ_API_KEY = Deno.env.get("OTPIQ_API_KEY");
      if (!OTPIQ_API_KEY) {
        console.error("[otp-handler] OTPIQ_API_KEY not configured");
        return Response.json(
          { success: false, error: "OTPIQ_API_KEY not configured" },
          { status: 500, headers: corsHeaders },
        );
      }

      // Send OTP via Otpiq with timeout (only for real numbers)
      const otpiqPayload = {
        phoneNumber: phone,
        smsType: "verification",
        provider: "whatsapp-sms",
        verificationCode: code,
      };

      console.log("[otp-handler] Sending OTP via Otpiq to:", phone);
      console.log(
        "[otp-handler] Otpiq API key present:",
        OTPIQ_API_KEY ? "Yes" : "No",
      );
      
      // Send with 5 second timeout to avoid hanging
      const controller = new AbortController();
      const timeoutId = setTimeout(() => {
        console.log("[otp-handler] Otpiq request timeout (5s)");
        controller.abort();
      }, 5000);
      
      try {
        console.log("[otp-handler] Making Otpiq API call...");
        const otpiqRes = await fetch("https://api.otpiq.com/api/sms", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${OTPIQ_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(otpiqPayload),
          signal: controller.signal,
        });
        
        clearTimeout(timeoutId);
        const responseText = await otpiqRes.text();
        console.log("[otp-handler] Otpiq response status:", otpiqRes.status);
        console.log(
          "[otp-handler] Otpiq response:",
          responseText.substring(0, 200),
        );
        
        if (otpiqRes.ok) {
          console.log("[otp-handler] ✅ OTP sent successfully via Otpiq");
          return Response.json(
            { success: true, expiresAt },
            { status: 200, headers: corsHeaders },
          );
        } else {
          console.error(
            "[otp-handler] ❌ Otpiq returned error:",
            otpiqRes.status,
          );
          // Still return success since OTP is stored
          return Response.json(
            {
              success: true,
              expiresAt,
              warning: "OTP stored but SMS may not have been sent",
            },
            { status: 200, headers: corsHeaders },
          );
        }
      } catch (e) {
        clearTimeout(timeoutId);
        console.error("[otp-handler] ❌ Otpiq request error:", e);
        
        // If timeout or error, still return success since OTP is stored
        if (e instanceof Error && e.name === "AbortError") {
          console.log("[otp-handler] ⚠️ Otpiq timeout, but OTP is stored");
        }
        
        return Response.json(
          {
            success: true,
            expiresAt,
            warning: "OTP stored but SMS send timed out",
          },
          { status: 200, headers: corsHeaders },
        );
      }
    }

    // ========== VERIFY OTP ==========
    if (action === "verify") {
      const {
        phoneNumber,
        code,
        purpose = "signup",
      } = body as VerifyOtpRequest;

      if (!phoneNumber || !code) {
        return Response.json(
          { error: "phoneNumber and code are required" },
          { status: 400, headers: corsHeaders },
        );
      }

      const phone = normalizePhone(phoneNumber);

      // Get latest OTP for phone/purpose not consumed and not expired
      const queryUrl = new URL(`${supabaseUrl}/rest/v1/otp_verifications`);
      queryUrl.searchParams.set("phone", `eq.${phone}`);
      queryUrl.searchParams.set("purpose", `eq.${purpose}`);
      queryUrl.searchParams.set("consumed", `eq.false`);
      queryUrl.searchParams.set("order", "created_at.desc");
      queryUrl.searchParams.set("limit", "1");

      const fetchRes = await fetch(queryUrl.toString(), {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });

      if (!fetchRes.ok) {
        return Response.json(
          { valid: false, error: "Failed to query OTP" },
          { status: 500, headers: corsHeaders },
        );
      }

      const rows = await fetchRes.json();
      const otp = rows?.[0];

      if (!otp) {
        return Response.json(
          { valid: false, error: "No OTP found" },
          { status: 400, headers: corsHeaders },
        );
      }

      // Expiry check
      if (new Date(otp.expires_at).getTime() < Date.now()) {
        return Response.json(
          { valid: false, error: "OTP expired" },
          { status: 400, headers: corsHeaders },
        );
      }

      // Attempt throttling (max 5 attempts)
      const maxAttempts = 5;
      if ((otp.attempts ?? 0) >= maxAttempts) {
        return Response.json(
          { valid: false, error: "Too many attempts" },
          { status: 429, headers: corsHeaders },
        );
      }

      const isMatch = String(otp.code) === String(code);

      // Update attempts/consume
      const patchRes = await fetch(
        `${supabaseUrl}/rest/v1/otp_verifications?id=eq.${otp.id}`,
        {
          method: "PATCH",
        headers: {
            "Content-Type": "application/json",
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          attempts: (otp.attempts ?? 0) + 1,
          consumed: isMatch,
        }),
        },
      );

      if (!patchRes.ok) {
        const text = await patchRes.text();
        return Response.json(
          { valid: false, error: "Failed to update OTP state", details: text },
          { status: 500, headers: corsHeaders },
        );
      }

      return Response.json(
        { valid: isMatch },
        { status: 200, headers: corsHeaders },
      );
    }

    // ========== AUTHENTICATE (Unified Login/Signup) ==========
    if (action === "authenticate") {
      const { phoneNumber, code } = body as AuthenticateRequest;

      if (!phoneNumber || !code) {
        return Response.json(
          { error: "phoneNumber and code are required" },
          { status: 400, headers: corsHeaders },
        );
      }

      const phone = normalizePhone(phoneNumber);
      const testNumbers = ["9647814104097", "9647816820964"];
      // Also include numbers starting with 964999 (legacy test users)
      const isTestNumber =
        testNumbers.includes(phone) || phone.startsWith("964999");
      console.log("[otp-handler] authenticate: Normalized phone:", phone);

      // Verify OTP first (check for any purpose)
      const queryUrl = new URL(`${supabaseUrl}/rest/v1/otp_verifications`);
      queryUrl.searchParams.set("phone", `eq.${phone}`);
      queryUrl.searchParams.set("consumed", `eq.false`);
      queryUrl.searchParams.set("order", "created_at.desc");
      queryUrl.searchParams.set("limit", "1");

      const fetchRes = await fetch(queryUrl.toString(), {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });

      if (!fetchRes.ok) {
        const t = await fetchRes.text();
        console.error(
          "[otp-handler] authenticate: Failed to query OTP",
          fetchRes.status,
          t,
        );
        return Response.json(
          { error: "Failed to query OTP", details: t },
          { status: 500, headers: corsHeaders },
        );
      }

      const rows = await fetchRes.json();
      const otp = rows?.[0];

      if (!otp) {
        console.error(
          "[otp-handler] authenticate: No OTP found for phone",
          phone,
        );
        console.error("[otp-handler] authenticate: Query returned", rows);
        return Response.json(
          {
            error:
              "No OTP found for this phone number. Please request a new OTP.",
          },
          { status: 400, headers: corsHeaders },
        );
      }

      console.log("[otp-handler] authenticate: Found OTP record:", {
        id: otp.id, 
        phone: otp.phone, 
        code: otp.code, 
        consumed: otp.consumed, 
        purpose: otp.purpose,
        expires_at: otp.expires_at,
      });

      const expiresAt = new Date(otp.expires_at).getTime();
      const now = Date.now();
      if (expiresAt < now) {
        console.error("[otp-handler] authenticate: OTP expired", {
          expiresAt,
          now,
          diff: now - expiresAt,
        });
        return Response.json(
          { error: "OTP expired. Please request a new OTP." },
          { status: 400, headers: corsHeaders },
        );
      }

      const codeMatch = String(otp.code) === String(code);
      if (!codeMatch) {
        console.error("[otp-handler] authenticate: Invalid OTP code", {
          expected: otp.code, 
          received: code,
          expectedType: typeof otp.code,
          receivedType: typeof code,
        });
        return Response.json(
          { error: "Invalid OTP code" },
          { status: 400, headers: corsHeaders },
        );
      }
      console.log("[otp-handler] authenticate: OTP verified successfully");

      // Consume OTP
      await fetch(`${supabaseUrl}/rest/v1/otp_verifications?id=eq.${otp.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({ consumed: true }),
      });

      // CRITICAL: Find profile FIRST to get the correct ID
      // This ensures we use the existing profile ID when creating/finding auth user
      const emailPrimary = `${phone}@hur.delivery`;
      
      // Find profile by phone to get id_number and profile ID
      let idNumber: string | null = null;
      let profileId: string | null = null;
      let existingProfile: any = null;
      try {
        const profByPhone = new URL(`${supabaseUrl}/rest/v1/users`);
        profByPhone.searchParams.set("select", "*");
        const normalizedPlus = `+${phone}`;
        profByPhone.searchParams.set(
          "or",
          `(phone.eq.${phone},phone.eq.${encodeURIComponent(normalizedPlus)})`,
        );
        console.log(
          "[otp-handler] authenticate: Searching for profile with phone:",
          phone,
          "or",
          normalizedPlus,
        );
        const profByPhoneRes = await fetch(profByPhone.toString(), {
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
          },
        });
        console.log(
          "[otp-handler] authenticate: Profile query response status:",
          profByPhoneRes.status,
        );
        if (profByPhoneRes.ok) {
          const profRows = await profByPhoneRes.json();
          console.log(
            "[otp-handler] authenticate: Profile query returned:",
            Array.isArray(profRows) ? `${profRows.length} rows` : "non-array",
          );
          if (Array.isArray(profRows) && profRows.length > 0) {
            existingProfile = profRows[0];
            profileId = existingProfile.id || null;
            idNumber = existingProfile.id_number || null;
            console.log(
              "[otp-handler] authenticate: ✅ Found user profile by phone, profileId:",
              profileId,
              "idNumber:",
              idNumber,
            );
          } else {
            console.log(
              "[otp-handler] authenticate: No profile found by phone (array empty or not found)",
            );
          }
        } else {
          const errorText = await profByPhoneRes.text();
          console.error(
            "[otp-handler] authenticate: Profile query failed:",
            profByPhoneRes.status,
            errorText.substring(0, 200),
          );
        }
      } catch (err) {
        console.error(
          "[otp-handler] authenticate: Error finding profile by phone:",
          err,
        );
      }

      // Generate deterministic password: phone@idcard or phone@last6digits
      // CRITICAL: Ensure password format is consistent
      const fallbackIdPart = phone.slice(-6);
      let idPart: string | null = null;
      if (idNumber !== null && idNumber !== undefined) {
        const sanitized = String(idNumber).trim();
        if (sanitized.length > 0) {
          idPart = sanitized.replace(/\s+/g, "");
        }
      }
      const deterministicPassword = `${phone}@${idPart ?? fallbackIdPart}`;

      console.log(
        "[otp-handler] authenticate: Generated deterministic password format:",
        phone,
        "@",
        idPart ?? fallbackIdPart,
      );

      // CRITICAL: Find or create auth user
      // Priority: 1) Auth user with profile ID, 2) Auth user by email, 3) Create new with profile ID if profile exists
      let authUser: any = null;
      
      // FIRST: If profile exists, try to find auth user by profile ID
      if (profileId) {
        try {
          console.log(
            "[otp-handler] authenticate: Checking for auth user with profile ID:",
            profileId,
          );
          const getUserByIdRes = await fetch(
            `${supabaseUrl}/auth/v1/admin/users/${profileId}`,
            {
              method: "GET",
              headers: {
                apikey: serviceRoleKey,
                Authorization: `Bearer ${serviceRoleKey}`,
              },
            },
          );
          
          if (getUserByIdRes.ok) {
            const userByIdData = await getUserByIdRes.json();
            if (userByIdData && userByIdData.id) {
              // CRITICAL: Verify phone matches before using this auth account
              const foundUserPhone = userByIdData.user_metadata?.phone || userByIdData.phone;
              const phoneMatches = foundUserPhone && (
                foundUserPhone === phone || 
                foundUserPhone === `+${phone}` || 
                foundUserPhone === phone.replace(/^\+/, "")
              );
              
              if (!foundUserPhone) {
                console.log(
                  "[otp-handler] authenticate: ⚠️ Found auth user by profile ID but NO phone in metadata!",
                );
                console.log(
                  "[otp-handler] authenticate: Cannot verify this is the same user - will create new account",
                );
                // Don't use this user - we can't verify it's the same person
              } else if (!phoneMatches) {
                console.log(
                  "[otp-handler] authenticate: ⚠️ Found auth user by profile ID but phone doesn't match!",
                );
                console.log(
                  "[otp-handler] authenticate: Found user phone:",
                  foundUserPhone,
                  "Current phone:",
                  phone,
                );
                console.log(
                  "[otp-handler] authenticate: This is a different user - will create new account",
                );
                // Don't use this user - it's for a different phone number
              } else {
                // Phone matches - safe to use this auth account
                authUser = userByIdData;
                console.log(
                  "[otp-handler] authenticate: ✅ Found auth user by profile ID (phone verified):",
                  authUser.id,
                  "Phone:",
                  foundUserPhone,
                );
              
              // CRITICAL: Update password for existing user
              if (authUser) {
              console.log(
                "[otp-handler] authenticate: Updating password for existing auth account",
              );
              try {
                const updatePasswordRes = await fetch(
                  `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
                  {
                    method: "PUT",
                    headers: {
                      "Content-Type": "application/json",
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                    },
                    body: JSON.stringify({
                      password: deterministicPassword,
                      email_confirm: true,
                    }),
                  },
                );
                
                if (updatePasswordRes.ok) {
                  console.log(
                    "[otp-handler] authenticate: ✅ Password updated successfully",
                  );
                } else {
                  const errorText = await updatePasswordRes.text();
                  console.error(
                    "[otp-handler] authenticate: ⚠️ Failed to update password:",
                    errorText,
                  );
                  // Continue anyway - user might still be able to log in
                }
              } catch (updateErr) {
                console.error(
                  "[otp-handler] authenticate: ⚠️ Error updating password:",
                  updateErr,
                );
                // Continue anyway
              }
              } // Close if (authUser) - password update block
              } // Close else - phone verification passed
            }
          } else if (getUserByIdRes.status !== 404) {
            const errorText = await getUserByIdRes.text();
            console.error(
              "[otp-handler] authenticate: Error checking auth user by profile ID:",
              getUserByIdRes.status,
              errorText,
            );
          }
        } catch (err) {
          console.error(
            "[otp-handler] authenticate: Exception checking auth user by profile ID:",
            err,
          );
        }
      }
      
      // SECOND: If not found by profile ID, try by email (both formats) and phone
      if (!authUser) {
        try {
          // Try primary email format
          const emailQueryParam = `email=eq.${encodeURIComponent(emailPrimary)}`;
          
          console.log(
            "[otp-handler] authenticate: Searching for auth user by email:",
            emailPrimary,
          );
          
          const getUserRes = await fetch(
            `${supabaseUrl}/auth/v1/admin/users?${emailQueryParam}`,
            {
              method: "GET",
              headers: {
                apikey: serviceRoleKey,
                Authorization: `Bearer ${serviceRoleKey}`,
              },
            },
          );

          if (getUserRes.ok) {
            const userData = await getUserRes.json();
            if (
              userData &&
              userData.users &&
              Array.isArray(userData.users) &&
              userData.users.length > 0
            ) {
              const foundUser = userData.users[0];
              
              // CRITICAL: Verify that the found user's phone matches the current phone
              // If phone doesn't match, this is a different user and we should create a new account
              const foundUserPhone = foundUser.user_metadata?.phone || foundUser.phone;
              const foundUserEmail = foundUser.email || "";
              
              console.log(
                "[otp-handler] authenticate: Found auth user by email:",
                foundUser.id,
                "Email:",
                foundUserEmail,
                "Phone in metadata:",
                foundUserPhone,
                "Current phone:",
                phone,
              );
              
              // CRITICAL: Check if phone matches
              // If no phone in metadata, we CANNOT verify this is the same user
              // We MUST create a new unique account to prevent account hijacking
              const phoneMatches = foundUserPhone && (
                foundUserPhone === phone || 
                foundUserPhone === `+${phone}` || 
                foundUserPhone === phone.replace(/^\+/, "")
              );
              
              if (!foundUserPhone) {
                console.log(
                  "[otp-handler] authenticate: ⚠️ Found auth user but NO phone in metadata!",
                );
                console.log(
                  "[otp-handler] authenticate: Cannot verify this is the same user",
                );
                console.log(
                  "[otp-handler] authenticate: Will create new unique auth account to prevent account hijacking",
                );
                // CRITICAL: Don't use this user - we can't verify it's the same person
                // Continue to create a new account
              } else if (!phoneMatches) {
                console.log(
                  "[otp-handler] authenticate: ⚠️ Found auth user but phone number doesn't match!",
                );
                console.log(
                  "[otp-handler] authenticate: Found user phone:",
                  foundUserPhone,
                  "Current phone:",
                  phone,
                );
                console.log(
                  "[otp-handler] authenticate: This is a different user - will create new auth account",
                );
                // Don't use this user - it's for a different phone number
                // Continue to create a new account
              } else {
                // Phone matches - safe to use this user
                authUser = foundUser;
                console.log(
                  "[otp-handler] authenticate: ✅ Found existing auth user by email (phone verified):",
                  authUser.id,
                  "Phone:",
                  foundUserPhone,
                );
              }
              
              // CRITICAL: Check if auth user ID matches profile ID
              if (authUser && profileId && profileId !== authUser.id) {
                console.log(
                  "[otp-handler] authenticate: ⚠️ WARNING - Auth user ID doesn't match profile ID!",
                );
                console.log(
                  "[otp-handler] authenticate: Auth User ID:",
                  authUser.id,
                  "Profile ID:",
                  profileId,
                );
                console.log(
                  "[otp-handler] authenticate: Will migrate profile to match auth user ID after password update",
                );
                // We'll handle the profile migration after password update
              } else if (profileId && profileId === authUser.id) {
                console.log(
                  "[otp-handler] authenticate: ✅ Profile ID matches auth user ID:",
                  profileId,
                );
              } else if (!profileId) {
                console.log(
                  "[otp-handler] authenticate: ℹ️ No profile found by phone (new user)",
                );
              }
              
              // Only update if we have a valid authUser (phone matched)
              if (authUser) {
              // Update password and email to ensure consistency
              // CRITICAL: Update both email and password together to ensure they match
              const setRes = await fetch(
                `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
                {
                  method: "PUT",
                headers: {
                    "Content-Type": "application/json",
                    apikey: serviceRoleKey,
                    Authorization: `Bearer ${serviceRoleKey}`,
                },
                  body: JSON.stringify({
                    email: emailPrimary, // Ensure email matches
                    password: deterministicPassword,
                    email_confirm: true,
                  }),
                },
              );

              if (!setRes.ok) {
                const text = await setRes.text();
                console.error(
                  "[otp-handler] authenticate: Failed to update password and email:",
                  text,
                );
                return Response.json(
                  { error: "Failed to set password", details: text },
                  { status: 500, headers: corsHeaders },
                );
              }
              console.log(
                "[otp-handler] authenticate: Password and email updated successfully",
              );
              
              // CRITICAL: Add a small delay to allow Supabase to propagate the password change
              // This is necessary because password updates may not be immediately available
              await new Promise((resolve) => setTimeout(resolve, 500));
            }
            
            // CRITICAL: If we don't have profile data yet, try to find it again
            // This handles cases where the initial lookup might have failed
            if (!existingProfile && !profileId) {
              console.log(
                "[otp-handler] authenticate: Retrying profile lookup after finding auth user...",
              );
              try {
                const retryProfByPhone = new URL(`${supabaseUrl}/rest/v1/users`);
                retryProfByPhone.searchParams.set("select", "*");
                const normalizedPlus = `+${phone}`;
                retryProfByPhone.searchParams.set(
                  "or",
                  `(phone.eq.${phone},phone.eq.${encodeURIComponent(normalizedPlus)})`,
                );
                const retryProfRes = await fetch(retryProfByPhone.toString(), {
                  headers: {
                    apikey: serviceRoleKey,
                    Authorization: `Bearer ${serviceRoleKey}`,
                  },
                });
                if (retryProfRes.ok) {
                  const retryProfRows = await retryProfRes.json();
                  if (Array.isArray(retryProfRows) && retryProfRows.length > 0) {
                    existingProfile = retryProfRows[0];
                    profileId = existingProfile.id || null;
                    idNumber = existingProfile.id_number || null;
                    console.log(
                      "[otp-handler] authenticate: ✅ Found profile on retry, profileId:",
                      profileId,
                    );
                  }
                }
              } catch (retryErr) {
                console.error(
                  "[otp-handler] authenticate: Error on profile retry:",
                  retryErr,
                );
              }
            }
            
            // CRITICAL: If profile exists with different ID, migrate it
            if (profileId && profileId !== authUser.id && existingProfile) {
              console.log(
                "[otp-handler] authenticate: 🔄 Migrating profile to match auth user ID...",
              );
              console.log(
                "[otp-handler] authenticate: Profile ID:",
                profileId,
                "Auth User ID:",
                authUser.id,
              );
              try {
                // Check if profile with auth user ID already exists
                const checkAuthIdRes = await fetch(
                  `${supabaseUrl}/rest/v1/users?id=eq.${authUser.id}`,
                  {
                    headers: {
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                    },
                  },
                );
                
                if (checkAuthIdRes.ok) {
                  const existingProfileCheck = await checkAuthIdRes.json();
                  console.log(
                    "[otp-handler] authenticate: Check for existing profile with auth ID returned:",
                    Array.isArray(existingProfileCheck) ? `${existingProfileCheck.length} rows` : "non-array",
                  );
                  if (Array.isArray(existingProfileCheck) && existingProfileCheck.length === 0) {
                    // No profile with auth ID - migrate the profile
                    console.log(
                      "[otp-handler] authenticate: 🔄 Migrating profile from",
                      profileId,
                      "to",
                      authUser.id,
                    );
                    
                    // Copy profile data to new ID (exclude id and created_at)
                    const newProfileData: any = {};
                    for (const key in existingProfile) {
                      if (key !== 'id' && key !== 'created_at') {
                        newProfileData[key] = existingProfile[key];
                      }
                    }
                    newProfileData.id = authUser.id;
                    newProfileData.updated_at = new Date().toISOString();
                    
                    console.log(
                      "[otp-handler] authenticate: Creating new profile with ID:",
                      authUser.id,
                    );
                    const createNewProfileRes = await fetch(
                      `${supabaseUrl}/rest/v1/users`,
                      {
                        method: "POST",
                        headers: {
                          "Content-Type": "application/json",
                          apikey: serviceRoleKey,
                          Authorization: `Bearer ${serviceRoleKey}`,
                          Prefer: "return=minimal",
                        },
                        body: JSON.stringify(newProfileData),
                      },
                    );
                    
                    console.log(
                      "[otp-handler] authenticate: Create profile response status:",
                      createNewProfileRes.status,
                    );
                    
                    if (createNewProfileRes.ok) {
                      console.log(
                        "[otp-handler] authenticate: ✅ Profile migrated successfully - new profile created",
                      );
                      
                      // Delete old profile
                      console.log(
                        "[otp-handler] authenticate: Deleting old profile with ID:",
                        profileId,
                      );
                      const deleteOldRes = await fetch(
                        `${supabaseUrl}/rest/v1/users?id=eq.${profileId}`,
                        {
                          method: "DELETE",
                          headers: {
                            apikey: serviceRoleKey,
                            Authorization: `Bearer ${serviceRoleKey}`,
                            Prefer: "return=minimal",
                          },
                        },
                      );
                      if (deleteOldRes.ok) {
                        console.log(
                          "[otp-handler] authenticate: ✅ Deleted old profile with mismatched ID",
                        );
                      } else {
                        const deleteError = await deleteOldRes.text();
                        console.error(
                          "[otp-handler] authenticate: ❌ Failed to delete old profile:",
                          deleteOldRes.status,
                          deleteError.substring(0, 200),
                        );
                      }
                    } else {
                      const createError = await createNewProfileRes.text();
                      console.error(
                        "[otp-handler] authenticate: ❌ Failed to create new profile:",
                        createNewProfileRes.status,
                        createError.substring(0, 200),
                      );
                    }
                  } else {
                    console.log(
                      "[otp-handler] authenticate: ℹ️ Profile with auth ID already exists, skipping migration",
                    );
                  }
                } else {
                  const checkError = await checkAuthIdRes.text();
                  console.error(
                    "[otp-handler] authenticate: ❌ Failed to check for existing profile:",
                    checkAuthIdRes.status,
                    checkError.substring(0, 200),
                  );
                }
              } catch (migrateErr) {
                console.error(
                  "[otp-handler] authenticate: ❌ Error migrating profile:",
                  migrateErr,
                );
              }
            } else if (profileId && profileId === authUser.id) {
              console.log(
                "[otp-handler] authenticate: ✅ Profile ID already matches auth user ID, no migration needed",
              );
            } else if (!profileId) {
              console.log(
                "[otp-handler] authenticate: ℹ️ No profile found, skipping migration",
              );
            } else if (!existingProfile) {
              console.log(
                "[otp-handler] authenticate: ⚠️ Profile ID exists but existingProfile data not available for migration",
              );
            }

            // Only verify if we have a valid authUser
            if (!authUser) {
              console.log(
                "[otp-handler] authenticate: Skipping password verification - will create new account",
              );
            } else {
              // Verify password was set correctly
              // CRITICAL: Use the auth user's actual email, not emailPrimary, in case it differs
              const authUserEmail = authUser.email || emailPrimary;
              console.log(
                "[otp-handler] authenticate: Verifying password with email:",
                authUserEmail,
              );
              
              const passwordValid = await verifyAuthCredentials(
              supabaseUrl,
              serviceRoleKey,
              authUserEmail,
              deterministicPassword,
            );
            
            if (!passwordValid) {
              console.error(
                "[otp-handler] authenticate: ⚠️ Password verification failed after update. Retrying with email update...",
              );
              // Retry password update with explicit email update
              const retrySetRes = await fetch(
                `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
                {
                  method: "PUT",
                  headers: {
                    "Content-Type": "application/json",
                    apikey: serviceRoleKey,
                    Authorization: `Bearer ${serviceRoleKey}`,
                  },
                  body: JSON.stringify({
                    email: emailPrimary, // Explicitly set email
                    password: deterministicPassword,
                    email_confirm: true,
                  }),
                },
              );
              
              if (!retrySetRes.ok) {
                const retryText = await retrySetRes.text();
                console.error(
                  "[otp-handler] authenticate: ❌ Retry password update failed:",
                  retryText,
                );
                return Response.json(
                  {
                    error: "Failed to set password. Please try again.",
                    details: retryText.substring(0, 200),
                  },
                  { status: 500, headers: corsHeaders },
                );
              }
              
              // Wait for propagation
              await new Promise((resolve) => setTimeout(resolve, 500));
              
              // Verify again after retry - try both email formats
              let retryPasswordValid = await verifyAuthCredentials(
                supabaseUrl,
                serviceRoleKey,
                emailPrimary,
                deterministicPassword,
              );
              
              // If primary email fails, try the auth user's current email
              if (!retryPasswordValid && authUserEmail !== emailPrimary) {
                console.log(
                  "[otp-handler] authenticate: Trying verification with auth user's email:",
                  authUserEmail,
                );
                retryPasswordValid = await verifyAuthCredentials(
                  supabaseUrl,
                  serviceRoleKey,
                  authUserEmail,
                  deterministicPassword,
                );
              }
              
              if (!retryPasswordValid) {
                console.error(
                  "[otp-handler] authenticate: ❌ Password verification still failed after retry",
                );
                // Don't fail here - password might be set but verification is timing out
                // Log warning but continue - the client can try to sign in
                console.log(
                  "[otp-handler] authenticate: ⚠️ Continuing despite verification failure - password should be set",
                );
              } else {
                console.log(
                  "[otp-handler] authenticate: ✅ Password verified after retry",
                );
              }
            } else {
              console.log(
                "[otp-handler] authenticate: ✅ Password verified successfully",
              );
            }
          }
              } // Close if (authUser) - phone matched block
          } // Close if (getUserRes.ok) block
        } catch (e) {
          console.error("[otp-handler] authenticate: Error querying auth user:", e);
        }
      } // Close if (!authUser) block (try-catch for email lookup)
      
      // ADDITIONAL: If still not found, log for debugging (we'll try creation next)
      if (!authUser) {
        console.log(
          "[otp-handler] authenticate: Auth user not found after all email lookups, will attempt creation",
        );
      }

      // THIRD: If auth user doesn't exist, create one
      // CRITICAL: Always create auth account - this is required for authentication
      if (!authUser) {
        console.log(
          "[otp-handler] authenticate: 🔐 Auth user not found, creating new auth account...",
        );
        
        // CRITICAL FIX: Generate UNIQUE email for new auth accounts
        // Cannot reuse emails based on phone alone - each auth account MUST be unique
        // Use timestamp to ensure uniqueness even if same phone is used multiple times
        const timestamp = Date.now();
        const uniqueEmail = `${phone}_${timestamp}@hur.delivery`;
        
        console.log(
          "[otp-handler] authenticate: Phone:",
          phone,
          "Unique Email:",
          uniqueEmail,
          "Password format:",
          deterministicPassword.substring(0, 20) + "...",
        );
        if (profileId) {
          console.log(
            "[otp-handler] authenticate: ⚠️ WARNING - Profile exists with ID:",
            profileId,
            "but no matching auth user. Will create auth user and migrate profile.",
          );
        } else {
          console.log(
            "[otp-handler] authenticate: ℹ️ No profile found - new user, will create auth account only",
          );
        }
        try {
          console.log(
            "[otp-handler] authenticate: 📝 Creating auth account with unique email:",
            uniqueEmail,
            "and password format:",
            deterministicPassword.substring(0, 20) + "...",
          );
          const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              email: uniqueEmail,
              password: deterministicPassword,
              email_confirm: true,
                user_metadata: {
                  phone: phone,
                  created_at: timestamp,
                test_user:
                  testNumbers.includes(phone) || phone.startsWith("964999"),
                },
            }),
          });
          
          console.log(
            "[otp-handler] authenticate: Create auth account response status:",
            createRes.status,
          );
          
          // Log response body for debugging
          if (!createRes.ok) {
            const errorBody = await createRes.text();
            console.error(
              "[otp-handler] authenticate: Create auth account error response:",
              errorBody.substring(0, 500),
            );
          }

          if (createRes.ok) {
            const newUserData = await createRes.json();
            console.log(
              "[otp-handler] authenticate: Create response data keys:",
              Object.keys(newUserData),
            );
            authUser = newUserData.user || newUserData;
            
            // Handle different response formats
            if (!authUser) {
              console.error(
                "[otp-handler] authenticate: ❌ Auth account creation returned null/undefined",
              );
              console.error(
                "[otp-handler] authenticate: Response data:",
                JSON.stringify(newUserData).substring(0, 500),
              );
              return Response.json(
                { error: "Failed to create auth account - invalid response" },
                { status: 500, headers: corsHeaders },
              );
            }
            
            if (!authUser.id) {
              console.error(
                "[otp-handler] authenticate: ❌ Auth account creation returned user without ID",
              );
              console.error(
                "[otp-handler] authenticate: User data:",
                JSON.stringify(authUser).substring(0, 500),
              );
              return Response.json(
                { error: "Failed to create auth account - no user ID in response" },
                { status: 500, headers: corsHeaders },
              );
            }
            
            console.log(
              "[otp-handler] authenticate: ✅ Created new auth account:",
              authUser.id,
              "Email:",
              authUser.email || emailPrimary,
            );
            
            // CRITICAL: Ensure profile ID matches auth user ID
            // If profile exists with different ID, we MUST update it to match auth user ID
            if (profileId && profileId !== authUser.id && existingProfile) {
              console.log(
                "[otp-handler] authenticate: 🚨 CRITICAL - Profile ID mismatch detected!",
              );
              console.log(
                "[otp-handler] authenticate: Old Profile ID:",
                profileId,
                "New Auth User ID:",
                authUser.id,
              );
              console.log(
                "[otp-handler] authenticate: Migrating profile to new auth user ID...",
              );
              
              try {
                // Check if profile with auth user ID already exists (shouldn't happen, but check)
                const checkAuthIdRes = await fetch(
                  `${supabaseUrl}/rest/v1/users?id=eq.${authUser.id}`,
                  {
                    headers: {
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                    },
                  },
                );
                
                if (checkAuthIdRes.ok) {
                  const existingProfileCheck = await checkAuthIdRes.json();
                  if (Array.isArray(existingProfileCheck) && existingProfileCheck.length > 0) {
                    console.error(
                      "[otp-handler] authenticate: ERROR - Profile with auth ID already exists!",
                      "This should not happen. Deleting old profile and keeping new one.",
                    );
                    // Delete the old profile with mismatched ID
                    const deleteOldRes = await fetch(
                      `${supabaseUrl}/rest/v1/users?id=eq.${profileId}`,
                      {
                        method: "DELETE",
                        headers: {
                          apikey: serviceRoleKey,
                          Authorization: `Bearer ${serviceRoleKey}`,
                          Prefer: "return=minimal",
                        },
                      },
                    );
                    if (deleteOldRes.ok) {
                      console.log(
                        "[otp-handler] authenticate: Deleted old profile with mismatched ID",
                      );
                    }
                  } else {
                    // No profile with auth ID exists - update the profile found by phone
                    // Use UPDATE with WHERE clause to change the primary key
                    // Note: This requires special handling in PostgreSQL
                    console.log(
                      "[otp-handler] authenticate: Updating profile ID from",
                      profileId,
                      "to",
                      authUser.id,
                    );
                    
                    // First, create a new profile with the correct ID and all data from old profile
                    const newProfileData = {
                      ...existingProfile,
                      id: authUser.id,
                      updated_at: new Date().toISOString(),
                    };
                    delete newProfileData.created_at; // Let database set this
                    
                    const createNewProfileRes = await fetch(
                      `${supabaseUrl}/rest/v1/users`,
                      {
                        method: "POST",
                        headers: {
                          "Content-Type": "application/json",
                          apikey: serviceRoleKey,
                          Authorization: `Bearer ${serviceRoleKey}`,
                          Prefer: "return=minimal",
                        },
                        body: JSON.stringify(newProfileData),
                      },
                    );
                    
                    if (createNewProfileRes.ok) {
                      console.log(
                        "[otp-handler] authenticate: ✅ Created new profile with correct ID",
                      );
                      
                      // Delete the old profile BEFORE updating profileId
                      const oldProfileId = profileId; // Save old ID before updating
                      const deleteOldRes = await fetch(
                        `${supabaseUrl}/rest/v1/users?id=eq.${oldProfileId}`,
                        {
                          method: "DELETE",
                          headers: {
                            apikey: serviceRoleKey,
                            Authorization: `Bearer ${serviceRoleKey}`,
                            Prefer: "return=minimal",
                          },
                        },
                      );
                      if (deleteOldRes.ok) {
                        console.log(
                          "[otp-handler] authenticate: ✅ Deleted old profile with mismatched ID:",
                          oldProfileId,
                        );
                        // NOW update profileId to reflect successful migration
                        profileId = authUser.id;
                        console.log(
                          "[otp-handler] authenticate: ✅ Profile migration complete! New profile ID:",
                          profileId,
                        );
                      } else {
                        const deleteError = await deleteOldRes.text();
                        console.error(
                          "[otp-handler] authenticate: ⚠️ Failed to delete old profile:",
                          deleteError,
                        );
                        // Still update profileId since new profile was created successfully
                        profileId = authUser.id;
                        console.log(
                          "[otp-handler] authenticate: ⚠️ Using new profile despite delete failure",
                        );
                      }
                    } else {
                      const createError = await createNewProfileRes.text();
                      console.error(
                        "[otp-handler] authenticate: Failed to create new profile:",
                        createError,
                      );
                      // Try direct UPDATE as fallback (might work if no foreign key constraints)
                const updateRes = await fetch(
                  `${supabaseUrl}/rest/v1/users?id=eq.${profileId}`,
                  {
                    method: "PATCH",
                  headers: {
                      "Content-Type": "application/json",
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                      Prefer: "return=minimal",
                  },
                  body: JSON.stringify({ id: authUser.id }),
                  },
                );
                
                if (updateRes.ok) {
                  console.log(
                          "[otp-handler] authenticate: ✅ Profile ID updated via direct UPDATE",
                  );
                  // Update profileId to reflect the migration
                  profileId = authUser.id;
                  console.log(
                    "[otp-handler] authenticate: Profile ID now matches auth ID:",
                    profileId,
                  );
                } else {
                  const updateErrorText = await updateRes.text();
                  console.error(
                          "[otp-handler] authenticate: Direct UPDATE also failed:",
                    updateErrorText,
                  );
                      }
                    }
                  }
                }
              } catch (updateErr) {
                console.error(
                  "[otp-handler] authenticate: Error updating profile ID:",
                  updateErr,
                );
              }
            } else if (!profileId) {
              // CRITICAL: No profile found by phone - DO NOT create one automatically
              // The profile should only be created during registration, not during authentication
              // This ensures users complete the registration flow
              console.log(
                "[otp-handler] authenticate: ℹ️ No profile found - user needs to complete registration",
              );
              console.log(
                "[otp-handler] authenticate: Profile will be created during registration flow",
              );
              // Do not create profile here - let the registration flow handle it
            }

            // CRITICAL: Wait for password to propagate before verification
            await new Promise((resolve) => setTimeout(resolve, 500));
            
            // Verify password was set correctly
            // Note: Verification might fail due to timing, but password should be set
            const passwordValid = await verifyAuthCredentials(
              supabaseUrl,
              serviceRoleKey,
              uniqueEmail,
              deterministicPassword,
            );
            if (!passwordValid) {
              console.error(
                "[otp-handler] authenticate: ⚠️ Newly created auth account failed immediate credential verification",
              );
              console.log(
                "[otp-handler] authenticate: This may be due to propagation delay. Retrying password update...",
              );
              
              // Retry password update to ensure it's set
              try {
                const retrySetRes = await fetch(
                  `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
                  {
                    method: "PUT",
                    headers: {
                      "Content-Type": "application/json",
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                    },
                    body: JSON.stringify({
                      email: uniqueEmail,
                      password: deterministicPassword,
                      email_confirm: true,
                    }),
                  },
                );
                
                if (retrySetRes.ok) {
                  console.log(
                    "[otp-handler] authenticate: ✅ Retried password update for new account",
                  );
                  // Wait again
                  await new Promise((resolve) => setTimeout(resolve, 500));
                  
                  // Try verification one more time
                  const retryValid = await verifyAuthCredentials(
                    supabaseUrl,
                    serviceRoleKey,
                    uniqueEmail,
                    deterministicPassword,
                  );
                  if (retryValid) {
                    console.log(
                      "[otp-handler] authenticate: ✅ Password verified after retry",
                    );
                  } else {
                    console.log(
                      "[otp-handler] authenticate: ⚠️ Verification still failed, but password should be set - continuing",
                    );
                  }
                }
              } catch (retryErr) {
                console.error(
                  "[otp-handler] authenticate: Error retrying password update:",
                  retryErr,
                );
              }
              
              // CRITICAL: DO NOT delete the account - password should be set even if verification fails
              // The client can try to sign in, and if it fails, they can request a new OTP
              console.log(
                "[otp-handler] authenticate: ℹ️ Continuing despite verification failure - auth account created, password should be set",
              );
            } else {
              console.log(
                "[otp-handler] authenticate: ✅ Password verified successfully for new account",
              );
            }
          } else {
            const errorText = await createRes.text();
            console.error(
              "[otp-handler] authenticate: ❌ Failed to create auth account:",
              createRes.status,
              errorText.substring(0, 200),
            );
            
            // CRITICAL: Check if user already exists (might have been created in parallel or email mismatch)
            // Try multiple lookup strategies
            const lookupStrategies = [
              // Strategy 1: Unique email (the one we just tried to create)
              { param: `email=eq.${encodeURIComponent(uniqueEmail)}`, name: "unique email" },
              // Strategy 2: Primary email
              { param: `email=eq.${encodeURIComponent(emailPrimary)}`, name: "primary email" },
            ];
            
            // Also try by profile ID if we have one
            if (profileId) {
              lookupStrategies.push({
                param: `id=eq.${profileId}`,
                name: "profile ID",
              });
            }
            
            for (const strategy of lookupStrategies) {
              if (authUser) break; // Already found
              
              try {
                console.log(
                  "[otp-handler] authenticate: Trying to find auth user by",
                  strategy.name,
                );
                const findUserRes = await fetch(
                  `${supabaseUrl}/auth/v1/admin/users?${strategy.param}`,
                  {
                    method: "GET",
                    headers: {
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                    },
                  },
                );
                if (findUserRes.ok) {
                  const findUserData = await findUserRes.json();
                  // Handle both array response and direct user object
                  let users: any[] = [];
                  if (findUserData && Array.isArray(findUserData)) {
                    users = findUserData;
                  } else if (findUserData && findUserData.users && Array.isArray(findUserData.users)) {
                    users = findUserData.users;
                  } else if (findUserData && findUserData.id) {
                    // Direct user object
                    users = [findUserData];
                  }
                  
                  if (users.length > 0) {
                    authUser = users[0];
                    console.log(
                      "[otp-handler] authenticate: ✅ Found existing auth user by",
                      strategy.name,
                      ":",
                      authUser.id,
                    );
                    
                    // Update password to ensure it's correct
                    try {
                      const updatePasswordRes = await fetch(
                        `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
                        {
                          method: "PUT",
                          headers: {
                            "Content-Type": "application/json",
                            apikey: serviceRoleKey,
                            Authorization: `Bearer ${serviceRoleKey}`,
                          },
                          body: JSON.stringify({
                            password: deterministicPassword,
                            email: emailPrimary,
                            email_confirm: true,
                          }),
                        },
                      );
                      if (updatePasswordRes.ok) {
                        console.log(
                          "[otp-handler] authenticate: ✅ Updated password for existing auth user",
                        );
                      } else {
                        const updateError = await updatePasswordRes.text();
                        console.error(
                          "[otp-handler] authenticate: ⚠️ Failed to update password:",
                          updateError.substring(0, 200),
                        );
                      }
                    } catch (updateErr) {
                      console.error(
                        "[otp-handler] authenticate: Error updating password:",
                        updateErr,
                      );
                    }
                    break; // Found user, stop searching
                  }
                }
              } catch (findErr) {
                console.error(
                  "[otp-handler] authenticate: Error finding user by",
                  strategy.name,
                  ":",
                  findErr,
                );
              }
            }
            
            // If still no auth user, return error
            if (!authUser) {
              console.error(
                "[otp-handler] authenticate: ❌ CRITICAL - Could not find or create auth account after all attempts",
              );
              return Response.json(
                { 
                  error: "Failed to create or find auth account. Please try again.",
                  details: errorText.substring(0, 200),
                },
                { status: 500, headers: corsHeaders },
              );
            }
          }
        } catch (createErr) {
          console.error(
            "[otp-handler] authenticate: ❌ CRITICAL ERROR creating auth account:",
            createErr,
          );
          
          // Last resort: try comprehensive lookup strategies
          const lookupStrategies = [
            { param: `email=eq.${encodeURIComponent(uniqueEmail)}`, name: "unique email" },
            { param: `email=eq.${encodeURIComponent(emailPrimary)}`, name: "primary email" },
          ];
          
          if (profileId) {
            lookupStrategies.push({ param: `id=eq.${profileId}`, name: "profile ID" });
          }
          
          for (const strategy of lookupStrategies) {
            if (authUser) break;
            
            try {
              console.log(
                "[otp-handler] authenticate: Last resort - trying to find auth user by",
                strategy.name,
              );
              const findUserRes = await fetch(
                `${supabaseUrl}/auth/v1/admin/users?${strategy.param}`,
                {
                  method: "GET",
                  headers: {
                    apikey: serviceRoleKey,
                    Authorization: `Bearer ${serviceRoleKey}`,
                  },
                },
              );
              if (findUserRes.ok) {
                const findUserData = await findUserRes.json();
                let users: any[] = [];
                if (findUserData && Array.isArray(findUserData)) {
                  users = findUserData;
                } else if (findUserData && findUserData.users && Array.isArray(findUserData.users)) {
                  users = findUserData.users;
                } else if (findUserData && findUserData.id) {
                  users = [findUserData];
                }
                
                if (users.length > 0) {
                  authUser = users[0];
                  console.log(
                    "[otp-handler] authenticate: ✅ Found auth user after error by",
                    strategy.name,
                    ":",
                    authUser.id,
                  );
                  
                  // Update password
                  try {
                    await fetch(
                      `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
                      {
                        method: "PUT",
                        headers: {
                          "Content-Type": "application/json",
                          apikey: serviceRoleKey,
                          Authorization: `Bearer ${serviceRoleKey}`,
                        },
                        body: JSON.stringify({
                          password: deterministicPassword,
                          email: emailPrimary,
                          email_confirm: true,
                        }),
                      },
                    );
                  } catch (updateErr) {
                    console.error(
                      "[otp-handler] authenticate: Error updating password in catch:",
                      updateErr,
                    );
                  }
                  break;
                }
              }
            } catch (findErr) {
              console.error(
                "[otp-handler] authenticate: Error in last resort lookup:",
                findErr,
              );
            }
          }
          
          // If still no auth user, return error
          if (!authUser) {
            return Response.json(
              {
                error: "Failed to create auth account. Please try again.",
                details: String(createErr).substring(0, 200),
              },
              { status: 500, headers: corsHeaders },
            );
          }
        }
      }

      if (!authUser || !authUser.id) {
        console.error(
          "[otp-handler] authenticate: User not found in auth system",
        );
        return Response.json(
          { error: "User not found in auth system" },
          { status: 404, headers: corsHeaders },
        );
      }

      // FINAL CHECK: Ensure profile ID matches auth user ID before returning
      // This is a catch-all to handle any edge cases where migration didn't happen earlier
      // CRITICAL: Only migrate if profile exists - do NOT create new profiles here
      if (profileId && profileId !== authUser.id && existingProfile) {
        console.log(
          "[otp-handler] authenticate: 🔄 FINAL CHECK - Profile ID mismatch detected, migrating now...",
        );
        console.log(
          "[otp-handler] authenticate: Profile ID:",
          profileId,
          "Auth User ID:",
          authUser.id,
        );
        
        try {
          // Check if profile with auth user ID already exists
          const finalCheckRes = await fetch(
            `${supabaseUrl}/rest/v1/users?id=eq.${authUser.id}`,
            {
              headers: {
                apikey: serviceRoleKey,
                Authorization: `Bearer ${serviceRoleKey}`,
              },
            },
          );
          
          if (finalCheckRes.ok) {
            const finalCheckData = await finalCheckRes.json();
            if (Array.isArray(finalCheckData) && finalCheckData.length === 0) {
              // No profile with auth ID - migrate now
              console.log(
                "[otp-handler] authenticate: 🔄 FINAL MIGRATION - Creating profile with auth user ID",
              );
              
              const finalProfileData: any = {};
              for (const key in existingProfile) {
                if (key !== 'id' && key !== 'created_at') {
                  finalProfileData[key] = existingProfile[key];
                }
              }
              finalProfileData.id = authUser.id;
              finalProfileData.updated_at = new Date().toISOString();
              
              const finalCreateRes = await fetch(
                `${supabaseUrl}/rest/v1/users`,
                {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    apikey: serviceRoleKey,
                    Authorization: `Bearer ${serviceRoleKey}`,
                    Prefer: "return=minimal",
                  },
                  body: JSON.stringify(finalProfileData),
                },
              );
              
              if (finalCreateRes.ok) {
                console.log(
                  "[otp-handler] authenticate: ✅ FINAL MIGRATION - Profile created successfully",
                );
                
                // Delete old profile
                const finalDeleteRes = await fetch(
                  `${supabaseUrl}/rest/v1/users?id=eq.${profileId}`,
                  {
                    method: "DELETE",
                    headers: {
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                      Prefer: "return=minimal",
                    },
                  },
                );
                if (finalDeleteRes.ok) {
                  console.log(
                    "[otp-handler] authenticate: ✅ FINAL MIGRATION - Old profile deleted",
                  );
                }
              } else {
                const finalCreateError = await finalCreateRes.text();
                console.error(
                  "[otp-handler] authenticate: ❌ FINAL MIGRATION failed:",
                  finalCreateRes.status,
                  finalCreateError.substring(0, 200),
                );
              }
            } else {
              console.log(
                "[otp-handler] authenticate: ✅ FINAL CHECK - Profile with auth ID already exists",
              );
            }
          }
        } catch (finalErr) {
          console.error(
            "[otp-handler] authenticate: ❌ FINAL MIGRATION error:",
            finalErr,
          );
        }
      } else if (profileId && profileId === authUser.id) {
        console.log(
          "[otp-handler] authenticate: ✅ FINAL CHECK - Profile ID matches auth user ID",
        );
      }

      // CRITICAL: Verify auth user exists before returning
      if (!authUser || !authUser.id) {
        console.error(
          "[otp-handler] authenticate: ❌ CRITICAL - Auth user is null after all attempts!",
        );
        return Response.json(
          { error: "Failed to create or find auth account. Please try again." },
          { status: 500, headers: corsHeaders },
        );
      }
      
      // Return success with email and password for client to sign in
      // Include hasProfile flag to help frontend determine if user needs registration
      const hasProfile = profileId !== null && profileId === authUser.id;
      // CRITICAL: Return the actual auth user's email, not the generic emailPrimary
      // The auth user's email is unique and may include timestamp for new accounts
      const actualEmail = authUser.email || emailPrimary;
      console.log(
        "[otp-handler] authenticate: ✅ Returning success, authUserId:",
        authUser.id,
        "email:",
        actualEmail,
        "hasProfile:",
        hasProfile,
      );
      return Response.json(
        { 
          success: true, 
          email: actualEmail,
          password: deterministicPassword,
          authUserId: authUser.id,
          hasProfile: hasProfile, // Frontend can use this to determine if registration is needed
        },
        { status: 200, headers: corsHeaders },
      );
    }

    // ========== RESET PASSWORD ==========
    if (action === "reset_password") {
      const { phoneNumber, code } = body as ResetPasswordRequest;

      if (!phoneNumber || !code) {
        return Response.json(
          { error: "phoneNumber and code are required" },
          { status: 400, headers: corsHeaders },
        );
      }

      const phone = normalizePhone(phoneNumber);
      const testNumbers = ["9647814104097", "9647816820964"];
      // Also include numbers starting with 964999 (legacy test users)
      const isTestNumber =
        testNumbers.includes(phone) || phone.startsWith("964999");
      console.log(
        "[otp-handler] reset_password: Normalized phone:",
        phone,
        "Code length:",
        String(code).length,
      );

      // Verify OTP first
      const queryUrl = new URL(`${supabaseUrl}/rest/v1/otp_verifications`);
      queryUrl.searchParams.set("phone", `eq.${phone}`);
      queryUrl.searchParams.set("purpose", `eq.reset_password`);
      queryUrl.searchParams.set("consumed", `eq.false`);
      queryUrl.searchParams.set("order", "created_at.desc");
      queryUrl.searchParams.set("limit", "1");

      const fetchRes = await fetch(queryUrl.toString(), {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });

      if (!fetchRes.ok) {
        const t = await fetchRes.text();
        console.error(
          "[otp-handler] reset_password: Failed to query OTP",
          fetchRes.status,
          t,
        );
        return Response.json(
          { error: "Failed to query OTP", details: t },
          { status: 500, headers: corsHeaders },
        );
      }

      const rows = await fetchRes.json();
      const otp = rows?.[0];

      if (!otp) {
        console.error(
          "[otp-handler] reset_password: No OTP found for phone",
          phone,
        );
        return Response.json(
          {
            error:
              "No OTP found for this phone number. Please request a new OTP.",
          },
          { status: 400, headers: corsHeaders },
        );
      }

      const expiresAt = new Date(otp.expires_at).getTime();
      const now = Date.now();
      if (expiresAt < now) {
        console.error("[otp-handler] reset_password: OTP expired", {
          expiresAt,
          now,
          diff: now - expiresAt,
        });
        return Response.json(
          { error: "OTP expired. Please request a new OTP." },
          { status: 400, headers: corsHeaders },
        );
      }

      const codeMatch = String(otp.code) === String(code);
      if (!codeMatch) {
        console.error("[otp-handler] reset_password: Invalid OTP code", {
          expected: otp.code,
          received: code,
        });
        return Response.json(
          { error: "Invalid OTP code" },
          { status: 400, headers: corsHeaders },
        );
      }
      console.log("[otp-handler] reset_password: OTP verified successfully");

      // Consume OTP
      await fetch(`${supabaseUrl}/rest/v1/otp_verifications?id=eq.${otp.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({ consumed: true }),
      });

      // Find or create auth user
      const emailPrimary = `${phone}@hur.delivery`;
      
      // First, try to find profile by phone
      let targetAuthUserId: string | null = null;
      try {
        const profByPhone = new URL(`${supabaseUrl}/rest/v1/users`);
        profByPhone.searchParams.set("select", "id,phone,id_number");
        const normalizedPlus = `+${phone}`;
        profByPhone.searchParams.set(
          "or",
          `(phone.eq.${phone},phone.eq.${encodeURIComponent(normalizedPlus)})`,
        );
        const profByPhoneRes = await fetch(profByPhone.toString(), {
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
          },
        });
        if (profByPhoneRes.ok) {
          const profRows = await profByPhoneRes.json();
          if (Array.isArray(profRows) && profRows.length > 0) {
            targetAuthUserId = profRows[0]?.id || null;
            console.log(
              "[otp-handler] reset_password: Found user profile by phone, profileId:",
              targetAuthUserId,
            );
          }
        }
      } catch (err) {
        console.error(
          "[otp-handler] reset_password: Error finding profile by phone:",
          err,
        );
      }

      // Find auth user by email
      let authUser: any = null;
      try {
        const getUserRes = await fetch(
          `${supabaseUrl}/auth/v1/admin/users?email=${encodeURIComponent(emailPrimary)}`,
          {
            method: "GET",
          headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
          },
          },
        );

        if (getUserRes.ok) {
          const userData = await getUserRes.json();
          if (
            userData &&
            userData.users &&
            Array.isArray(userData.users) &&
            userData.users.length > 0
          ) {
            const foundUser = userData.users[0];
            
            // CRITICAL: Verify phone matches before allowing password reset
            const foundUserPhone = foundUser.user_metadata?.phone || foundUser.phone;
            const phoneMatches = foundUserPhone && (
              foundUserPhone === phone || 
              foundUserPhone === `+${phone}` || 
              foundUserPhone === phone.replace(/^\+/, "")
            );
            
            if (!foundUserPhone) {
              console.log(
                "[otp-handler] reset_password: ⚠️ Found auth user but NO phone in metadata!",
              );
              console.log(
                "[otp-handler] reset_password: Cannot verify this is the correct user",
              );
              console.log(
                "[otp-handler] reset_password: Will create new unique auth account to prevent unauthorized access",
              );
              // Don't use this user - we can't verify it's the same person
            } else if (!phoneMatches) {
              console.log(
                "[otp-handler] reset_password: ⚠️ Found auth user but phone doesn't match!",
              );
              console.log(
                "[otp-handler] reset_password: Found user phone:",
                foundUserPhone,
                "Current phone:",
                phone,
              );
              console.log(
                "[otp-handler] reset_password: Will create new unique auth account",
              );
              // Don't use this user - it's for a different phone number
            } else {
              // Phone matches - safe to use this user for password reset
              authUser = foundUser;
              console.log(
                "[otp-handler] reset_password: ✅ Found auth user by email (phone verified):",
                authUser.id,
                "Phone:",
                foundUserPhone,
              );
            }
          }
        }
      } catch (e) {
        console.log(
          "[otp-handler] reset_password: Error querying auth user:",
          e,
        );
      }

      // If still not found, create auth account
      if (!authUser) {
        console.log(
          "[otp-handler] reset_password: Auth user not found, creating new auth account...",
        );
        
        // CRITICAL FIX: Generate UNIQUE email for new auth accounts
        // Cannot reuse emails based on phone alone - each auth account MUST be unique
        const timestamp = Date.now();
        const uniqueEmail = `${phone}_${timestamp}@hur.delivery`;
        const fallbackIdPart = phone.slice(-6);
        const tempPassword = `${phone}@${fallbackIdPart}`;
        
        console.log(
          "[otp-handler] reset_password: Creating with unique email:",
          uniqueEmail,
        );
        
        try {
          const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              email: uniqueEmail,
              password: tempPassword,
              email_confirm: true,
              user_metadata: {
                phone: phone,
                created_at: timestamp,
                test_user:
                  phone.startsWith("964999") ||
                  ["9647814104097", "9647816820964"].includes(phone),
              },
            }),
          });

          if (createRes.ok) {
            const newUserData = await createRes.json();
            authUser = newUserData.user || newUserData;
            console.log(
              "[otp-handler] reset_password: Created new auth account:",
              authUser.id,
            );
            console.log(
              "[otp-handler] reset_password: Auth user object:",
              JSON.stringify({ id: authUser.id, email: authUser.email }),
            );
            
            // If we have a profile with a different ID, update it to match auth ID
            if (targetAuthUserId && targetAuthUserId !== authUser.id) {
              console.log(
                "[otp-handler] reset_password: Updating profile ID to match auth ID...",
              );
              console.log(
                "[otp-handler] reset_password: Old profile ID:",
                targetAuthUserId,
              );
              console.log(
                "[otp-handler] reset_password: New auth ID:",
                authUser.id,
              );
              try {
                const updateRes = await fetch(
                  `${supabaseUrl}/rest/v1/users?id=eq.${targetAuthUserId}`,
                  {
                    method: "PATCH",
                  headers: {
                      "Content-Type": "application/json",
                      apikey: serviceRoleKey,
                      Authorization: `Bearer ${serviceRoleKey}`,
                      Prefer: "return=minimal",
                  },
                  body: JSON.stringify({ id: authUser.id }),
                  },
                );
                
                if (updateRes.ok) {
                  console.log(
                    "[otp-handler] reset_password: Profile ID updated successfully",
                  );
                } else {
                  const updateErrorText = await updateRes.text();
                  console.error(
                    "[otp-handler] reset_password: Failed to update profile ID:",
                    updateErrorText,
                  );
                  console.error(
                    "[otp-handler] reset_password: Update response status:",
                    updateRes.status,
                  );
                }
              } catch (updateErr) {
                console.error(
                  "[otp-handler] reset_password: Error updating profile ID:",
                  updateErr,
                );
              }
            } else if (!targetAuthUserId) {
              console.log(
                "[otp-handler] reset_password: No profile found by phone - user may need to register",
              );
            } else {
              console.log(
                "[otp-handler] reset_password: Profile ID already matches auth ID",
              );
            }
          } else {
            const errorText = await createRes.text();
            console.error(
              "[otp-handler] reset_password: Failed to create auth account:",
              errorText,
            );
            console.error(
              "[otp-handler] reset_password: Create response status:",
              createRes.status,
            );
            return Response.json(
              { error: "Failed to create auth account", details: errorText },
              { status: 500, headers: corsHeaders },
            );
          }
        } catch (createErr) {
          console.error(
            "[otp-handler] reset_password: Error creating auth account:",
            createErr,
          );
          return Response.json(
            {
              error: "Failed to create auth account",
              details: String(createErr),
            },
            { status: 500, headers: corsHeaders },
          );
        }
      }

      if (!authUser || !authUser.id) {
        console.error(
          "[otp-handler] reset_password: User not found in auth system",
        );
        console.error("[otp-handler] reset_password: authUser:", authUser);
        return Response.json(
          { error: "User not found in auth system" },
          { status: 404, headers: corsHeaders },
        );
      }

      const user = authUser;
      console.log(
        "[otp-handler] reset_password: Using auth user ID for password update:",
        user.id,
      );

      // Read id_number from public users table using user.id
      const profUrl = new URL(`${supabaseUrl}/rest/v1/users`);
      profUrl.searchParams.set("id", `eq.${user.id}`);
      profUrl.searchParams.set("select", "id,id_number");
      const profRes = await fetch(profUrl.toString(), {
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      
      // If profile not found by ID, try by phone (in case profile ID wasn't updated yet)
      let profile: any = null;
      if (profRes.ok) {
        const profRows = await profRes.json();
        profile = Array.isArray(profRows) ? profRows[0] : null;
      }
      
      if (!profile && targetAuthUserId) {
        // Profile exists but with different ID - try fetching by the old ID
        console.log(
          "[otp-handler] reset_password: Profile not found by auth ID, trying profile ID...",
        );
        const profUrl2 = new URL(`${supabaseUrl}/rest/v1/users`);
        profUrl2.searchParams.set("id", `eq.${targetAuthUserId}`);
        profUrl2.searchParams.set("select", "id,id_number");
        const profRes2 = await fetch(profUrl2.toString(), {
          headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
          },
        });
        if (profRes2.ok) {
          const profRows2 = await profRes2.json();
          profile = Array.isArray(profRows2) ? profRows2[0] : null;
        }
      }
      
      const idNumber = profile?.id_number;
      // Compute deterministic password: phonenumber@IDCARDnumber
      // Fallback: if no id_number on file yet, use last 6 digits of phone
      const fallbackIdPart = phone.slice(-6);
      const deterministicPassword = `${phone}@${idNumber ? String(idNumber) : fallbackIdPart}`;

      console.log(
        "[otp-handler] reset_password: Setting deterministic password (format: phone@idNumber)",
      );
      console.log(
        "[otp-handler] reset_password: Updating password for user ID:",
        user.id,
      );

      // Update password via Auth Admin API
      const setRes = await fetch(
        `${supabaseUrl}/auth/v1/admin/users/${user.id}`,
        {
          method: "PUT",
        headers: {
            "Content-Type": "application/json",
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({ password: String(deterministicPassword) }),
        },
      );

      if (!setRes.ok) {
        const text = await setRes.text();
        console.error("[otp-handler] reset_password: Failed to set password");
        console.error("[otp-handler] reset_password: Status:", setRes.status);
        console.error("[otp-handler] reset_password: Response:", text);
        console.error("[otp-handler] reset_password: User ID used:", user.id);
        return Response.json(
          { error: "Failed to set password", details: text },
          { status: 500, headers: corsHeaders },
        );
      }

      // Return the password so the client can sign in immediately (do not log this server-side)
      return Response.json(
        { success: true, newPassword: deterministicPassword },
        { status: 200, headers: corsHeaders },
      );
    }

    // ========== DELETE AUTH USER ==========
    if (action === "delete_auth_user") {
      const { phoneNumber } = body as { phoneNumber?: string };

      if (!phoneNumber) {
        return Response.json(
          { error: "phoneNumber is required" },
          { status: 400, headers: corsHeaders },
        );
      }

      const phone = normalizePhone(phoneNumber);
      console.log("[otp-handler] delete_auth_user: Normalized phone:", phone);

      // Find auth user by email
      const emailPrimary = `${phone}@hur.delivery`;

      let authUser: any = null;
      
      // Try to find user by email using Admin API
      // First try primary email
      try {
        const getUserRes = await fetch(
          `${supabaseUrl}/auth/v1/admin/users?email=${encodeURIComponent(emailPrimary)}`,
          {
            method: "GET",
          headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
          },
          },
        );

        if (getUserRes.ok) {
          const userData = await getUserRes.json();
          if (
            userData &&
            userData.users &&
            Array.isArray(userData.users) &&
            userData.users.length > 0
          ) {
            authUser = userData.users[0];
            console.log(
              "[otp-handler] delete_auth_user: Found user by primary email:",
              authUser.id,
            );
          }
        }
      } catch (e) {
        console.log(
          "[otp-handler] delete_auth_user: Error querying primary email:",
          e,
        );
      }

      // If still not found, try listing all users (fallback)
      if (!authUser) {
        try {
          const adminRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
            method: "GET",
            headers: {
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
          });

          if (adminRes.ok) {
            const users = await adminRes.json();
            // The response might be { users: [...] } or just [...]
            const usersList = users.users || users;
            if (Array.isArray(usersList)) {
              authUser = usersList.find((u: any) => {
                const em = (u.email || "").toLowerCase();
                return em === emailPrimary.toLowerCase();
              });
              if (authUser) {
                console.log(
                  "[otp-handler] delete_auth_user: Found user by listing all users:",
                  authUser.id,
                );
              }
            }
          }
        } catch (e) {
          console.log(
            "[otp-handler] delete_auth_user: Error listing users:",
            e,
          );
        }
      }

      // If user not found, that's okay - maybe it doesn't exist or was already deleted
      if (!authUser) {
        console.log(
          "[otp-handler] delete_auth_user: Auth user not found - may not exist",
        );
        // Return success anyway - user doesn't exist, so deletion is already "done"
        return Response.json(
          { success: true, message: "Auth user not found (may not exist)" },
          { status: 200, headers: corsHeaders },
        );
      }

      console.log(
        "[otp-handler] delete_auth_user: Found auth user:",
        authUser.id,
      );

      // Delete the auth user using Admin API
      const deleteRes = await fetch(
        `${supabaseUrl}/auth/v1/admin/users/${authUser.id}`,
        {
          method: "DELETE",
        headers: {
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
        },
        },
      );

      if (!deleteRes.ok) {
        const text = await deleteRes.text();
        console.error(
          "[otp-handler] delete_auth_user: Failed to delete, status:",
          deleteRes.status,
          "response:",
          text,
        );
        return Response.json(
          { error: "Failed to delete auth user", details: text },
          { status: 500, headers: corsHeaders },
        );
      }

      console.log(
        "[otp-handler] delete_auth_user: ✅ Auth user deleted successfully",
      );

      return Response.json(
        { success: true },
        { status: 200, headers: corsHeaders },
      );
    }

    // Unknown action
    console.error("[otp-handler] ❌ Unknown action received:", action);
    console.error(
      "[otp-handler] Body received:",
      JSON.stringify(body, null, 2),
    );
    return Response.json(
      { 
        error:
          "Unknown action. Use: send, verify, reset_password, or delete_auth_user",
        receivedAction: action || "(missing)",
        bodyKeys: Object.keys(body || {}),
      },
      { status: 400, headers: corsHeaders },
    );
  } catch (e: any) {
    console.error("[otp-handler] ==== UNCAUGHT ERROR ====");
    console.error(
      "[otp-handler] Error type:",
      e?.constructor?.name ?? typeof e,
    );
    console.error("[otp-handler] Error message:", e?.message ?? String(e));
    console.error("[otp-handler] Error stack:", e?.stack);
    console.error(
      "[otp-handler] Full error:",
      JSON.stringify(e, Object.getOwnPropertyNames(e)),
    );
    
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    };
    
    return Response.json(
      { error: e?.message ?? "Unknown error", details: String(e) },
      { status: 500, headers: corsHeaders },
    );
  }
});

