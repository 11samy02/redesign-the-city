# Citizen variety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline). Steps use checkbox syntax.

**Goal:** Add two citizens (resident with a disability, expat), give every home type its own roster with its own picture, swap a few turn cards to fit, and prove the bots and the print export cope.

**Architecture:** All data lives in `roles.gd` and `tile_defs.gd`; scoring, bots, UI and print already read it, so the work is data + art + text + tests. Household art is resolved in one place, `TileDefs.art_path`.

**Tech Stack:** Godot 4.7 GDScript, Python SVG generators in `tools/`.

**Spec:** `docs/superpowers/specs/2026-11-01-citizen-variety-design.md`

## Global Constraints

- Shop stays 222 tiles; per-kind totals stay 18 small / 18 medium / 14 large / 8+8 student residences.
- Decks stay 64 event + 64 penalty cards (`CardDefs.DECK_SIZE`).
- No citizen type above about 25% of the shop's citizens, each at least about 10%.
- Roles: `student, worker, child, older` + `access` (Resident with a disability), `expat` (Expat).
- Tests: `godot --headless --path . --script res://tests/run_tests.gd` must end `0 failed`.
- Godot binary: `C:/Users/samya/Documents/Godot_v4.7-stable_win64.exe`.

## Review Focus

- A home with only new citizens (access/expat) scores without errors and the unmet need text reads naturally ("No restaurant within reach").
- Variety bonus lookup never indexes past the table with 6 happy kinds.
- Every household has a unique art file; none is missing (the shop would show a blank tile).
- Bot plays full games with 2 and 4 seats without script errors and builds restaurants for expats.
- Card art generation does not reference removed `apartment_*` tile names.

### Task 1: Roles, needs, variety bonus
**Files:** Modify `scripts/core/roles.gd`, `scripts/core/scoring.gd`, `scripts/core/circumstance_defs.gd`; tests `tests/test_roles.gd`, `tests/test_scoring.gd`, `tests/test_circumstances.gd`.
**Produces:** `Roles.ACCESS`, `Roles.EXPAT`, need `dining` (restaurant), `Scoring.VARIETY_BONUS` of length 7.
- [ ] Update tests first: role ids list of six, access/expat needs, `dining` is a route need, missing text "No restaurant within reach", variety table length equals `Roles.IDS.size() + 1`, six-kind bonus, flu wave and cold snap hit `access`.
- [ ] Implement the roles (access: needs health+park, heat 2, likes kiosk/parking + pedestrian/shaded streets; expat: needs work+dining, likes coffee shop/parking/school + bike lane).
- [ ] `VARIETY_BONUS := [0, 0, 2, 5, 9, 14, 20]`; circumstance effects and rule texts.
- [ ] Run unit tests.

### Task 2: Households and art keys
**Files:** Modify `scripts/core/tile_defs.gd`, `tests/test_tile_defs.gd`.
**Produces:** each `HOUSEHOLDS` entry gets `"art"`; `TileDefs.art_path` returns the household's art for homes; roster per spec.
- [ ] Tests: totals per kind unchanged, shares per role between 10% and 25%, unique art per household, art file exists, no household equal in members to another of a different home kind unless sizes differ.
- [ ] Implement rosters and `art_path`.
- [ ] Run unit tests.

### Task 3: Art
**Files:** Create `tools/gen_homes.py`; modify `tools/gen_art.py`, `tools/gen_cards.py`, `scripts/game/top_bar.gd`, `scripts/game/circumstance_card_face.gd`.
- [ ] 13 unique household buildings (3 reuse the existing drawings under new names) + `role_access.svg`, `role_expat.svg`.
- [ ] Rewire old `apartment_*` references; run generators; open Godot once so `.import` files exist.
- [ ] Contact sheet review.

### Task 4: Text
**Files:** `scripts/ui/rules_panel.gd`, `scripts/ui/describe.gd` (only if needed).
- [ ] Citizen and parking text mention the new citizens; "Who lives where" lists new households.

### Task 5: Cards
**Files:** `scripts/core/card_defs.gd`, `tools/gen_cards.py`, `tests/test_cards.gd`.
- [ ] Replace `tax_rebate`, `bank_bonus` (events) and `rival_developer`, `library_repairs` (penalties) with `ramps_and_lifts`, `embassy_reception`, `diplomatic_incident`, `lift_repairs`; art specs; run card probe on them.

### Task 6: Bots
**Files:** `tests/test_bot.gd`, `tests/test_bot_planner.gd`; run `tests/simulate_balance.gd`.
- [ ] Test: planner puts a restaurant on a mat for an expat home; test bots finish full games.
- [ ] Run balance simulation before/after and report.

### Task 7: Print and docs
- [ ] Run `tools/export_print.gd`, inspect the sheet; update the docs vault.
