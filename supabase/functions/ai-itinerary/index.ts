// AI Itinerary Edge Function
// Generates a complete itinerary for a trip using Claude, then bulk-inserts
// days and activities into the database. Supports two input modes:
//
//   inputType: "generate" — destination + dates + preferences → full itinerary
//   inputType: "import"   — paste a URL / blog / TikTok / free text → AI extracts
//
// Required Supabase secrets:
//   ANTHROPIC_API_KEY — API key for the Anthropic Messages API

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Types ───────────────────────────────────────────────────────────

interface TripPreferences {
  vibes: string[];           // e.g. ["foodie", "cultural"]
  budgetLevel?: string;      // "budget" | "moderate" | "luxury"
}

interface GenerateRequest {
  inputType: "generate";
  tripId: string;
  userId: string;
  destination: string;
  startDate: string;         // ISO date "2026-06-15"
  endDate: string;           // ISO date
  preferences: TripPreferences;
}

interface ImportRequest {
  inputType: "import";
  tripId: string;
  userId: string;
  inputText: string;         // URL or freeform text
  startDate?: string;        // optional; AI infers if missing
  endDate?: string;
}

type AIRequest = GenerateRequest | ImportRequest;

interface ClaudeActivity {
  title: string;
  description?: string;
  locationName?: string;
  startTime?: string;        // "HH:mm:ss"
  endTime?: string;
  category: "food" | "transport" | "activity" | "accommodation" | "other";
  costEstimate?: number;
  currency?: string;
}

interface ClaudeDay {
  dayNumber: number;
  date?: string;             // ISO date "2026-06-15"
  title?: string;
  notes?: string;
  activities: ClaudeActivity[];
}

interface ClaudeItineraryOutput {
  days: ClaudeDay[];
}

// ─── Claude API Call ─────────────────────────────────────────────────

const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
const CLAUDE_MODEL = "claude-3-5-sonnet-20241022";

/** Builds the structured-output prompt that Claude must answer. */
function buildSystemPrompt(): string {
  return `You are a travel planning assistant. Given a destination, date range, and traveler preferences, you produce a realistic, well-paced itinerary as STRICT JSON only — no prose, no markdown, no code fences.

The JSON MUST conform to this TypeScript schema:

interface ItineraryOutput {
  days: Array<{
    dayNumber: number;        // 1-indexed
    date?: string;            // "YYYY-MM-DD" when known
    title?: string;           // short theme like "Old Town & Beach"
    notes?: string;           // optional 1-sentence summary
    activities: Array<{
      title: string;          // place / activity name
      description?: string;   // 1-2 sentences
      locationName?: string;  // human-readable address or neighbourhood
      startTime?: string;     // "HH:mm:ss" 24h
      endTime?: string;       // "HH:mm:ss" 24h
      category: "food" | "transport" | "activity" | "accommodation" | "other";
      costEstimate?: number;  // local currency amount, integer
      currency?: string;      // ISO code e.g. "EUR", "USD"
    }>;
  }>;
}

Rules:
- Output ONLY the JSON object. No explanations, no markdown.
- Use 3–6 activities per day (mornings, midday, afternoon, evening).
- Stagger start times naturally and leave realistic gaps for transit.
- Pick real places (not fictional). Each day MUST include 3–4 lesser-known local gems — small restaurants, neighborhood spots, hidden viewpoints, niche museums, quiet parks — alongside any unavoidable must-see icons. Bias toward what locals actually recommend over what's at the top of guidebooks.
- When a place is a hidden gem or local favourite, briefly say so in the activity's description (e.g., "favourite of locals, rarely on guidebooks", "tucked-away spot most tourists miss"). When it's a marquee landmark, you can skip that note.
- Categorize correctly: meals = food, hotels/check-in = accommodation, etc.
- For multi-day trips, vary the daily theme (avoid repetition).
- Respect budget level and adjust the gem mix accordingly:
  - "budget"   → free attractions, street food finds, hostels, free walking tours, public spots.
  - "moderate" → mid-range neighborhood favourites and local restaurants.
  - "luxury"   → boutique experiences, chef-led restaurants, design hotels, private/small-group activities.`;
}

