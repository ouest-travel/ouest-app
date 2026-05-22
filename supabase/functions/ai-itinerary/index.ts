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
  latitude?: number;         // approximate lat for map pin
  longitude?: number;        // approximate lng for map pin
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
// Sonnet alias resolves to the current latest Sonnet release. We use the
// alias (not a dated version) so we automatically pick up improvements
// without needing to redeploy.
const CLAUDE_MODEL = "claude-sonnet-4-5";

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
      latitude: number;       // REQUIRED: approximate WGS84 decimal lat (e.g. 41.4036)
      longitude: number;      // REQUIRED: approximate WGS84 decimal lng (e.g. 2.1744)
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
- EVERY activity MUST include latitude and longitude as decimal numbers. These power the map view. Use your best knowledge of where the place is — for a famous landmark use its actual coords; for a neighborhood spot, place the pin near the neighborhood center. Never omit, never invent placeholder values like 0,0. Always include real coordinates within the destination city/region.
- Pick real places (not fictional). Each day MUST include 3–4 lesser-known local gems — small restaurants, neighborhood spots, hidden viewpoints, niche museums, quiet parks — alongside any unavoidable must-see icons. Bias toward what locals actually recommend over what's at the top of guidebooks.
- When a place is a hidden gem or local favourite, briefly say so in the activity's description (e.g., "favourite of locals, rarely on guidebooks", "tucked-away spot most tourists miss"). When it's a marquee landmark, you can skip that note.
- Categorize correctly: meals = food, hotels/check-in = accommodation, etc.
- For multi-day trips, vary the daily theme (avoid repetition).
- Respect budget level and adjust the gem mix accordingly:
  - "budget"   → free attractions, street food finds, hostels, free walking tours, public spots.
  - "moderate" → mid-range neighborhood favourites and local restaurants.
  - "luxury"   → boutique experiences, chef-led restaurants, design hotels, private/small-group activities.`;
}

/** Optional enrichment context fetched server-side from the trip + user history. */
interface EnrichmentContext {
  tripTitle?: string;
  tripDescription?: string;
  countryCodes?: string[];
  currency?: string;
  budget?: number | null;
  memberCount?: number;
  travelerName?: string;
  nationality?: string;
  profileInterests?: string[];
  pastTrips?: PastTripSummary[];
  seasonHint?: string;
  weatherSummary?: string;
}

interface PastTripSummary {
  destination: string;
  countryCodes: string[];
  topActivities: string[];
}

/** Builds the user-message payload depending on the input type. */
function buildUserPrompt(req: AIRequest, ctx: EnrichmentContext = {}): string {
  const contextBlock = renderContextBlock(ctx);

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
      contextBlock,
      `Generate a complete day-by-day itinerary. Day 1 starts on ${req.startDate}; ` +
        `produce exactly ${days} day${days === 1 ? "" : "s"}. ` +
        `Respond with ONLY the JSON object.`,
    ]
      .filter((s) => s.length > 0)
      .join("\n\n");
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
      `- For every activity, include latitude and longitude as decimal numbers — use your best knowledge of where each named place is.`,
      `- If the content is sparse (e.g., just a few captions or bullet points), generously fill in supporting activities to make a complete, well-paced trip around the mentioned places.`,
      `- If the content mentions specific times, days, or sequences, respect them.`,
      `- If a destination is implied but not stated (e.g., the content is clearly about Tokyo), use that as the location context.`,
      `- Add the hidden-gem mix from the system prompt rules even when extracting from external content.`,
      contextBlock ? `\n${contextBlock}` : "",
      "",
      "--- Content ---",
      req.inputText.slice(0, 12000),
      "--- End content ---",
      "",
      dateRange,
      `Respond with ONLY the JSON object.`,
    ]
      .filter((s) => s.length > 0)
      .join("\n");
  }
}

/**
 * Renders the optional enrichment context as a readable block for Claude.
 * Returns an empty string if nothing useful is present, so the prompt stays clean.
 */
function renderContextBlock(ctx: EnrichmentContext): string {
  const lines: string[] = [];

  // Trip-level intent (lever 1)
  const tripBits: string[] = [];
  if (ctx.tripTitle) tripBits.push(`titled "${ctx.tripTitle}"`);
  if (ctx.tripDescription) tripBits.push(`described as "${ctx.tripDescription}"`);
  if (ctx.countryCodes?.length)
    tripBits.push(`covering ${ctx.countryCodes.join(", ")}`);
  if (ctx.memberCount && ctx.memberCount > 1)
    tripBits.push(`for a group of ${ctx.memberCount}`);
  else if (ctx.memberCount === 1) tripBits.push(`for a solo traveler`);
  if (tripBits.length) {
    lines.push(`Trip intent: ${tripBits.join("; ")}.`);
  }

  // Budget hints
  if (ctx.budget && ctx.budget > 0) {
    const cur = ctx.currency ?? "USD";
    lines.push(
      `Total budget: ~${ctx.budget.toLocaleString()} ${cur}. Quote cost estimates in ${cur} and keep daily spending within a reasonable share of this.`
    );
  } else if (ctx.currency) {
    lines.push(`Preferred currency for cost estimates: ${ctx.currency}.`);
  }

  // Traveler signal (lever 1)
  const travelerBits: string[] = [];
  if (ctx.travelerName) travelerBits.push(`called ${ctx.travelerName}`);
  if (ctx.nationality) travelerBits.push(`from ${ctx.nationality}`);
  if (ctx.profileInterests?.length)
    travelerBits.push(
      `with broader travel interests: ${ctx.profileInterests.join(", ")}`
    );
  if (travelerBits.length) {
    lines.push(`Traveler profile: ${travelerBits.join("; ")}.`);
  }

  // Taste profile from past trips (lever 2)
  if (ctx.pastTrips?.length) {
    const summary = ctx.pastTrips
      .map((t) => {
        const acts = t.topActivities.slice(0, 4).join(", ");
        return acts
          ? `${t.destination} (loved: ${acts})`
          : t.destination;
      })
      .join(" • ");
    lines.push(
      `Past trips for style/taste reference (do NOT copy these, just match the quality/specificity): ${summary}.`
    );
  }

  // Seasonal + weather (lever 3)
  if (ctx.seasonHint) lines.push(ctx.seasonHint);
  if (ctx.weatherSummary) lines.push(ctx.weatherSummary);

  if (lines.length === 0) return "";
  return `Additional context:\n${lines.map((l) => `- ${l}`).join("\n")}`;
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

/**
 * Strip code fences and prose, then attempt to repair a truncated JSON object.
 * Claude occasionally:
 *   - Wraps the JSON in ```json ... ``` even when told not to
 *   - Adds a sentence of prose before/after
 *   - Gets cut off mid-object when max_tokens is exhausted
 * This function handles all three.
 */
function extractJSON(raw: string): string {
  let s = raw.trim();

  // 1. Strip ``` or ```json code fences if present (handles multi-line content).
  s = s.replace(/^```(?:json)?\s*\n?/i, "").replace(/\n?```\s*$/i, "");

  // 2. Trim down to the outermost JSON object by finding the first { and last }.
  const first = s.indexOf("{");
  if (first === -1) return s;
  let last = s.lastIndexOf("}");
  if (last <= first) {
    // No closing brace at all — output was truncated. Attempt repair by adding
    // closing braces/brackets to balance the structure.
    return repairTruncatedJSON(s.slice(first));
  }
  return s.slice(first, last + 1);
}

/**
 * Last-resort: when Claude's output was cut off mid-object, count unclosed
 * braces/brackets and append closers in the correct order. Drops the trailing
 * partial token (anything after the last comma or last complete value).
 */
function repairTruncatedJSON(s: string): string {
  // Walk the string tracking bracket depth and string state.
  let inString = false;
  let escape = false;
  const stack: string[] = [];
  let lastSafePoint = -1;

  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (ch === "\\") {
        escape = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "{" || ch === "[") {
      stack.push(ch);
      continue;
    }
    if (ch === "}" || ch === "]") {
      stack.pop();
      // After closing, this is a safe truncation point.
      if (stack.length > 0) lastSafePoint = i;
      continue;
    }
    if (ch === "," && stack.length > 0) {
      lastSafePoint = i;
    }
  }

  // Truncate to the last completed element, then close all open brackets.
  let trimmed = lastSafePoint > 0 ? s.slice(0, lastSafePoint) : s;
  // If we cut at a comma, drop it (no trailing commas in JSON).
  trimmed = trimmed.replace(/,\s*$/, "");

  // If we cut inside a string, close it first.
  if (inString) trimmed += '"';

  // Close open brackets in reverse order.
  const closers = stack
    .reverse()
    .map((open) => (open === "{" ? "}" : "]"))
    .join("");

  return trimmed + closers;
}

async function callClaude(
  req: AIRequest,
  ctx: EnrichmentContext = {}
): Promise<ClaudeItineraryOutput> {
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
      // 8192 leaves comfortable headroom for a 7-day itinerary with rich
      // descriptions + hidden-gem notes. Claude Sonnet 4.5 supports much more
      // but we don't need it for this task.
      max_tokens: 8192,
      system: buildSystemPrompt(),
      messages: [
        {
          role: "user",
          content: buildUserPrompt(expanded, ctx),
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
  const stopReason: string | undefined = data?.stop_reason;
  const jsonStr = extractJSON(text);

  let parsed: ClaudeItineraryOutput;
  try {
    parsed = JSON.parse(jsonStr);
  } catch (parseError) {
    // Log diagnostics: stop reason, full length, and head/tail of the response
    // so we can see WHERE it broke without flooding the log.
    console.error("Failed to parse Claude JSON", {
      stop_reason: stopReason,
      text_length: text.length,
      json_length: jsonStr.length,
      text_head: text.slice(0, 500),
      text_tail: text.slice(-500),
      parse_error: parseError instanceof Error ? parseError.message : String(parseError),
    });
    const hint =
      stopReason === "max_tokens"
        ? "The AI ran out of room. Try a shorter trip or fewer vibes."
        : "Couldn't parse the AI response. Please try again.";
    throw new Error(hint);
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

/**
 * Validates a coordinate is a real finite number within the expected range.
 * Rejects 0/0 (a common placeholder) and out-of-range values. Returns null on
 * failure so the DB column stays nullable rather than storing garbage.
 */
function validCoord(
  value: number | undefined | null,
  min: number,
  max: number
): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  if (value < min || value > max) return null;
  // Treat exactly 0 as "missing" — Claude occasionally returns 0 as a placeholder
  // for unknown coords. Real activities are never at the Null Island reference.
  if (value === 0) return null;
  return value;
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
      latitude: validCoord(a.latitude, -90, 90),
      longitude: validCoord(a.longitude, -180, 180),
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

// ─── Context Enrichment ──────────────────────────────────────────────

/**
 * Lever 1: pulls the full trip row + member count + the requesting user's
 * profile. The trip is required; the other two are best-effort and tolerated
 * if they fail (e.g. RLS oddities, missing profile rows).
 */
async function fetchTripContext(
  supabase: ReturnType<typeof createClient>,
  tripId: string,
  userId: string
): Promise<{
  trip: any;
  memberCount: number;
  profile: any;
}> {
  // Trip lookup — required.
  let trip: any = null;
  try {
    const { data, error } = await supabase
      .from("trips")
      .select("*")
      .eq("id", tripId)
      .single();
    if (error) {
      console.error("Trip lookup error:", error);
    }
    trip = data;
  } catch (e) {
    console.error("Trip lookup threw:", e);
  }

  // Member count — best-effort.
  let memberCount = 0;
  try {
    const { count, error } = await supabase
      .from("trip_members")
      .select("id", { count: "exact", head: true })
      .eq("trip_id", tripId);
    if (error) console.error("Member count error:", error);
    memberCount = count ?? 0;
  } catch (e) {
    console.error("Member count threw:", e);
  }

  // Profile — best-effort.
  let profile: any = null;
  try {
    const { data, error } = await supabase
      .from("profiles")
      .select("full_name, nationality, travel_interests")
      .eq("id", userId)
      .single();
    if (error) console.error("Profile lookup error:", error);
    profile = data;
  } catch (e) {
    console.error("Profile lookup threw:", e);
  }

  return { trip, memberCount, profile };
}

/**
 * Lever 2: builds a compact taste profile from the user's past trips.
 * Best-effort — returns an empty array if anything fails or the user has
 * no prior trips.
 */
async function fetchTasteProfile(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  excludeTripId: string
): Promise<PastTripSummary[]> {
  try {
    // Fetch the user's 5 most recent OTHER trips, with their activities nested.
    const { data, error } = await supabase
      .from("trips")
      .select(
        "id, destination, country_codes, itinerary_days(itinerary_activities(title, category))"
      )
      .eq("created_by", userId)
      .neq("id", excludeTripId)
      .order("created_at", { ascending: false })
      .limit(5);

    if (error || !data) return [];

    return data
      .map((trip: any) => {
        // Flatten all activities across all days, pick the most evocative titles.
        const allActivities: { title: string; category: string }[] = (trip
          .itinerary_days ?? [])
          .flatMap((d: any) => d.itinerary_activities ?? []);

        // Prefer food + activity categories (they're more distinctive than transport/accommodation).
        const ranked = allActivities
          .filter((a) => a.title && a.title.length > 2)
          .sort((a, b) => {
            const pref = (c: string) =>
              c === "food" ? 0 : c === "activity" ? 1 : 2;
            return pref(a.category) - pref(b.category);
          });

        return {
          destination: trip.destination as string,
          countryCodes: (trip.country_codes ?? []) as string[],
          topActivities: ranked.slice(0, 4).map((a) => a.title),
        };
      })
      .filter((t) => t.destination); // Drop trips missing a destination
  } catch (e) {
    console.error("Taste profile fetch failed:", e);
    return [];
  }
}

/** Lever 3a: computes a coarse seasonal hint from start date + destination text. */
function computeSeasonHint(startDate: string, destination: string): string {
  try {
    const date = new Date(startDate);
    const month = date.getUTCMonth() + 1; // 1-12
    const monthName = date.toLocaleString("en-US", {
      month: "long",
      timeZone: "UTC",
    });

    // Guess hemisphere from destination text — a coarse heuristic but better than nothing.
    const dest = destination.toLowerCase();
    const southernHemKeywords = [
      "australia",
      "new zealand",
      "argentina",
      "chile",
      "brazil",
      "peru",
      "south africa",
      "uruguay",
      "bolivia",
      "paraguay",
      "fiji",
      "tasmania",
      "patagonia",
      "buenos aires",
      "rio",
      "cape town",
      "sydney",
      "melbourne",
      "auckland",
      "santiago",
    ];
    const isSouthernHem = southernHemKeywords.some((k) => dest.includes(k));

    const seasonByMonth: Record<number, [string, string]> = {
      // [northern, southern]
      1: ["mid-winter", "mid-summer"],
      2: ["late winter", "late summer"],
      3: ["early spring", "early autumn"],
      4: ["spring", "autumn"],
      5: ["late spring", "late autumn"],
      6: ["early summer", "early winter"],
      7: ["mid-summer", "mid-winter"],
      8: ["late summer", "late winter"],
      9: ["early autumn", "early spring"],
      10: ["autumn", "spring"],
      11: ["late autumn", "late spring"],
      12: ["early winter", "early summer"],
    };
    const [northern, southern] = seasonByMonth[month] ?? ["", ""];
    const season = isSouthernHem ? southern : northern;

    return `Seasonal context: the trip is in ${monthName}, which is ${season} in this region — pick activities that suit the weather and call out any seasonal highlights (festivals, blooms, peak/off-peak crowds) when relevant.`;
  } catch {
    return "";
  }
}

/**
 * Lever 3b: best-effort fetch of a real weather forecast for near-term trips
 * (within ~14 days). Uses free Open-Meteo APIs (no key needed). Returns a
 * compact summary string or null if the trip is too far out / geocoding fails.
 */
async function fetchWeatherForecast(
  destination: string,
  startDate: string,
  endDate: string
): Promise<string | null> {
  try {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const now = new Date();
    const daysAway = Math.floor((start.getTime() - now.getTime()) / 86400000);

    // Open-Meteo only supports forecasts within ~16 days. Skip otherwise.
    if (daysAway < 0 || daysAway > 14) return null;

    // 1. Geocode the destination to lat/lon (free, no API key).
    const geoUrl = new URL("https://geocoding-api.open-meteo.com/v1/search");
    geoUrl.searchParams.set("name", destination);
    geoUrl.searchParams.set("count", "1");
    const geoRes = await fetch(geoUrl.toString());
    if (!geoRes.ok) return null;
    const geoData = await geoRes.json();
    const place = geoData?.results?.[0];
    if (!place) return null;

    // 2. Forecast for the trip dates.
    const fcUrl = new URL("https://api.open-meteo.com/v1/forecast");
    fcUrl.searchParams.set("latitude", String(place.latitude));
    fcUrl.searchParams.set("longitude", String(place.longitude));
    fcUrl.searchParams.set(
      "daily",
      "temperature_2m_max,temperature_2m_min,precipitation_probability_mean"
    );
    fcUrl.searchParams.set("timezone", "auto");
    fcUrl.searchParams.set("start_date", iso(start));
    fcUrl.searchParams.set("end_date", iso(end));

    const fcRes = await fetch(fcUrl.toString());
    if (!fcRes.ok) return null;
    const fc = await fcRes.json();
    const maxArr: number[] = fc?.daily?.temperature_2m_max ?? [];
    const minArr: number[] = fc?.daily?.temperature_2m_min ?? [];
    const rainArr: number[] = fc?.daily?.precipitation_probability_mean ?? [];

    if (maxArr.length === 0) return null;

    const avg = (xs: number[]) =>
      Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);
    const tMax = avg(maxArr);
    const tMin = avg(minArr);
    const rain = rainArr.length ? avg(rainArr) : 0;

    let rainNote = "";
    if (rain >= 60) rainNote = " High rain chance — favour indoor/covered options.";
    else if (rain >= 30) rainNote = " Some rain expected — pack a light layer.";

    return `Weather forecast for the trip: highs around ${tMax}°C, lows around ${tMin}°C, average ${rain}% rain chance.${rainNote}`;
  } catch (e) {
    console.error("Weather fetch failed:", e);
    return null;
  }
}

/** ISO YYYY-MM-DD in UTC, used by Open-Meteo. */
function iso(d: Date): string {
  return d.toISOString().slice(0, 10);
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
    // 3. Enrich context — fetch trip details, taste profile, and seasonal hints
    //    in parallel. Lever 1 (trip) is required; levers 2 & 3 are best-effort.
    const [tripCtx, tasteProfile] = await Promise.all([
      fetchTripContext(supabase, body.tripId, body.userId),
      fetchTasteProfile(supabase, body.userId, body.tripId),
    ]);

    if (!tripCtx.trip) {
      return json({ success: false, error: "Trip not found." }, 404);
    }

    // Use destination from the trip row (more reliable than the request payload
    // for import mode where the user didn't type one).
    const destination: string =
      tripCtx.trip.destination ??
      (body.inputType === "generate" ? body.destination : "");

    const startDate: string | undefined =
      body.inputType === "generate"
        ? body.startDate
        : tripCtx.trip.start_date ?? body.startDate;
    const endDate: string | undefined =
      body.inputType === "generate"
        ? body.endDate
        : tripCtx.trip.end_date ?? body.endDate;

    // Lever 3 — seasonal hint (cheap, always available) + weather forecast
    // (best-effort, only for near-term trips).
    const seasonHint =
      startDate && destination
        ? computeSeasonHint(startDate, destination)
        : undefined;

    const weatherSummary =
      startDate && endDate && destination
        ? await fetchWeatherForecast(destination, startDate, endDate)
        : null;

    const ctx: EnrichmentContext = {
      tripTitle: tripCtx.trip.title,
      tripDescription: tripCtx.trip.description?.trim() || undefined,
      countryCodes: tripCtx.trip.country_codes ?? undefined,
      currency: tripCtx.trip.currency ?? undefined,
      budget:
        typeof tripCtx.trip.budget === "number" ? tripCtx.trip.budget : null,
      memberCount: tripCtx.memberCount,
      travelerName:
        (tripCtx.profile?.full_name as string | undefined) || undefined,
      nationality:
        (tripCtx.profile?.nationality as string | undefined) || undefined,
      profileInterests:
        (tripCtx.profile?.travel_interests as string[] | undefined) ??
        undefined,
      pastTrips: tasteProfile,
      seasonHint,
      weatherSummary: weatherSummary ?? undefined,
    };

    // 4. Call Claude with enriched context.
    const itinerary = await callClaude(body, ctx);

    // 5. Insert into DB using service-role privileges.
    const { dayCount, activityCount } = await insertItinerary(
      supabase,
      body.tripId,
      body.userId,
      itinerary,
      startDate
    );

    // 6. Mark this usage row as successful for analytics.
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
    // Return 200 with success:false so the Swift client can decode + surface the
    // real error message. Non-2xx status codes get wrapped by supabase-swift as
    // a generic "non-2xx status code" error, swallowing the helpful detail.
    return json({ success: false, error: msg }, 200);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
