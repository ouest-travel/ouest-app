// /u/:handle — public profile preview with rich OG tags.
//
// Respects the is_private flag from migration 00019: private profiles return
// a generic card with no personal info so a leaked URL can't dox the user.

import type { VercelRequest, VercelResponse } from "@vercel/node";
import { fetchProfileByHandle } from "../../lib/profile.js";
import { renderPage, esc } from "../../lib/html.js";

const SITE = "https://ouest.travel";

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const handleRaw = String(req.query.handle ?? "").trim();
  // Strip leading @ if present so /u/@timmy and /u/timmy both work
  const handle = handleRaw.replace(/^@/, "");
  if (!handle) {
    res.status(400).send("Missing handle");
    return;
  }

  const profile = await fetchProfileByHandle(handle);
  const url = `${SITE}/u/${encodeURIComponent(handle)}`;

  if (!profile) {
    const html = renderPage(
      {
        url,
        title: "Profile not found — Ouest",
        description: "We couldn't find that traveler on Ouest.",
        imageUrl: `${SITE}/logo.png`,
        appStoreUrl: "https://apps.apple.com/app/ouest",
      },
      `
      <img src="/logo.png" alt="Ouest" class="logo" />
      <div class="label">Not found</div>
      <h1>No traveler at @${esc(handle)}</h1>
      <p class="subtitle">Double-check the handle, or get the app to find them.</p>
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

  const displayName = profile.fullName || `@${profile.handle}`;
  const ogTitle = profile.isPrivate
    ? "A traveler on Ouest"
    : `${displayName} on Ouest`;
  const tripNoun = profile.tripCount === 1 ? "trip" : "trips";
  const ogDescription = profile.isPrivate
    ? "This profile is private. Get the app to follow."
    : profile.bio?.trim()
      ? profile.bio.trim()
      : `${profile.tripCount} ${tripNoun} planned on Ouest`;

  const ogImage = `${SITE}/api/og/profile?handle=${encodeURIComponent(handle)}`;
  const deepLink = `ouest://u/${encodeURIComponent(handle)}`;

  const avatar = profile.avatarUrl
    ? `<img src="${esc(profile.avatarUrl)}" alt="" class="logo" style="border-radius:50%" />`
    : `<img src="/logo.png" alt="Ouest" class="logo" />`;

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
    ${avatar}
    <div class="label">${esc(profile.isPrivate ? "Private" : "Traveler")}</div>
    <h1>${esc(displayName)}</h1>
    <div class="meta">@${esc(profile.handle)}${
      profile.isPrivate ? "" : ` · ${profile.tripCount} ${tripNoun}`
    }</div>
    ${
      !profile.isPrivate && profile.bio
        ? `<p class="subtitle">${esc(profile.bio)}</p>`
        : ""
    }
    <a href="${esc(deepLink)}" class="btn-primary">Open in Ouest</a>
    <a href="https://apps.apple.com/app/ouest" class="btn-secondary">Download on the App Store</a>
    `
  );

  res
    .setHeader("Content-Type", "text/html; charset=utf-8")
    .setHeader("Cache-Control", "public, max-age=60, s-maxage=300")
    .status(200)
    .send(html);
}
