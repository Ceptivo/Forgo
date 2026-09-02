# Forgo — Project Build Plan

**Domain:** forgo.co.za
**Platform:** Android only (v1), built in Flutter (leaves iOS open later without a rewrite)
**Builder:** Solo founder, using Claude Code
**Company:** Not yet registered with CIPC

---

## 1. Concept

Forgo is a goal-based commitment app. Users stake money on a fitness/health goal from a pre-loaded wallet. Completion is verified entirely through in-app photo capture — either a screenshot of the activity from the user's fitness app of choice, or a direct photo (e.g. bathroom scale) — checked by AI, with no fitness-service API integrations required. If the user fails, 80% of the stake goes to a charity tied to that goal category; the platform keeps 20%. On success, the full stake returns to the user's wallet.

---

## 2. Goal Types (both live at launch)

### A. Distance / Run goals
- Example: "Run 5km"
- Verified via **in-app screenshot capture** (no gallery upload) of the completed activity from any fitness app the user already uses (Strava, Samsung Health, Garmin, Nike Run Club, etc.) — no OAuth/API integration with any of these services required
- AI checks the screenshot for: genuine app-UI appearance, a distance/activity that matches the goal, and a visible date/time consistent with the goal's deadline window
- Structure: supports both **one-off** goals (e.g. "run 5km by March 1") and **recurring/cumulative** goals (e.g. "run 5km per week")
- On failure → 80% of stake to a user-chosen **Disability charity** (for people who can't walk/run)

### B. Weight-loss goals
- Example: "Lose 10kg"
- Verified via **in-app camera only** (no gallery upload) — one photo of the scale at start, one at the end. No periodic check-ins for v1.
- On failure → 80% of stake to a user-chosen **Hunger/starving-children charity**

---

## 3. Charity System
- Two fixed categories, mapped to goal type: **Disability** (run goals) and **Hunger** (weight-loss goals)
- 2–3 curated charities per category at launch; user picks the specific charity within their category
- Needs a partnership/agreement with each charity so donation claims are backed by proof, and clear "X% of forfeited stakes" disclosure per SA advertising/consumer protection rules

---

## 4. Stakes & Wallet
- **Wallet model:** users top up a wallet balance; stakes deduct from it (not charged per-goal)
- **Stake amounts:** presets of R10 / R20 / R50 / R100 / R200, plus a custom amount entry
- **Success:** full stake returned to wallet
- **Failure:** 80% to charity, 20% retained by the platform
- **Concurrent goals:** users can run multiple goals at once
- **Withdrawals:** automated payout via Payfast's API
  - ⚠️ **Flag before building this part:** Payfast is primarily a payment *collection* gateway. Confirm it actually supports automated payouts/disbursements to users before relying on it — if not, you'll need a fallback (manual EFT batching, or a payout-capable provider) for the withdrawal flow.

---

## 5. Verification
- **No fitness API integrations for v1** — Strava, Google Fit, and Samsung Health integrations were considered and dropped (see note below) in favor of a single, simpler photo/screenshot pipeline for every goal type
- **In-app camera/screen capture only** (no gallery upload) for both goal types — a screenshot of the fitness-app activity summary for run goals, a photo of the scale for weight-loss goals — checked by AI (Claude's vision API) for plausibility
- **Custom goals:** if a user types a custom goal instead of picking from the list, an AI check screens whether it's realistically verifiable at all through photo/screenshot evidence — unverifiable goals are rejected up front as a fraud-prevention measure
- **Uncertain/flagged submissions:** routed to a review queue inside the app, under the founder's account → **"Flagged Submissions"** — reviewed manually by you, not auto-approved or auto-rejected

> **Why the API integrations were dropped:** Google Fit's REST API has been closed to new sign-ups since May 2024 and is being fully deprecated in 2026. Samsung Health requires a partner approval process that typically takes 1–2 weeks. Strava's API (as of June 2026) requires a paid developer subscription ($11.99/month) for up to 10 users, and a separate application for more. Screenshot-based verification skips all of that, works with any fitness app (not just three named ones), and is weaker on fraud-resistance than a direct API pull — mitigated by requiring live in-app capture (not gallery), AI authenticity/date checks, and routing anything uncertain to manual review.

---

## 6. Accounts & Access
- **Sign up/login:** email/password
- **Minimum age:** 18+ only (standard for a money-handling app)

---

## 7. Tech Stack
| Layer | Choice |
|---|---|
| Frontend | Flutter (Android v1) |
| Backend/DB | Supabase |
| Payments | Payfast (top-ups + withdrawals — verify payout support) |
| AI verification | Claude API (vision) — screenshot/photo checks + custom-goal verifiability screening |
| Fitness data | None — verified via in-app screenshot capture, not a service integration |
| Notifications | Push reminders before each goal deadline |

---

## 8. Legal / Compliance (parallel track — doesn't block coding start)
- Terms of Service + Privacy Policy (Google Play requires a working privacy policy URL before approval)
- Charity partnership agreements + a way to record/prove donations were made
- CIPC company registration
- Advertising Regulatory Board / Consumer Protection Act compliance for "% goes to charity" claims
- Get a proper read on the regulatory side of **holding user funds and running automated payouts** — at meaningful scale this can brush up against SARB/exchange-control or e-money rules in South Africa, worth a real conversation with a fintech-aware lawyer before you scale wallet balances up

---

## 9. Suggested Build Order for Claude Code
1. Auth (email/password) + profile + 18+ gate
2. Wallet (Payfast top-up, balance tracking)
3. Goal creation flow — goal type selection, preset/custom stake amount, one-off vs recurring for run goals
4. Charity selection UI (category-locked, 2–3 choices)
5. Verification flows — one unified in-app camera/screen capture system (no gallery access):
   - Run goals: in-app screenshot of the fitness-app activity summary
   - Weight-loss goals: start photo + end photo of the scale
6. AI verification layer — screenshot/photo authenticity + plausibility checks, date/time consistency with the goal deadline, and custom-goal verifiability screening
7. Forfeiture/success logic — automatic resolution, 80/20 split on failure, full return on success
8. Flagged Submissions review screen (founder-only)
9. Push notification reminders
10. Withdrawal flow — confirm Payfast payout capability first; build fallback if needed
