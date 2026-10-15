# Design skills: research notes

Sourced from [designeer.xyz](https://designeer.xyz/), a curated directory of
interface craft, component libraries, AI tools and design engineers, plus the
collections it points to. Researched October 2026.

## What we adopted (in this repo)

| Item | Where | Why |
|---|---|---|
| `DESIGN.md` | repo root | The DESIGN.md convention (Google Labs, popularised by Refero Styles, designmd.me and typeui.sh on designeer's Build page) gives agents exact visual constraints. Ours is generated from `Theme.swift` and the colorsets. |
| `ios-design` skill | `.claude/skills/ios-design/` | HIG non-negotiables and SwiftUI craft, wired to `OuestTheme` tokens. Inspired by `ebuntario/apple-hig`, `wshobson/mobile-ios-design` and petekp's SwiftUI playbook. |
| `design-critique` skill | `.claude/skills/design-critique/` | Structured 9-lens critique with prioritised fixes, modelled on the `visual-critique` plugin in `Owl-Listener/designer-skills`. |

## Worth installing locally (optional)

These are plugins rather than repo files, so each developer installs them in their own Claude Code:

```
/plugin marketplace add Owl-Listener/designer-skills
/plugin install visual-critique@designer-skills      # /critique-screen, /critique-ux
/plugin install interaction-design@designer-skills   # states, onboarding, errors, forms
/plugin install ui-design@designer-skills            # /platform-audit (iOS), /color-palette, /type-system
/plugin install design-research@designer-skills      # personas, interviews, usability tests
```

- **[Owl-Listener/designer-skills](https://github.com/Owl-Listener/designer-skills)**
  (MC Dean, MIT): 33 plugins, 273 skills, 76 commands across research, UX
  strategy, UI, interaction, design systems, prototyping, ops, AI product
  design and inclusive design.
- **[ebuntario/apple-hig](https://github.com/ebuntario/apple-hig)** (MIT): the
  full HIG as 68 reference files and checklists. Use it when `ios-design` isn't
  deep enough on a specific component or technology (widgets, Live Activities,
  Dynamic Island).
- **Refero MCP**: real product screens and flows an agent can search for reference before designing.

## For `web/` only

- `npx typeui.sh pull <style>` pulls style skills from
  [bergside/awesome-design-skills](https://github.com/bergside/awesome-design-skills) (67 styles).
- shadcn/ui skills and registries (designeer Build → Skills) only apply if the web app moves to React components.

## Evaluated and skipped

Most of designeer's Components and Visuals sections (React/Tailwind component
libraries, shaders, 3D) don't apply to a SwiftUI app.
