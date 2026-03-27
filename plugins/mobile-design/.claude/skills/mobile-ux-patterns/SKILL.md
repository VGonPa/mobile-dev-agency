---
name: mobile-ux-patterns
description: Designs mobile UX using evidence-based patterns and cognitive principles. Use when building navigation, forms, onboarding, screen states (loading/empty/error), tap targets, gesture interactions, or choosing between bottom tabs vs drawer vs sheets. Starts with the WHY behind each pattern so you pick the right one — not just copy UI code.
user-invocable: true
---

# Mobile UX Patterns

Good mobile UX isn't about following a checklist — it's about understanding WHY certain patterns work on small, touch-driven, one-handed devices. This skill gives you decision frameworks rooted in cognitive science and ergonomics so you choose the right pattern for your context.

> **Common Mistakes This Skill Prevents**
>
> - Tap targets smaller than 44pt/48dp (causes mis-taps, frustrates users, fails accessibility audits)
> - Putting primary actions in the top-left corner (hardest thumb reach on one-handed use)
> - Showing a spinner when a skeleton screen would prevent layout shift and feel faster
> - Using a hamburger menu for 3-4 top-level destinations (hides primary navigation behind a tap)
> - Dumping a 7-step tutorial on first launch instead of teaching progressively in context
> - Forms with side-by-side fields on mobile (forces precision tapping on narrow columns)
> - Gestures as the ONLY way to perform an action (undiscoverable, excludes accessibility users)
> - Empty states with no call-to-action (dead ends that strand the user)

## When to Use This Skill

- Deciding between navigation patterns (tabs, drawer, sheets)
- Designing forms for mobile input
- Building screen states (loading, empty, error, success)
- Sizing and placing interactive elements
- Planning onboarding flows
- Adding micro-interactions and gesture shortcuts
- Reviewing mobile layouts for ergonomic and cognitive issues

## When NOT to Use This Skill

This skill covers **mobile UX patterns and principles**. It does NOT cover:

- **Visual design** — color theory, typography scales, brand aesthetics, icon design
- **Platform-specific API implementation** — use Flutter/SwiftUI/Jetpack Compose docs
- **Accessibility compliance** — WCAG/ADA audits need dedicated accessibility skills (though many patterns here improve accessibility as a side effect)
- **Backend architecture** — API design, data modeling, caching strategies
- **Analytics instrumentation** — event tracking, funnel analysis, A/B test setup

## Step 1: Laws of UX Applied to Mobile

These aren't academic theories — they're measurable constraints that predict whether your UI will feel intuitive or frustrating.

### Fitts's Law — Size and Distance Determine Speed

**The principle:** Time to reach a target = f(distance to target / size of target). Smaller or farther targets take longer and produce more errors.

**Mobile implication:** Fingers are imprecise. A mouse cursor is 1px; a fingertip contact patch is ~7mm (40px at 160dpi).

**Rules:**

| Element | Minimum Size | Why |
|---------|-------------|-----|
| Tap targets | 44×44pt (iOS) / 48×48dp (Android) | Apple HIG and Material Design minimums — below this, error rates spike |
| Spacing between targets | ≥8pt/8dp | Prevents adjacent mis-taps, especially for users with motor impairments |
| Primary CTA button | Full width or ≥280dp wide | Reduces horizontal aiming on the most important action |

**Decision:** If two actions compete for space, make the most frequent action larger and closer to the natural thumb rest position. Destructive actions (delete, cancel) should be smaller and farther from primary actions — never the same size side-by-side.

### Hick's Law — More Choices = Slower Decisions

**The principle:** Decision time increases logarithmically with the number of options.

**Mobile implication:** Screen real estate forces trade-offs. Every option you show competes for attention.

**Rules:**
- **Navigation:** 3–5 primary destinations maximum in bottom tabs. More than 5 causes choice paralysis and shrinks tap targets below minimum.
- **Actions:** Surface 1–2 primary actions per screen. Move secondary actions to overflow menus or contextual sheets.
- **Lists:** When showing selectable options, group into categories or use progressive disclosure (show top 5, "Show all" to expand).

**Decision:** When you have more than 5 equally important options, the answer isn't "fit them all in" — it's "re-evaluate your information architecture." Either some aren't truly primary, or you need sub-navigation.

### Jakob's Law — Users Spend Most Time in OTHER Apps

**The principle:** Users transfer expectations from familiar apps to yours. Breaking platform conventions forces relearning.

