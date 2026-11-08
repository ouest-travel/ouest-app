// Shared helpers for building HTML responses with OG / Twitter metadata.
// Returned HTML is what link unfurlers (iMessage, Slack, Discord, X, etc.)
// scrape on first request. The page also acts as a fallback landing for
// users without the app installed.

const ESCAPE: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

export function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ESCAPE[c]);
}

// Public origin of the site that received the request, for canonical URLs
// and og:image. Derived from the request rather than hardcoded because the
// deployment is reachable on links.ouest.travel (the host the app shares)
// while the bare ouest.travel currently points elsewhere.
export function siteOrigin(req: Request): string {
  const host =
    req.headers.get("x-forwarded-host") ??
    req.headers.get("host") ??
    "links.ouest.travel";
  return `https://${host}`;
}

// The dynamic segment after `/<prefix>/` in a pathname, e.g. "/t/AbC123" →
// "AbC123". Also accepts the direct function path "/api/t/AbC123".
export function lastPathSegment(pathname: string, prefix: string): string {
  const m = pathname.match(new RegExp(`/${prefix}/([^/?#]+)`));
  return m ? decodeURIComponent(m[1]) : "";
}

export type OgMeta = {
  url: string; // canonical URL
  title: string;
  description: string;
  imageUrl: string; // absolute URL (preferred 1200x630)
  appStoreUrl: string;
  // Optional: custom URL scheme to bounce into the app
  deepLink?: string;
};

// Wraps the existing visual style from index.html and renders a small landing
// card. Kept inline so we don't depend on a build step — this file ships as
// pure TS and the HTML string is what Vercel serves.
export function renderPage(meta: OgMeta, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${esc(meta.title)}</title>
  <meta name="description" content="${esc(meta.description)}" />

  <!-- Open Graph (iMessage, Facebook, Slack, Discord, LinkedIn) -->
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="Ouest" />
  <meta property="og:url" content="${esc(meta.url)}" />
  <meta property="og:title" content="${esc(meta.title)}" />
  <meta property="og:description" content="${esc(meta.description)}" />
  <meta property="og:image" content="${esc(meta.imageUrl)}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />

  <!-- Twitter / X -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${esc(meta.title)}" />
  <meta name="twitter:description" content="${esc(meta.description)}" />
  <meta name="twitter:image" content="${esc(meta.imageUrl)}" />

  <!-- App banner (Safari "Open in app" prompt) -->
  <meta name="apple-itunes-app" content="app-id=6759875932" />

  <link rel="icon" type="image/png" href="/logo.png" />
  <link rel="apple-touch-icon" href="/logo.png" />

  <style>
    @import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600;9..144,700&family=Inter:wght@400;500;600&display=swap');
    *{margin:0;padding:0;box-sizing:border-box}
    :root{--brand:#2563EB;--brand-cyan:#38BDF8;--bg:#0E0F11;--surface:#1A1B1E;--text:#FFF;--text-secondary:rgba(255,255,255,0.7);--text-tertiary:rgba(255,255,255,0.45);--border:rgba(255,255,255,0.1)}
    body{background:var(--bg);color:var(--text);font-family:'Inter',-apple-system,system-ui,sans-serif;-webkit-font-smoothing:antialiased;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;position:relative;overflow-x:hidden}
    body::before{content:'';position:fixed;inset:-50%;background:radial-gradient(ellipse at 20% 30%,rgba(37,99,235,0.25),transparent 50%),radial-gradient(ellipse at 80% 70%,rgba(56,189,248,0.18),transparent 50%),radial-gradient(ellipse at 50% 100%,rgba(168,85,247,0.15),transparent 50%);z-index:0}
    .card{position:relative;z-index:1;max-width:460px;width:100%;background:rgba(26,27,30,0.7);border:1px solid var(--border);backdrop-filter:blur(40px);-webkit-backdrop-filter:blur(40px);border-radius:24px;padding:40px 28px;text-align:center;box-shadow:0 20px 60px rgba(0,0,0,0.5),0 0 0 1px rgba(255,255,255,0.04) inset}
    .logo{width:80px;height:80px;margin:0 auto 20px;display:block;filter:drop-shadow(0 8px 24px rgba(37,99,235,0.4))}
    .hero{width:100%;aspect-ratio:16/9;background-size:cover;background-position:center;border-radius:14px;margin:0 0 24px;border:1px solid var(--border)}
    .label{font-size:12px;font-weight:600;letter-spacing:1.5px;text-transform:uppercase;color:var(--brand-cyan);margin-bottom:12px}
    h1{font-family:'Fraunces',serif;font-size:32px;font-weight:600;line-height:1.15;letter-spacing:-0.5px;margin-bottom:8px}
    .meta{font-size:14px;color:var(--text-secondary);margin-bottom:24px}
    .subtitle{font-size:15px;color:var(--text-secondary);line-height:1.5;margin-bottom:24px}
    .btn-primary{display:inline-flex;align-items:center;justify-content:center;gap:10px;width:100%;padding:16px 24px;background:linear-gradient(135deg,var(--brand),var(--brand-cyan));color:white;font-size:16px;font-weight:600;border-radius:14px;text-decoration:none;box-shadow:0 8px 24px rgba(37,99,235,0.35);margin-bottom:12px}
    .btn-secondary{display:inline-flex;align-items:center;justify-content:center;width:100%;padding:14px 24px;background:transparent;color:var(--text-secondary);font-size:14px;font-weight:500;border-radius:14px;text-decoration:none;border:1px solid var(--border)}
    .footer{position:relative;z-index:1;margin-top:32px;font-size:12px;color:var(--text-tertiary);text-align:center}
    .footer a{color:var(--text-tertiary);text-decoration:none;border-bottom:1px solid rgba(255,255,255,0.15);padding-bottom:1px}
  </style>
</head>
<body>
  <div class="card">${bodyHtml}</div>
  <div class="footer">Ouest — Plan trips together. <a href="https://ouest.travel">ouest.travel</a></div>
  ${
    meta.deepLink
      ? `<script>
    // Try to open the app immediately on iOS. If the scheme fails the user
    // stays on this page and can tap the App Store button.
    if (/iPad|iPhone|iPod/.test(navigator.userAgent)) {
      setTimeout(() => { window.location.href = ${JSON.stringify(meta.deepLink)}; }, 50);
    }
  </script>`
      : ""
  }
</body>
</html>`;
}
