import { supabaseAdmin } from "./supabase.js";

export type TripPreview = {
  inviteCode: string;
  title: string;
  destination: string;
  startDate: string | null; // ISO date
  endDate: string | null;
  coverImageUrl: string | null;
  memberCount: number;
  createdByName: string | null;
};

// Resolve a trip invite code to the trip's public preview fields.
// Anyone with a valid invite code can see the preview — the code IS the gate.
// Returns null if the code doesn't exist, is inactive, or expired.
export async function fetchTripByInviteCode(
  code: string
): Promise<TripPreview | null> {
  const sb = supabaseAdmin();

  // 1. Resolve invite -> trip_id (also check it's active + not expired)
  const { data: invite, error: inviteErr } = await sb
    .from("trip_invites")
    .select("trip_id, is_active, expires_at, max_uses, use_count")
    .eq("code", code)
    .maybeSingle();

  if (inviteErr || !invite) return null;
  if (!invite.is_active) return null;
  if (invite.expires_at && new Date(invite.expires_at) < new Date()) return null;
  if (invite.max_uses > 0 && invite.use_count >= invite.max_uses) return null;

  // 2. Fetch trip + creator name + member count in parallel
  const [tripRes, countRes] = await Promise.all([
    sb
      .from("trips")
      .select(
        "title, destination, start_date, end_date, cover_image_url, created_by"
      )
      .eq("id", invite.trip_id)
      .maybeSingle(),
    sb
      .from("trip_members")
      .select("*", { count: "exact", head: true })
      .eq("trip_id", invite.trip_id),
  ]);

  if (tripRes.error || !tripRes.data) return null;
  const trip = tripRes.data;

  let createdByName: string | null = null;
  if (trip.created_by) {
    const { data: creator } = await sb
      .from("profiles")
      .select("full_name, handle")
      .eq("id", trip.created_by)
      .maybeSingle();
    createdByName = creator?.full_name ?? creator?.handle ?? null;
  }

  return {
    inviteCode: code,
    title: trip.title,
    destination: trip.destination,
    startDate: trip.start_date,
    endDate: trip.end_date,
    coverImageUrl: trip.cover_image_url,
    memberCount: countRes.count ?? 0,
    createdByName,
  };
}

// Pretty date range: "Jun 12 – 19" or "Jun 28 – Jul 4, 2026"
export function formatDateRange(
  start: string | null,
  end: string | null
): string | null {
  if (!start || !end) return null;
  const s = new Date(start + "T00:00:00Z");
  const e = new Date(end + "T00:00:00Z");
  const sameMonth =
    s.getUTCMonth() === e.getUTCMonth() && s.getUTCFullYear() === e.getUTCFullYear();
  const month = (d: Date) =>
    d.toLocaleString("en-US", { month: "short", timeZone: "UTC" });
  // A range that crosses a year boundary needs both years spelled out,
  // otherwise "Aug 8 – Aug 14" hides that it's a year apart.
  if (s.getUTCFullYear() !== e.getUTCFullYear()) {
    return `${month(s)} ${s.getUTCDate()}, ${s.getUTCFullYear()} – ${month(e)} ${e.getUTCDate()}, ${e.getUTCFullYear()}`;
  }
  const sameYearAsNow = s.getUTCFullYear() === new Date().getUTCFullYear();
  const yearSuffix = sameYearAsNow ? "" : `, ${e.getUTCFullYear()}`;
  if (sameMonth) {
    return `${month(s)} ${s.getUTCDate()} – ${e.getUTCDate()}${yearSuffix}`;
  }
  return `${month(s)} ${s.getUTCDate()} – ${month(e)} ${e.getUTCDate()}${yearSuffix}`;
}
