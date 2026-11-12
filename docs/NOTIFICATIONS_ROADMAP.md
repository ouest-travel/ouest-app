# Notifications — Roadmap

What's live, and what's queued for after beta. Each "queued" item lists the
infrastructure it needs, so future-you (or another engineer) can pick it up
without re-deriving the plan.

---

## ✅ Shipped (live in production)

| Trigger | Title rotation | Migration |
|---|---|---|
| Trip invite | "Adventures are better together 🌍" / "You're being recruited ✈️" / … | `00021`, `00030` |
| New comment on trip | "Your crew is making moves 🌍" / "Someone has thoughts 💭" / … | `00021`, `00030` |
| New expense | "Budget updates just came in 💸" / "Money moves 💰" / … | `00021`, `00030` |
| Trip liked | "Someone's feeling your trip ❤️" / "You've got a fan 👀" / … | `00021`, `00030` |
| New follower | "New travel buddy 🌍" / "New explorer in your orbit 🛫" / … | `00021`, `00030` |
| New poll | "Time to vote on the next adventure 🗳️" / "Decisions, decisions 🤔" / … | `00021`, `00030` |
| New journal entry | "Memory unlocked 📸" / "A new chapter for the trip ✨" / … | `00021`, `00030` |
| **New itinerary activity** | "New activity suggestion dropped 👀" / "Somebody just found a hidden gem 💎" / … (with "🍜" variants when category=food, and "the itinerary is finally coming together 🙌" when bulk-added by AI) | `00031` |

All triggers run as `AFTER INSERT` on their source tables and write to
`public.notifications`. The push trigger (migration `00027`) then fires
`net.http_post` to the `push-notification` Edge Function, which sends APNs
to every device token registered for the recipient.

Each title is picked at random per recipient via `pick_random_text(text[])`
(migration `00030`) so the same broadcast doesn't read identically across
the group.

---

## 🔜 Queued for after beta

### 1. Trip preparation reminders (Fun Tone)

Sample copy you've already approved:

- "Future you at the airport says 'thank you' for checking your documents now ✈️"
- "Don't let missing paperwork humble you at the gate 😭"
- "The vacation is booked. The preparation? Still pending 👀"
- "A few more details and this trip becomes real ✈️"
- "Small planning now = less stress later 🌍"

**Trigger conditions** (any one fires once per trip, with a 24h cooldown
between sends to avoid spam):

- Trip exists with `status='planning'` AND has dates AND no `itinerary_days`
  rows → "your trip is still 83% imagination"
- Trip has dates AND no activities for >50% of its days → "small planning
  now = less stress later"
- Trip has entry requirements available but `entry_reqs_acknowledged=false`
  → "future you at the airport says thank you"

**Infrastructure needed:**

- `pg_cron` extension (Supabase Pro supports it natively — enable via
  Dashboard → Database → Extensions).
- Cron job runs every 6h: iterates planning trips, checks staleness, picks
  a random copy, inserts into `notifications`.
- Add `last_reminder_sent_at` column to `trips` so cron can enforce the 24h
  cooldown.
- New `NotificationType.tripReminder` enum case + iOS routing (probably to
  the trip detail).

Effort: ~4h. Best done after beta has shown which trips actually go stale.

---

### 2. Trip-imminent practical reminders

Sample copy you've already approved:

- "Your trip is coming up ✈️ Time to double-check your documents and entry
  requirements."
- "Passport? Visa? Good vibes? 🌍 Make sure you're travel-ready for your
  upcoming trip."
- "Departure countdown: ⏳ Have you checked entry requirements yet?"
- "Before you board… make sure your travel docs are sorted 🛂"
- "Your trip is almost here 👀 Don't forget to review visas, passports, and
  entry rules."

**Trigger conditions**: fire **once each** at T-14, T-7, T-3, T-1 days
before `trips.start_date`.

**Infrastructure needed:**

- Same `pg_cron` setup as above.
- Daily cron job: `SELECT trips WHERE start_date - today IN (1, 3, 7, 14)
  AND status <> 'completed' AND NOT EXISTS (matching reminder row)`.
