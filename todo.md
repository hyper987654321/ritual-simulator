# Todo

This file is planning material only. It is not implementation truth. Current
behavior lives in `src` and is summarized descriptively in `design.md`.

Todo items should describe upcoming work only. If a system is implemented, move
the source-backed description to `design.md` instead of keeping it here.

## Economy Guardrails

- [ ] Keep the economy limited to three intended currencies: `Essence`,
  `Ritual Gems`, and `Ascension Stars`.
- [ ] Do not add relics, sockets, many crafting materials, boss keys, pet
  sacrifice, skin tokens, event coins, or random paid chests without a specific
  design decision.
- [ ] Do not sell paid random rewards unless the purchase flow handles Roblox
  random-item odds and disclosure requirements.

## Ritual Gems

- [ ] Create a dedicated Ritual Gems currency icon. The HUD can temporarily
  reuse the Essence icon, but the final icon should read as premium: magenta,
  violet, gold, faceted, shiny, or store-pack oriented rather than blue Essence
  energy.
- [ ] Create a dedicated Ritual Power icon for power displays instead of relying
  on text-only or reused currency art.
- [ ] Add real Roblox developer product ids for Gem packs.
- [ ] Add client purchase prompts for Gem packs once real product ids exist.
- [ ] Add server-side Gem spending actions outside the potion shop: skip/wait
  shortcuts, missing Essence purchases, extra Ritual Rush points, luck, and
  speed.
- [ ] Add free Gem earning sources: daily claim, first rebirth of the day,
  achievements, grand reset reward, and rare crystal bonus.

Simple future UI:

```text
Ritual Gems: 35

[Buy 100 Gems]
[Buy 500 Gems]
[Buy 1500 Gems]
```

## Ritual Rush Monetization

- [ ] Add a live client purchase flow for Premium Ritual Rush using a real
  product id.
- [ ] Confirm Premium Ritual Rush unlocks the second reward row through the
  existing server receipt grant path once a real product id and client prompt
  are configured.
- [ ] Consider paid Rush-adjacent products with explicit server-side validation:
  `2x Ritual Points` for `15 min`, fast progress, instant `+250 Ritual Points`,
  or a Daily Ritual Pack with Essence, potion items, and points.
- [ ] Do not sell paid random rolls directly unless the purchase flow handles
  Roblox random-item odds and disclosure requirements.

## Potion Boosts And Boost Shop

- [ ] Tune Ritual Rush potion milestone amounts and placement after playtesting.
- [ ] Keep paid boosts direct and non-random.
- [ ] Defer pet damage boosts, roll speed boosts, `2x Ritual Points`, and
  instant `+250 Ritual Points` until potion balance is stable.

## Piggy Bank

- [ ] Add a simple mobile-style `Piggy Bank` after Ritual Rush and Ritual Gems.
- [ ] Fill the bank with extra bonus Essence when the player earns Essence. The
  player should not lose earned Essence.
- [ ] Add a paid `Break Bank` purchase flow with real product id and receipt
  validation.
- [ ] Consider a later Piggy Bank Level 2 that stores Gems too.

Example future UI:

```text
Piggy Bank
3,450 / 10,000 Essence

Break Bank - 49 Robux
```

## Ascension Expansion

- [ ] Add Zones 6-10 so the second Ascension milestone can be reached.
- [ ] Tune Zone 4, Zone 5, and first Ascension reward pacing after playtesting.
- [ ] Add a final Ascension statue model once the art direction is decided.
- [ ] Decide whether Ascension needs leaderboard, profile, or cosmetic display
  treatment beyond the saved counters.

## Ascension Shop

- [ ] Decide and implement permanent Ascension Star spending.
- [ ] Keep the shop boring and stat-focused rather than cosmetic or side-system
  heavy.

Example future shop:

```text
ASCENSION SHOP

+5% Essence Gain
Cost: 1 Star

+3% Luck
Cost: 1 Star

+5% Ritual Rush Points
Cost: 1 Star

+5% Roll Speed
Cost: 1 Star

+25 Starting Capacity
Cost: 1 Star
```
