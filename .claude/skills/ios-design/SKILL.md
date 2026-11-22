---
name: ios-design
description: Design and build polished, native-feeling SwiftUI screens for Ouest. Use before creating or restyling any SwiftUI view, component, sheet, empty/error/loading state, onboarding step or animation in Ouest/Views, and whenever the user asks for better UI, UX, polish, layout, spacing, colour, typography, motion or accessibility in the iOS app.
---

# Ouest iOS design

You are designing for a SwiftUI travel app with an established design system.
Your job is to make screens feel as considered as Apple's own apps while staying
unmistakably Ouest. Generic "AI-generated" UI is the failure mode to avoid.

## 0. Load context first

1. Read `DESIGN.md` at the repo root. It holds every token, rule and component.
2. Skim `Ouest/Utilities/Theme.swift` and `Ouest/Views/Components/` so you
   reuse what exists rather than reinventing it.
3. Find the closest existing screen to what you're building and match its
   structure (e.g. `Views/Home/TripCardView.swift` for cards).

## 1. Design before code

Before writing a view, answer briefly (in your head or in a short note to the user):

- **Job:** what is the one thing the user comes to this screen to do? It
  becomes the single primary action.
- **Hierarchy:** what are the first, second and third things the eye should hit?
- **States:** what do loading, empty, error, content, partial and offline look
  like? Who can't act (a view-only member)?
- **Platform pattern:** push (NavigationStack), sheet (focused task with a
  clear end), full-screen cover (immersive or blocking), or inline?
  Use a sheet with `.presentationDetents` for quick-add flows.
- **Thumb reach:** primary actions go in the bottom half or the toolbar.
  Destructive actions are never the easiest tap.

## 2. Non-negotiables

**Tokens**
- Colours only via `OuestTheme.Colors.*` / `StatusStyle`. No `Color(hex:)`,
  no `.blue`, no literal opacity-on-black for surfaces.
- `brandFill` for backgrounds, `brandInk` for text and icons.
- Spacing via `OuestTheme.Layout` first, `Spacing` second. Never a magic number.
- Radius via `OuestTheme.Radius`, with `.continuous` corner style.
- Elevation via `.ouestElevation(...)`, never `.shadow`.

**Type and icons**
- Headings use `Typography.heroTitle/screenTitle/sectionTitle` (Fraunces).
  Everything else uses `cardTitle/body/caption/micro`.
- Never `.font(.system(size:))`. Icons use `OuestTheme.Icon.*` fonts.
- Check that the layout survives the **AX5 Dynamic Type** size. Let text wrap,
  and switch HStacks to VStacks using `ViewThatFits` or
  `@Environment(\.dynamicTypeSize)` when needed.

**Accessibility**
- Hit targets are at least 44×44pt (`.contentShape(Rectangle())` and padding,
  not a bigger glyph).
- Every icon-only control has `.accessibilityLabel`. Group compound rows with
  `.accessibilityElement(children: .combine)`.
- Never use colour alone to carry meaning. Status pills pair colour with a word or symbol.
- Animate only through `OuestTheme.Anim` and the canonical motion modifiers,
  which respect Reduce Motion. If you write a custom animation, gate it on
  `@Environment(\.accessibilityReduceMotion)`.
- Check both appearances. Dark mode must not lose card separation or contrast.

**Layout**
- Screen content uses `Layout.pageGutter` horizontally. Tab scroll views end
  with `Layout.tabBarInset` bottom padding.
- `Layout.stackGap` goes between cards and `Layout.sectionGap` between sections.
  Vary rhythm on purpose, because uniform gaps flatten hierarchy.
- Prefer native containers (`List`, `Form`, `NavigationStack`, `.toolbar`,
  `.searchable`, `.refreshable`, `.swipeActions`, `.contextMenu`) over hand-rolled
  equivalents. They bring correct behaviour for free.

## 3. Craft details that separate good from great

- **Feedback loop:** every tap gets an immediate visual response
  (`.pressEffect()`) and important ones get haptics (`HapticFeedback.light()`
  for taps, `.success()`/`.error()` for outcomes, `.selection()` for pickers).
  Outcomes surface via `.ouestToast`.
- **Optimistic UI:** reflect the change instantly and roll back with a
  failure toast that offers retry.
- **Skeletons over spinners:** use `.shimmer()` placeholders shaped like the
  content for loads over about 300ms. Use a spinner only inside a button (`isLoading`).
- **Continuity:** use `.zoomSource/.zoomDestination` for card-to-detail,
  `matchedGeometryEffect` for in-place morphs, and `.appear(_:index:)`
  staggers for first render (never on every scroll).
- **Content first:** let destination imagery and trip gradients carry the
  emotion. Keep chrome quiet with fewer borders, fewer badges and one accent per card.
- **Numbers:** use `.monospacedDigit()` for amounts and counts that change,
  and `Text(_, format:)` for currency and dates in the user's locale.
- **Copy:** sentence case, specific verbs ("Add activity", not "Submit"),
  and no exclamation marks. Empty-state titles say what the screen is for.
- **Edge cases:** check long destination names, 0/1/many members, missing
  photos, RTL, and very small or very large type.

## 4. Anti-patterns (reject on sight)

- Gradients, glows or glassmorphism stacked on everything. Use one decorative layer at most.
- More than one filled primary button visible at once.
- Grey text on a tinted background below about 4.5:1 contrast.
- Cards inside cards inside cards. Flatten by using `surfaceRaised` or a divider.
- Custom tab bars, back buttons or alerts that fight the system.
- Hard-coded frames that clip at larger text sizes.
- Emoji as icons in product UI (SF Symbols only).
- Rebuilding `OuestButton`, `OuestCard`, `OuestEmptyState`,
  `OuestErrorState`, `OuestTextField` or toasts instead of reusing them.

## 5. Before you hand it back

Run this checklist and fix anything that fails:

- [ ] Only tokens; `grep -n "Color(hex\|\.font(.system(size\|\.shadow(" <file>` returns nothing new
- [ ] One clear primary action; hierarchy readable at a glance
- [ ] Loading, empty, error and content states implemented
- [ ] Light and dark both checked (add `#Preview` variants with `.preferredColorScheme(.dark)`)
- [ ] Dynamic Type at AX sizes doesn't clip or truncate essential text
- [ ] VoiceOver labels on icon buttons; 44pt targets
- [ ] Motion uses `OuestTheme.Anim` or canonical modifiers
- [ ] Add `#Preview`s covering the key states

If the change adds a new token or component, update `DESIGN.md` in the same change.

For a deeper review of an existing screen, use the `design-critique` skill.
