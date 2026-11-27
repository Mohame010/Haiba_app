---
trigger: always_on
---

# UI and UX Quality Rules (always on)

Goal: every screen feels calm, spacious, consistent and premium. Clarity beats decoration.

## Spacing and layout
- Use ONLY spacing tokens from the theme or core constants on a 4 dp grid (4, 8, 12, 16, 24, 32, 48). No magic numbers. If a token is missing, add it to core once.
- Screen horizontal padding 20 dp on phones (via token). Vertical rhythm: 24 between sections, 12 between related items, 8 inside a group.
- Cards and list rows: inner padding at least 16, tappable rows at least 56 high, 12 between cards.
- Content max width 560 dp, centered, on wide screens.
- One primary action per screen, placed in a fixed bottom action bar (SafeArea, 16 padding) with scrollable content above it. It never floats over content and is never hidden by the keyboard.
- Group related information into sections with a short title. Do not stack more than about 7 ungrouped elements.
- No walls of text: short sentences, about 60 characters per line at most, key facts as label and value rows.

## Hierarchy and typography
- At most 4 text styles per screen, all from the theme (title, section title, body, caption). Size and weight carry hierarchy, not color alone.
- Arabic text: line height 1.4 to 1.6, no letter spacing, no italics. Never truncate names, numbers or codes the user must read; let them wrap. Ellipsis only for secondary text inside lists.
- Digits and codes (phone, registration number, challenge code, OTP) render LTR inside RTL layouts and are visually distinct (larger, medium weight, selectable where useful).

## Components and consistency
- Reuse shared widgets from core/widgets (buttons, text fields, section card, empty state, error state with retry, status banner, loading skeleton). If one is missing, create it once in core and reuse it. Never restyle per feature.
- One corner radius family and one elevation level per component type. The same component looks the same everywhere.
- Icons always have a text label or a Semantics label. Status is never conveyed by color alone (add an icon and text).
- Destructive or irreversible actions look distinct (secondary or error styling), are separated from the primary action, and are confirmed in a dialog that restates the consequence.

## States and feedback
- Every screen has a designed loading state (skeleton or inline progress, not a lone spinner on a blank page), empty state (icon, one sentence, an action), error state (plain-language cause and a retry action) and offline state.
- Respond to every tap within 100 ms: pressed state, then progress. Disable a button only with a visible reason (helper text under it). Never leave a dead control unexplained.
- Messages say what happened and what to do next, in a respectful tone. No technical codes, no blame.
- Success is confirmed briefly (snackbar or inline state), not with blocking dialogs.

## Motion and touch
- Transitions 200 to 300 ms with standard easing. No decorative or looping animation. Respect the system reduce-motion setting.
- Touch targets at least 48 x 48 dp with 8 dp between neighbors. Primary actions sit within thumb reach (bottom of the screen).
- Forms: one column, labels always visible (not only hints), the right keyboard type, next and done actions, inline validation after the field loses focus, never before.

## Verification
- When finishing a screen, check it at 360 x 640, at 2.0 text scale, in Arabic RTL and English LTR, and with the keyboard open, and state what you checked. If the primary action needs more than one scroll on a small phone, justify it or restructure.