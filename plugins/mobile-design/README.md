# design-craft

5 skills + 2 agents for mobile UI/UX design. Covers the full design-to-code pipeline: discovery, UX patterns, visual design, Flutter implementation, and design review. Produces beautiful, accessible, modern interfaces — not generic AI slop.

## Skills

| Skill | Purpose | Invocable |
|-------|---------|-----------|
| `mobile-design-discovery` | Interactive discovery session — extracts what the user wants before any code is written | ✅ |
| `mobile-ux-patterns` | Evidence-based UX patterns: navigation, forms, states, gestures, cognitive principles | ✅ |
| `mobile-visual-design` | Opinionated visual design: typography, color, spacing, elevation, animation, dark mode | ✅ |
| `flutter-ui-craft` | Flutter implementation: Material 3 theming, design tokens, responsive layouts, accessibility | ✅ |
| `mobile-design-review` | Design review: usability, accessibility, visual quality, platform correctness | ✅ |

## Agents

| Agent | Purpose | Tools |
|-------|---------|-------|
| `mobile-ui-designer` | Full design-to-code workflow with checkpoints: Discovery → UX → Visual → Taste Check → Code → Review | Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch |
| `mobile-design-reviewer` | Design audit for existing screens: Scan → Analyze → Cross-screen consistency → Report (🔴🟡🔵) | Read, Glob, Grep, Bash |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    design-craft plugin                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Skills (knowledge layer)                                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  discovery    │  │  ux-patterns │  │ visual-design │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬────────┘  │
│         │                 │                  │           │
│  ┌──────┴───────┐  ┌─────┴────────┐                     │
│  │ flutter-ui-  │  │   design-    │                      │
│  │    craft     │  │   review     │                      │
│  └──────┬───────┘  └─────┬────────┘                     │
│         │                │                               │
│  ───────┼────────────────┼──────────────────────────     │
│         │                │                               │
│  Agents (execution layer)│                               │
│  ┌──────┴────────────────┴──────┐  ┌─────────────────┐  │
│  │    mobile-ui-designer        │  │ mobile-design-  │  │
│  │    (preloads all 5 skills)   │  │    reviewer     │  │
│  │                              │  │ (preloads 3)    │  │
│  │  Discovery                   │  │                 │  │
│  │    → UX Design               │  │  Scan           │  │
│  │      → Visual Design         │  │   → Analyze     │  │
│  │        → 🎨 Taste Check      │  │     → Cross-    │  │
│  │          → Flutter Code      │  │       screen    │  │
│  │            → Design Review   │  │       → Report  │  │
│  └──────────────────────────────┘  └─────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Workflow: mobile-ui-designer

```
Discovery ──checkpoint──▶ UX Design ──checkpoint──▶ Visual Design
    │                                                     │
    │                                               checkpoint
    │                                                     │
    │                                               Taste Check
    │                                                     │
    │                                          PASS? ─── ADJUST?
    │                                            │         │
    │                                       checkpoint   (back to
    │                                            │     Visual/UX)
    │                                            ▼
    │                                     Flutter Code
    │                                            │
    │                                       checkpoint
    │                                            │
    │                                     Design Review
    │                                       (optional)
    ▼
  User controls every transition
```

### Workflow: mobile-design-reviewer

```
Scan screens ──▶ Analyze each ──▶ Cross-screen ──▶ Report ──▶ Fix mode
                   screen        consistency      🔴🟡🔵     (advisory)
```

## Installation

Add this plugin to your Claude Code project:

```bash
# In your project's .claude/settings.json or settings.local.json
{
  "plugins": [
    "/path/to/flutter-agent-squad/plugins/mobile-design"
  ]
}
```

## Usage

### Full design workflow (agent)

```
Use the mobile-ui-designer agent to design a workout timer screen
```

The agent will guide you through discovery → UX → visual → taste check → code → review, with checkpoints at each phase.

### Design audit (agent)

```
Use the mobile-design-reviewer agent to audit all screens in lib/features/
```

### Individual skills

```
/mobile-design-discovery    — Start a discovery session
/mobile-ux-patterns         — Get UX pattern guidance
/mobile-visual-design       — Define visual language
/flutter-ui-craft           — Implement Flutter UI
/mobile-design-review       — Review an existing screen
```

## License

MIT
