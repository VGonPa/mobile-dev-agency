# Mobile UX Patterns — Reference Tables

Lookup tables and specific values for patterns described in [SKILL.md](SKILL.md). Don't implement from these tables alone — read the decision context in SKILL.md first.

## Thumb Zone Pixel Ranges

Measured from bottom-left corner of screen. Values are approximate — based on ergonomic studies of typical adult hand grip. Left-handed users mirror horizontally.

### Small Phone (≤5.4", e.g., iPhone SE / mini)

| Zone | Area (from bottom) | Notes |
|------|-------------------|-------|
| **Natural** (easy) | Bottom 0–200pt, center 60% width | Comfortable thumb arc without grip shift |
| **Stretch** (ok) | 200–400pt height, full width; bottom edges | Reachable with slight thumb extension |
| **Hard** (avoid) | Above 400pt, especially top corners | Requires grip shift or second hand |

### Standard Phone (5.5–6.1", e.g., iPhone 15 / Pixel 8)

| Zone | Area (from bottom) | Notes |
|------|-------------------|-------|
| **Natural** | Bottom 0–250pt, center 60% width | Primary action zone |
| **Stretch** | 250–500pt height, full width; bottom edges | Content reading zone |
| **Hard** | Above 500pt, especially top corners | Status bar, navigation titles |

### Large Phone (6.2–6.9", e.g., iPhone Pro Max / Pixel Pro)

| Zone | Area (from bottom) | Notes |
|------|-------------------|-------|
| **Natural** | Bottom 0–220pt, center 50% width | Narrower natural zone due to wider device |
| **Stretch** | 220–480pt height, full width | Majority of content area |
| **Hard** | Above 480pt, plus far edges at any height | Top bar AND side edges are hard to reach |

### Design Implications by Device Size

| Element | Small Phone | Standard Phone | Large Phone |
|---------|------------|----------------|-------------|
| Bottom nav height | 49pt (iOS) / 56dp (Android) | Same | 56dp+ (consider extra padding) |
| FAB position | 16pt from bottom-right edge | 16dp from edges | 24dp from edges (keep in natural zone) |
| Primary CTA | Full width, 16pt side margins | Full width, 16–24dp margins | Max width 600dp, centered |
| Top bar action buttons | 44×44pt minimum | 48×48dp minimum | 48×48dp, extra spacing between |

## Tap Target Sizes

### Platform Minimums (Non-Negotiable)

| Platform | Minimum Target Size | Minimum Spacing | Source |
|----------|-------------------|-----------------|--------|
| iOS | 44×44pt | 8pt between targets | Apple Human Interface Guidelines |
| Android | 48×48dp | 8dp between targets | Material Design Guidelines |
| WCAG 2.2 AAA | 44×44 CSS px | — | W3C Target Size Enhanced |
| WCAG 2.2 AA | 24×24 CSS px | — | W3C Target Size Minimum |

### Recommended Sizes by Element

| Element | Minimum | Recommended | Notes |
|---------|---------|-------------|-------|
| Icon button | 44pt/48dp | 48pt/48dp | Visual icon can be smaller; tap area must meet minimum |
| Text button | 44pt height | 48pt height, 16pt padding | Width determined by text + padding |
| List row | 44pt height | 56–72dp height | Taller rows for content with subtitle |
| Checkbox / Radio | 44pt touch area | 48dp touch area | Visual element is 18-24dp; padding fills touch target |
| Slider thumb | 44pt touch area | 48dp touch area | Visual thumb is ~20dp; touch area extends beyond |
| Close / dismiss "X" | 44×44pt | 48×48dp | Often made too small — users rage-tap this |
| Stepper (+/-) | 44pt per button | 48dp per button | Each button independently meets minimum |

## Interaction Timing Thresholds

### Response Time Budgets