/** Builds the user-message payload depending on the input type. */
function buildUserPrompt(req: AIRequest): string {
  if (req.inputType === "generate") {
    const days = Math.max(
      1,
      Math.ceil(
        (new Date(req.endDate).getTime() - new Date(req.startDate).getTime()) /
          (1000 * 60 * 60 * 24)
      ) + 1
    );
    const vibesLine = req.preferences.vibes.length
      ? `Traveler vibes: ${req.preferences.vibes.join(", ")}.`
      : "";
    const budgetLine = req.preferences.budgetLevel
      ? `Budget level: ${req.preferences.budgetLevel}.`
      : "";

    return [
      `Destination: ${req.destination}`,
      `Trip dates: ${req.startDate} to ${req.endDate} (${days} day${days === 1 ? "" : "s"}).`,
      vibesLine,
      budgetLine,
      `Generate a complete day-by-day itinerary. Day 1 starts on ${req.startDate}; ` +
        `produce exactly ${days} day${days === 1 ? "" : "s"}. ` +
        `Respond with ONLY the JSON object.`,
    ]
      .filter((s) => s.length > 0)
      .join("\n");
  } else {
    // import mode — content may come from a TikTok caption, Instagram post,
    // YouTube description, blog article, or freeform user notes.
    const dateRange =
      req.startDate && req.endDate
        ? `The trip is from ${req.startDate} to ${req.endDate}. Use these dates.`
        : `If specific dates aren't mentioned, organize into a logical day-by-day plan starting on Day 1.`;

    return [
      `The user shared the following content (possibly a social media post, blog article, or their own notes) describing places they want to visit on a trip. Extract a structured itinerary from it.`,
      "",
      `Guidelines for extraction:`,
      `- Focus on real places, restaurants, neighborhoods, and activities mentioned.`,
      `- If the content is sparse (e.g., just a few captions or bullet points), generously fill in supporting activities to make a complete, well-paced trip around the mentioned places.`,
      `- If the content mentions specific times, days, or sequences, respect them.`,
      `- If a destination is implied but not stated (e.g., the content is clearly about Tokyo), use that as the location context.`,
      `- Add the hidden-gem mix from the system prompt rules even when extracting from external content.`,
      "",
      "--- Content ---",
      req.inputText.slice(0, 12000),
      "--- End content ---",
      "",
      dateRange,
      `Respond with ONLY the JSON object.`,
    ].join("\n");
  }
}

/**
 * Extracts the value of a `<meta>` tag by property/name.
 * Looks for both `property="..."` (OG/Twitter style) and `name="..."` (standard).
 */
function extractMeta(html: string, key: string): string | null {
  // Pattern 1: <meta property="og:title" content="...">
  const propRx = new RegExp(
    `<meta\\s+[^>]*property\\s*=\\s*["']${key}["'][^>]*content\\s*=\\s*["']([^"']*)["']`,
    "i"
  );
  // Pattern 2: <meta content="..." property="og:title">
  const propRevRx = new RegExp(
    `<meta\\s+[^>]*content\\s*=\\s*["']([^"']*)["'][^>]*property\\s*=\\s*["']${key}["']`,
    "i"
  );
  // Pattern 3: <meta name="description" content="...">
  const nameRx = new RegExp(
    `<meta\\s+[^>]*name\\s*=\\s*["']${key}["'][^>]*content\\s*=\\s*["']([^"']*)["']`,
    "i"
  );

  for (const rx of [propRx, propRevRx, nameRx]) {
    const m = html.match(rx);
    if (m && m[1]) {
      // Decode common HTML entities
      return m[1]
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .trim();
    }
  }
  return null;
}

/**
 * Extracts page content for any URL, prioritizing OG meta tags (which Instagram,
 * TikTok, YouTube, and most modern SPAs rely on for share previews). Falls back to
 * body text for traditional blogs/news/articles.
 *
 * Returns a synthesized text block suitable for Claude. Empty string if nothing useful.
 */
