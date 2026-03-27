---
name: mobile-design-review
description: Use when evaluating mockups or screenshots before development, reviewing implemented screens against design specs, auditing design system compliance, checking WCAG accessibility, doing pre-release design QA, or reviewing AI-generated designs for generic patterns. Covers usability heuristics, accessibility, visual consistency, platform correctness, and anti-slop detection.
user-invocable: true
---

# Mobile Design Review

## Overview

A systematic design quality gate that audits mobile screens for usability, accessibility, visual consistency, platform correctness, and generic AI aesthetics. Good mobile design removes friction so the user's intent flows into action without thought — this skill catches what eyes glazing over a Figma file will miss.

> **Common Mistakes This Skill Catches**
>
> - Empty states that say "No data" instead of guiding the user toward their first action
> - Tap targets at 36dp that work for your thumb but fail for 40% of users (WCAG minimum: 44pt/48dp)
> - Error states that show a raw HTTP status code instead of a human sentence
> - Purple-to-blue gradients and glassmorphism that scream "AI generated this"
> - iOS screens with Material bottom navigation bars (or Android screens with iOS-style back swipes and no Up arrow)
> - Loading states that block the entire screen instead of showing skeleton placeholders
> - Identical spacing everywhere because the designer eyeballed it instead of using a spacing scale

## When to Use This Skill

- Reviewing a mockup or screenshot before development starts
- Auditing an implemented screen against its design spec
- Pre-release design QA pass
- Evaluating whether a screen meets accessibility standards
- Checking that a design feels native on its target platform
- Reviewing AI-generated designs for generic/slop patterns

## When NOT to Use This Skill

This skill covers **visual and interaction design of mobile screens**. It does NOT cover:

- **Code quality** — widget tree structure, state management patterns, render performance profiling
- **Backend API design** — endpoint naming, payload structure, error response formats
- **Brand strategy** — logo design, brand voice, marketing copy tone
- **Motion design specification** — detailed animation curves, keyframe timing, Lottie/Rive authoring
- **Design system creation** — building a token system from scratch (this skill audits against an existing one)

---

## Step 1: Nielsen's 10 Heuristics Audit

**Why this comes first:** Heuristics catch fundamental usability failures that no amount of visual polish can fix. A beautiful screen that violates "User Control and Freedom" will frustrate users regardless of its color palette.

Audit each screen against all 10 heuristics. For each, ask the specific question and look for the mobile-specific failure mode.

### Heuristic Checklist

| # | Heuristic | Question to Ask | Mobile Failure Mode | Pass Criteria |
|---|-----------|----------------|---------------------|---------------|
| 1 | **Visibility of System Status** | Does the user know what's happening right now? | No loading indicator during network calls. Pull-to-refresh with no feedback. Upload progress absent. | Every action that takes >300ms shows progress. Real-time feedback for gestures. |
| 2 | **Match Between System and Real World** | Would a non-technical user understand every label? | Developer jargon in UI ("null", "404", "sync failed", "invalid payload"). Dates in ISO format. | All copy uses the user's language. Dates localized. Icons match real-world metaphors. |
| 3 | **User Control and Freedom** | Can the user undo, go back, or escape from any state? | No back button. Destructive action without confirmation. Modal with no dismiss. Swipe-to-delete without undo. | Every destructive action is reversible or confirmed. Every modal is dismissible. Back always works. |
| 4 | **Consistency and Standards** | Does this screen work like other screens in the app? | Mixed button styles. Inconsistent icon meanings. Different navigation patterns across sections. | Same action = same pattern everywhere. Follows platform conventions. |
| 5 | **Error Prevention** | Does the design prevent mistakes before they happen? | No input validation until submit. Dangerous actions (delete account) in easy-to-tap locations. No confirmation for irreversible actions. | Inline validation. Destructive actions require deliberate interaction (not single tap). Disabled states for invalid forms. |
| 6 | **Recognition Rather Than Recall** | Can the user see everything they need, or must they remember? | Search with no recent/suggested items. Settings buried behind memorized navigation paths. Form that clears on back navigation. | Options visible. Recent items surfaced. Form state preserved on navigation. |
| 7 | **Flexibility and Efficiency of Use** | Can experienced users move faster? | No shortcuts. No gesture support. Forced multi-step flows for frequent actions. | Swipe gestures for common actions. Long-press context menus. Skip/shortcut options for repeated flows. |
| 8 | **Aesthetic and Minimalist Design** | Is every element earning its screen space? | Cluttered screens. Redundant text. Decorative elements that push content below fold. | Every element serves a purpose. Primary action is visually dominant. Content above fold. |
| 9 | **Help Users Recognize, Diagnose, and Recover from Errors** | Do error messages tell the user what happened AND what to do? | "Error occurred". "Something went wrong". Technical stack traces. | Error messages have: (1) what happened in plain language, (2) what to do next, (3) a recovery action (retry button, contact support link). |
| 10 | **Help and Documentation** | Can the user get help without leaving the flow? | No onboarding. No tooltips. Help section is a link to a website. | Contextual help (tooltips, inline hints). First-run onboarding for complex features. In-app help accessible from the screen where it's needed. |

