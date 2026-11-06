// Report Alert Edge Function
// Emails the Ouest team whenever a user files a report, so every report is
// reviewed within the 48 hours the Terms of Use promise (App Store
// Guideline 1.2: timely response to objectionable content).
//
// Triggered by a Supabase Database Webhook on INSERT into public.reports.
// Set it up in the dashboard: Database → Webhooks → Create:
//   table public.reports, event INSERT, type "Supabase Edge Functions",
//   function report-alert, and add an HTTP header
//   x-webhook-secret: <REPORT_ALERT_WEBHOOK_SECRET>
//
// Secrets:
//   RESEND_API_KEY               API key from resend.com (sends the email)
//   REPORT_ALERT_WEBHOOK_SECRET  shared secret the webhook sends in x-webhook-secret
//   REPORT_ALERT_TO              optional, defaults to ouesttravel@gmail.com
//   REPORT_ALERT_FROM            optional, defaults to Resend's test sender, which
//                                only delivers to the Resend account's own email

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEFAULT_TO = "ouesttravel@gmail.com";
const DEFAULT_FROM = "Ouest Reports <onboarding@resend.dev>";
const REVIEW_WINDOW_HOURS = 48;

interface ReportRecord {
  id: string;
  reporter_id: string;
  target_type: "trip" | "comment" | "profile";
  target_id: string;
  reason: string;
  created_at: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/** One-line description of what was reported, best-effort. */
async function describeTarget(
  admin: ReturnType<typeof createClient>,
  report: ReportRecord
): Promise<string> {
  try {
    if (report.target_type === "comment") {
      const { data } = await admin
        .from("trip_comments")
        .select("content, user_id, trip_id")
        .eq("id", report.target_id)
        .single();
      if (data) {
        return `Comment by user ${data.user_id} on trip ${data.trip_id}: "${data.content}"`;
      }
    } else if (report.target_type === "trip") {
      const { data } = await admin
        .from("trips")
        .select("title, destination, created_by")
        .eq("id", report.target_id)
        .single();
      if (data) {
        return `Trip "${data.title}" (${data.destination}) by user ${data.created_by}`;
      }
    } else if (report.target_type === "profile") {
      const { data } = await admin
        .from("profiles")
        .select("handle, full_name, bio")
        .eq("id", report.target_id)
        .single();
      if (data) {
        return `Profile @${data.handle ?? "?"} (${data.full_name ?? "no name"})${
          data.bio ? `, bio: "${data.bio}"` : ""
        }`;
      }
    }
  } catch (e) {
    console.warn("[report-alert] target lookup failed:", e);
  }
  return "Content not found (it may already be deleted).";
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const secret = Deno.env.get("REPORT_ALERT_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return json({ error: "Unauthorized" }, 401);
  }

  let report: ReportRecord | undefined;
  try {
    const payload = await req.json();
    if (payload?.type === "INSERT" && payload?.table === "reports") {
      report = payload.record;
    }
  } catch {
    // fall through
  }
  if (!report) {
    return json({ error: "Expected a reports INSERT webhook payload" }, 400);
  }

  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) {
    console.error("[report-alert] RESEND_API_KEY not configured");
    return json({ error: "Email not configured" }, 500);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const target = await describeTarget(admin, report);
  const dueBy = new Date(
    new Date(report.created_at).getTime() + REVIEW_WINDOW_HOURS * 3600 * 1000
  ).toUTCString();

  const rows: [string, string][] = [
    ["Type", report.target_type],
    ["Reason", report.reason],
    ["Reported content", target],
    ["Target ID", report.target_id],
    ["Reporter ID", report.reporter_id],
    ["Filed", new Date(report.created_at).toUTCString()],
    ["Review by", dueBy],
    ["Report ID", report.id],
  ];

  const html = `
    <h2>New ${escapeHtml(report.target_type)} report</h2>
    <p>Review and act within ${REVIEW_WINDOW_HOURS} hours: remove the content and
    suspend the account if it breaks the community guidelines.</p>
    <table cellpadding="6" style="border-collapse:collapse">
      ${rows
        .map(
          ([k, v]) =>
            `<tr><td style="color:#64748B;vertical-align:top"><b>${k}</b></td><td>${escapeHtml(v)}</td></tr>`
        )
        .join("")}
    </table>`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: Deno.env.get("REPORT_ALERT_FROM") ?? DEFAULT_FROM,
      to: [Deno.env.get("REPORT_ALERT_TO") ?? DEFAULT_TO],
      subject: `[Ouest] New ${report.target_type} report: ${report.reason}`,
      html,
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    console.error("[report-alert] email send failed:", res.status, detail);
    return json({ error: "Email send failed" }, 502);
  }

  return json({ success: true });
});