async function fetchUrlContent(url: string): Promise<string> {
  try {
    const response = await fetch(url, {
      headers: {
        // Use a desktop browser UA so SPAs serve the same OG tags they'd give to facebookexternalhit etc.
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
      },
      redirect: "follow",
    });
    if (!response.ok) return "";
    const html = await response.text();

    // 1. Pull rich preview metadata first.
    const ogTitle = extractMeta(html, "og:title");
    const ogDescription = extractMeta(html, "og:description");
    const ogSiteName = extractMeta(html, "og:site_name");
    const twitterTitle = extractMeta(html, "twitter:title");
    const twitterDescription = extractMeta(html, "twitter:description");
    const metaDescription = extractMeta(html, "description");

    const title = ogTitle ?? twitterTitle ?? extractTitleTag(html);
    const description =
      ogDescription ?? twitterDescription ?? metaDescription ?? null;
    const sourceName = ogSiteName ?? hostname(url);

    // 2. Strip the body to plain text. For blog/article-style pages this is
    //    where most of the useful detail lives.
    const bodyText = html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
      .replace(/<header[\s\S]*?<\/header>/gi, " ")
      .replace(/<footer[\s\S]*?<\/footer>/gi, " ")
      .replace(/<nav[\s\S]*?<\/nav>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/gi, " ")
      .replace(/&amp;/gi, "&")
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/\s+/g, " ")
      .trim();

    // 3. Synthesize a clean block for the LLM. Lead with the most reliable
    //    bits (OG metadata) so even SPAs with sparse body content stay useful.
    const parts: string[] = [];
    if (sourceName) parts.push(`Source: ${sourceName}`);
    if (title) parts.push(`Title: ${title}`);
    if (description) parts.push(`Description: ${description}`);
    if (bodyText && bodyText.length > 200) {
      parts.push(`Page content:\n${bodyText.slice(0, 10000)}`);
    } else if (bodyText && bodyText.length > 0 && !description) {
      // Tiny body and no description — still pass it along, every bit helps.
      parts.push(`Page content:\n${bodyText}`);
    }

    return parts.join("\n\n");
  } catch (error) {
    console.error("URL fetch failed:", error);
    return "";
  }
}

/** Best-effort fallback to extract the <title> tag if no OG title is set. */
function extractTitleTag(html: string): string | null {
  const m = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return m ? m[1].trim() : null;
}

/** Pull a clean hostname (e.g., "instagram.com") from a URL. */
function hostname(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

/**
 * Detects URLs in the inputText and, if present, expands them with fetched OG/page
 * content. Handles multiple URLs (e.g. a list of TikTok links). Always preserves
 * the original user text so anything they typed manually still counts.
 */
async function expandImportInput(req: ImportRequest): Promise<ImportRequest> {
  // Match all http(s) URLs, dedupe, cap at 5 to avoid runaway requests.
  const urlMatches = [...req.inputText.matchAll(/https?:\/\/\S+/g)].map((m) => m[0]);
  const uniqueUrls = Array.from(new Set(urlMatches)).slice(0, 5);
  if (uniqueUrls.length === 0) return req;

  // Fetch all URLs in parallel (best-effort — empty results are dropped).
  const fetches = await Promise.all(
    uniqueUrls.map(async (url) => ({
      url,
      content: await fetchUrlContent(url),
    }))
  );

  const expansions: string[] = [];
  for (const { url, content } of fetches) {
    if (!content) continue;
    expansions.push(`--- Content from ${url} ---\n${content}`);
  }

  if (expansions.length === 0) return req;

  return {
    ...req,
    inputText: `${req.inputText}\n\n${expansions.join("\n\n")}`,
  };
}

/** Strip code fences in case Claude ignores instructions and wraps JSON. */
function extractJSON(raw: string): string {
  let s = raw.trim();
  if (s.startsWith("```")) {
    s = s.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "");
  }
  // Find the first { and last } to handle prefix/suffix prose just in case.
  const first = s.indexOf("{");
  const last = s.lastIndexOf("}");
  if (first === -1 || last === -1 || last <= first) return s;
  return s.slice(first, last + 1);
}