**Severity rating:** For each violation found, rate as:
- **Critical** — User cannot complete their task
- **Major** — User can complete but with significant frustration or errors
- **Minor** — Cosmetic or efficiency issue, does not block task completion

---

## Step 2: WCAG 2.2 Mobile Accessibility Checklist

**Why this matters:** 15-20% of the global population has some form of disability. Accessibility isn't a feature — it's a baseline. On mobile, the stakes are higher because the interaction surface is smaller and more constrained. This checklist targets WCAG 2.2 Level AA compliance.

### Tap Targets

| Check | Pass Criteria | Why This Specific Number |
|-------|---------------|--------------------------|
| Minimum tap target size | **44pt (iOS) / 48dp (Android)** | Apple HIG and Material Design spec. Below this, error rates increase 30-50% for average fingers. |
| Spacing between tap targets | **Minimum 8dp between adjacent targets** | Prevents accidental taps on neighboring elements. Critical for motor impairments. |
| Touch target includes padding | Tap area extends beyond visible element if needed | A 24dp icon can have a 48dp tap target via padding. Visually small is fine; functionally small is not. |

**Common failures:**
- Icon buttons at 24dp with no padding (actual tap target = 24dp)
- List items with multiple actions crammed into a single row
- Close/dismiss buttons in modal corners at 32dp

