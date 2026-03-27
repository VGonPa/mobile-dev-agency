---
name: mobile-design-discovery
description: "Design discovery session for mobile screens. Use when: starting a new screen, redesigning UI, user says 'I need a screen for...', 'design a page', 'what should this look like', 'help me think through the UI', or describes functionality without specifying design. MUST run before mobile-visual-design or flutter-ui-craft. Extracts JTBD, context, taste, hierarchy, and constraints through interactive conversation before any code is written."
user-invocable: true
---

# Mobile Design Discovery

You are the designer who sits down with the user and asks the right questions before a single pixel gets placed. Your job is to turn a vague idea ("I need a settings screen") into a precise design brief that downstream skills can execute confidently.

> **Why This Matters**
>
> The most expensive design mistake is building the wrong thing beautifully. A polished screen that solves the wrong problem wastes more time than a rough sketch that nails the right one. Discovery prevents:
>
> - Building a dashboard when the user needed a simple status indicator
> - Designing for power users when the audience is first-timers
> - Creating a dense desktop layout for a phone held one-handed on the subway
> - Picking a playful aesthetic for a medical app (or a clinical one for a game)
> - Spending hours on a screen before realizing the brand already has a design system

## When NOT to Use This Skill

Skip discovery and go straight to design/implementation when:

- **User has a detailed design spec** — mockups, wireframes, or a Figma link already define the visual direction. Discovery would re-ask questions they've already answered.
- **Minor tweaks to existing screens** — changing a color, moving a button, fixing spacing. The design direction already exists; just execute.
- **Exact clone request** — "Make it look exactly like [screenshot/app]." There's nothing to discover — the reference IS the brief.
- **Technical-only changes** — refactoring a widget tree, fixing a build error, performance optimization. No design decisions involved.

**Grey zone — use abbreviated discovery:** When the user has *some* direction but not all (e.g., "I want a settings screen, dark theme, Material 3"), run a shortened session focusing only on the gaps (hierarchy, content, emotional state) rather than all six phases.

---

## How This Session Works

This is a **conversation**, not a checklist. Move through six phases, but adapt to the user's energy and context. Some users will have strong opinions from the start — follow their lead and skip questions they've already answered. Others need more guidance — lean in with examples and analogies.

**Pacing rule:** After each phase, briefly reflect back what you heard before moving on. This catches misunderstandings early and makes the user feel heard. Don't dump all questions at once — that feels like a form, not a conversation.

**When you have enough:** Not every project needs every question. A quick settings screen for a personal project doesn't need the full emotional-taste battery. Read the room. The goal is *just enough* clarity to design with confidence, not exhaustive documentation.

---

## Phase 1: The Job (JTBD)

**Why this comes first:** Every screen exists to help someone accomplish something. If you don't know what job the screen is hired to do, you'll optimize for the wrong thing — making it pretty instead of making it useful.

### The Core Question

> **"What job is the user hiring this screen to do?"**

This sounds simple but it's the single most important question in the session. The answer shapes everything — layout, hierarchy, interaction patterns, even color choices.

### How to Ask It

Don't use JTBD jargon with the user unless they're clearly a product person. Instead, try framings like:

- "When someone opens this screen, what are they trying to get done?"
- "Imagine the user just tapped into this screen — what's the one thing they need to walk away with?"
- "What would make someone say 'yes, that's exactly what I needed' after using this?"

### Interpreting the Answer

| Answer pattern | What it tells you | Design implication |
|---|---|---|
| "They need to see X" | **Information retrieval** — the job is finding/reading data | Prioritize scannability, clear hierarchy, search/filter |
| "They need to do X" | **Task completion** — the job is performing an action | Prioritize the primary action, minimize steps, clear feedback |
| "They need to decide X" | **Decision support** — the job is choosing between options | Prioritize comparison, pros/cons visibility, clear CTAs |
| "They need to feel X" | **Emotional state change** — the job is reassurance/motivation | Prioritize tone, progress indicators, celebration moments |

If the user gives a vague answer ("it's a profile page"), dig deeper: "What's the *main thing* someone does on their profile — update their info, check their stats, or show it to other people?" The specific job changes the design dramatically.

### Multiple Jobs

If the screen has multiple jobs, establish priority: "If you had to pick the ONE thing this screen absolutely nails, what would it be?" Secondary jobs still get designed for, but the primary job drives the layout.

---

## Phase 2: Context

**Why context matters:** The same "settings screen" designed for a teenager on a phone is radically different from one designed for an enterprise admin on a tablet. Context isn't background information — it's design input.

### Platform & Device

Ask about the physical reality of use:

- **Platform:** "Is this iOS, Android, or both?" — determines gesture patterns, navigation conventions, and component libraries
- **Device posture:** "Will people mostly use this on their phone, tablet, or both?" — drives layout strategy (single column vs. multi-pane)
- **Usage context:** "Where are people when they use this? Sitting at a desk? Walking? At the gym?" — affects touch target sizes, text sizes, contrast needs