- Add `trip_reminders_sent` table (or columns on trips) tracking which
  pre-trip windows have already been notified, so the daily cron is
  idempotent if it runs twice.
- Notification routes to **Entry Reqs** section (already exists in the
  trip detail). New `NotificationType.tripImminent` + routing.

Effort: ~3h. Highest practical value of the bunch — these alerts genuinely
prevent gate disasters.

---

### 3. Re-engagement pushes

Sample copy you've already approved:

- "Still thinking about that trip? 👀"
- "Your saved trip ideas are waiting ✈️"
- "That destination isn't going to explore itself 🌍"
- "The wild west is calling, open Ouest."
- "Your next adventure starts with one plan."
- "New travel inspiration just landed 🔥"

**Trigger conditions**: user hasn't opened the app in N days AND has
notification permission AND has a registered device token.

**Infrastructure needed:**

- Add `last_seen_at timestamptz` column to `profiles`. iOS pings an RPC
  (or just updates the row directly via PostgREST) on `.task` in the
  root view.
- `pg_cron` daily job: find profiles where `now() - last_seen_at > '7
  days'` AND `last_seen_at > '30 days ago'` (don't pester long-gone users),
  insert a random re-engagement push.
- Per-user cooldown of ~14 days so the same user doesn't get pinged
  weekly.
- Add a "Marketing" preference toggle to `notification_preferences` so
  users can opt out of these without losing transactional pushes — this
  is the App Store-friendly thing to do.

Effort: ~5h. Lower priority than the imminent-trip reminders since you
need actual lapsed users before this returns value.

---

### 4. "Itinerary completeness" milestone

Sample copy:

- "The itinerary is finally coming together 🙌"
- "The group trip chaos is becoming organized. Miracles happen."

**Note**: partially shipped — the bulk-insert path of `notify_new_activity`
(migration `00031`) already uses these strings when 2+ activities land in
one statement. A separate "you just crossed N total activities, congrats"
milestone is *not* shipped.

**To add the full milestone**: when activity count for a trip crosses
thresholds (e.g. 5, 10, 25), insert a celebratory notification. Best done
as an `AFTER INSERT` trigger that counts rows and checks against a
stored watermark.

Effort: ~1h. Low priority, mostly delight.

---

### 5. Marketing hooks (not notifications)

These are launch-screen / empty-state / onboarding copy, not pushes:

- "Simplify. Track. Trip."
- "Your trip, organized."
- "Less planning stress. More memories."
- "Travel better together."
- "The planner friend finally has help."

**Where to use them:**

| Copy | Best surface |
|---|---|
| "Simplify. Track. Trip." | App Store subtitle / launch screen tagline |
| "Your trip, organized." | Empty Home view (no trips yet) |
| "Less planning stress. More memories." | Onboarding step 2 / 3 |
| "Travel better together." | TripMembersView empty state ("invite your first traveler") |
| "The planner friend finally has help." | AI Generate sheet header (current: "Skip the blank page") |

These live in SwiftUI views, not in the notifications system. Worth a
dedicated 1h pass through the empty states to drop them in.

---

## Architecture notes (for whoever picks this up)

- The push pipeline is one path: DB trigger → `pg_net.http_post` → Edge
  Function (`push-notification`) → APNs. Anything that lands in
  `public.notifications` automatically gets pushed. So new notification
  types only require: (1) trigger function that inserts a row, (2)
  Swift `NotificationType` enum case, (3) routing in
  `NotificationsView.navPath(for:)`.
- For scheduled jobs use `pg_cron`. Supabase enables it on Pro tier; the
  setup is `CREATE EXTENSION pg_cron;` plus `SELECT cron.schedule(...)`.
- Random title selection uses `public.pick_random_text(text[])` (added in
  `00030`). New trigger functions should follow the same pattern: define
  a `text[]` of variants, call `pick_random_text(...)` per recipient.
- Per-recipient picking inside a loop (vs picking once before the loop)
  guarantees the same broadcast doesn't look identical across the group.
