// Composed OG card for a trip (1200 × 630), rendered on Vercel's edge runtime.
// This is the image that shows up in iMessage / Slack / Discord previews.
//
// Layout:
//   [Trip cover photo, full-bleed background]
//   [Dark gradient overlay bottom-left for legibility]
//   ◆ Ouest          ← logomark, top-left
//
//   PARIS            ← Fraunces 140px (or smaller if long)
//   Jun 12 – 19 · 4 travelers  ← Inter 28px

import { ImageResponse } from "@vercel/og";
import { fetchTripByInviteCode, formatDateRange } from "../../lib/trip.js";

export const config = { runtime: "edge" };

// Inter from Google Fonts (Fraunces too — we ship them with the image so the
// edge function doesn't need a font CDN call at request time).
const FRAUNCES_URL =
  "https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,700&display=swap";

async function loadFont(url: string): Promise<ArrayBuffer> {
  const css = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0" },
  }).then((r) => r.text());
  const fontUrl = css.match(/url\((https:\/\/[^)]+)\)/)?.[1];
  if (!fontUrl) throw new Error("Could not parse font URL from CSS");
  return fetch(fontUrl).then((r) => r.arrayBuffer());
}

export default async function handler(req: Request) {
  const { searchParams } = new URL(req.url);
  const code = (searchParams.get("code") ?? "").trim();

  const [trip, fraunces] = await Promise.all([
    code ? fetchTripByInviteCode(code) : Promise.resolve(null),
    loadFont(FRAUNCES_URL),
  ]);

  const W = 1200;
  const H = 630;

  // Fallback card: generic invite
  if (!trip) {
    return new ImageResponse(
      (
        <div
          style={{
            width: "100%",
            height: "100%",
            background:
              "linear-gradient(135deg, #0E0F11 0%, #1E3A8A 50%, #0E0F11 100%)",
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            color: "#FFF",
          }}
        >
          <div
            style={{
              fontFamily: "Fraunces",
              fontSize: 96,
              letterSpacing: -2,
            }}
          >
            Ouest
          </div>
          <div style={{ fontSize: 28, color: "rgba(255,255,255,0.7)", marginTop: 12 }}>
            Plan trips together
          </div>
        </div>
      ),
      {
        width: W,
        height: H,
        fonts: [{ name: "Fraunces", data: fraunces, weight: 700, style: "normal" }],
      }
    );
  }

  const cityShort = trip.destination.split(",")[0]?.trim() || trip.destination;
  const heroCity = cityShort.toUpperCase();
  // Shrink the city text if it's long so it never wraps awkwardly
  const cityFontSize =
    heroCity.length <= 6 ? 220 : heroCity.length <= 10 ? 160 : 120;

  const dateRange = formatDateRange(trip.startDate, trip.endDate);
  const memberNoun = trip.memberCount === 1 ? "traveler" : "travelers";
  const metaLine = [dateRange, `${trip.memberCount} ${memberNoun}`]
    .filter(Boolean)
    .join(" · ");

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          position: "relative",
          background: "#0E0F11",
        }}
      >
        {trip.coverImageUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={trip.coverImageUrl}
            alt=""
            width={W}
            height={H}
            style={{
              position: "absolute",
              inset: 0,
              width: "100%",
              height: "100%",
              objectFit: "cover",
            }}
          />
        )}
        {/* Dark gradient so white text on a busy photo stays legible */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.2) 40%, rgba(0,0,0,0.85) 100%)",
          }}
        />
        {/* Logomark, top-left */}
        <div
          style={{
            position: "absolute",
            top: 40,
            left: 48,
            display: "flex",
            alignItems: "center",
            gap: 12,
            color: "#FFF",
            fontSize: 28,
            fontWeight: 600,
            letterSpacing: 2,
          }}
        >
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 8,
              background: "linear-gradient(135deg, #2563EB, #38BDF8)",
              boxShadow: "0 8px 24px rgba(37,99,235,0.4)",
            }}
          />
          OUEST
        </div>
        {/* Hero text, bottom-left */}
        <div
          style={{
            position: "absolute",
            left: 56,
            bottom: 48,
            display: "flex",
            flexDirection: "column",
            color: "#FFF",
          }}
        >
          <div
            style={{
              fontFamily: "Fraunces",
              fontSize: cityFontSize,
              fontWeight: 700,
              lineHeight: 1,
              letterSpacing: -4,
              textShadow: "0 4px 24px rgba(0,0,0,0.5)",
            }}
          >
            {heroCity}
          </div>
          {metaLine && (
            <div
              style={{
                marginTop: 16,
                fontSize: 32,
                color: "rgba(255,255,255,0.85)",
                letterSpacing: 0.5,
              }}
            >
              {metaLine}
            </div>
          )}
        </div>
      </div>
    ),
    {
      width: W,
      height: H,
      fonts: [{ name: "Fraunces", data: fraunces, weight: 700, style: "normal" }],
      headers: {
        "Cache-Control": "public, max-age=300, s-maxage=86400",
      },
    }
  );
}