async function callClaude(req: AIRequest): Promise<ClaudeItineraryOutput> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY not configured");
  }

  // For import mode, attempt URL expansion first.
  const expanded =
    req.inputType === "import" ? await expandImportInput(req) : req;

  const response = await fetch(CLAUDE_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      system: buildSystemPrompt(),
      messages: [
        {
          role: "user",
          content: buildUserPrompt(expanded),
        },
      ],
    }),
  });

  if (!response.ok) {
    const errBody = await response.text();
    console.error("Claude API error:", response.status, errBody);
    throw new Error(`Claude API returned ${response.status}: ${errBody.slice(0, 200)}`);
  }

  const data = await response.json();
  const text: string = data?.content?.[0]?.text ?? "";
  const jsonStr = extractJSON(text);

  let parsed: ClaudeItineraryOutput;
  try {
    parsed = JSON.parse(jsonStr);
  } catch (parseError) {
    console.error("Failed to parse Claude JSON:", text);
    throw new Error("Couldn't parse the AI response. Please try again.");
  }

  if (!parsed.days || !Array.isArray(parsed.days) || parsed.days.length === 0) {
    throw new Error("AI returned an empty itinerary. Try different preferences.");
  }

  return parsed;
}

// ─── DB Insertion ────────────────────────────────────────────────────

const ALLOWED_CATEGORIES = new Set([
  "food",
  "transport",
  "activity",
  "accommodation",
  "other",
]);

function sanitizeCategory(c: string | undefined): string {
  if (c && ALLOWED_CATEGORIES.has(c)) return c;
  return "activity";
}

/** Trim a string to a max length, or return undefined if empty. */
function clip(value: string | undefined, max: number): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  return trimmed.slice(0, max);
}

/** Coerce HH:mm or HH:mm:ss → HH:mm:ss, or null if invalid. */
function normalizeTime(t: string | undefined): string | null {
  if (!t) return null;
  const m = t.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (!m) return null;
  const h = String(parseInt(m[1], 10)).padStart(2, "0");
  const min = m[2];
  const s = m[3] ?? "00";
  return `${h}:${min}:${s}`;
}

interface DBInsertResult {
  dayCount: number;
  activityCount: number;
}

async function insertItinerary(
  supabase: ReturnType<typeof createClient>,
  tripId: string,
  userId: string,
  itinerary: ClaudeItineraryOutput,
  startDate?: string
): Promise<DBInsertResult> {
  // Replace any existing AI-generated content: delete all current days for this trip.
  // (Days cascade to activities via the FK.) The user explicitly requested a fresh
  // generation, so wiping prior state is the expected behaviour.
  await supabase.from("itinerary_days").delete().eq("trip_id", tripId);

  let dayCount = 0;
  let activityCount = 0;

  // Pre-compute fallback dates based on startDate if Claude didn't provide them
  const baseDate = startDate ? new Date(startDate) : null;

  for (const day of itinerary.days) {
    const fallbackDate = baseDate
      ? new Date(baseDate.getTime() + (day.dayNumber - 1) * 86400000)
          .toISOString()
          .slice(0, 10)
      : null;

    const dayPayload = {
      trip_id: tripId,
      day_number: day.dayNumber,
      date: day.date ?? fallbackDate,
      title: clip(day.title, 200),
      notes: clip(day.notes, 2000),
    };

    const { data: insertedDay, error: dayErr } = await supabase
      .from("itinerary_days")
      .insert(dayPayload)
      .select("id")
      .single();

    if (dayErr || !insertedDay) {
      console.error("Day insert failed:", dayErr, dayPayload);
      continue;
    }

    dayCount++;

    if (!day.activities?.length) continue;

    const activityRows = day.activities.map((a, idx) => ({
      day_id: insertedDay.id,
      title: clip(a.title, 200) ?? "Activity",
      description: clip(a.description, 2000),
      location_name: clip(a.locationName, 300),
      start_time: normalizeTime(a.startTime),
      end_time: normalizeTime(a.endTime),
      category: sanitizeCategory(a.category),
      cost_estimate: typeof a.costEstimate === "number" ? a.costEstimate : null,
      currency: clip(a.currency, 3),
      sort_order: idx,
      created_by: userId,
    }));

    const { error: actsErr } = await supabase
      .from("itinerary_activities")
      .insert(activityRows);

    if (actsErr) {
      console.error("Activities insert failed:", actsErr);
      continue;
    }

    activityCount += activityRows.length;
  }

  return { dayCount, activityCount };
}