**Rules:**
- **iOS:** Prefer large title navigation bars, edge-swipe to go back, bottom tab bars, SF Symbols icon style
- **Android:** Prefer top app bars with Material icons, system back gesture/button, FABs for primary creation actions, Navigation Rail on tablets
- **Cross-platform (Flutter):** Default to `platform`-adaptive widgets. Override ONLY when your brand identity demands it AND the alternative is equally discoverable.

**Decision:** If you're debating "custom vs platform-standard," ask: "Will the user know what to do without instructions?" If the answer is no, use the platform convention.

### Miller's Law — Chunk Information in Groups of 7±2

**The principle:** Working memory holds ~7 items. Beyond that, comprehension drops.

**Mobile implication:** Mobile screens show even fewer items at once. Chunk aggressively.

**Rules:**
- Group form fields into sections of 3–5 fields with clear headers
- Break long lists into categorized sections
- Multi-step processes: show 3–5 steps maximum per flow (use stepper indicators)
- Dashboard cards: 5–7 key metrics maximum — more requires a "details" drill-down

### Postel's Law — Be Liberal in What You Accept

**The principle:** Accept input in as many reasonable formats as possible; normalize internally.

**Mobile implication:** Mobile keyboards are terrible for precise formatting. Don't fight the user.

**Rules:**
- Phone numbers: accept `+1 (555) 123-4567`, `5551234567`, `555-123-4567` — normalize server-side
- Dates: offer a date picker instead of demanding `YYYY-MM-DD` typed input
- Currency: accept `$10`, `10.00`, `10` — parse and format yourself
- Search: tolerate typos with fuzzy matching; show "Did you mean…?" suggestions

**Decision:** Every format restriction you add is a potential form abandonment. Only enforce format when the system genuinely cannot interpret ambiguous input.

## Step 2: Thumb Zone Design

**Why this matters:** 75% of mobile interactions are one-handed. If your primary actions aren't in the natural thumb arc, you're making every interaction harder than it needs to be.

### The Thumb Zone Model

The thumb pivots from the base of the palm. This creates three zones:

| Zone | Reach | Placement Strategy |
|------|-------|--------------------|
| **Natural** (easy) | Bottom-center of screen | Primary actions, FABs, navigation tabs, most-used controls |
| **Stretch** (ok) | Bottom-left, bottom-right, center | Secondary actions, content area, lists |
| **Hard** (avoid) | Top-left, top-right corners | Never put frequently-used actions here. OK for rare actions (settings, profile) |

