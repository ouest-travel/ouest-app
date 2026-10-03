# Ouest — DESIGN.md

The machine-readable design spec for Ouest, a collaborative group-travel app
for iOS. Agents and people building UI read this first. The source of truth
for every value is the code. This file describes what exists and why, and
must be updated whenever `Ouest/Utilities/Theme.swift` or the colorsets change.

- Tokens: `Ouest/Utilities/Theme.swift` (`OuestTheme.*`)
- Colors: `Ouest/Resources/Assets.xcassets/*.colorset` (light + dark)
- Motion helpers: `Ouest/Utilities/Extensions/View+Animations.swift`
- Shared components: `Ouest/Views/Components/`

---

## 1. Brand identity

Ouest is about planning trips with friends: warm and editorial, with one
confident blue. It should feel like a well-made travel journal, not a
booking engine.

- **Voice:** calm, specific, encouraging. No exclamation marks in UI copy.
  Empty states say what the screen is *for* ("Plan your days"), not what is
  missing ("No itinerary yet").
- **Signature moves:** Fraunces serif headings over SF body text. One blue
  (`#2563EB`) for action. Destination gradients on trip cards. Soft springs.
- **Restraint:** one primary action per screen. Colour carries meaning
  (brand = act, status = state). It is never decoration on top of decoration.

## 2. Color

Always use `OuestTheme.Colors.*` (or `OuestTheme.StatusStyle`). Never write
`Color(hex:)` or a literal colour in a view. Hex values live only in
colorsets. Every role has a light and a dark value.

### Surfaces
| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F0F4FF` | `#0C1222` | Page behind everything |
| `surface` | `#FFFFFF` | `#162032` | Cards, sheets |
| `surfaceRaised` | `#FAFBFF` | `#1E2D45` | Element on top of a card |
| `fill` | `#EEF2FF` | `#1E2D45` | Inputs, chips, icon wells |
| `border` | `#0F172A` @ 8% | `#FFFFFF` @ 9% | Hairlines, dark-mode card edge |

### Text
| Token | Light | Dark | Use |
|---|---|---|---|
| `textPrimary` | `#0F172A` | `#F8FAFC` | Titles, body |
| `textSecondary` | `#475569` | `#B6C2D4` | Supporting text, metadata |
| `textTertiary` | `#64748B` | `#E2E8F0` @ 62% | Placeholders, timestamps |
| `textInverse` | white | white | Text on brand fill or gradients |

### Brand
| Token | Light | Dark | Use |
|---|---|---|---|
| `brandFill` | `#2563EB` | `#2563EB` | Primary button fill, selection ring |
| `brandFillPressed` | `#1D4ED8` | `#3B82F6` | Pressed primary |
| `brandInk` | `#1D4ED8` | `#93C5FD` | Brand-coloured *text* and icons |
| `brandOutline` | `#C7D2FE` | `#93C5FD` @ 35% | Secondary button stroke |
| `brandLight` | `brandFill` @ 12% | same | Tint behind icons |

Rule: **fill vs ink.** Use `brandFill` for backgrounds and `brandInk` for
text. Blue text in `brandFill` fails contrast in dark mode.

### Semantic
| Token | Light | Dark |
|---|---|---|
| `error` | `#DC2626` | `#DC2626` |
| `errorInk` | `#B91C1C` | `#FCA5A5` |
| `errorTint` | `#FEE2E2` | `#DC2626` @ 18% |
| `successFill` | `#059669` | `#059669` |
| `warningInk` | `#B45309` | `#FCD34D` |

### Trip status (always a tint + ink pair: `OuestTheme.StatusStyle`)
| Style | Tint (L / D) | Ink (L / D) |
|---|---|---|
| `.planning` | `#FEF3C7` / `#F59E0B`@18% | `#92400E` / `#FCD34D` |
| `.active` | `#D1FAE5` / `#10B981`@18% | `#065F46` / `#6EE7B7` |
| `.completed` | `#E2E8F0` / `#94A3B8`@18% | `#334155` / `#CBD5E1` |

### Gradients
- `decorGradient` (blue → sky) for decorative hero areas.
- `inkGradient` (blue → indigo; light blues in dark mode) for gradient text.
- `tripGradients[0...7]` are destination card backdrops. Each dark variant
  is one step deeper. Pick by stable index, never at random per render.
- Never assign a raw colour to a gradient stop.

### Toasts
`ToastSuccessFill #065F46`, `ToastFailureFill #991B1B`, `ToastFailureRetry
#FCA5A5`. Opaque 800-step fills, consumed only by `OuestToast`.

## 3. Typography

| Token | Font | Default size | Scales with |
|---|---|---|---|
| `heroTitle` | Fraunces Bold | 36 | `.largeTitle` |
| `screenTitle` | Fraunces Bold | 28 | `.title1` |
| `sectionTitle` | Fraunces Semibold | 18 | `.title3` |
| `cardTitle` | SF Bold | 17 | `.body` |
| `body` | SF Regular | 15 | `.subheadline` |
| `caption` | SF Regular | 13 | `.footnote` |
| `micro` | SF Semibold | 11 | `.caption2` |

- Fraunces is for **headings only**. Everything else is SF.
- Every style is Dynamic-Type aware. Never use `.font(.system(size:))`.
- Hierarchy comes from the serif/sans contrast and size, not from colour.

## 4. Spacing & layout (4pt grid)

