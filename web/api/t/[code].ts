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

import type { VercelRequest, VercelResponse } from "@vercel/node";
import { fetchTripByInviteCode, formatDateRange } from "../../lib/trip.js";
import { renderPage, esc } from "../../lib/html.js";

const SITE = "https://ouest.travel";

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const code = String(req.query.code ?? "").trim();
  if (!code) {
    res.status(400).send("Missing trip code");
    return;
  }

  const trip = await fetchTripByInviteCode(code);
  const url = `${SITE}/t/${encodeURIComponent(code)}`;

  // Trip not found / expired / revoked — render a generic "invite expired" card
  if (!trip) {
    const html = renderPage(
      {
        url,
        title: "Invite no longer valid — Ouest",
        description: "This trip invite has expired or been revoked.",
        imageUrl: `${SITE}/logo.png`,
        appStoreUrl: "https://apps.apple.com/app/ouest",
      },
      `
      <img src="/logo.png" alt="Ouest" class="logo" />
      <div class="label">Invite expired</div>
      <h1>This link is no longer active</h1>
      <p class="subtitle">Ask the trip owner to send you a fresh invite.</p>
      <a href="https://apps.apple.com/app/ouest" class="btn-secondary">Get Ouest on the App Store</a>
      `
    );
    res
      .setHeader("Content-Type", "text/html; charset=utf-8")
      .setHeader("Cache-Control", "public, max-age=60, s-maxage=60")
      .status(404)
      .send(html);
    return;
  }

  // Compose the preview metadata
  const cityShort = trip.destination.split(",")[0]?.trim() || trip.destination;
  const dateRange = formatDateRange(trip.startDate, trip.endDate);
  const ogTitle = dateRange
    ? `${cityShort} · ${dateRange}`
    : cityShort;
  const memberNoun = trip.memberCount === 1 ? "traveler" : "travelers";
  const ogDescription = trip.createdByName
    ? `${trip.createdByName} + ${Math.max(0, trip.memberCount - 1)} ${memberNoun} on Ouest`
    : `${trip.memberCount} ${memberNoun} on Ouest`;

  const ogImage = `${SITE}/api/og/trip?code=${encodeURIComponent(code)}`;
  const deepLink = `ouest://join/${encodeURIComponent(code)}`;

  const hero = trip.coverImageUrl
    ? `<div class="hero" style="background-image:url('${esc(trip.coverImageUrl)}')"></div>`
    : "";

  const html = renderPage(
    {
      url,
      title: `${ogTitle} — Ouest`,
      description: ogDescription,
      imageUrl: ogImage,
      appStoreUrl: "https://apps.apple.com/app/ouest",
      deepLink,
    },
    `
    ${hero}
    <div class="label">You're invited</div>
    <h1>${esc(trip.title)}</h1>
    <div class="meta">${esc(ogTitle)} · ${esc(`${trip.memberCount} ${memberNoun}`)}</div>
    <a href="${esc(deepLink)}" class="btn-primary">Open in Ouest</a>
    <a href="https://apps.apple.com/app/ouest" class="btn-secondary">Download on the App Store</a>
    `
  );

  res
    .setHeader("Content-Type", "text/html; charset=utf-8")
    // Cache for 5 min at the edge — short enough that title/member-count edits
    // surface quickly, long enough to absorb iMessage unfurler bursts.
    .setHeader("Cache-Control", "public, max-age=60, s-maxage=300")
    .status(200)
    .send(html);
}