See [REFERENCE.md → Thumb Zone Pixel Ranges](REFERENCE.md#thumb-zone-pixel-ranges) for exact measurements per device size.

### Practical Application

| UI Element | Placement | Why |
|-----------|-----------|-----|
| Primary CTA ("Save", "Send", "Next") | Bottom of screen, full width or bottom-right | Natural zone, reachable without grip shift |
| Bottom navigation bar | Fixed bottom | Natural zone for all tabs |
| FAB (Floating Action Button) | Bottom-right | Natural thumb rest for right-handed majority; left-handed users reach it in stretch zone |
| Back / Close | Top-left (standard) | Platform convention overrides ergonomics here — users expect it. Keep it ≥44pt. |
| Destructive actions ("Delete") | Top area or behind confirmation | Hard zone = accidental-tap protection |
| Pull-to-refresh | Top of scrollable content | Stretch zone, but the pulling gesture itself is natural |

**Decision:** When platform convention conflicts with thumb ergonomics (e.g., iOS back button in top-left), follow the convention. When you're designing a custom interaction with no established convention, always prefer the natural zone.

## Step 3: Navigation Pattern Decision Tree

**Choose based on structure, not aesthetics.** The right navigation pattern depends on how many destinations you have and how users move between them.

### Decision Framework

```
How many top-level destinations?

├── 2-5 destinations
│   ├── Users switch frequently between them? → Bottom Tab Bar
│   └── One primary + others secondary? → Bottom Tab Bar (with emphasis on primary)
│
├── 6+ destinations
│   ├── All equally important? → Drawer (hamburger menu)
│   └── 3-5 primary + rest secondary? → Bottom Tabs + "More" tab → Drawer/List
│
├── Contextual sub-navigation within a section?
│   └── → Top Tabs (TabBar) within that section
│
├── Temporary task or detail view?
│   ├── Quick action, partial content? → Bottom Sheet (modal or persistent)
│   └── Full new context? → Full-screen push navigation
│
└── Tablet / large screen?
    └── → Navigation Rail (side) + content area
```

### Pattern Comparison

| Pattern | Best For | Worst For | Max Items |
|---------|----------|-----------|-----------|
| **Bottom Tabs** | 3–5 frequent, equal destinations | More than 5 items; infrequent destinations | 5 (absolute max) |
| **Drawer** | 6+ destinations; settings; user profile | Primary navigation users need constantly (hidden = forgotten) | No hard limit, but <10 visible without scroll |
| **Top Tabs** | Sub-categories within a section (e.g., "All / Active / Completed") | Primary navigation (not visible enough); >4 tabs (requires scroll) | 4 visible, more with scroll |
| **Bottom Sheet** | Quick actions, filters, detail previews, confirmations | Full workflows; forms >3 fields | N/A |
| **Full-screen** | New task contexts, long forms, immersive content | Quick toggles between sibling views | N/A |

### Anti-Patterns

- **Hamburger menu for 3 items** — If it fits in a bottom tab bar, use one. Drawer hides navigation = lower feature discovery.
- **Bottom tabs + drawer** — Pick one primary pattern. Both simultaneously confuses users about where to find things.
- **Nested drawers** — If your IA needs nested drawers, your IA is too deep. Flatten it.
- **Tab bar labels omitted** — Icons alone are ambiguous. Always pair icon + label in bottom tabs. Top tabs can be label-only.

## Step 4: Screen States — Every Screen Has Five States

A screen that only handles "data loaded successfully" handles 20% of real-world scenarios. Design all five states or users hit dead ends.

### The Five States

| State | What the User Sees | Design Goal |
|-------|-------------------|-------------|
| **Loading** | Data is being fetched | Communicate progress, prevent layout shift |
| **Empty** | No data exists yet | Guide user to create first item |
| **Error** | Something went wrong | Explain what happened, offer recovery |
| **Partial** | Some data loaded, some failed | Show what you can, indicate what's missing |
| **Ideal** | Full data, everything works | The design you started with |

### Loading States

**Choose skeleton screens over spinners.** Skeleton screens (gray placeholder shapes matching the content layout) feel ~30% faster than spinners in user perception studies, because:

1. They prevent layout shift (content appears in place)
2. They communicate what's coming (shapes set expectations)
3. They feel like progress (skeleton → content is a smooth transition; spinner → content is a jump)

| Technique | Use When | Avoid When |
|-----------|----------|------------|
| **Skeleton screen** | List/card layouts, profile pages, dashboards | Actions that take <200ms (use nothing) |
| **Shimmer skeleton** | Same as skeleton, adds perceived motion | Too many shimmer elements (distracting) |
| **Spinner** | Indeterminate wait inside a modal/button, or short operations (1-3s) | Full-page loads (skeleton is better) |
| **Progress bar** | File uploads, multi-step processing with known duration | Unknown duration (infinite progress bar = anxiety) |
| **Inline placeholder** | Individual components loading independently | N/A |

**Timing rule:** See [REFERENCE.md → Interaction Timing Thresholds](REFERENCE.md#interaction-timing-thresholds).

### Empty States

An empty state is a **first-run experience**, not an error. It's your chance to teach and motivate.

**Required elements:**
1. **Illustration or icon** — Visually confirms "you're in the right place, there's just nothing here yet"
2. **Descriptive text** — Explain what will appear here ("Your saved workouts will appear here")
3. **Primary CTA** — One clear action to create the first item ("Create your first workout")

**Anti-patterns:**
- Blank screen with no explanation
- "No data" with no action (dead end)
- Same empty state for "never used" vs "search returned nothing" (different intent = different message)

### Error States

**Conversational, not technical.** Users don't care about HTTP 500 or `NullPointerException`.

**Rules:**
1. **Say what happened** in human language: "We couldn't load your workouts" (not "Error: fetch failed")
2. **Say why** if known: "Your connection seems to be offline"
3. **Offer a recovery action**: "Tap to retry" button, or "Check your connection and try again"
4. **Don't blame the user**: "Something went wrong" not "You did something wrong"

| Error Type | Message Pattern | Action |
|-----------|----------------|--------|
| Network | "Couldn't connect. Check your connection." | Retry button |
| Server | "Something went wrong on our end." | Retry button + "Contact support" link |
| Not found | "This [item] may have been removed." | Go back / Go home |
| Permission | "You don't have access to this." | Request access / Go back |

### Success States

**Celebrate proportionally.** A saved form doesn't need confetti. A completed onboarding flow does.

| Action | Celebration Level | Pattern |
|--------|------------------|---------|
| Minor save/update | Subtle: checkmark animation, brief snackbar | Auto-dismiss in 2-4 seconds |
| Task completion | Moderate: success screen with "Next step" CTA | Show for 2-3 seconds, then transition |
| Major milestone (onboarding complete, first purchase) | High: illustration + congratulatory text + CTA | Dedicated success screen |

## Step 5: Form Design — 9 Rules for Mobile Forms

Mobile forms are where abandonment happens. Every unnecessary field, confusing label, or wrong keyboard is a potential drop-off.

### The 9 Rules

**1. Single column layout — always.**
Side-by-side fields on mobile force precision tapping on narrow targets. The only exception: short related fields (city + state, or first name + last name) where the visual grouping aids comprehension AND both fields are wide enough to meet tap target minimums.

**2. Labels above fields, not inside (not placeholder-as-label).**
**Why:** Placeholder text disappears on focus. The user types two characters, forgets what field they're in, has to delete to check. Floating labels (Material Design) solve this — the label animates above the field on focus.

**3. Inline validation — on blur, not on keystroke.**
**Why keystroke validation is hostile:** "Invalid email" appearing after typing `j` is noise. Validate when the user leaves the field (blur), not while they're still typing. Show errors below the field in red with a specific message ("Email must include @" not "Invalid input").

**4. Smart defaults — pre-fill what you can.**
- Country: from device locale
- Date: today's date if contextually appropriate
- Currency: from device region
- Toggles: the most common choice as default

**5. Progressive disclosure — show fields only when relevant.**
If a checkbox or dropdown selection determines whether 3 more fields are needed, hide those fields until the trigger is selected. Don't overwhelm with fields that may not apply.

**6. Correct keyboard type for every field.**
See [REFERENCE.md → Keyboard Types by Field](REFERENCE.md#keyboard-types-by-field). Using `TextInputType.emailAddress` for an email field gives the user `@` and `.` on the primary keyboard — one less tap per field.

**7. Clear CTAs — one primary action per form.**
"Submit" at the bottom, full width. If the form has "Save" and "Save & Continue," make one primary (filled) and the other secondary (outlined). Never two equally-styled buttons.

**8. Error recovery — don't clear the form.**
On submission error, preserve all input. Scroll to the first error field. Highlight what needs fixing. Never make the user re-enter valid data because one field failed.

**9. Minimize required fields.**
Every required field is friction. Ask: "Do we need this NOW, or can we ask later?" Collect the minimum at sign-up; enrich the profile progressively.

## Step 6: Onboarding Patterns

**The goal of onboarding is activation, not education.** Users don't want a tour — they want to do the thing they downloaded the app for.

### Decision Framework

| Approach | Use When | Avoid When |
|----------|----------|------------|
| **Progressive onboarding** (teach features in context as user encounters them) | Most apps — lowest friction, highest retention | The app's core mechanic is truly novel and unintuitable |
| **Benefits-focused walkthrough** (3-5 screens showing value propositions) | App Store screenshots don't convey the value; competitive market where differentiation matters | The value is obvious from the UI itself |
| **Interactive tutorial** (guided first-use with real actions) | Core interaction is gesture-heavy or non-obvious (e.g., a drawing app, novel input method) | The tutorial is longer than just using the app |
| **Coach marks / tooltips** (highlight specific UI elements) | 1-2 key features need attention in an otherwise standard UI | More than 3-4 coach marks (becomes a slide show) |

### Rules

1. **Maximum 3–5 onboarding steps.** Each step beyond 5 loses ~20% of users. If your onboarding needs more steps, your app is too complex for first use.
2. **Always offer skip.** Forcing onboarding punishes returning users and power users. "Skip" should be visible, not a tiny "X" in the corner.
3. **Show a progress indicator.** "Step 2 of 4" reduces anxiety. Unknown length = user assumes it's endless.
4. **Ask permissions in context, not upfront.** Don't batch-request camera + location + notifications on first launch. Ask for camera when the user tries to take a photo. Ask for notifications when they enable reminders. Contextual requests have 2–3× higher grant rates.
5. **Benefits before features.** "Get feedback on your technique" (benefit) > "Our AI analyzes 17 joint angles" (feature). Users care about outcomes.
6. **Personalization as onboarding.** If you can ask 2-3 questions that meaningfully customize the experience ("What's your fitness level?" → adapted difficulty), the onboarding itself delivers value.

## Step 7: Micro-Interaction Timing

**Timing is the difference between "snappy" and "sluggish."** The same animation at 150ms feels responsive; at 500ms it feels laggy.

### Core Timing Thresholds

| Threshold | Perception | Design Response |
|-----------|-----------|-----------------|
| <100ms | **Instant** — user feels direct manipulation | No feedback needed; the result IS the feedback |
| 100–300ms | **Fast** — noticeable delay but feels responsive | Use for transitions, state changes, button feedback |
| 300ms–1s | **Perceptible delay** — needs acknowledgment | Show immediate visual change (color, animation start) |
| 1–10s | **Waiting** — user's attention may wander | Show spinner or progress indicator |
| >10s | **Long wait** — user may abandon | Show percentage progress, estimated time, or allow backgrounding |

See [REFERENCE.md → Interaction Timing Thresholds](REFERENCE.md#interaction-timing-thresholds) for specific animation durations.

### Animation Purpose Framework

**Every animation must serve a purpose.** If you can't identify which of these it serves, remove it.

| Purpose | Example | Duration |
|---------|---------|----------|
| **Feedback** — "I received your input" | Button press scale, checkbox fill | 50–100ms |
| **Orientation** — "Here's where you are now" | Page transitions, navigation slides | 200–300ms |
| **Connection** — "These things are related" | Shared element transitions, hero animations | 250–350ms |
| **Celebration** — "You accomplished something" | Confetti, checkmark drawing, success burst | 300–600ms |
| **Attention** — "Look at this" | Subtle pulse, badge bounce | 200–400ms, then stop (never loop indefinitely) |

### Easing Curves

| Curve | Use For | Why |
|-------|---------|-----|
| **ease-out** (decelerate) | Elements entering the screen | Fast start = responsive; slow end = smooth landing |
| **ease-in** (accelerate) | Elements leaving the screen | Slow start = user can track; fast exit = gets out of the way |
| **ease-in-out** | Elements changing position on screen | Natural arc of physical motion |
| **linear** | Progress bars, color fades | Constant rate feels correct for measured progress |
| **spring** | Playful / energetic UIs, bouncing elements | Overshoot + settle feels alive — use sparingly |

## Step 8: Gesture Design

**Rule zero: Gestures are accelerators, never the sole path.** Every gesture-triggered action MUST have a visible UI alternative (button, menu item). Gestures are invisible — users can't discover what they can't see.

### Gesture Hierarchy

| Gesture | Discoverability | Use For | Always Pair With |
|---------|----------------|---------|-----------------|
| **Tap** | High (buttons are visible) | Primary actions | N/A — tap IS the visible path |
| **Long press** | Medium (conventions exist) | Context menus, selection mode | Visual cue after 200ms (haptic + highlight) |
| **Swipe horizontal** | Medium (list conventions) | Delete/archive on list items, page navigation | Undo snackbar for destructive swipes |
| **Swipe vertical** | High (scroll is natural) | Pull-to-refresh, dismiss bottom sheet | Refresh indicator animation |
| **Pinch** | Low (no visual cue) | Zoom on images/maps | Zoom controls (+/- buttons) |
| **Double tap** | Low (no visual cue) | Zoom, like/favorite | Button alternative |
| **Drag** | Low (needs affordance) | Reorder lists, move elements | Drag handle icon (≡), or "Edit" mode |

### Discoverability Techniques

**Problem:** Swipe-to-delete on a list item is invisible to new users.

**Solutions (choose one):**
1. **Peek on first use:** Slightly offset the first list item to reveal the swipe action, then animate it back. One-time tutorial that's part of the UI.
2. **Coach mark:** Tooltip saying "Swipe left to delete" on first encounter. Self-dismissing after user performs the action.
3. **Contextual hint:** After the user long-presses (suggesting they're looking for actions), show a toast: "Tip: you can also swipe to delete."

### Gesture Conflict Prevention

| Conflict | Solution |
|----------|----------|
| Horizontal swipe vs. horizontal scroll | Swipe actions on vertical lists only; disable on horizontally scrollable content |
| Vertical swipe vs. pull-to-refresh | Pull-to-refresh only triggers when scrolled to top |
| Edge swipe (back) vs. drawer swipe | Drawer opens from hamburger tap only; edge swipe reserved for system back |
| Long press vs. drag | Long press activates selection; drag only starts AFTER selection mode is active |

**Decision:** When two gestures conflict on the same element, the more common/expected gesture wins. The less common gesture gets a button fallback. Never require the user to "figure out" the right gesture through trial and error.