`Spacing`: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32`

Prefer the semantic `Layout` intents over raw spacing:

| Token | Value | Meaning |
|---|---|---|
| `pageGutter` | 16 | Horizontal edge padding of a screen |
| `cardPadding` | 16 | Inside a card |
| `stackGap` | 12 | Between cards in a section |
| `sectionGap` | 28 | Between sections |
| `tabBarInset` | 96 | Bottom padding on every tab scroll view (floating tab bar + AI bubble) |
| `controlHeight` | 50 | Buttons and text fields |

## 5. Corner radius

`Radius`: `sm 8 · md 14 · lg 20 · xl 24 · full 999 (capsule)`

- Buttons and text fields use `md`. Cards use `lg`. Sheets and hero media use `xl`.
- Use `RoundedRectangle(cornerRadius:, style: .continuous)` for new shapes.
- Nested radius = outer radius − padding (a 20pt card with 8pt inset holds 12pt children).

## 6. Elevation

Use `.ouestElevation(.sm | .md | .lg | .pressed, cornerRadius:)` and never a raw `.shadow`.

- **Light:** neutral black shadows, `sm` 7%/r4/y1, `md` 7%/r12/y4,
  `lg` 14%/r20/y6, `pressed` 5%/r2/y1.
- **Dark:** no shadow. A 1pt `border` hairline instead, because a shadow
  disappears on `#0C1222`.
- Pass `cornerRadius` matching the clip shape.

## 7. Iconography

- SF Symbols only. Size them with `OuestTheme.Icon` fonts so they scale:
  `inline` (.body), `control` (.title3 ≈ 20pt), `feature` (.largeTitle ≈ 34pt).
- `Icon.hero` (56pt, fixed) is for empty-state art only.
- Icon-only buttons need an `accessibilityLabel` and a 44×44pt hit area.

## 8. Motion

Springs only, from `OuestTheme.Anim`:

| Token | Spring | Use |
|---|---|---|
| `quick` | 0.25s, bounce 0.15 | Toggles, button state, small UI |
| `smooth` | 0.4s, bounce 0.12 | Layout changes, sheets content |
| `gentle` | 0.6s, bounce 0.1 | Large reveals |
| `bouncy` | 0.5s, bounce 0.3 | Celebratory moments only (like, vote) |
| `stagger(i)` | 0.45s + 0.06s × i | List entrance |

- Use the canonical modifiers: `.appear(_:index:)`, `.pulse`, `.shimmer`,
  `.likeBurst`, `.shake`, `.zoomSource/.zoomDestination`, `.pressEffect()`.
  They already honour **Reduce Motion**. The legacy aliases
  (`fadeSlideIn`, `bouncyAppear`, `cardEntrance`…) are for old call sites only.
- Pair meaningful actions with `HapticFeedback` (`light`, `medium`,
  `success`, `error`, `selection`). Don't add haptics to scrolling or passive updates.

## 9. Core components

| Component | API | Notes |
|---|---|---|
| `OuestButton` | `title, style: .primary/.secondary/.destructive, isLoading, action` | Full-width, 50pt, `Radius.md`, haptic and press effect built in. One primary per screen. |
| `OuestCard` | `OuestCard { … }` | `surface`, padding 16, `Radius.lg`, `.ouestElevation(.md)` |
| `OuestTextField` | `placeholder, keyboardType, isSecure, hasError` | 50pt, `fill` background, error state |
| `OuestEmptyState` | `symbol, title, message, footnote?, primary?, secondary?` | Built on `ContentUnavailableView`. See copy rules in the file header. |
| `OuestErrorState` | `error: OuestError, context, detail?, onRecover` | `.offline / .notFound / .noPermission / .serverError / .unknown`, each with symbol, copy and recovery |
| `.ouestToast($toast, onRetry:)` | `OuestToast.success(_) / .failure(_, retry:)` | Sits above `tabBarInset`. Auto-dismisses unless it has a retry. |
| `AvatarView`, `TripDateRangePicker`, `NationalityPickerView` | — | Reuse; don't rebuild. |

Every data-driven screen designs **four states**: loading (shimmer
skeleton), empty (`OuestEmptyState`), error (`OuestErrorState`) and content.

## 10. Design rationale

- **Tokens resolve through colorsets** so light and dark live in one place
  and views can't drift.
- **Fill vs ink split** exists because the same blue can't be both a
  readable text colour and a button fill in both appearances.
- **Status is a pair** so nobody picks a tint without its readable ink.
- **Dark elevation is a border** because shadows are invisible on navy.
- **Everything scales with Dynamic Type**. Fixed-size fonts and icons were
  the main accessibility bug before this system.
- **Serif headings** give the editorial, journal-like warmth that makes it
  a travel app rather than a utility.

## Known debt

- `Colors.surfaceSecondary/surfaceTertiary`, `success`, `warning` and `brand`
  are back-compat aliases. Use the role names in new code.
- `Colors.deepNavy` is a literal kept for LoginView and the splash screen. It isn't a role.
- `Ouest/Assets.xcassets` (outside `Resources/`) holds stale `Surface*`
  colorsets whose values differ from the canonical catalog. The checked-in
  `.pbxproj` bundles only `Resources/Assets.xcassets`, but regenerating the
  project with XcodeGen (`sources: Ouest`) would pick up both and cause
  duplicate colour names. Edit only `Resources/Assets.xcassets`. The stray
  catalog is a candidate for deletion.
