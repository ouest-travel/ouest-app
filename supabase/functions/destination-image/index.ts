// Destination Image Edge Function
// Gives a trip without a user-uploaded cover a stock Unsplash photo of its
// destination.
//
// Flow:
//   1. Verify the caller's JWT.
//   2. Load the trip through the caller's client (RLS: must be a member).
//   3. Refuse to overwrite a user-uploaded cover (no attribution = user's).
//   4. Look the destination up in `destination_images`; on miss (or a stale
//      "not found"), search Unsplash and cache the pick.
//   5. Write cover + attribution onto the trip through the caller's client,
//      so RLS enforces edit permission instead of us re-checking roles.
//   6. Ping Unsplash's download endpoint (required by their API terms
//      whenever a photo is chosen for use).
//
// Secrets: UNSPLASH_ACCESS_KEY (set via `supabase secrets set`), plus the
// platform-provided SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const UNSPLASH_API = "https://api.unsplash.com";
const UTM = "utm_source=ouest&utm_medium=referral";
const NOT_FOUND_TTL_MS = 7 * 24 * 60 * 60 * 1000;

interface DestinationImage {
  url: string;
  photographer: string;
  photographerUrl: string;
  photoUrl: string;
  downloadLocation?: string;
}

interface CacheRow {
  query: string;
  image_url: string | null;
  photographer: string | null;
  photographer_url: string | null;
  photo_url: string | null;
  download_location: string | null;
  fetched_at: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// Cache key: "  Lisbon,  Portugal " and "lisbon, portugal" are one entry.
function normalise(destination: string): string {
  return destination.trim().toLowerCase().replace(/\s+/g, " ");
}

function withUtm(url: string): string {
  return url.includes("?") ? `${url}&${UTM}` : `${url}?${UTM}`;
}

async function searchUnsplash(
  query: string,
  accessKey: string,
): Promise<DestinationImage | null> {
  const params = new URLSearchParams({
    query,
    orientation: "landscape",
    content_filter: "high",
    per_page: "1",
  });
  const res = await fetch(`${UNSPLASH_API}/search/photos?${params}`, {
    headers: {
      Authorization: `Client-ID ${accessKey}`,
      "Accept-Version": "v1",
    },
  });
  if (!res.ok) {
    throw new Error(`Unsplash search failed: ${res.status}`);
  }
  const body = await res.json();
  const photo = body?.results?.[0];
  if (!photo?.urls?.raw) return null;

  // `raw` accepts imgix params; 1600px wide covers a 3x phone hero and
  // keeps the payload far smaller than the original.
  return {
    url: `${photo.urls.raw}&w=1600&q=80&fm=jpg&fit=max`,
    photographer: photo.user?.name ?? "Unsplash photographer",
    photographerUrl: withUtm(photo.user?.links?.html ?? "https://unsplash.com"),
    photoUrl: withUtm(photo.links?.html ?? "https://unsplash.com"),
    downloadLocation: photo.links?.download_location,
  };
}

/// Returns the cached image for a destination, fetching and caching on a
/// miss. `null` means Unsplash has nothing for this query.
async function resolveImage(
  admin: SupabaseClient,
  destination: string,
  accessKey: string,
): Promise<DestinationImage | null> {
  const key = normalise(destination);

  const { data: cached } = await admin
    .from("destination_images")
    .select("*")
    .eq("query", key)
    .maybeSingle<CacheRow>();

  if (cached) {
    if (cached.image_url) {
      return {
        url: cached.image_url,
        photographer: cached.photographer ?? "Unsplash photographer",
        photographerUrl: cached.photographer_url ?? "https://unsplash.com",
        photoUrl: cached.photo_url ?? "https://unsplash.com",
        downloadLocation: cached.download_location ?? undefined,
      };
    }
    const age = Date.now() - new Date(cached.fetched_at).getTime();
    if (age < NOT_FOUND_TTL_MS) return null;
  }

  const image = await searchUnsplash(destination, accessKey);

  const { error: cacheError } = await admin.from("destination_images").upsert({
    query: key,
    image_url: image?.url ?? null,
    photographer: image?.photographer ?? null,
    photographer_url: image?.photographerUrl ?? null,
    photo_url: image?.photoUrl ?? null,
    download_location: image?.downloadLocation ?? null,
    fetched_at: new Date().toISOString(),
  });
  if (cacheError) {
    console.warn("[destination-image] cache write failed:", cacheError);
  }

  return image;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ success: false, error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ success: false, error: "Missing authorization" }, 401);
  }

  const accessKey = Deno.env.get("UNSPLASH_ACCESS_KEY");
  if (!accessKey) {
    console.error("[destination-image] UNSPLASH_ACCESS_KEY is not set");
    return json({ success: false, error: "Image service not configured" }, 500);
  }

  let tripId: string | undefined;
  try {
    ({ tripId } = await req.json());
  } catch {
    // fall through to the validation below
  }
  if (typeof tripId !== "string" || tripId.length === 0) {
    return json({ success: false, error: "tripId is required" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();
  if (userError || !user) {
    return json({ success: false, error: "Invalid session" }, 401);
  }

  // RLS: non-members get no row.
  const { data: trip, error: tripError } = await userClient
    .from("trips")
    .select("id, destination, cover_image_url, cover_attribution")
    .eq("id", tripId)
    .maybeSingle();
  if (tripError || !trip) {
    return json({ success: false, error: "Trip not found" }, 404);
  }

  // Never replace a photo the user uploaded themselves.
  if (trip.cover_image_url && !trip.cover_attribution) {
    return json({ success: true, applied: false, image: null });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  let image: DestinationImage | null;
  try {
    image = await resolveImage(admin, trip.destination, accessKey);
  } catch (e) {
    console.error("[destination-image] lookup failed:", e);
    return json({ success: false, error: "Image lookup failed" }, 502);
  }

  if (!image) {
    return json({ success: true, applied: false, image: null });
  }

  // Through the caller's client so RLS decides whether they may edit.
  // `.select().single()` turns "0 rows updated" (viewer) into an error.
  const { error: updateError } = await userClient
    .from("trips")
    .update({
      cover_image_url: image.url,
      cover_attribution: image.photographer,
      cover_attribution_url: image.photographerUrl,
    })
    .eq("id", tripId)
    .select("id")
    .single();
  if (updateError) {
    return json({ success: false, error: "Not allowed to edit this trip" }, 403);
  }

  // Unsplash requires a download ping each time a photo is chosen for use.
  // Best effort — a failure here must not cost the user their cover.
  if (image.downloadLocation) {
    fetch(image.downloadLocation, {
      headers: { Authorization: `Client-ID ${accessKey}`, "Accept-Version": "v1" },
    }).catch((e) => console.warn("[destination-image] download ping failed:", e));
  }

  return json({
    success: true,
    applied: true,
    image: {
      url: image.url,
      photographer: image.photographer,
      photographerUrl: image.photographerUrl,
      photoUrl: image.photoUrl,
    },
  });
});
