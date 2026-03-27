---
name: mobile-visual-design
description: Designs visually distinctive mobile interfaces with opinionated spacing, typography, color, elevation, animation, and dark mode systems. Use when choosing fonts, building color palettes, setting spacing tokens, designing elevation hierarchies, creating animation language, implementing dark mode, or when any UI feels "generic" or "AI-generated." Applies anti-AI-slop rules and 2026 design trends to produce work that passes the portfolio test.
user-invocable: true
---

# Mobile Visual Design

Good design is a series of intentional decisions, not defaults. Every pixel communicates hierarchy, every color carries meaning, every animation tells a story about physics. This skill gives you the frameworks to make those decisions with confidence — not guess, not copy, not settle for "looks fine."

The goal is not "modern UI." The goal is UI with **personality** — design that a skilled human designer would be proud to ship and put in their portfolio.

> **Common Mistakes This Skill Prevents**
>
> - Using Inter/Roboto because "it's clean" (it's default — it signals zero design thought)
> - Slapping purple-to-blue gradients on everything (the universal AI-generated-UI fingerprint)
> - Spacing values like 10px, 15px, 23px (arbitrary — breaks visual rhythm)
> - One border radius for everything (a card and a chip are not the same object)
> - Colors named `blue500` instead of `primary` or `success` (what happens when your brand isn't blue?)
> - Dark mode = invert everything (destroys hierarchy and contrast)
> - Animations that all use the same 300ms linear curve (feels robotic, not physical)
> - Symmetrical 2x2 grids with identical card sizes (screams "template")

## When to Use This Skill

- Choosing typography and font pairings for a new app
- Building a color system from a brand color or seed
- Defining spacing, elevation, or border radius tokens
- Designing dark mode that isn't an afterthought
- Creating animation/motion language
- Any time the UI feels "flat," "generic," or "like every other app"
- Pre-launch visual audit: "Would a designer ship this?"

## When NOT to Use This Skill

This skill covers **visual design systems and aesthetics**. It does NOT cover:

- **UX patterns and flows** — navigation structure, onboarding sequences, form design (use mobile-ux-patterns)
- **Component architecture** — widget composition, state management, responsive breakpoints
- **Accessibility compliance** — WCAG auditing, screen reader optimization (though contrast ratios are covered here)
- **Brand strategy** — logo design, naming, brand positioning
- **Icon design** — custom icon creation (though icon selection guidance is in anti-AI-slop rules)

---

## 1. Spacing System: The 8px Grid

**Why it matters:** Arbitrary spacing is the fastest way to make a UI feel "off." Humans perceive visual rhythm subconsciously — inconsistent spacing reads as amateur even when users can't articulate why.

### The Rule

**Every spacing value must be a multiple of 4px, with 8px as the base unit.** No exceptions. No "just this once."

| Token | Value | Use |
|-------|-------|-----|
| `space-xs` | 4px | Icon-to-label gaps, inline element padding |
| `space-sm` | 8px | Tight element grouping, list item internal padding |
| `space-md` | 16px | Standard content padding, between related elements |
| `space-lg` | 24px | Section separation within a card/container |
| `space-xl` | 32px | Between distinct content groups |
| `space-2xl` | 48px | Major section breaks, screen-level padding |
| `space-3xl` | 64px | Hero spacing, dramatic visual breathing room |

### Decision Framework

**"How related are these two elements?"**

- **Same thought** (icon + label): `space-xs` (4px)
- **Same group** (title + subtitle): `space-sm` (8px)
- **Same section** (card content items): `space-md` (16px)
- **Different sections** (card to card): `space-xl` (32px)
- **Different contexts** (header to body): `space-2xl` (48px)

**The ratio matters more than the absolute value.** Tighter spacing = stronger relationship. The jump from 8→16 says "related." The jump from 16→48 says "new topic." If you can't feel the difference, your spacing is too uniform.

See [REFERENCE.md → Spacing Tokens](REFERENCE.md#spacing-tokens-flutter) for Flutter `EdgeInsets` constants.

---

## 2. Typography Hierarchy

**Why it matters:** Typography is information architecture made visible. A screen with one font size is a wall of text. A screen with clear typographic hierarchy guides the eye without any other visual cue.

### The Rules

1. **Body text: 16px minimum.** Not 14px. Not "14px looks fine on my phone." 16px is the floor for comfortable mobile reading. Below 16px is reserved for captions and metadata.
2. **Heading scale: 1.3x ratio.** Each heading level is 1.3× the one below it. This creates a perceptible but not jarring jump.
3. **Line height: 1.4–1.6 for body, 1.1–1.2 for headings.** Body text needs room to breathe. Headings are short and need to feel compact.
4. **2–3 weights maximum.** Regular + Medium + Bold. If you're using Light, Regular, Medium, SemiBold, Bold, and Black — you don't have a hierarchy, you have a mess.

### Typographic Scale

| Token | Size | Weight | Line Height | Use |
|-------|------|--------|-------------|-----|
| `display` | 34px | Bold | 1.1 | Hero numbers, splash screens |
| `heading-1` | 28px | Bold | 1.15 | Screen titles |
| `heading-2` | 22px | SemiBold | 1.2 | Section headers |
| `heading-3` | 18px | Medium | 1.25 | Card titles, subsections |
| `body` | 16px | Regular | 1.5 | Primary content |
| `body-small` | 14px | Regular | 1.4 | Secondary content, descriptions |
| `caption` | 12px | Regular | 1.4 | Timestamps, metadata, labels |
| `overline` | 11px | Medium (CAPS) | 1.5 | Category labels, section tags |

### Font Pairing: Personality, Not Convention

**The font pairing IS the personality.** Two fonts communicate more brand identity than a logo on a mobile screen.

**Pairing Rule:** One display/heading font with character, one body font with readability. Never two decorative fonts. Never two neutrals.

| Personality | Heading Font | Body Font | Feels Like |
|-------------|-------------|-----------|------------|
| **Editorial / Premium** | Playfair Display | Source Sans 3 | Magazine feature, curated content |
| **Tech / Precision** | Space Grotesk | Inter | Developer tool, fintech dashboard |
| **Friendly / Approachable** | Sora | DM Sans | Consumer app, social platform |
| **Athletic / Bold** | Plus Jakarta Sans (Bold) | Outfit | Fitness tracker, sports app |
| **Minimal / Luxury** | Cormorant Garamond | Nunito Sans | Fashion, lifestyle, high-end |
| **Playful / Creative** | Fredoka | Quicksand | Kids' app, creative tools |

**How to choose:** Ask "If this app were a person, how would they speak?" Formal and precise → serif heading. Casual and warm → rounded sans. Technical and trustworthy → geometric sans. Then pick the body font for pure readability in that personality range.

**Anti-pattern:** Choosing a font because it's "popular" or "safe." Inter is a fine font — but using it because you didn't think about fonts is not design. If you choose Inter, it should be because geometric neutrality IS your brand personality (rare), not because it was the default.

See [REFERENCE.md → Font Pairing Implementation](REFERENCE.md#font-pairing-implementation) for Google Fonts setup and TextTheme code.

---

## 3. Color System

**Why it matters:** Color is the most emotionally immediate design element. A wrong blue doesn't just "look off" — it changes how trustworthy, energetic, or calm the app feels. And if your color system is organized by hue instead of role, it will break the moment your brand evolves.

### Rule 1: Name Colors by Role, Never by Hue

```
// WRONG — brittle, meaningless
blue500, purple300, green400

// RIGHT — semantic, survives rebrand
primary, primaryContainer, success, error, surface, onSurface
```

**Why:** When your brand color changes from blue to teal, `primary` still works. `blue500` becomes a lie.

### Semantic Color Roles

| Role | Purpose | Example Usage |
|------|---------|---------------|
| `primary` | Brand identity, primary actions | FABs, active nav, key buttons |
| `primaryContainer` | Subtle primary surfaces | Selected states, highlight backgrounds |
| `secondary` | Supporting accent | Secondary buttons, tags, badges |
| `tertiary` | Third-level accent | Decorative elements, categories |
| `surface` | Content backgrounds | Cards, sheets, dialogs |
| `surfaceVariant` | Differentiated surfaces | Input fields, inactive chips |
| `background` | Screen background | Scaffold background |
| `error` | Destructive / error states | Validation errors, delete actions |
| `success` | Positive confirmation | Completed states, valid input |
| `warning` | Caution states | Expiring content, approaching limits |
| `onPrimary` | Text/icons on primary | Button labels on primary color |
| `onSurface` | Text/icons on surface | Body text, icons on cards |
| `outline` | Borders, dividers | Card outlines, input borders |

### Rule 2: Build From a Seed, Not From Scratch

Never hand-pick 15 individual hex values. Start with ONE seed color (your primary) and generate the system mathematically.

**Palette Generation Strategy:**

1. **Pick your seed** — the single most important brand color
2. **Choose a harmony model** based on the emotional goal:

| Harmony | Method | Emotional Effect | Best For |
|---------|--------|-----------------|----------|
| **Analogous** | ±30° on color wheel | Calm, cohesive, professional | Health, finance, enterprise |
| **Complementary** | 180° opposite | High energy, dynamic contrast | Sports, fitness, gaming |
| **Split-complementary** | 150° + 210° | Vibrant but balanced | Consumer apps, social |
| **Monochromatic + accent** | Tints/shades + 1 accent | Sophisticated, focused | Luxury, editorial, minimal |
| **Triadic** | 120° apart | Bold, playful, diverse | Creative tools, kids' apps |

3. **Generate tonal ranges** — each role needs light (container), medium (default), and dark (on-color) variants

### Fitness Domain Color Conventions

If building a fitness/health app, these associations are deeply ingrained in users:

| Context | Expected Color | Why |
|---------|---------------|-----|
| Heart rate / intensity | Red spectrum | Universal vital sign association |
| Recovery / rest | Blue-green | Clinical calm, cooldown |
| Achievement / PR | Gold / amber | Trophy, medal association |
| Active / in-progress | Brand primary (energetic) | Energy, movement |
| Calories / burn | Orange-red | Heat, fire, energy expenditure |
| Hydration | Cyan / light blue | Water |

**Don't fight these conventions.** Using green for heart rate or purple for hydration creates cognitive friction that no amount of onboarding fixes.

See [REFERENCE.md → Color System Implementation](REFERENCE.md#color-system-implementation) for Material 3 ColorScheme setup and seed-based generation.

---

## 4. Border Radius Hierarchy

**Why it matters:** A single border radius applied everywhere says "I used a CSS framework." Intentional variation in radius communicates the visual weight and function of each element.

### The Rule

**Larger, more prominent elements get larger radii. Smaller, inline elements get tighter radii.**

| Token | Value | Use |
|-------|-------|-----|
| `radius-sm` | 4px | Inline chips, code blocks, tight containers |
| `radius-md` | 8px | Buttons, input fields, small cards |
| `radius-lg` | 16px | Cards, dialogs, sheets |
| `radius-xl` | 24px | Large image containers, hero cards |
| `radius-full` | 9999px | Avatars, pills, FABs |

### Decision Framework

Ask: **"How heavy is this element?"**

- Lightweight / inline → `radius-sm` (4px): badges, tags, tooltips
- Interactive / mid-weight → `radius-md` (8px): buttons, inputs, dropdowns
- Container / content-bearing → `radius-lg` (16px): cards, modals, sheets
- Hero / focal → `radius-xl` (24px): featured cards, image frames
- Circular / iconic → `radius-full`: avatars, status dots, floating buttons

**Anti-pattern:** `borderRadius: 12` on everything. If your buttons, cards, inputs, and chips all have the same radius, you've eliminated a hierarchy signal. Even a 4px vs 8px vs 16px distinction is enough.

---

## 5. Elevation System

**Why it matters:** Elevation (shadow/layering) communicates interactivity and z-axis position. An element that floats above others is more important, more interactive, or more temporary. But too many elevation levels create visual noise — the eye can only distinguish so many layers.

### The Rule

**Maximum 5–6 elevation levels.** Each level must be visually distinct. If you can't tell level 3 from level 4 at a glance, they're the same level — merge them.

| Level | Shadow | Use | Implies |
|-------|--------|-----|---------|
| `elevation-0` | None | Background, flat content | Static, part of the surface |
| `elevation-1` | Subtle, tight | Cards, list items | Contained content, liftable |
| `elevation-2` | Medium, spread | Floating buttons, raised cards | Interactive, actionable |
| `elevation-3` | Pronounced | Dropdown menus, tooltips | Temporary, overlaying |
| `elevation-4` | Strong | Bottom sheets, drawers | Modal-adjacent, system UI |
| `elevation-5` | Maximum | Dialogs, modals | Highest priority, blocks below |

### Shadow Construction

**Layered shadows look more natural than single shadows.** Real objects cast a tight dark shadow (contact shadow) AND a large diffuse shadow (ambient light).

```
// BAD: Single flat shadow
boxShadow: [BoxShadow(blurRadius: 10, color: black12)]

// GOOD: Layered — contact shadow + ambient shadow
boxShadow: [
  BoxShadow(blurRadius: 2, offset: Offset(0, 1), color: black.withValues(alpha: 0.08)),  // contact
  BoxShadow(blurRadius: 8, offset: Offset(0, 4), color: black.withValues(alpha: 0.06)),  // ambient
]
```

### Decision Framework

**"How interactive and how temporary is this element?"**

- Static content on the page → `elevation-0`
- Content container users can tap into → `elevation-1`
- Floating action / persistent interactive element → `elevation-2`
- Temporary overlay (menu, tooltip) → `elevation-3`
- System-level overlay (sheet, drawer) → `elevation-4`
- Must-respond dialog → `elevation-5`

**Rule of thumb:** If the element disappears when you tap elsewhere, it needs at least `elevation-3`. If the element blocks interaction with content below, it needs `elevation-5`.

See [REFERENCE.md → Elevation Tokens](REFERENCE.md#elevation-tokens-flutter) for Flutter shadow definitions.

---

## 6. Dark Mode

**Why it matters:** Dark mode is not "invert the colors." It's a complete re-evaluation of hierarchy, contrast, and color saturation. Bad dark mode is worse than no dark mode — it signals that the feature was an afterthought.

### The Rules

**Rule 1: `#121212`, not `#000000`.** Pure black (#000000) causes "black smearing" on OLED screens (pixels turning fully off creates visible trails during scrolling). It also creates jarring contrast with any colored element. `#121212` (or a dark-tinted equivalent) avoids both problems.

**Rule 2: Off-white text, not `#FFFFFF`.** Pure white on dark backgrounds causes halation (a "glowing" effect that fatigues the eyes). Use `#E0E0E0` to `#EBEBEB` for body text. Reserve `#FFFFFF` for headings and emphasis only.

**Rule 3: Desaturate colors 15–20%.** Colors that look vibrant on white backgrounds become eye-searing on dark backgrounds. Reduce saturation by 15–20% for dark mode variants.

**Rule 4: Maintain 4.5:1 minimum contrast ratio.** WCAG AA compliance isn't optional. Test every text/background combination. The most common dark mode failure is light gray text on dark gray backgrounds that technically meets "looks okay" but fails contrast checks.

### Dark Mode Surface Hierarchy

| Surface | Light Mode | Dark Mode | Purpose |
|---------|-----------|-----------|---------|
| Background | `#FFFFFF` | `#121212` | Base layer |
| Surface (cards) | `#FFFFFF` | `#1E1E1E` | +1 elevation tint |
| Surface variant | `#F5F5F5` | `#2C2C2C` | Differentiated containers |
| Surface elevated | `#FFFFFF` + shadow | `#333333` | Higher elevation = lighter |

**Key inversion:** In light mode, elevation = shadow (darker). In dark mode, elevation = lighter surface. Higher elements are literally brighter, simulating light falling on raised surfaces.

### Decision Framework for Dark Mode Colors

For every color token, ask:

1. **Does it maintain 4.5:1 contrast against its background?** → Adjust if not
2. **Does it look uncomfortably bright?** → Desaturate 15–20%
3. **Is it a surface/background color?** → Use the elevation-tinted scale above
4. **Is it semantic (error, success)?** → Keep hue recognizable, adjust lightness

See [REFERENCE.md → Dark Mode Implementation](REFERENCE.md#dark-mode-implementation) for ThemeData configuration and color mapping.

---

## 7. Animation Language

**Why it matters:** Animation isn't decoration — it's communication. A button that snaps to a new state feels broken. A button that eases into position feels physical and intentional. But animations that are too slow, too bouncy, or too uniform feel worse than no animation at all.

### Duration Tiers

**Animations should be as fast as possible while still being perceivable.** Users notice animation; they shouldn't have to wait for it.

| Tier | Duration | Use | Principle |
|------|----------|-----|-----------|
| **Fast** | 150ms | Micro-interactions: toggles, checkboxes, color changes, opacity shifts | "I acknowledged your tap" |
| **Normal** | 250ms | Element transitions: cards expanding, tabs switching, list reordering | "Something is changing" |
| **Slow** | 350ms | Layout transitions: page transitions, bottom sheet reveals, modal entrance | "A new context is arriving" |

**Rule:** If you're considering anything over 400ms, you'd better have a very good reason. Mobile users are impatient. An animation that's twice as long isn't twice as good — it's half as fast.

### Spring Physics: Make It Feel Real

**Linear animations feel robotic. Ease curves feel better. Spring physics feel physical.**

Spring-based animation emulates real-world behavior: objects have mass, momentum, and resistance. The result is motion that feels like it exists in the real world.

| Parameter | Range | Effect |
|-----------|-------|--------|
| **Damping ratio** | 0.7–0.85 | Lower = more bounce, higher = more controlled. 0.7 for playful, 0.85 for professional |
| **Stiffness** | 200–400 | Lower = slower/softer, higher = snappier. 300 is a good default |
| **Mass** | 1.0 | Almost never change this. Adjusting mass is confusing — use damping instead |

### Animation Decision Framework

| Action | Duration | Curve | Why |
|--------|----------|-------|-----|
| Button press feedback | 150ms | `easeOut` | Acknowledge immediately |
| Toggle / switch | 150ms | Spring (damping: 0.8) | Snappy physical feel |
| Card expand/collapse | 250ms | Spring (damping: 0.85) | Smooth content reveal |
| Page transition | 350ms | Spring (damping: 0.8) | Context change needs time |
| Bottom sheet reveal | 350ms | Spring (damping: 0.75) | Slight bounce = "it arrived" |
| Dismiss / swipe away | 200ms | `easeIn` | Get out of the way fast |
| Loading skeleton pulse | 1500ms loop | `easeInOut` | Gentle, non-distracting |
| Success celebration | 400ms | Spring (damping: 0.6) | Expressive, joyful |

**Anti-patterns:**
- **Same duration for everything** — if your toggle and your page transition both take 300ms, you have no motion hierarchy
- **Linear curves** — nothing in the physical world moves at constant velocity
- **Bounce on serious actions** — a delete confirmation shouldn't bounce. Match animation energy to emotional context

See [REFERENCE.md → Animation Tokens](REFERENCE.md#animation-tokens-flutter) for Flutter curve and spring definitions.

---

## 8. 2026 Design Trends

**Why these matter:** Design trends aren't arbitrary fashion — they reflect evolving user expectations. Users who see tactile UIs in top apps develop an unconscious expectation for that quality. Ignoring current trends doesn't make your design "timeless" — it makes it feel dated.

**How to use trends:** Cherry-pick intentionally. Adopt trends that serve your UX. Ignore trends that would compromise usability for visual flash.

### Tactile UI / Neubrutalism Lite

**What:** Interfaces that feel like you could touch them. Subtle textures, micro-shadows that respond to interaction, surfaces that feel like real materials rather than flat colored rectangles.

**How to apply:**
- Slightly larger shadows that shift on press (element "pushes into" the surface)
- Subtle background textures (noise overlays at 2–4% opacity)
- Press states that scale down slightly (0.97–0.98) before bouncing back
- Borders with slight color variation suggesting light direction

**When to use:** Consumer apps, fitness, social, creative tools.
**When NOT to use:** Enterprise dashboards, data-heavy screens where every pixel counts.

### Progressive Blur (Depth of Field)

**What:** Background elements progressively blur as foreground content scrolls over them, simulating camera depth-of-field.

**How to apply:**
- `BackdropFilter` with `ImageFilter.blur` on overlapping surfaces
- Blur radius increases with z-distance (higher elements see blurrier backgrounds)
- Combine with frosted-glass surfaces for navigation bars and bottom sheets

**When to use:** Scroll-heavy content, media apps, layered interfaces.
**Performance note:** `BackdropFilter` is expensive. Test on low-end devices. Provide a fallback (solid semi-transparent background) for devices that can't maintain 60fps.

### Bento Grid Layouts

**What:** Asymmetrical grid layouts with mixed-size tiles (like a bento box), replacing the monotonous same-size-card grid.

**How to apply:**
- Mix 1x1, 2x1, 1x2, and 2x2 tiles in a grid
- Larger tiles for featured/primary content, smaller for secondary
- Maintain consistent gutters (use your spacing system)
- Content density varies — hero tiles are spacious, small tiles are dense

**When to use:** Dashboards, home screens, discovery feeds, profile screens.
**When NOT to use:** Sequential content (messages, feeds where order matters more than hierarchy).

### Kinetic Typography

**What:** Text that responds to interaction — animates on scroll, reacts to gestures, has staggered entrance animations.

**How to apply sparingly:**
- Staggered fade-in for list items (50ms delay between items)
- Heading text that scales or fades during scroll transitions
- Number counters that animate to their final value
- **Maximum one kinetic text element per screen** — more is overwhelming

**When to use:** Onboarding, achievement screens, hero sections.
**When NOT to use:** Body text, form labels, any text the user needs to read quickly.

---

## 9. Anti-AI-Slop Rules

**Why this section exists:** AI-assisted design tools (including this one) have failure modes. They converge on the same "safe" choices, producing interfaces that are technically correct but soulless. These rules are guardrails against the most common AI-generated-UI fingerprints.

**These rules are non-negotiable.** If the design you're producing matches these anti-patterns, stop and redesign.

### Rule 1: No Default Purple Gradients

Purple-to-blue (or purple-to-pink) linear gradients are the #1 tell of AI-generated UI. They appear because purple tests well in isolation and gradient adds perceived "polish." The result is a sea of identical-looking apps.

**Instead:** Use your brand color system. If your brand IS purple, use it as a flat color with intentional highlight accents — not a gradient that screams "AI made this."

### Rule 2: No Default Fonts

Inter, Roboto, and system defaults are fine fonts. But using them because you didn't choose a font is not design — it's the absence of design.

**Instead:** Choose a font pairing that communicates personality (see Section 2). The font decision should be intentional enough that you can explain WHY you chose it.

### Rule 3: Semantic Colors, Not Pretty Colors

AI tools love picking colors that "look nice together" without assigning meaning. The result is decorative color with no information value.

**Instead:** Every color in the UI should have a role (see Section 3). If you can't name WHY an element is that color, it shouldn't be that color.

### Rule 4: Custom Icons (or Curated Sets)

Default Material Icons are recognizable from a mile away. They're designed for breadth, not personality.

**Instead:** Choose an icon set that matches your typography personality:
- **Phosphor Icons** — warm, rounded, versatile (pairs with friendly fonts)
- **Lucide** — clean, geometric (pairs with tech/precision fonts)
- **Tabler Icons** — bold, stroke-based (pairs with athletic/bold fonts)
- **Heroicons** — solid variants feel native on iOS, outline on Android

If budget allows, customize 10–15 key icons. The navigation icons and primary actions are what users see most — those alone set the tone.

### Rule 5: Conversational Microcopy

AI-generated UIs use generic labels: "Submit," "Continue," "Learn More," "Get Started." These are functional but devoid of personality.

**Instead:** Microcopy should match the app's voice:
- "Submit" → "Save my progress" / "Lock it in" / "Let's go"
- "Error" → "Something went sideways" / "That didn't work"
- "Empty state" → "Nothing here yet — want to add something?"
- "Loading" → "Crunching the numbers..." / "Warming up..."

**Rule of thumb:** If you replaced your microcopy with any other app's microcopy and nobody noticed, it's too generic.

### Rule 6: Break the Grid (Intentionally)

Symmetrical grids with identical card sizes are the layout equivalent of clipart. Real design has visual hierarchy expressed through layout, not just font size.

**Instead:**
- Use bento grids (Section 8) for dashboards and discovery
- Feature ONE element prominently, let others recede
- Vary card sizes based on content importance
- Allow negative space — not every screen-inch needs content

### The Portfolio Test

**Before shipping any screen, ask: "Would I put this in a design portfolio?"**

If the answer is "it's fine" or "it works" — that's a no. Portfolio-worthy design has at least one intentional visual decision that makes it distinctive. It could be:
- A surprising but effective color choice
- Typography with clear personality
- A layout that guides the eye with intention
- An animation that adds meaning, not just motion
- An empty state that makes you smile

**"Competent" is the enemy of "good."** Every screen should have at least one moment of design intention beyond "I followed the system." The system exists to free you for those moments — not to replace them.

---

## 10. Putting It All Together: Design System Checklist

Use this before finalizing any design system or major screen:

### Foundation (Do First)
- [ ] Spacing tokens defined on 8px grid (minimum 6 values)
- [ ] Typography scale with ≤3 weights and intentional font pairing
- [ ] Color system with semantic naming and defined harmony model
- [ ] Border radius hierarchy with ≥3 distinct levels

### Depth & Motion (Do Second)
- [ ] Elevation system with ≤6 levels, layered shadows
- [ ] Animation durations for fast/normal/slow tiers
- [ ] Spring physics parameters defined (damping + stiffness)

### Polish (Do Third)
- [ ] Dark mode with `#121212` base, desaturated colors, 4.5:1 contrast
- [ ] At least one 2026 trend applied where appropriate
- [ ] All anti-AI-slop rules pass (no purple gradients, no default fonts, semantic colors, curated icons, conversational microcopy, broken grid)

### The Final Question
- [ ] **Portfolio test passed** — every screen has at least one intentional design decision beyond "following the system"