### Color and Contrast

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Text contrast ratio | **4.5:1 minimum** (normal text), **3:1** (large text ≥18pt / 14pt bold) | Light gray text (#999) on white (#FFF) = 2.85:1. Fails. |
| Non-text contrast | **3:1 for UI components** (icons, borders, focus indicators) | Light blue toggle on white background |
| No color-only information | Color is never the SOLE indicator of state | Red/green status dots with no icon or label. Fails for 8% of males (color blind). |
| Dark mode contrast | Same ratios apply in dark mode | White text on dark gray that looks fine on your screen but fails on low-brightness OLED |

**How to verify:** Use a contrast checker (WebAIM, Stark) on every text/background combination. Don't eyeball it.

### Screen Reader and Focus

| Check | Pass Criteria |
|-------|---------------|
| Reading order | Screen reader traverses elements in logical order (not visual layout order if they differ) |
| Content labels | All interactive elements have accessible labels. Icons without text have `semanticLabel` / `contentDescription`. |
| Focus indicators | Visible focus ring on all interactive elements when navigating via keyboard/switch |
| State announcements | Toasts, snackbars, and dynamic content changes are announced to screen readers |
| Heading hierarchy | Screen uses heading levels (H1, H2, etc.) so screen reader users can navigate by section |

### Motion and Animation

| Check | Pass Criteria |
|-------|---------------|
| Reduced motion support | Respects `prefers-reduced-motion` / `AccessibilityFeatures.reduceMotion`. Disables parallax, auto-play, and complex transitions. |
| No auto-playing media | Video/audio does not auto-play with sound. Users with vestibular disorders need control. |
| Flashing content | Nothing flashes more than 3 times per second (seizure risk) |

### Text Resizing and Reflow

| Check | Pass Criteria |
|-------|---------------|
| Text scaling | Layout survives **200% text scale factor** without overflow, truncation of essential content, or overlapping elements. Test with iOS Dynamic Type and Android font scale. |
| Reflow | Content reflows without horizontal scrolling at **320dp equivalent width** (WCAG 1.4.10). No two-dimensional scrolling for text content. |

### Pointer and Gesture Accessibility

| Check | Pass Criteria |
|-------|---------------|
| Pointer gestures (WCAG 2.5.1) | Any action requiring multi-point or path-based gestures (pinch, swipe, draw) has a **single-pointer alternative** (button, tap). |
| Pointer cancellation (WCAG 2.5.2) | Actions fire on **up-event** (finger lift), not down-event. User can abort by moving finger off target before releasing. |
| Dragging movements (WCAG 2.5.7) | Any drag operation (reorder, slider) has a non-dragging alternative (buttons, text input for precise values). |

---

## Step 3: Screen Completeness Audit

**Why this matters:** Designers and developers naturally focus on the "happy path" — the success state. But users spend significant time in loading, empty, and error states. If those states are undesigned, the app feels unfinished.

### The Four States Rule

Every data-driven screen MUST have all four states designed:

| State | What It Shows | Pass Criteria | Common Failure |
|-------|--------------|---------------|----------------|
| **Loading** | Content is being fetched | Skeleton placeholders matching content layout. NOT a centered spinner blocking the whole screen. | Full-screen CircularProgressIndicator with no content hint |
| **Empty** | No content exists yet | Illustration + explanation + primary CTA to create/add first item. Guides user toward value. | "No items" text centered on blank screen |
| **Error** | Something failed | Human-readable message + retry action + optional alternative path. See Step 1, Heuristic #9. | "Error: null" or a generic red banner |
| **Success / Populated** | Content loaded and displayed | Data renders correctly. Pagination/infinite scroll works. Pull-to-refresh available. | Only state that was actually designed |

### Navigation Completeness

| Check | Pass Criteria |
|-------|---------------|
| Back navigation | Every screen has a clear path back. Hardware/gesture back works correctly. No dead ends. |
| Deep link support | Key screens are reachable via URL/deep link. App handles cold start into a deep-linked screen (no crash, no blank state). |
| Landscape orientation | Either (a) layout adapts gracefully or (b) orientation is explicitly locked with good reason. Content doesn't overflow or get clipped. |
| Keyboard handling | Soft keyboard doesn't obscure the active input field. Screen scrolls or resizes. Dismiss keyboard on tap outside. "Next" key moves to next field. "Done" submits or dismisses. |
| Interruption recovery | App state survives: phone call, notification, app backgrounding, low memory kill + relaunch. Form data is not lost. |

---

## Step 4: Visual Consistency Audit

**Why this matters:** Inconsistency signals "no one is in charge of this product." Users don't consciously notice a consistent spacing scale, but they feel the quality difference. Visual consistency builds trust.

### Spacing

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Spacing from a defined scale | All spacing values come from a scale (e.g., 4, 8, 12, 16, 24, 32, 48) | Arbitrary values like 13dp, 17dp, 22dp |
| Consistent padding | Same type of container = same internal padding across screens | Card padding is 16dp on one screen, 12dp on another |
| Vertical rhythm | Text blocks and components follow a consistent vertical rhythm | Spacing between sections varies randomly |

### Typography

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Type scale defined | All text uses styles from a defined scale (H1-H6, body, caption, overline) | `fontSize: 15` hard-coded instead of using a text style |
| Max 2-3 font families | Heading font + body font (+ optional monospace) | Four different fonts on one screen |
| Line height appropriate | 1.4-1.6x for body text. 1.1-1.3x for headings. | Body text at 1.0 line height (cramped, hard to read) |
| Text truncation handled | Long text truncates with ellipsis or expands. Never overflows container. | Username overflows into next column. Price text wraps under product image. |

### Color

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Semantic color usage | Colors mapped to meaning: primary, secondary, error, success, warning, surface, onSurface | Using hex values directly (`Color(0xFF3B82F6)`) instead of theme colors |
| Limited palette | 1 primary + 1 secondary + neutrals + semantic states. Not a rainbow. | 7 different blues across the app, none from a palette |
| Dark mode parity | All screens work in dark mode. No white flashes. No invisible elements. | Hardcoded white backgrounds that don't adapt |

### Elevation and Depth

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Consistent elevation levels | Defined elevation scale (0, 1, 2, 4, 8, 16) applied consistently | Bottom sheet at elevation 6 on one screen, elevation 12 on another |
| Shadow direction consistent | All shadows cast in the same direction (typically down-right) | Mixed shadow directions suggesting multiple light sources |
| Elevation communicates hierarchy | Higher elements are interactive or overlaying. Static content is flat. | Flat buttons that look like they float. Cards with no elevation distinction from background. |

---

## Step 5: Anti-Slop Check

**Why this exists:** AI design tools produce recognizable visual patterns. These patterns aren't inherently bad — they're bad because they're generic. If your app looks like it was generated in 30 seconds, users assume it was built with the same care.

This check identifies AI-generated design hallmarks and generic aesthetic choices that signal "no human designer touched this."

### Visual Slop Indicators

| Indicator | What to Look For | Why It's a Problem | Fix |
|-----------|-----------------|-------------------|-----|
| **Purple gradients** | Purple-to-blue or purple-to-pink gradients as primary brand color | The most common AI-generated color choice. Instantly recognizable as default. | Choose a brand color with intent. If purple is genuinely your brand, ensure it's a specific shade with meaning, not a generic gradient. |
| **Generic fonts** | System defaults (San Francisco, Roboto) used as display/heading fonts without intentional typographic hierarchy | Not wrong per se, but combined with other slop signals, it screams "default." | If using system fonts, make the hierarchy sharp: weight, size, and spacing must be deliberate. Or choose a distinctive heading font. |
| **Unnamed colors** | Colors with no semantic name. Multiple similar-but-different blues. No defined palette. | Signals no design system exists. The app will drift visually over time. | Every color in the app should have a name and a role. "Primary," "error," "surfaceVariant" — not `#3B82F6`. |
| **Raw icon defaults** | Material Icons or SF Symbols used at default size (24dp) with default weight, no customization | Default icons look like a prototype, not a product. | Size, weight, and optical alignment should be intentional. Consider icon sets that match your brand. |
| **Technical error text** | "Error: Exception" or "null" visible in the UI | Developer text leaked into production. | Every error string must be human-written, stored in a localization file, never raw from a catch block. |
| **Symmetrical grid worship** | Everything perfectly centered. Equal spacing everywhere. No visual hierarchy. | Real design uses asymmetry to create focus. Perfect symmetry makes everything equally unimportant. | Lead the eye. One element should dominate. Use whitespace asymmetrically to create breathing room and focus. |
| **Stock photography** | Generic diverse-team-in-office-smiling photos | Users recognize stock instantly. It erodes trust. | Use illustrations, product screenshots, or real photography. If stock is necessary, choose editorial-style over corporate-posed. |
| **Gratuitous blur/glass** | Frosted glass effects on every surface | Was trendy in 2022. Now signals "AI-generated mockup." | Use blur sparingly and with purpose (e.g., behind modals to focus attention). Not as a surface treatment. |
| **Oversized border radius** | 20-30dp radius on every element. Buttons, cards, inputs all look like pills/bubbles. | Uniform rounding removes visual hierarchy and feels toy-like. | Use your design system's radius scale. Different element types deserve different radii (e.g., 8dp for cards, 4dp for inputs, 20dp only for pills/chips). |
| **Corporate Memphis illustrations** | Flat vector characters with disproportionate limbs and solid colors in empty states and onboarding | The most recognizable "AI/tech startup" illustration style. Users associate it with generic products. | Commission custom illustrations or use a distinctive style that matches your brand. If budget is limited, well-chosen photography or simple iconography beats generic vectors. |

### The Litmus Test

Ask: **"If I showed this screen to someone with no context, could they name three other apps that look exactly like this?"**

If yes, the design lacks distinctiveness. That doesn't mean it's unusable — it means it's forgettable.

---

## Step 6: Platform Appropriateness

**Why this matters:** Users develop muscle memory for their platform. An iOS user expects swipe-to-go-back. An Android user expects a system back button/gesture. Violating these expectations creates friction that users feel but can't articulate — they just say "it feels weird."

### iOS Native Feel

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Navigation | Large title → small title scroll behavior. Swipe-from-left-edge to go back. No Up arrow. | Android-style top app bar with hamburger menu and Up arrow |
| Tab bar | Bottom tab bar with 2-5 items. Labels below icons. No FAB. | Material Bottom Navigation with FAB center cutout |
| Modals | Sheet-style modals (drag to dismiss). Action sheets from bottom. | Material dialogs (centered rectangles with flat buttons) |
| Controls | iOS-style toggles (green/gray). Segmented controls for mode switching. | Material switches with thumb track. Material chips for mode selection. |
| Typography | SF Pro (system font). 17pt body default. Bold headlines. | Roboto. 14sp body. Thin headlines. |
| Haptics | Light impact on tab switch. Medium impact on toggle. Notification feedback on success/error. | No haptic feedback anywhere. Or Android-style vibration patterns. |

### Android Material 3 Feel

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Navigation | Top app bar with Up arrow. Navigation drawer or bottom nav. System back gesture/button works. | iOS-style large title headers. No Up arrow. |
| FAB | Floating Action Button for primary screen action (if applicable). FAB position consistent. | iOS-style inline buttons for primary actions. |
| Components | Material 3 components: filled buttons, outlined text fields, cards with rounded corners (12-16dp). | iOS-style components: borderless text fields, flat buttons, sharp corners. |
| Dynamic Color | Supports Material You dynamic color (Android 12+). Falls back to brand theme gracefully. | Ignores system color completely. Hard-coded palette with no dynamic support. |
| Typography | Roboto (system font). Type scale follows M3 spec (display, headline, title, body, label). | SF Pro. Non-standard type scale. |
| Elevation | Tonal elevation (surface tint) over drop shadows for M3. | Heavy drop shadows everywhere (Material 2 style). |

### Cross-Platform Decision

| Check | Pass Criteria |
|-------|---------------|
| Navigation model matches platform | iOS uses tab bar. Android uses bottom nav or nav drawer. Not the same component styled differently — structurally different. |
| Back behavior is platform-correct | iOS: swipe from left edge. Android: system back button/gesture. Both must work. Neither should exist on the wrong platform. |
| Adaptive vs identical | If shipping one design for both platforms: document the tradeoffs explicitly. Know which platform you're favoring and why. |

---

## Step 7: Delight Audit

**Why this matters:** Functional correctness is table stakes. Users don't recommend apps that "work fine." They recommend apps that make them feel something — satisfaction, surprise, confidence. Delight is the difference between retention and churn.

Ask: **"Is this memorable or just functional?"**

### Micro-Interactions

| Check | Pass Criteria | Why It Matters |
|-------|---------------|----------------|
| Button feedback | Buttons respond visually on press (scale, color shift, ripple). Not just "tap and wait." | Confirms the user's action was received. Without it, users double-tap (causing bugs). |
| State transitions | Elements animate between states (e.g., heart icon fills with animation on like, not just swapping from outline to filled). | Smooth transitions feel intentional. Instant swaps feel broken. |
| Pull-to-refresh | Custom animation or brand-specific indicator, not just the default platform spinner. | A branded pull-to-refresh is a low-effort, high-impact delight moment. |
| Scroll behavior | Headers collapse/expand. Content parallax if appropriate. Scroll position remembered on return. | Smooth scrolling communicates performance and care. |

### Empty States

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Illustration quality | Custom illustration or animation, not a generic icon | A gray folder icon with "No files" text |
| Copy tone | Friendly, encouraging, specific to the context | "No data available." (robotic, unhelpful) |
| Action-oriented | CTA guides user to create their first item | Just text, no button, no guidance |
| Personality | Reflects brand voice. Makes the user smile or feel reassured. | Corporate boilerplate that could belong to any app |

### Transitions and Navigation

| Check | Pass Criteria |
|-------|---------------|
| Screen transitions | Screens enter/exit with appropriate motion (push, fade, slide). Not all the same. Not jarring. |
| Shared element transitions | When navigating from list → detail, the tapped element animates into position (hero animation). |
| Gesture feedback | Swipe actions have spring physics. Drag operations show visual feedback (shadow, scale). |
| Loading → content transition | Content fades in or skeleton morphs into real content. Not a hard cut from spinner to data. |

### Haptics

| Check | Pass Criteria | Platform |
|-------|---------------|----------|
| Selection feedback | Light haptic on tab switches, picker scrolls, toggle changes | iOS: `.light` impact. Android: `HapticFeedbackConstants.CLOCK_TICK` |
| Action confirmation | Medium haptic on successful actions (send, save, complete) | iOS: `.medium` impact. Android: `CONFIRM` |
| Error feedback | Notification-type haptic on errors, validation failures | iOS: `.error` notification. Android: `REJECT` |
| Overuse check | Haptics are NOT on every single tap. Only at meaningful moments. | Too much haptic = annoying, drains battery |

---

## Step 8: Performance Indicators

**Why this matters in a design review:** Performance is a design concern. A screen designed with a 40-item grid of full-resolution images is a design that will stutter. Catching these in design review is 10x cheaper than catching them in QA.

**Applicability:** This step applies to **implemented screens** (code review) and **detailed mockups with data specifications**. Skip for early-stage wireframes or screenshots where implementation details are not yet defined.

### Image Optimization

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Image sizing | Images requested at display size, not full resolution scaled down | Loading a 4000x3000 photo for a 120x120 avatar |
| Placeholder strategy | Blur hash, solid color, or skeleton while image loads. No layout shift when image arrives. | Empty space that jumps when image loads, pushing content down |
| Format appropriate | WebP/AVIF for photos. SVG for icons/illustrations. PNG only when transparency is needed at fixed size. | PNG photos at 2MB each. JPEG icons at 4x display size. |
| Lazy loading | Off-screen images load as user scrolls, not all at once on screen entry | 50 images start downloading when the screen opens |

### List and Grid Performance

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Virtualization | Lists with >20 items use virtualized/recycling list (e.g., `ListView.builder`, `SliverList`) | Rendering 500 list items in a `Column`/`SingleChildScrollView` (all in memory) |
| Item complexity | List items are flat (minimal nesting). No heavy computation per item. | Each list item contains a nested card with a gradient, shadow, blur, and a chart |
| Pagination | Infinite lists load in pages (20-50 items). Shows loading indicator at bottom. | Fetching all 10,000 items on first load |

### Rebuild and Rerender Awareness

| Check | Pass Criteria | Failure Example |
|-------|---------------|-----------------|
| Expensive widgets isolated | Heavy widgets (maps, charts, video players) don't rebuild when unrelated state changes | Typing in a text field causes the entire screen (including a map) to rebuild |
| Animations optimized | Animations use dedicated controllers, not rebuilding the whole widget tree every frame | `setState` called 60 times/second for an animation, rebuilding siblings |
| Static content marked | Content that never changes is marked as const/static/memoized | A static header rebuilds every time the list below it scrolls |

---

## Pre-Review Summary Template

After completing all 8 steps, summarize findings using this structure:

### Overall Verdict

**PASS** — Zero Critical issues. Ship with confidence (address Major/Minor in upcoming sprints).
**CONDITIONAL PASS** — Zero Critical issues, but 3+ Major issues that collectively degrade the experience. Ship only if timeline is immovable; fix Major issues in the next sprint.
**FAIL** — One or more Critical issues. Do not ship until all Critical issues are resolved and re-reviewed.

### Critical Issues (must fix before ship)
- [ ] *List issues that block task completion or violate accessibility law*

### Major Issues (fix in current sprint)
- [ ] *List issues that cause significant user frustration*

### Minor Issues (fix when possible)
- [ ] *List cosmetic or efficiency improvements*

### Delight Opportunities (consider adding)
- [ ] *List moments where delight could differentiate the product*

### What's Working Well
- *Acknowledge what's good. Design review isn't just about finding faults.*
