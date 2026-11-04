import { supabaseAdmin } from "./supabase.js";

export type ProfilePreview = {
  handle: string;
  fullName: string | null;
  bio: string | null;
  avatarUrl: string | null;
  nationality: string | null;
  isPrivate: boolean;
  tripCount: number;
};

// Resolve a profile handle to its public preview fields.
// Private profiles return isPrivate=true with sensitive fields zeroed out
// so the OG card can render a generic "private profile" preview.
export async function fetchProfileByHandle(
  handle: string
): Promise<ProfilePreview | null> {
  const sb = supabaseAdmin();

  const { data: profile, error } = await sb
    .from("profiles")
    .select("id, handle, full_name, bio, avatar_url, nationality, is_private")
    .ilike("handle", handle) // case-insensitive match
    .maybeSingle();

  if (error || !profile) return null;

  if (profile.is_private) {
    return {
      handle: profile.handle,
      fullName: null,
      bio: null,
      avatarUrl: null,
      nationality: null,
      isPrivate: true,
      tripCount: 0,
    };
  }

  // Count public trips this user is a member of
  const { count } = await sb
    .from("trip_members")
    .select("*", { count: "exact", head: true })
    .eq("user_id", profile.id);

  return {
    handle: profile.handle,
    fullName: profile.full_name,
    bio: profile.bio,
    avatarUrl: profile.avatar_url,
    nationality: profile.nationality,
    isPrivate: false,
    tripCount: count ?? 0,
  };
}