// ─── Rate Limiting ───────────────────────────────────────────────────

/// Max AI generations a single user may run in a rolling 24h window.
/// Caps Anthropic API spend per user and prevents abuse.
const DAILY_LIMIT = 10;

/// Returns whether the user is under the daily quota and how many calls they've used.
async function checkRateLimit(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<{ ok: boolean; used: number; limit: number }> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("ai_usage_log")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", since);

  if (error) {
    // Fail-open: a lookup error shouldn't block a real user, but log loudly
    // so we notice if this happens consistently.
    console.error("Rate-limit check failed:", error);
    return { ok: true, used: 0, limit: DAILY_LIMIT };
  }
  const used = count ?? 0;
  return { ok: used < DAILY_LIMIT, used, limit: DAILY_LIMIT };
}

/// Inserts a usage log row at the start of a request (success=false). Returns
/// the row id so we can mark it successful later if the call completes.
async function logUsageStart(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  inputType: string
): Promise<string | null> {
  const { data, error } = await supabase
    .from("ai_usage_log")
    .insert({
      user_id: userId,
      function: "ai-itinerary",
      input_type: inputType,
      success: false,
    })
    .select("id")
    .single();

  if (error) {
    console.error("Usage log insert failed:", error);
    return null;
  }
  return data?.id ?? null;
}

async function logUsageSuccess(
  supabase: ReturnType<typeof createClient>,
  rowId: string
): Promise<void> {
  const { error } = await supabase
    .from("ai_usage_log")
    .update({ success: true })
    .eq("id", rowId);
  if (error) console.error("Usage log update failed:", error);
}

// ─── Main handler ────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing authorization" }, 401);
  }

  let body: AIRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  // Validate
  if (!body.tripId || !body.userId || !body.inputType) {
    return json({ error: "Missing required fields: tripId, userId, inputType" }, 400);
  }

  if (body.inputType === "generate") {
    if (!body.destination || !body.startDate || !body.endDate) {
      return json(
        { error: "Generate mode requires destination, startDate, endDate" },
        400
      );
    }
  } else if (body.inputType === "import") {
    if (!body.inputText || body.inputText.trim().length < 10) {
      return json({ error: "Import mode requires inputText (at least 10 chars)" }, 400);
    }
  } else {
    return json({ error: `Unknown inputType: ${(body as AIRequest).inputType}` }, 400);
  }

  // Service-role client used for both rate limiting and downstream DB writes.
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // 1. Rate limit — reject before any expensive work.
  const rateLimit = await checkRateLimit(supabase, body.userId);
  if (!rateLimit.ok) {
    return json(
      {
        success: false,
        error: `You've hit today's AI generation limit (${rateLimit.limit}/day). Try again tomorrow.`,
        used: rateLimit.used,
        limit: rateLimit.limit,
      },
      429
    );
  }

  // 2. Log the attempt up-front so even failed Claude calls count toward the
  //    quota (prevents retry-loop abuse).
  const usageRowId = await logUsageStart(supabase, body.userId, body.inputType);

  try {
    // 3. Call Claude
    const itinerary = await callClaude(body);

    // 4. Insert into DB using service-role privileges
    const startDate =
      body.inputType === "generate" ? body.startDate : body.startDate;

    const { dayCount, activityCount } = await insertItinerary(
      supabase,
      body.tripId,
      body.userId,
      itinerary,
      startDate
    );

    // 5. Mark this usage row as successful for analytics.
    if (usageRowId) {
      await logUsageSuccess(supabase, usageRowId);
    }

    return json({
      success: true,
      dayCount,
      activityCount,
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("AI itinerary error:", msg);
    return json({ success: false, error: msg }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