| Duration | User Perception | Required Feedback | Example |
|----------|----------------|-------------------|---------|
| 0–100ms | Instant | None — direct manipulation feel | Tap highlight, toggle switch, checkbox |
| 100–300ms | Fast but noticeable | Subtle transition or state change | Navigation animation, dropdown open |
| 300ms–1s | Noticeable delay | Immediate visual acknowledgment | Button loading state, inline spinner |
| 1–5s | Significant wait | Progress indicator (spinner) | API call, image upload |
| 5–10s | Long wait | Determinate progress bar if possible | File processing, batch operations |
| 10–30s | Very long wait | Percentage progress + estimated time | Large file upload, data sync |
| >30s | Background task | Allow backgrounding + notification on complete | Video processing, bulk import |

### Animation Duration Guide

| Animation Type | Duration | Easing | Notes |
|---------------|----------|--------|-------|
| Button feedback (press/release) | 50–100ms | ease-out | Must feel instant — longer feels laggy |
| Ripple effect (Material) | 200–300ms | ease-out | Expanding circle from touch point |
| Fade in/out | 150–250ms | ease-in-out | Simple opacity transitions |
| Slide transition (navigation) | 250–350ms | ease-in-out | iOS: 350ms default; Material: 300ms |
| Bottom sheet appear | 200–300ms | ease-out (decelerate) | Slides up from bottom edge |
| Bottom sheet dismiss | 150–250ms | ease-in (accelerate) | Faster exit than entrance |
| Shared element / hero | 300–400ms | ease-in-out | Complex transitions need more time |
| Skeleton shimmer cycle | 1000–1500ms | linear | One full sweep; loop continuously |
| Snackbar appear | 150–200ms | ease-out | Slides up from bottom |
| Snackbar auto-dismiss | After 4–8s | — | 4s for short text; 8s if action button |
| Toast auto-dismiss | After 2–3.5s | — | Informational only, no action |
| Celebration animation | 400–800ms | spring / ease-out | Confetti, checkmark draw, burst |
| Collapse / expand | 200–300ms | ease-in-out | Accordion, expandable card |
| Drag reorder | Real-time | — | Follow finger with no delay |

### Debounce & Throttle Timings

| Interaction | Timing | Why |
|-------------|--------|-----|
| Search-as-you-type | 300ms debounce | Waits for typing pause; avoids firing on every keystroke |
| Scroll event listeners | 16ms throttle (~60fps) | Matches screen refresh rate |
| Resize / orientation | 150ms debounce | Waits for rotation animation to complete |
| Button double-tap prevention | 300ms throttle | Prevents accidental double-submission |
| Pull-to-refresh cooldown | 1000ms throttle | Prevents accidental rapid re-fetches |

## Keyboard Types by Field

Using the correct keyboard type reduces taps-per-field by surfacing relevant keys.

### Flutter `TextInputType` Mapping

| Field Type | TextInputType | Keyboard Shows | Notes |
|-----------|---------------|----------------|-------|
| Email | `emailAddress` | `@` and `.` on primary keyboard | No auto-capitalize |
| Password | `visiblePassword` | Standard + toggle visibility | Pair with `obscureText: true` |
| Phone | `phone` | Number pad + `+`, `-`, `*`, `#` | |
| Number (integer) | `number` | Number pad only | No decimal point |
| Number (decimal) | `numberWithOptions(decimal: true)` | Number pad + `.` | For prices, measurements |
| URL | `url` | `.com`, `/`, `.` on primary keyboard | No auto-capitalize |
| Multiline text | `multiline` | Standard + return key inserts newline | `maxLines` > 1 |
| Name | `name` | Standard + auto-capitalize words | |
| Street address | `streetAddress` | Standard | Enables address autofill |
| Search | `text` with `TextInputAction.search` | Standard + search icon on submit key | |

### Flutter `TextInputAction` (Submit Key Label)

| Action | Submit Key Shows | Use When |
|--------|-----------------|----------|
| `next` | "Next" / → arrow | Multi-field forms (moves focus to next field) |
| `done` | "Done" / ✓ | Last field in form (dismisses keyboard) |
| `search` | 🔍 | Search input fields |
| `send` | "Send" | Chat / messaging input |
| `go` | "Go" | URL input, navigation |
| `newline` | Return ↵ | Multiline text areas |

