# Forgo

Goal-based commitment app — stake money on a fitness/health goal, prove it with
an in-app photo/screenshot, keep your stake. Miss it, and 80% goes to charity.

Android-only v1, built with Flutter. See `docs/forgo-build-plan.md` for the
full product spec and build order.

## Status

Steps 1–3 of the build order are done: email/password auth with an 18+ age
gate, a wallet with Payfast top-ups, and goal creation (type selection,
one-off vs recurring for run goals, preset/custom stake, atomic stake
deduction on creation). Charity selection and all verification/resolution
logic are still ahead. Everything is mobile-first and responsive across
phone/tablet widths (see `lib/core/responsive/responsive.dart`).

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

4. **Wallet schema** — run `supabase/migrations/0002_wallet_transactions.sql`
   the same way. Adds the `wallet_transactions` table, RLS so users can only
   see their own rows, and a `credit_wallet_from_transaction` function that
   only the Edge Functions below can call (never the app directly).

5. **Deploy the Payfast Edge Functions** — these hold the Payfast signing
   logic and the merchant credentials; the app never sees either. Requires
   the [Supabase CLI](https://supabase.com/docs/guides/cli):

   ```
   supabase login
   supabase link --project-ref zfsklkcsfpygjmgwzaeb
   supabase functions deploy create-payfast-payment payfast-itn payfast-return payfast-cancel
   ```

6. **Set Payfast secrets** — once you have a Payfast account (sandbox is
   free — https://developers.payfast.co.za/docs#sandbox — and fine to start
   with):

   ```
   supabase secrets set PAYFAST_MERCHANT_ID=your-merchant-id
   supabase secrets set PAYFAST_MERCHANT_KEY=your-merchant-key
   supabase secrets set PAYFAST_PASSPHRASE=your-passphrase
   supabase secrets set PAYFAST_MODE=sandbox
   ```

   Switch `PAYFAST_MODE` to `live` (and swap in live credentials) when
   you're ready to accept real payments. In your Payfast dashboard, the
   notify URL Payfast will call is
   `https://zfsklkcsfpygjmgwzaeb.supabase.co/functions/v1/payfast-itn`.

7. **Goals schema** — run `supabase/migrations/0003_goals.sql` the same
   way. Adds the `goals` table and a `create_goal_with_stake` function that
   atomically deducts the stake and creates the goal in one transaction
   (never as two separate client calls, which could leave a goal without
   its stake or vice versa). **This migration also closes a real gap in
   migration 0001**: the `profiles` "update own profile" policy is a
   row-level check with no column restriction, so any signed-in user could
   currently set their own `wallet_balance_cents` to anything via a normal
   client update — RLS can't express "this column but not that one" on its
   own. 0003 adds the missing column-level `REVOKE` regardless of whether
   you've built anything on goals yet, so **run it even if you don't care
   about goals right now.**

8. Install dependencies and run:

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
    wallet/        # balance card, Payfast top-up flow, transaction history
    goals/         # goal creation (run/weight-loss), stake, goals list
    home/          # bottom-nav shell + dashboard
supabase/
  migrations/      # SQL to run against the Supabase project (not auto-applied)
  functions/       # Deno Edge Functions — Payfast signing + ITN webhook (not auto-deployed)
```

## Testing

```
flutter analyze
flutter test

# Edge Functions (requires Deno: https://docs.deno.com/runtime/getting_started/installation/)
deno test supabase/functions/_shared/payfast_test.ts
```

No Android SDK is available in this build environment, so `flutter run` /
`flutter build apk` haven't been exercised here — install Android Studio (or
just the command-line SDK) locally to build and run on a device/emulator.
The Payfast flow is untested end-to-end for the same reason (no merchant
account yet) — the signature/round-trip logic is unit-tested, but a real
sandbox top-up should be tried once secrets are configured.

## Next build steps

Per the build plan's suggested order: charity selection UI, camera-based
verification capture, Claude vision verification, forfeiture/success logic,
the founder-only flagged-submissions review queue, push notifications, and
the Payfast withdrawal flow (pending confirmation Payfast supports payouts,
not just collection — see the build plan's flag on this).
