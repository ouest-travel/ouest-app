// /u/:handle — public profile preview with rich OG tags.
//
// Respects the is_private flag from migration 00019: private profiles return
// a generic card with no personal info so a leaked URL can't dox the user.
//
// Edge runtime — see the note in api/t/[code].ts.

import { fetchProfileByHandle } from "../../lib/profile.js";
import { renderPage, esc, siteOrigin, lastPathSegment } from "../../lib/html.js";

export const config = { runtime: "edge" };

const APP_STORE = "https://apps.apple.com/app/id6759875932";

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const handleRaw = (url.searchParams.get("handle") ?? lastPathSegment(url.pathname, "u")).trim();
  // Strip leading @ if present so /u/@timmy and /u/timmy both work
  const handle = handleRaw.replace(/^@/, "");
  if (!handle) {
    return new Response("Missing handle", { status: 400 });
  }

  const site = siteOrigin(req);
  const profile = await fetchProfileByHandle(handle);
  const pageUrl = `${site}/u/${encodeURIComponent(handle)}`;

  if (!profile) {
    const html = renderPage(
      {
        url: pageUrl,
        title: "Profile not found — Ouest",
        description: "We couldn't find that traveler on Ouest.",
        imageUrl: `${site}/logo.png`,
        appStoreUrl: APP_STORE,
      },
      `
      <img src="/logo.png" alt="Ouest" class="logo" />
      <div class="label">Not found</div>
      <h1>No traveler at @${esc(handle)}</h1>
      <p class="subtitle">Double-check the handle, or get the app to find them.</p>
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

  const ogImage = `${site}/api/og/profile?handle=${encodeURIComponent(handle)}`;
  const deepLink = `ouest://u/${encodeURIComponent(handle)}`;

  const avatar = profile.avatarUrl
    ? `<img src="${esc(profile.avatarUrl)}" alt="" class="logo" style="border-radius:50%" />`
    : `<img src="/logo.png" alt="Ouest" class="logo" />`;

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
    <a href="${APP_STORE}" class="btn-secondary">Download on the App Store</a>
    `
  );

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=60, s-maxage=300",
    },
  });
}
