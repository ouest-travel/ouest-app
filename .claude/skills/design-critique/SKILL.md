---
name: design-critique
description: Run a structured visual and UX critique of an Ouest screen or flow and produce prioritised, actionable fixes. Use when the user asks to review, critique, audit, polish or "make better" an existing SwiftUI view, screenshot, flow or the web landing page, or before shipping a significant UI change.
---

# Design critique

A senior designer's review, grounded in Ouest's system. Critique the work and
not the author. Every finding must name a concrete fix.

## Inputs

- The view file(s) and anything they compose. Read them fully.
- A screenshot or simulator capture if available (the `run` skill can produce one).
- `DESIGN.md` for the rules being judged against.

## Lenses (go through every one)

1. **Purpose and hierarchy**: Is the screen's one job obvious within 3 seconds?
   Is there exactly one primary action? Does size, weight and position order the
   content the way the user needs it?
2. **Composition and rhythm**: Are alignment edges consistent? Is the spacing
   from `Layout`/`Spacing`, and is the rhythm intentional (tighter within groups,
   looser between them)? Does anything look crowded or orphaned?
3. **Typography**: Fraunces is used only for headings and the scale tokens are
   respected. Are line lengths and truncation handled? Does it work at AX sizes?
4. **Color and contrast**: Only tokens. Fill vs ink is used correctly. Status
   always appears as a pair. WCAG AA contrast holds in **both** appearances.
   Is there one accent rather than many?
5. **Affordance and feedback**: Do tappable things look tappable? Are hit
   targets at least 44pt? Is there press feedback, haptics where it matters,
   and a toast for outcomes?
6. **States and edge cases**: Loading, empty, error, offline, partial and
   permission-limited (view-only member). Check long text, 0/1/many items and
   missing images.
7. **Information density**: Is anything here that the user doesn't need right now?
   Can secondary detail move behind progressive disclosure?
8. **Platform fit and accessibility**: Native navigation and modality patterns,
   VoiceOver order and labels, Reduce Motion, Dynamic Type.
9. **Brand and consistency**: Does it feel like the rest of Ouest, with
   reused components and editorial warmth? Does it look generic?

## Output format

```
## Critique: <screen>

**Verdict:** one sentence on overall quality and the single biggest lever.

### Must fix (breaks usability, accessibility or the system)
1. <finding>. Why it matters. **Fix:** <specific change, with file:line and token names>

### Should fix (noticeably raises quality)
...

### Polish (delight and craft)
...

### What's working
- Keep these; be specific.
```

Order findings within each tier by impact divided by effort. Limit them to the
10 that matter most rather than listing everything.

## After the critique

Offer to apply the Must-fix and Should-fix items. When applying them, follow the
`ios-design` skill's checklist, and update `DESIGN.md` if a token or
component changes.
