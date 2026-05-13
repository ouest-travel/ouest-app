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
- Pick real, well-known places — not fictional names.
- Categorize correctly: meals = food, hotels/check-in = accommodation, etc.
- For multi-day trips, vary the daily theme (avoid repetition).
- Respect budget level: "budget" = free/cheap/street food; "moderate" = mid-range; "luxury" = high-end restaurants and experiences.`;
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
    // import mode
    const dateRange =
      req.startDate && req.endDate
        ? `The trip is from ${req.startDate} to ${req.endDate}. Use these dates.`
        : `If specific dates aren't mentioned, organize into a logical day-by-day plan starting on Day 1.`;

    return [
      `The user pasted the following content describing a trip. Extract a structured itinerary from it:`,
      "",
      "---",
      req.inputText.slice(0, 12000), // cap to keep prompt under model limits
      "---",
      "",
      dateRange,
      `Respond with ONLY the JSON object.`,
    ].join("\n");
  }
}

/** Fetch URL content + strip HTML to plain text (best-effort). */
async function fetchUrlContent(url: string): Promise<string> {
  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; OuestBot/1.0)" },
      redirect: "follow",
    });
    if (!response.ok) return "";
    const html = await response.text();
    // Very rough HTML → text: drop scripts/styles, then strip remaining tags.
    return html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/gi, " ")
      .replace(/\s+/g, " ")
      .trim();
  } catch (error) {
    console.error("URL fetch failed:", error);
    return "";
  }
}

/** Detects a URL in the inputText and, if present, replaces it with fetched content. */
async function expandImportInput(req: ImportRequest): Promise<ImportRequest> {
  const urlMatch = req.inputText.match(/https?:\/\/\S+/);
  if (!urlMatch) return req;

  const fetched = await fetchUrlContent(urlMatch[0]);
  if (!fetched) return req;

  return {
    ...req,
    inputText: `${req.inputText}\n\nPage content from ${urlMatch[0]}:\n${fetched}`,
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

  try {
    // 1. Call Claude
    const itinerary = await callClaude(body);

    // 2. Insert into DB using service-role privileges
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const startDate =
      body.inputType === "generate" ? body.startDate : body.startDate;

    const { dayCount, activityCount } = await insertItinerary(
      supabase,
      body.tripId,
      body.userId,
      itinerary,
      startDate
    );

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
