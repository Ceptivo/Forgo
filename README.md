# Forgo

Goal-based commitment app — stake money on a fitness/health goal, prove it with
an in-app photo/screenshot, keep your stake. Miss it, and 80% goes to charity.

Android-only v1, built with Flutter. See `docs/forgo-build-plan.md` for the
full product spec and build order.

## Status

Step 1 of the build order is done: email/password auth, an 18+ age gate at
signup, a profile screen backed by Supabase, and the bottom-nav app shell
(Home / Goals / Wallet / Profile) with placeholders for the tabs not built
yet. Everything is mobile-first and responsive across phone/tablet widths
(see `lib/core/responsive/responsive.dart`).

## Design system

Black canvas, violet accent, bento-grid dashboard — see
`lib/core/theme/app_theme.dart` and `lib/core/widgets/bento_grid.dart`.
There's no light theme; black is the brand, not a system-preference mode.

- **Colors** — `AppColors` in `app_theme.dart`: near-black surfaces on a
  pure black background, a violet accent (`#8B5CF6`) with a brighter glow
  variant for gradients, muted greys for secondary text.
- **Type** — Manrope, bundled locally as a variable font
  (`assets/fonts/Manrope-Variable.ttf`, registered per-weight in
  `pubspec.yaml`) rather than fetched from Google Fonts at runtime — one
  less network dependency on first launch.
- **Bento grid** — `BentoGrid`/`BentoCard`/`BentoGridItem` in
  `lib/core/widgets/bento_grid.dart` lay out unequal-sized cards (a full
  width hero, half-width stat tiles, taller cards) the way the Home
  dashboard does. `GlowBackground` adds the faint grid + soft violet glow
  backdrop behind hero content. Reuse these for new screens rather than
  hand-rolling another grid.

## Setup

1. **Flutter SDK** — this project targets the `stable` channel (3.35.x).
2. **Environment secrets** — copy `.env.example` to `.env` and fill in your
   Supabase project's URL and anon/publishable key:

   ```
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

   `.env` is gitignored — never commit real credentials. The anon key is
   safe for client-side use (it's the key Supabase designs for embedding in
   apps), but it's still kept out of source control for hygiene and so the
   service-role key never accidentally ends up here later.

3. **Database schema** — run `supabase/migrations/0001_profiles.sql` against
   your Supabase project (SQL Editor, or `supabase db push` if you use the
   CLI). This can't be applied from the app itself — the app only ever holds
   the anon key, which can't run DDL. The migration creates the `profiles`
   table, a trigger that populates it from signup metadata, row-level
   security policies so users can only read/write their own row, and a
   server-side `CHECK` constraint enforcing the 18+ minimum age as a
   backstop to the client-side check.

4. Install dependencies and run:

   ```
   flutter pub get
   flutter run
   ```

## Project layout

```
lib/
  core/            # config, theme, responsive helpers, router — shared across features
  features/
    auth/          # login/signup, 18+ age gate
    profile/       # profile screen + Supabase-backed profile repository
    home/          # bottom-nav shell + dashboard + "coming soon" tab placeholders
supabase/
  migrations/      # SQL to run against the Supabase project (not auto-applied)
```

## Testing

```
flutter analyze
flutter test
```

No Android SDK is available in this build environment, so `flutter run` /
`flutter build apk` haven't been exercised here — install Android Studio (or
just the command-line SDK) locally to build and run on a device/emulator.

## Next build steps

Per the build plan's suggested order: wallet + Payfast top-up, goal creation
flow, charity selection, camera-based verification capture, Claude vision
verification, forfeiture/success logic, the founder-only flagged-submissions
review queue, push notifications, and the Payfast withdrawal flow (pending
confirmation Payfast supports payouts, not just collection).
