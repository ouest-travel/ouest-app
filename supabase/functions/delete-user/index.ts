// Delete User Edge Function
// Permanently deletes the calling user's account (App Store Guideline 5.1.1(v)).
//
// Flow:
//   1. Verify the caller's JWT and resolve their user id.
//   2. Sign in with Apple accounts: exchange the fresh authorization code
//      the app sends for a refresh token and revoke it, as Apple requires
//      on account deletion. Best-effort; deletion still proceeds.
//   3. Best-effort removal of their storage objects (avatar, trip covers).
//   4. auth.admin.deleteUser — profiles → trips → every trip-scoped table
//      cascade from there via ON DELETE CASCADE.
//
// Uses the platform-provided SUPABASE_URL / SUPABASE_ANON_KEY /
// SUPABASE_SERVICE_ROLE_KEY secrets. Apple revocation also needs:
//   APPLE_SIWA_KEY_ID       Key ID of a .p8 key with Sign in with Apple enabled
//   APPLE_SIWA_PRIVATE_KEY  that .p8 file, base64-encoded or pasted as-is
//   APPLE_TEAM_ID           optional, falls back to APNS_TEAM_ID
//   APPLE_CLIENT_ID         optional, falls back to APNS_BUNDLE_ID (the app's bundle id)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ─── Sign in with Apple token revocation ────────────────────────────

const APPLE_AUTH_URL = "https://appleid.apple.com";

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** The secret may hold the .p8 file base64-encoded (like APNS_PRIVATE_KEY)
 *  or pasted as-is, with real or escaped newlines and stray quotes. */
function decodePrivateKey(value: string): string {
  const trimmed = value.trim().replace(/^["']|["']$/g, "");
  if (trimmed.includes("BEGIN PRIVATE KEY")) return trimmed.replace(/\\n/g, "\n");
  return atob(trimmed.replace(/\s/g, ""));
}

/** ES256 client secret Apple expects on /auth/token and /auth/revoke. */
async function createAppleClientSecret(
  teamId: string,
  clientId: string,
  keyId: string,
  privateKeyBase64: string
): Promise<string> {
  const pemBody = decodePrivateKey(privateKeyBase64)
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const now = Math.floor(Date.now() / 1000);
  const encode = (obj: unknown) =>
    base64url(new TextEncoder().encode(JSON.stringify(obj)));
  const signingInput = `${encode({ alg: "ES256", kid: keyId })}.${encode({
    iss: teamId,
    iat: now,
    exp: now + 300,
    aud: APPLE_AUTH_URL,
    sub: clientId,
  })}`;
  // Web Crypto returns the raw r||s signature JWT needs.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

/** Decode a JWT payload without verifying it. Only used on an id_token
 *  received directly from Apple over TLS. */
function jwtPayload(jwt: string): Record<string, unknown> {
  const part = jwt.split(".")[1] ?? "";
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "=")));
}

/** Exchange the one-time code for a refresh token, then revoke it.
 *  `expectedAppleSub` is the Apple user id linked to this account; the code
 *  comes from whichever Apple ID is signed in on the device, so a mismatch
 *  means it belongs to someone else and nothing is revoked. */
async function revokeAppleTokens(
  authorizationCode: string,
  expectedAppleSub: string
): Promise<void> {
  const keyId = Deno.env.get("APPLE_SIWA_KEY_ID");
  const privateKey = Deno.env.get("APPLE_SIWA_PRIVATE_KEY");
  const teamId = Deno.env.get("APPLE_TEAM_ID") ?? Deno.env.get("APNS_TEAM_ID");
  const clientId =
    Deno.env.get("APPLE_CLIENT_ID") ?? Deno.env.get("APNS_BUNDLE_ID");
  if (!keyId || !privateKey || !teamId || !clientId) {
    console.warn("[delete-user] Apple revocation skipped: secrets not configured");
    return;
  }

  const clientSecret = await createAppleClientSecret(
    teamId,
    clientId,
    keyId,
    privateKey
  );

  const tokenRes = await fetch(`${APPLE_AUTH_URL}/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`token exchange ${tokenRes.status}: ${await tokenRes.text()}`);
  }
  const { refresh_token, access_token, id_token } = await tokenRes.json();
  const appleSub = id_token ? jwtPayload(id_token).sub : undefined;
  if (appleSub !== expectedAppleSub) {
    throw new Error("authorization code belongs to a different Apple ID");
  }
  const token = refresh_token ?? access_token;
  if (!token) throw new Error("token exchange returned no token");

  const revokeRes = await fetch(`${APPLE_AUTH_URL}/auth/revoke`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: refresh_token ? "refresh_token" : "access_token",
    }),
  });
  if (!revokeRes.ok) {
    throw new Error(`revoke ${revokeRes.status}: ${await revokeRes.text()}`);
  }
}

// ─── Handler ─────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Resolve the caller from their own JWT — never trust a user id in the body.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return json({ error: "Invalid session" }, 401);
  }

  // Body is optional: only Sign in with Apple accounts send a code.
  let appleAuthorizationCode: string | undefined;
  try {
    const body = await req.json();
    if (typeof body?.apple_authorization_code === "string") {
      appleAuthorizationCode = body.apple_authorization_code;
    }
  } catch {
    // No or invalid JSON body — nothing to revoke.
  }

  const appleIdentity = user.identities?.find((i) => i.provider === "apple");
  const appleSub =
    (appleIdentity?.identity_data?.sub as string | undefined) ??
    appleIdentity?.id;
  if (appleAuthorizationCode && appleSub) {
    try {
      await revokeAppleTokens(appleAuthorizationCode, appleSub);
    } catch (e) {
      console.warn("[delete-user] Apple token revocation failed:", e);
    }
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  // Storage objects don't cascade with the row; clean up what we can.
  // Failures here are logged, not fatal — the account must still go.
  const folder = user.id.toLowerCase();
  try {
    await admin.storage.from("profile-avatars").remove([`${folder}/avatar.jpg`]);
  } catch (e) {
    console.warn("[delete-user] avatar cleanup failed:", e);
  }
  try {
    const { data: covers } = await admin.storage.from("trip-covers").list(folder);
    if (covers && covers.length > 0) {
      await admin.storage
        .from("trip-covers")
        .remove(covers.map((f) => `${folder}/${f.name}`));
    }
  } catch (e) {
    console.warn("[delete-user] cover cleanup failed:", e);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("[delete-user] deleteUser failed:", deleteError);
    return json({ error: deleteError.message }, 500);
  }

  return json({ success: true });
});
