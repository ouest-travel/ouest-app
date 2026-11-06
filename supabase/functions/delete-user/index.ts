// Delete User Edge Function
// Permanently deletes the calling user's account (App Store Guideline 5.1.1(v)).
//
// Flow:
//   1. Verify the caller's JWT and resolve their user id.
//   2. Best-effort removal of their storage objects (avatar, trip covers).
//   3. auth.admin.deleteUser — profiles → trips → every trip-scoped table
//      cascade from there via ON DELETE CASCADE.
//
// Uses the platform-provided SUPABASE_URL / SUPABASE_ANON_KEY /
// SUPABASE_SERVICE_ROLE_KEY secrets; nothing extra to configure.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

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
