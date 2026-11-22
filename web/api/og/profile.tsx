// Composed OG card for a profile (1200 × 630), rendered on the edge.
//
// Layout:
//   [Avatar large on left] | [Display name (Fraunces) + @handle + N trips on right]
//   Ouest watermark bottom-right.
//
// Private profiles get a generic card with no personal info.

import { ImageResponse } from "@vercel/og";
import { fetchProfileByHandle } from "../../lib/profile.js";

export const config = { runtime: "edge" };

const FRAUNCES_URL =
  "https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,700&display=swap";

async function loadFont(url: string): Promise<ArrayBuffer> {
  const css = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0" },
  }).then((r) => r.text());
  const fontUrl = css.match(/url\((https:\/\/[^)]+)\)/)?.[1];
  if (!fontUrl) throw new Error("Could not parse font URL");
  return fetch(fontUrl).then((r) => r.arrayBuffer());
}

export default async function handler(req: Request) {
  const { searchParams } = new URL(req.url);
  const handle = (searchParams.get("handle") ?? "").trim().replace(/^@/, "");

  const [profile, fraunces] = await Promise.all([
    handle ? fetchProfileByHandle(handle) : Promise.resolve(null),
    loadFont(FRAUNCES_URL),
  ]);

  const W = 1200;
  const H = 630;

  if (!profile) {
    return new ImageResponse(
      (
        <div
          style={{
            width: "100%",
            height: "100%",
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            alignItems: "center",
            background:
              "linear-gradient(135deg, #0E0F11 0%, #1E3A8A 50%, #0E0F11 100%)",
            color: "#FFF",
          }}
        >
          <div style={{ fontFamily: "Fraunces", fontSize: 96 }}>Ouest</div>
          <div
            style={{
              fontSize: 28,
              color: "rgba(255,255,255,0.7)",
              marginTop: 12,
            }}
          >
            No traveler at @{handle || "—"}
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

  const displayName = profile.isPrivate
    ? "Private traveler"
    : profile.fullName || `@${profile.handle}`;
  const tripNoun = profile.tripCount === 1 ? "trip" : "trips";
  const subtitle = profile.isPrivate
    ? "This profile is private"
    : `@${profile.handle} · ${profile.tripCount} ${tripNoun}`;

  const showAvatar = !profile.isPrivate && profile.avatarUrl;

  // Shrink display name if long
  const nameFontSize =
    displayName.length <= 14
      ? 92
      : displayName.length <= 22
        ? 72
        : 56;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          padding: 80,
          gap: 64,
          background:
            "linear-gradient(135deg, #0E0F11 0%, #1E3A8A 60%, #0E0F11 100%)",
          color: "#FFF",
          position: "relative",
        }}
      >
        {/* Avatar (or logo placeholder) */}
        <div
          style={{
            width: 360,
            height: 360,
            borderRadius: 360,
            background: "rgba(255,255,255,0.06)",
            border: "4px solid rgba(255,255,255,0.15)",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            overflow: "hidden",
            flexShrink: 0,
            boxShadow: "0 20px 60px rgba(37,99,235,0.35)",
          }}
        >
          {showAvatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={profile.avatarUrl!}
              alt=""
              width={360}
              height={360}
              style={{ width: "100%", height: "100%", objectFit: "cover" }}
            />
          ) : (
            <div
              style={{
                fontFamily: "Fraunces",
                fontSize: 180,
                color: "rgba(255,255,255,0.4)",
              }}
            >
              {(displayName[0] || "?").toUpperCase()}
            </div>
          )}
        </div>

        {/* Text */}
        <div style={{ display: "flex", flexDirection: "column", flex: 1 }}>
          <div
            style={{
              fontFamily: "Fraunces",
              fontSize: nameFontSize,
              fontWeight: 700,
              lineHeight: 1.05,
              letterSpacing: -2,
            }}
          >
            {displayName}
          </div>
          <div
            style={{
              marginTop: 20,
              fontSize: 32,
              color: "rgba(255,255,255,0.75)",
            }}
          >
            {subtitle}
          </div>
        </div>

        {/* Ouest watermark, bottom-right */}
        <div
          style={{
            position: "absolute",
            right: 56,
            bottom: 40,
            display: "flex",
            alignItems: "center",
            gap: 10,
            color: "rgba(255,255,255,0.6)",
            fontSize: 22,
            letterSpacing: 2,
            fontWeight: 600,
          }}
        >
          <div
            style={{
              width: 24,
              height: 24,
              borderRadius: 6,
              background: "linear-gradient(135deg, #2563EB, #38BDF8)",
            }}
          />
          OUEST
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
