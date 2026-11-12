// /t/:code — trip preview page with rich OG tags.
//
// Flow:
//   1. Look up the invite code in trip_invites (must be active, not expired)
//   2. Fetch the trip metadata (title, destination, dates, cover, member count)
//   3. Return HTML with og:title / og:description / og:image so link unfurlers
//      (iMessage, Slack, Discord, etc.) render a rich preview
//   4. On iOS, the page JS attempts ouest://join/:code to bounce into the app
//
// AASA covers /t/* so a direct tap on iOS opens the app via Universal Links
// without ever hitting this page (this page is the fallback / preview surface).
//
// Runs on the edge runtime, same as /api/og/*. The Node runtime build of this
// route failed at invocation on Vercel (FUNCTION_INVOCATION_FAILED) while the
// edge OG routes importing the same lib/ files worked, so both page routes
// use the edge runtime too.

import { fetchTripByInviteCode, formatDateRange } from "../../lib/trip.js";
import { renderPage, esc, siteOrigin, lastPathSegment } from "../../lib/html.js";

export const config = { runtime: "edge" };

const APP_STORE = "https://apps.apple.com/app/id6759875932";

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const code = (url.searchParams.get("code") ?? lastPathSegment(url.pathname, "t")).trim();
  if (!code) {
    return new Response("Missing trip code", { status: 400 });
  }

  const site = siteOrigin(req);
  const trip = await fetchTripByInviteCode(code);
  const pageUrl = `${site}/t/${encodeURIComponent(code)}`;

  // Trip not found / expired / revoked — render a generic "invite expired" card
  if (!trip) {
    const html = renderPage(
      {
        url: pageUrl,
        title: "Invite no longer valid — Ouest",
        description: "This trip invite has expired or been revoked.",
        imageUrl: `${site}/logo.png`,
        appStoreUrl: APP_STORE,
      },
      `
      <img src="/logo.png" alt="Ouest" class="logo" />
      <div class="label">Invite expired</div>
      <h1>This link is no longer active</h1>
      <p class="subtitle">Ask the trip owner to send you a fresh invite.</p>
      <a href="${APP_STORE}" class="btn-secondary">Get Ouest on the App Store</a>
      `
    );
    return new Response(html, {
      status: 404,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "public, max-age=60, s-maxage=60",
      },
    });
  }

  // Compose the preview metadata
  const cityShort = trip.destination.split(",")[0]?.trim() || trip.destination;
  const dateRange = formatDateRange(trip.startDate, trip.endDate);
  const ogTitle = dateRange ? `${cityShort} · ${dateRange}` : cityShort;
  const memberNoun = trip.memberCount === 1 ? "traveler" : "travelers";
  const others = Math.max(0, trip.memberCount - 1);
  const othersNoun = others === 1 ? "traveler" : "travelers";
  const ogDescription = trip.createdByName
    ? others > 0
      ? `${trip.createdByName} + ${others} ${othersNoun} on Ouest`
      : `${trip.createdByName} on Ouest`
    : `${trip.memberCount} ${memberNoun} on Ouest`;

  const ogImage = `${site}/api/og/trip?code=${encodeURIComponent(code)}`;
  const deepLink = `ouest://join/${encodeURIComponent(code)}`;

  const hero = trip.coverImageUrl
    ? `<div class="hero" style="background-image:url('${esc(trip.coverImageUrl)}')"></div>`
    : "";

  const html = renderPage(
    {
      url: pageUrl,
      title: `${ogTitle} — Ouest`,
      description: ogDescription,
      imageUrl: ogImage,
      appStoreUrl: APP_STORE,
      deepLink,
    },
    `
    ${hero}
    <div class="label">You're invited</div>
    <h1>${esc(trip.title)}</h1>
    <div class="meta">${esc(ogTitle)} · ${esc(`${trip.memberCount} ${memberNoun}`)}</div>
    <a href="${esc(deepLink)}" class="btn-primary">Open in Ouest</a>
    <a href="${APP_STORE}" class="btn-secondary">Download on the App Store</a>
    `
  );

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      // Cache for 5 min at the edge — short enough that title/member-count
      // edits surface quickly, long enough to absorb iMessage unfurler bursts.
      "Cache-Control": "public, max-age=60, s-maxage=300",
    },
  });
}
