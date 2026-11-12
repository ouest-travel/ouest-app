# ouest.travel — Web Landing & Universal Links

Static site for `ouest.travel` that serves:

1. **Apple App Site Association (AASA)** at `/.well-known/apple-app-site-association` — proves the app↔domain link so iOS opens trip invite URLs directly in the app.
2. **Trip invite landing page** at `/join/{CODE}` — falls back to App Store when the app isn't installed, opens app via Universal Link when it is.

## Deploy to Vercel (recommended)

```bash
cd web
npx vercel
# Follow prompts, then:
npx vercel --prod
```

Then in the Vercel dashboard:
- Project Settings → Domains → Add `ouest.travel`
- Update DNS at your domain registrar to point to Vercel (Vercel will show the exact records — usually an `A` record to `76.76.21.21` and a `CNAME` for `www`)

## Verify after deploy

```bash
# AASA must return JSON
curl -i https://ouest.travel/.well-known/apple-app-site-association

# Should see:
#   Content-Type: application/json
#   The JSON body with "appIDs": ["764FLZ7S8Z.com.ouest.app"]

# Landing page renders
curl https://ouest.travel/join/TESTCODE
```

Validate AASA with Apple's tool: <https://search.developer.apple.com/appsearch-validation-tool/>
Or Branch's: <https://branch.io/resources/aasa-validator/?domain=ouest.travel>

## Files

- `.well-known/apple-app-site-association` — the AASA file (no `.json` extension)
- `index.html` — landing page (handles all `/join/*` routes via Vercel rewrite)
- `vercel.json` — sets AASA Content-Type and routes `/join/*` to `index.html`

## Update App Store ID

Once the app is live on the App Store, update two things in `index.html`:

1. `<meta name="apple-itunes-app" content="app-id=PLACEHOLDER_APP_ID" />` — replace with your numeric App ID
2. `<a href="https://apps.apple.com/app/ouest" ...>` — replace with the full App Store URL
