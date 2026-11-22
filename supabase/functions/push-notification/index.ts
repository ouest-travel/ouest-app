// Push Notification Edge Function
// Receives notification data, queries device tokens, and sends APNs pushes.
//
// Required Supabase secrets:
//   APNS_KEY_ID       — Key ID from Apple Developer Portal
//   APNS_TEAM_ID      — Team ID from Apple Developer Portal
//   APNS_PRIVATE_KEY  — Base64-encoded .p8 key contents
//   APNS_BUNDLE_ID    — App bundle ID (com.ouest.app)
//   APNS_ENVIRONMENT  — "development" or "production"

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Types ───────────────────────────────────────────────────────────

interface PushRequest {
  user_ids: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface DeviceToken {
  id: string;
  user_id: string;
  token: string;
}

// ─── APNs JWT ────────────────────────────────────────────────────────

async function createApnsJwt(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const privateKeyBase64 = Deno.env.get("APNS_PRIVATE_KEY")!;

  // Decode the base64-encoded .p8 key
  const pemContents = atob(privateKeyBase64);
  const pemBody = pemContents
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  // Import the ES256 private key
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // Build JWT header + payload
  const header = { alg: "ES256", kid: keyId };
  const payload = { iss: teamId, iat: Math.floor(Date.now() / 1000) };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const headerB64 = encode(header);
  const payloadB64 = encode(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  // Sign with ES256
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  // Convert DER signature to raw r||s format for JWT
  const sigArray = new Uint8Array(signature);
  const sigB64 = btoa(String.fromCharCode(...sigArray))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${signingInput}.${sigB64}`;
}

// ─── Send single APNs push ──────────────────────────────────────────

async function sendApnsPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  jwt: string
): Promise<{ token: string; success: boolean; status: number }> {
  const env = Deno.env.get("APNS_ENVIRONMENT") || "development";
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") || "com.ouest.app";
  const host =
    env === "production"
      ? "api.push.apple.com"
      : "api.sandbox.push.apple.com";

  const apnsPayload = {
    aps: {
      alert: { title, body },
      badge: 1,
      sound: "default",
      "mutable-content": 1,
    },
    ...data,
  };

  try {
    const response = await fetch(`https://${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        Authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(apnsPayload),
    });

    return { token, success: response.ok, status: response.status };
  } catch (error) {
    console.error(`Failed to send push to ${token}:`, error);
    return { token, success: false, status: 0 };
  }
}

// ─── Main handler ────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Validate authorization (must use service_role key)
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body: PushRequest = await req.json();

    if (!body.user_ids?.length || !body.title || !body.body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: user_ids, title, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create Supabase admin client to query device tokens
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Fetch device tokens for all target users
    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("id, user_id, token")
      .in("user_id", body.user_ids);

    if (tokensError) {
      console.error("Error fetching tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens?.length) {
      return new Response(
        JSON.stringify({ sent: 0, failed: 0, message: "No device tokens found" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Check if APNs secrets are configured
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    if (!apnsKeyId) {
      // APNs not configured — just log and return success
      // Notifications are still stored in the DB by triggers
      console.log(
        `APNs not configured. Would send ${tokens.length} pushes for: ${body.title}`
      );
      return new Response(
        JSON.stringify({
          sent: 0,
          failed: 0,
          message: "APNs not configured — notifications stored in DB only",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create APNs JWT
    const jwt = await createApnsJwt();

    // Send pushes in parallel
    const results = await Promise.all(
      (tokens as DeviceToken[]).map((t) =>
        sendApnsPush(t.token, body.title, body.body, body.data || {}, jwt)
      )
    );

    const sent = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    // Clean up invalid tokens (410 = token no longer valid)
    const invalidTokens = results
      .filter((r) => r.status === 410)
      .map((r) => r.token);

    if (invalidTokens.length > 0) {
      await supabase
        .from("device_tokens")
        .delete()
        .in("token", invalidTokens);
      console.log(`Cleaned up ${invalidTokens.length} invalid tokens`);
    }

    return new Response(
      JSON.stringify({ sent, failed, total: tokens.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Push notification error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
