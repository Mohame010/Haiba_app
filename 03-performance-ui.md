---
trigger: always_on
---

# Memory, Performance and Responsive UI (always on)

## Memory and Performance (YOU MUST FOLLOW)

## Memory leaks: dispose everything you create
- `TextEditingController`, `ScrollController`, `FocusNode`, `AnimationController`, `TabController`, `PageController`: created in `initState`, disposed in `dispose()`.
- `StreamSubscription`, `Timer`, `ChangeNotifier`/`ValueNotifier` listeners: cancelled/removed in `dispose()` (or `Cubit.close()`).
- Cubits that own subscriptions override `close()` to cancel them before `super.close()`.
- Supabase Realtime channels: unsubscribe/remove when the screen or Cubit closes. Prefer fewer, scoped channels. Do not subscribe if a simple refetch is enough.
- Never capture `BuildContext`/widgets in long-lived closures, singletons, or static fields.
- Do not keep large objects (images, `Uint8List`, full result sets) in Cubit state. Keep paths/IDs and load on demand.
- Delete temp files (picked/compressed images) after a successful upload.
- Long-lived `get_it` singletons hold no screen-specific data.

## Performance
- Lists: `ListView.builder` / `SliverList` (lazy). Never `Column` inside `SingleChildScrollView` for unbounded data. Never `shrinkWrap: true` on long lists. Paginate (infinite scroll, keyset).
- Provide stable `key`s / `itemExtent` where it helps. Avoid rebuilding whole lists for one item change (`buildWhen`, `BlocSelector`, per-item widgets).
- Images: always bound decode size (`cacheWidth`/`cacheHeight` or `memCacheWidth`), use `cached_network_image`, compress before upload (≤ ~1600px / ~500KB JPEG). Never load full-resolution images into lists.
- Heavy CPU work (image processing, big JSON parsing, sorting large lists) goes to an isolate (`compute` / `Isolate.run`), never the UI thread.
- Debounce search/typing (≥ 300 ms) and cancel stale requests. No request per keystroke.
- No `Opacity`/`ClipRRect`/`saveLayer`-heavy widgets inside scrolling lists. Add `RepaintBoundary` only after measuring, not by default.
- Avoid unbounded animations; stop them when off-screen.
- Network: no N+1 queries. Fetch related data with one query/RPC. Select only needed columns. Cache lookups (governorates, universities, branches) in memory.
- Startup: initialize only what the first screen needs; defer the rest (Firebase extras, lookups) after first frame.
- Keep release builds in mind: no `print`/`debugPrint` of data, no debug-only work on hot paths. Profile in `--profile` mode on a low-end Android device when changing hot paths.
- If you suspect a perf or leak issue you cannot verify, say so explicitly and suggest the DevTools check (Memory / Performance / Widget rebuild counts).

---

## Responsive UI and Overflow (YOU MUST FOLLOW)

- Overflow is a bug. No yellow/black "RenderFlex overflowed" stripes at any supported size.
- Design for small phones first (≈ 360×640), then scale up to large phones and tablets. Do not hardcode device sizes.
- Use `LayoutBuilder` / `MediaQuery.sizeOf(context)` (not `MediaQuery.of`) for breakpoints; keep breakpoints in `core/`. Content max-width on wide screens.
- Never use fixed heights/widths for containers holding text. Use `Flexible`/`Expanded`, `ConstrainedBox`, intrinsic sizing, `Wrap`.
- Text: must survive system font scale up to 2.0 and long Arabic strings. Use `maxLines` + `overflow: TextOverflow.ellipsis` for list/card text; allow wrapping elsewhere. Never clamp text scale to hide a layout problem.
- Forms and screens with inputs: scrollable body (`SingleChildScrollView`/`CustomScrollView`), `resizeToAvoidBottomInset` handled, keyboard never covers the focused field or primary button.
- Wrap screens in `SafeArea`; respect notches, gesture bars and cutouts. Edge-to-edge aware.
- Tap targets ≥ 48×48 dp. Sufficient contrast. Add `Semantics`/tooltips on icon-only buttons.
- Orientation: either support it properly or lock deliberately; do not leave it half-broken.
- Verify visually (or by reasoning) for: small phone, large text scale, RTL (Arabic), LTR (English), keyboard open, and dark mode if supported. State which ones you checked.
- Use theme tokens (`ThemeData`, `ColorScheme`, shared spacing constants). No scattered magic numbers or hardcoded colors.

---