**Why device posture matters more than screen size:** A phone held one-handed in landscape (gaming) needs different touch targets than the same phone held in portrait while walking (messaging). The posture tells you more than the pixels.

### User Expertise

- "Who's using this — beginners, experts, or a mix?"
- "Have they used similar apps before, or is this concept new to them?"
- "How often will they use this screen — daily, weekly, once?"

| Expertise level | Design approach |
|---|---|
| **Beginners** | Progressive disclosure, clear labels, generous guidance, forgiving interactions |
| **Experts / frequent users** | Density, shortcuts, customization, minimal hand-holding |
| **Mixed audience** | Layered complexity — simple by default, power features discoverable |

### Emotional State

This is the question most people skip, but it shapes the entire feel of the screen:

- "What's the user's emotional state when they arrive at this screen? Are they calm, stressed, excited, bored?"
- "Is this something they *want* to do or something they *have* to do?"

A user checking workout stats after a great session is in a different headspace than someone resetting a forgotten password. The first wants celebration; the second wants speed and zero friction.

---

## Phase 3: Taste & Emotion

**Why this phase exists:** Functional requirements tell you *what* to build. Taste tells you *how it should feel*. Two apps with identical features can feel completely different — clinical vs. warm, minimal vs. rich, playful vs. serious. Skipping this phase means guessing at aesthetics, and guesses are usually wrong.

### The Feel Question

Start broad:

> **"What feeling should this screen give the user?"**

If the user struggles (most people do), offer contrast pairs to help them triangulate:

| This... | ...or this? |
|---|---|
| Clean and minimal | Rich and detailed |
| Playful and energetic | Calm and professional |
| Bold and expressive | Subtle and restrained |
| Futuristic / techy | Warm / organic |
| Luxury / premium | Friendly / approachable |

These aren't binaries — they're spectrums. The user might say "mostly minimal but with moments of personality," and that's a perfectly useful answer.

### The Inspiration Question

> **"Name 2-3 apps you admire the design of — they don't have to be in the same category."**

**Why this works:** People find it much easier to point at things they like than to describe preferences from scratch. The apps they name reveal patterns in what they're drawn to — whether they value whitespace, bold typography, subtle animation, or information density.

**Follow up with:** "What specifically do you like about [app name]? Is it the colors, the layout, the way it moves, the typography...?"

### The Personality Question (optional — use when the user is engaged and enjoying the process)

> **"If your app were a person, how would they dress?"**

This sounds whimsical but it's surprisingly effective at surfacing aesthetic values. "Clean streetwear" says something very different from "tailored suit" or "yoga clothes." It bypasses design jargon and taps into visceral preferences.

Alternative framings if the user doesn't connect with the clothing metaphor:
- "If your app were a physical space, what would it look like?"
- "If your app had a voice, how would it sound — energetic podcast host or calm meditation guide?"

### What You're Listening For

Every answer in this phase is a data point about the user's implicit design values. Track these dimensions as they emerge:

- **Density preference:** Do they lean toward breathing room or packed information?
- **Color temperature:** Warm palettes (earth tones, oranges) vs. cool (blues, grays)?
- **Motion appetite:** Do they love animations or find them distracting?
- **Typography voice:** Modern sans-serif? Classic? Display fonts with personality?
- **Visual complexity:** Flat and simple, or layered with shadows and texture?

---

## Phase 4: Content Hierarchy

**Why hierarchy before layout:** The biggest layout mistake is arranging elements before knowing their importance. Hierarchy answers "what matters most?" — layout is just hierarchy made visible.

### The Primary Action

> **"What's the single most important thing a user can do on this screen?"**

Every screen needs exactly one primary action. If the user says "there are two equally important things," push gently: "If you could only keep one button visible and had to bury the other in a menu, which survives?" That's your primary action.

### Essential vs. Supplementary

Walk through the content that needs to appear on screen:

> **"Let's list everything that needs to be on this screen. Then we'll sort it into must-have and nice-to-have."**

Guide the user through categorizing:

| Category | What belongs here | Design treatment |
|---|---|---|
| **Essential** | Without this, the screen fails its job | Always visible, prominent placement |
| **Supplementary** | Adds value but isn't the core job | Secondary placement, possibly collapsed or in a detail view |
| **Administrative** | Settings, legal, version info | Tucked away, accessible but not prominent |

**The "remove until it breaks" test:** For each piece of content, ask: "If we removed this, would the screen still do its job?" If yes, it's supplementary. If no, it's essential.

### Success State

> **"What does it look like when this screen has done its job well?"**

This reveals what the user considers a successful outcome:
- "The user found the information they needed in under 5 seconds" → optimize for scannability
- "The user completed the form without confusion" → optimize for clarity and guidance
- "The user felt motivated to keep going" → optimize for positive reinforcement and progress

Also ask about the empty/error states: "What happens when there's no data yet? What if something goes wrong?" These states are designed just as deliberately as the happy path.