### iOS-Specific Keyboard Behaviors

| Behavior | Configuration | Notes |
|----------|--------------|-------|
| Auto-capitalize sentences | `TextCapitalization.sentences` | Default for most text fields |
| Auto-capitalize words | `TextCapitalization.words` | Names, titles |
| No auto-capitalize | `TextCapitalization.none` | Email, username, URL |
| Auto-correct | `autocorrect: true` (default) | Disable for emails, usernames, codes |
| Secure text entry | `obscureText: true` | Passwords — also disables autocorrect |

## Navigation Pattern Quick Reference

### Bottom Tab Bar Specs

| Property | iOS (HIG) | Android (Material 3) |
|----------|-----------|---------------------|
| Height | 49pt (83pt with home indicator) | 80dp |
| Max items | 5 | 5 |
| Min items | 3 | 3 |
| Icon size | 25×25pt | 24×24dp |
| Label | Required | Required |
| Active indicator | Tinted icon + label | Pill-shaped indicator behind icon |
| Badge | Red dot or count | Small/large badge on icon |

### Bottom Sheet Specs

| Property | Value | Notes |
|----------|-------|-------|
| Corner radius | 12–16dp | Top corners only |
| Max height | 90% of screen | Leave status bar visible |
| Drag handle | Centered, 32×4dp, rounded | Visual affordance for dismiss gesture |
| Peek height (persistent) | ~25% of screen | Shows first action or summary |
| Scrim opacity | 32% black | Modal sheets only |
| Dismiss gestures | Swipe down, tap scrim | Both required for modal sheets |

### Drawer / Navigation Drawer Specs

| Property | Value | Notes |
|----------|-------|-------|
| Width | 256–320dp (Material), ≤80% screen width | Never full-width (user loses context) |
| Item height | 56dp | Meets tap target minimum |
| Section divider | 1dp + 16dp padding | Groups related items |
| Active item | Filled indicator + tinted icon/label | Clear "you are here" |
| Opening gesture | Hamburger tap (preferred) | Edge-swipe conflicts with system back on Android |

## Screen State Checklist

Use this to audit every screen in your app.

| State | Required Elements | Common Mistakes |
|-------|------------------|-----------------|
| **Loading** | Skeleton matching layout OR spinner with label | Spinner with no context; full-screen blank |
| **Empty (first use)** | Illustration + explanation + primary CTA | "No data" text only; missing CTA |
| **Empty (search/filter)** | "No results for X" + suggestion to adjust | Generic "No results" with no guidance |
| **Error (network)** | Human message + retry button | Technical error codes; no retry option |
| **Error (server)** | Human message + retry + support link | "Error 500" |
| **Error (not found)** | Explanation + navigation back/home | Blank screen or crash |
| **Partial** | Available data shown + indicator of what's missing | All-or-nothing (hide everything if one call fails) |
| **Success** | Proportional feedback (see SKILL.md Step 4) | No feedback at all; over-the-top celebration for minor actions |

## Form Field Validation Patterns

### Validation Timing

| Event | Validate? | Show Error? | Why |
|-------|-----------|------------|-----|
| On keystroke | No | No | Premature — user is still typing |
| On blur (field loses focus) | Yes | Yes, if invalid | User finished with this field |
| On focus (re-entering errored field) | Keep error visible | Yes, update live | User is trying to fix it — help them |
| On submit | All fields | All errors at once | Final validation before API call |
| After server error | Specific fields | Scroll to first error | Preserve all valid input |

### Common Validation Messages

| Field | Bad Message | Good Message |
|-------|------------|--------------|
| Email | "Invalid input" | "Enter a valid email address (e.g., name@example.com)" |
| Password | "Too weak" | "Password needs at least 8 characters, including a number" |
| Phone | "Invalid phone" | "Enter a 10-digit phone number" |
| Required field | "Required" | "First name is required" (name the field) |
| Date | "Invalid date" | "Enter a date in MM/DD/YYYY format" |
| Number range | "Out of range" | "Enter a number between 1 and 100" |