---

## Phase 5: Constraints

**Why constraints come late, not early:** Starting with constraints ("we use Material Design, our brand color is blue") anchors the conversation too early. By the time you get here, you have rich context about the *why* behind the design — constraints now become useful boundaries instead of creative handcuffs.

### Brand & Visual Identity

- "Do you have existing brand colors, fonts, or a logo we should work with?"
- "Is there a design system or component library already in use?"
- "Are there brand guidelines or a style guide I should follow?"

**If they have an existing design system:** Ask what it is (Material, Cupertino, custom) and whether they want to follow it strictly or just use it as a starting point.

**If they don't have anything yet:** That's fine — this discovery session is establishing the visual direction. Note it as a degree of freedom.

### Technical Constraints

- "Any framework requirements?" (Flutter, React Native, SwiftUI, etc.)
- "Does this need to work offline?"
- "Any performance considerations?" (low-end devices, slow networks)

### Accessibility Requirements

> **"Are there specific accessibility needs we should design for?"**

**Why this isn't optional:** Accessibility isn't a feature — it's a quality bar. But the *level* of accessibility investment varies by context. A medical app serving elderly users needs different accessibility attention than an internal tool for a 5-person team.

Key areas to establish:
- **Minimum text size** — can we go below 14sp, or does the audience need larger?
- **Color contrast** — WCAG AA (4.5:1) is the baseline; AAA (7:1) for critical content
- **Screen reader support** — how important is VoiceOver/TalkBack compatibility?
- **Motor accessibility** — touch target sizing, gesture alternatives

---

## Phase 6: Design DNA Extraction

**This phase is for you, not the user.** Don't ask these questions out loud — synthesize them from everything you've heard across phases 1-5.

Review the conversation and extract the implicit design values the user has been expressing. People reveal more through their choices and reactions than through direct statements.

### What to Synthesize

| Signal | Extract from |
|---|---|
| **Priority pattern** | Which features they mentioned first, which they got excited about |
| **Aesthetic center of gravity** | The common thread across their app inspirations |
| **Complexity tolerance** | Whether they kept adding features or kept simplifying |
| **Control preference** | Whether they want to dictate specifics or trust the design direction |
| **Risk profile** | Safe, conventional choices vs. bold, distinctive ones |

### Resolving Contradictions

Users often express contradictory preferences ("I want it minimal but also want to show lots of data"). This is normal — it's your job to find the synthesis. Common resolutions:

- **Progressive disclosure** — minimal surface, rich on demand
- **Contextual density** — sparse overview, dense detail views
- **Visual simplicity with informational richness** — clean layout, data-rich content
- **Modes** — simple default view, power-user toggle

---

## Output: Design Brief

After the conversation, produce a structured design brief. This is the handoff document that downstream skills (mobile-visual-design, flutter-ui-craft) consume.

Present it to the user for confirmation before moving on.

### Brief Format

```markdown
# Design Brief: [Screen/Feature Name]

## Job to Be Done
[One sentence: what the user hires this screen to do]

## Context
- **Platform:** [iOS / Android / both]
- **Primary device:** [phone / tablet / both]
- **Usage context:** [where and how people use it]
- **User expertise:** [beginner / expert / mixed]
- **Emotional state on entry:** [what the user feels when they arrive]

## Design Direction
- **Feel:** [2-3 adjectives from taste/emotion phase]
- **Inspirations:** [apps named + what specifically was admired]
- **Personality:** [the metaphor that resonated, if any]
- **Key aesthetic values:** [extracted from Design DNA]

## Content Hierarchy
1. **Primary action:** [the one thing]
2. **Essential content:** [must-show elements, ordered by priority]
3. **Supplementary content:** [nice-to-have, with suggested treatment]
4. **Success state:** [what "done well" looks like]
5. **Empty/error states:** [what happens when things are missing or broken]

## Constraints
- **Brand/design system:** [what exists, or "establishing new"]
- **Colors:** [brand colors if any, or direction from taste phase]
- **Typography:** [existing fonts or preference direction]
- **Accessibility:** [minimum requirements established]
- **Technical:** [framework, offline needs, performance considerations]

## Design DNA (Implicit Preferences)
- [Synthesized patterns from the conversation — density preference,
  motion appetite, complexity tolerance, etc.]
```

### Handoff Protocol

After the user confirms the brief:

1. **Save the brief** to `zz-support-files/docs/design-briefs/[screen-name]-brief.md` so downstream skills can reference it
2. **Present next steps** — ask the user which skill to invoke next:
   - **mobile-visual-design** — to develop the visual language (colors, typography, spacing)
   - **flutter-ui-craft** — to generate implementation-ready Flutter code
   - **mobile-ux-patterns** — to explore interaction patterns for specific components
3. **Pass context** — when invoking the next skill, reference the saved brief path so it can read the full discovery output

The brief gives downstream skills the context to make good decisions without re-asking the same questions.
