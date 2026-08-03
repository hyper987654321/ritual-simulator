# Ritual Core Simulator Balancing Brief

This document is for a broad economy and progression balancing pass.

Source code is the implementation truth. The numbers below were read from the
current source tree and should be treated as the current implemented baseline,
not final balance.

Primary goal for the next pass: research Roblox/mobile simulator pacing, then
produce concrete formulas, tables, and target timings that can be implemented in
source.

## Game Summary

Ritual Core Simulator is a Roblox pet simulator built around a small number of
clear progression loops.

The player:

1. Rolls pets from the Ritual Core.
2. Automatically equips the strongest owned pets.
3. Enters a zone where equipped pets attack crystals.
4. Crystals break and award capacity-limited Essence.
5. Essence buys Ritual Stone upgrades, rune upgrades, and new zones.
6. Rebirth resets the current run layer and gives permanent scaling.
7. Ascension is a larger reset unlocked at milestone zones. It keeps important
   long-term progress, resets the run layer harder, and gives long-term account
   strength.
8. Ritual Rush is a daily event track that rewards active play.
9. Ritual Gems are the premium/free-premium currency used currently for potions
   and planned for more direct, non-random sinks.

Current design direction:

- Keep the economy readable.
- Avoid adding many currencies.
- Do not sell random paid rewards unless Roblox random-item disclosure and odds
  rules are fully handled.
- Paid products should be direct and understandable.
- Resets should make the player feel faster on the next run, not punished.
- Ascension should extend long-term grind without deleting the pet collection or
  normal Rebirth count.
- Progression should become exponentially longer the farther the player gets:
  early milestones should come quickly, while later zones, Rebirths, and
  Ascensions should become increasingly grindy.
- The game can use mobile/Roblox-style paid acceleration. The balance pass
  should be honest about pay-to-win or pay-to-progress items and decide which
  ones improve the game without making normal free play feel pointless.
- The game should support major AFK progression. Avoid making the core loop a
  chain of manual upgrade clicks. Players should be able to set a farming goal,
  let pets work, return to progress, and make occasional meaningful decisions.

## Current Implemented Content

Current source has:

- 5 zones.
- 5 crystals per zone.
- 7 base pet models.
- 5 pet variants.
- 3 pet sizes.
- 105 final pet outcomes.
- 3 Ritual Stone upgrade types.
- 4 rune upgrade types.
- Rebirths.
- First Ascension at Zone 5.
- Ritual Rush daily points and milestones.
- Ritual Gems profile field and potion shop usage.
- Two potions/boosts: 2x Essence and 2x Luck for 15 minutes.

Current source does not yet have:

- Zones beyond Zone 5.
- Second Ascension at Zone 10.
- Ascension Star spending.
- Live Gem pack product ids.
- Live Premium Rush product id.
- Piggy Bank.
- Pet fusion, pet sacrifice, pet passives, pet storage limits, or pet
  auto-delete.
- Gem sinks outside potion purchases.

Known current placeholders:

- New profiles start with `1000` Ritual Gems for testing.
- Every configured Robux product has `RobloxProductId = 0`.
- The first Ascension statue is a local cube placeholder.
- Zones are generated as simple bounds/areas, not final authored world content.
- The tutorial overlay exists in source but is disabled.

## Current Currencies

### Essence

Primary soft currency.

Sources:

- Breaking crystals.
- Ritual Rush rewards.

Sinks:

- Ritual Stone upgrades.
- Rune upgrades.
- Zone unlocks.

Important behavior:

- Essence is clamped by current Ritual Stone capacity.
- If the player is at capacity, pets stop farming crystals.
- Crystal rewards that exceed remaining capacity are partially awarded.

### Ritual Gems

Premium/free-premium currency.

Current source:

- New profiles default to `1000` Ritual Gems for testing.
- Gem packs exist in config but have `RobloxProductId = 0`, so they are not
  live.
- Gems can buy configured potions.

Current sinks:

- `2x Essence Potion`: 25 Gems.
- `Lucky Ritual Potion`: 35 Gems.

Needs balancing:

- Final default profile Gem amount. The current `1000` is for testing.
- Free earning sources.
- Paid Gem pack amounts and prices.
- Potion prices.
- Future Gem sinks.

### Ascension Stars

Long-term Ascension currency.

Current source:

- First Ascension grants 1 Ascension Star.
- Stars are saved.
- Stars are not spendable yet.

Needs balancing:

- Whether each Ascension always grants 1 Star.
- Permanent upgrade list.
- Upgrade cost formula.
- Whether upgrades are linear, capped, branching, or tiered by Ascension count.

### Planned Piggy Bank

Piggy Bank is planned in `todo.md` but not implemented.

Current design direction:

- Piggy Bank should come after Ritual Rush and Ritual Gems are stable.
- It should fill with extra bonus Essence when the player earns Essence.
- It should not take away earned Essence from the normal player balance.
- `Break Bank` would be a direct paid purchase, not random.
- A later level could store Gems too, but this is not implemented.

Needs balancing:

- Whether Piggy Bank belongs in the first release of the economy.
- Fill rate as a percentage of earned Essence.
- Maximum bank capacity.
- Whether capacity scales by Rebirth, Ascension, or paid bank level.
- Break Bank Robux price and expected value.
- Whether Piggy Bank should include free breaks, cooldowns, or only paid breaks.

## Current Tutorial And Onboarding

Source: `src/shared/Config/TutorialConfig.luau`

Current tutorial steps:

| Step | Completion Source | Current Reward |
|---|---|---|
| Intro | Client | None |
| Roll your first pet | Server | None |
| Buy your first Ritual Stone upgrade | Server | None |
| Complete your first rebirth | Server | None |

Current behavior:

- Tutorial progress is saved.
- Gameplay actions complete server-owned tutorial steps.
- The client tutorial overlay is disabled in source.
- There are no tutorial rewards or forced tutorial locks.

Needs balancing:

- Whether tutorial should stay disabled or become part of first-time pacing.
- Whether first roll, first upgrade, and first Rebirth should grant small
  rewards.
- Whether tutorial rewards should be Essence, Gems, potions, or none.
- Whether tutorial rewards would distort early economy measurements.
- How onboarding should direct the player without slowing repeat play.

## Major AFK Gameplay Direction

Current source already has server-owned pet crystal farming, but the long-term
game should lean much harder into AFK simulator play.

The desired loop is:

```text
Choose goal -> pets farm automatically -> rewards and progress accumulate ->
player returns -> claims/adjusts/upgrades -> repeats
```

The player should not need to constantly click Ritual Stone upgrades, rune
upgrades, and other menus just to keep progressing. Manual actions should be
meaningful decisions, not the main source of grind.

Systems the balance pass should evaluate:

- AFK crystal farming that remains useful for long sessions.
- A capacity-full solution so farming does not become dead time too quickly.
- Auto-spend or goal-based upgrade rules.
- Rune Focus: choose one rune goal, then farming charges it automatically.
- Offline or away rewards with clear caps.
- Potion effects that make AFK sessions feel meaningfully better.
- Paid acceleration that extends AFK value, storage, speed, or convenience.
- Anti-exploit caps so AFK does not create unlimited server pressure or runaway
  economy inflation.

Possible AFK-friendly rune direction:

```text
Rune Focus unlocks at Zone 3 after first Rebirth.
Player chooses one active rune focus:
  Capacity / Luck / Roll Speed / Pet Power

While pets break crystals:
  selected rune gains Rune XP / Rune Charge automatically.

When the rune threshold is reached:
  rune level increases automatically or becomes claimable.

Rebirth keeps rune levels.
Ascension resets rune levels.
Ascension upgrades can improve rune charge rate or starting rune progress.
```

This keeps runes as a Rebirth-layer bridge without turning them into another
menu-click Essence sink.

Needs balancing:

- Whether rune upgrades should be automatic or claimable.
- Whether Rune XP should come from crystal breaks, time farming, Essence earned,
  or overflow Essence.
- Whether Rune XP should be a visible saved value or an internal progress bar.
- Whether choosing a Rune Focus is enough player agency.
- Whether multiple rune focuses unlock later.
- Whether potions should increase rune charge rate.
- Whether paid items can increase offline/AFK rune progress.
- How AFK caps work per session, per day, and offline.

## Visual Economy And Screen Feedback Direction

The game should feel active without overwhelming the player with currencies,
numbers, panels, and competing reward systems.

Design goal:

```text
Few currencies on the HUD.
Many visible signs of progress in the world.
```

The player should be able to glance at the screen and feel that things are
moving: pets attacking, crystals cracking, Essence flowing, bars filling,
goals advancing, and occasional bigger moments happening. At the same time,
the player should not feel like they must understand ten currencies or read ten
numbers at once.

Recommended currency visibility:

- Essence: primary always-visible soft currency.
- Ritual Gems: visible but visually secondary, mostly shop/premium context.
- Ascension Stars: visible only in Ascension/Ascension Shop context.
- Ritual Rush points: visible in Rush UI and maybe compact daily widget, not as
  a main HUD currency.
- Rune progress: should look like a focus/progress bar, not a new currency.
- Potions: inventory/active timers only, not another main currency row.

Recommended screen activity:

- Pets should visibly move, attack, return, idle, and react.
- Crystals should crack, pulse, shrink, flash, or refill as progress changes.
- Essence should visually travel to the player/core as lightweight effects.
- Capacity should fill in a satisfying way.
- Rune Focus should show a slow charging bar or altar glow while farming.
- Daily/Rush progress can pulse only when points are earned or a claim is ready.
- Rebirth/Ascension readiness should be a clear moment, not constant noise.
- Full capacity should be obvious and actionable.

Visual priority rules:

- Constant motion should live in the world, not in the HUD.
- HUD should show the current goal and the most important resource only.
- Floating numbers should be short-lived, merged, or throttled during heavy
  farming.
- Repeated rewards should batch visually instead of spamming the screen.
- Rare events should get bigger feedback than normal crystal breaks.
- Offline/AFK return should summarize gains instead of replaying every reward.

Possible low-overwhelm default HUD:

```text
Essence / Capacity
Current Goal
Current Zone
Small active boost chips
Compact buttons for Pets / Roll / Core / Shop / Rush / Teleport
```

Possible current goal examples:

- Fill Essence to upgrade Capacity.
- Unlock Zone 3.
- Rebirth ready.
- Rune Focus charging: Pet Power Rune 72%.
- Ascension ready in Zone 5.
- Capacity full: upgrade, Rebirth, or spend.

Needs balancing/design:

- Which progress indicators stay on HUD versus inside overlays.
- How many floating rewards can appear per second.
- When repeated Essence gains should merge into one number.
- How visible Rune Focus progress should be during AFK play.
- Whether capacity overflow should visually feed Rune Focus or another sink.
- How much motion is enough to keep AFK watching interesting without clutter.
- Which events deserve large celebration: rare pet, new zone, Rebirth,
  Ascension, first time rarity, Rush completion.
- How to make idle watching satisfying on mobile screens.

## Current Zone Table

Source: `src/shared/Config/ZoneConfig.luau`

| Zone | Name | Unlock Cost | Crystal Health | Crystal Essence Reward | Crystal Count |
|---:|---|---:|---:|---:|---:|
| 1 | Starter Zone | 0 | 12 | 6 | 5 |
| 2 | Moon Ruins | 200 | 34 | 28 | 5 |
| 3 | Rune Grounds | 600 | 95 | 82 | 5 |
| 4 | Solar Grove | 1600 | 260 | 220 | 5 |
| 5 | Ascension Court | 4200 | 720 | 620 | 5 |

Needs balancing:

- Zone unlock cost growth.
- Crystal health growth.
- Crystal reward growth.
- Reward-to-health ratio.
- Expected time to unlock each zone.
- Whether each zone should have the same crystal count.
- Whether zone progression should be linear in one run or require Rebirths.
- How Zone 6-10 should scale before the second Ascension.
- How Zone 20, 40, and later Ascensions should scale if added.

## Current Zone Traversal And Farming Activation

Sources:

- `src/shared/Config/ZoneConfig.luau`
- `src/server/Systems/World/ZoneTravelService.luau`

Current behavior:

- The server polls player zone position every `0.25` seconds.
- Entering an unlocked zone activates farming for that zone.
- Entering a locked zone does not change current zone and disables farming.
- Leaving all zones disables farming but keeps the last current zone.
- Zone unlocks require enough Essence and proximity to that zone's unlock wall.
- Teleport requests are available for already unlocked zones.

Needs balancing:

- World layout travel time between zones.
- Whether walking between zones should matter or teleport should dominate.
- Zone unlock wall placement and prompt distance.
- Whether later zones need bigger areas, more crystals, or different layouts.
- Whether farming activation should be forgiving on mobile movement.
- Whether teleport access should be free, delayed, gated, or monetized later.

## Current Ritual Stone Stats

Source: `src/shared/Config/RitualStoneConfig.luau`

Base stats:

| Stat | Base |
|---|---:|
| Capacity | 100 |
| Luck | 1 |
| Roll Speed Percent | 100 |

Stone upgrades:

| Upgrade | Base Cost | Cost Growth | Amount Per Level | Current Max |
|---|---:|---:|---:|---:|
| Capacity | 12 | 1.35 | +75 Capacity | None |
| Luck | 18 | 1.42 | +0.10 Luck | None |
| Roll Speed | 22 | 1.45 | +5% Roll Speed | None |

Current formulas:

```text
Capacity =
  100
  + CapacityLevel * 75
  + RuneCapacityBonus

Luck =
  1
  + LuckLevel * 0.10
  + Rebirths * 0.05
  + RuneLuckBonus
  + AscensionLuckBonus

RollSpeedPercent =
  clamp(
    100
    + RollSpeedLevel * 5
    + RuneRollSpeedPercentBonus,
    25,
    400
  )

StoneUpgradeCost(upgrade, currentLevel) =
  floor(BaseCost * CostGrowth ^ currentLevel)
```

Needs balancing:

- Whether stone upgrades should have max levels per run.
- Whether capacity should remain the main pacing gate.
- Whether Luck should remain unbounded.
- Whether Roll Speed cap should remain 400%.
- Whether stone upgrade costs should be tuned independently by zone or by
  Rebirth stage.
- How much Essence should be spent on upgrades before unlocking each zone.

## Current Rebirth

Source: `src/shared/Config/RitualStoneConfig.luau` and
`src/server/Systems/Player/PlayerStateService.luau`

Current requirement:

```text
RebirthRequiredEssence(rebirths) =
  floor(180 * 1.65 ^ rebirths)
```

Current cumulative Rebirth bonuses after `Rebirths`:

```text
RebirthEssenceMultiplier =
  1 + Rebirths * 0.25

RebirthLuckBonus =
  Rebirths * 0.05
```

Current reset:

- Essence resets to 0.
- Current zone resets to Zone 1.
- Unlocked zones reset to only Zone 1.
- Ritual Stone upgrade levels reset.
- Crystal runtime state resets.

Current kept:

- Pets.
- Equipped pets.
- Pet inventory counts.
- Rune levels.
- Ritual Gems.
- Potions.
- Active boosts.
- Ritual Rush progress.
- Rolls and progress records.
- Ascensions and Ascension Stars.

Needs balancing:

- First Rebirth timing.
- Rebirth requirement growth.
- Rebirth rewards.
- Number of Rebirths expected before first Ascension.
- Whether players should Rebirth many times before Zone 5 or reach Zone 5 in
  the first run.
- Whether Rebirth should require only Essence or also zone/upgrade milestones.
- Whether keeping runes through Rebirth makes runes too strong.

## Current Ascension

Source: `src/shared/Config/AscensionConfig.luau` and
`src/server/Systems/Player/PlayerStateService.luau`

Current requirement:

```text
RequiredAscensionZone(ascensions) =
  floor(5 * 2 ^ ascensions)
```

This means:

| Ascension Number | Required Zone |
|---:|---:|
| 1 | 5 |
| 2 | 10 |
| 3 | 20 |
| 4 | 40 |

Current source only has Zones 1-5, so only the first Ascension is reachable.

Current reward:

```text
AscensionStarsGranted = 1

AscensionLuckBonus =
  Ascensions * 0.50

AscensionCrystalEssenceMultiplier =
  1 + Ascensions * 0.25

AscensionRitualPowerBonus =
  Ascensions * 2500
```

Current reset:

- Essence resets to 0.
- Current zone resets to Zone 1.
- Unlocked zones reset to only Zone 1.
- Ritual Stone upgrade levels reset.
- Rune levels reset.
- Crystal runtime state resets.

Current kept:

- Pets.
- Equipped pets.
- Pet inventory counts.
- Rebirths.
- Ritual Gems.
- Potions.
- Active boosts.
- Ritual Rush progress.
- Rolls and best progress records.
- Rarest pet records.
- Tutorial progress.
- Purchase/receipt history.

Needs balancing:

- First Ascension target time.
- Whether Zone 5 is correct for first Ascension.
- Whether Zone 10, 20, 40 requirements remain good long term.
- Whether Ascension should keep all Rebirths.
- Whether Ascension should reset runes every time.
- Whether automatic bonuses are enough before star spending exists.
- Whether Ascension Stars should be spent on permanent upgrades.
- Upgrade list and cost scaling for Ascension Stars.
- Whether Ascension should give a visible status/flex reward beyond stats.

## Current Runes

Source: `src/shared/Config/RuneConfig.luau`

Unlock:

```text
Runes unlock when:
  Rebirths >= 1
  and Zone 3 is unlocked
```

Rune table:

| Rune | Base Cost | Cost Growth | Max Level | Bonus Per Level |
|---|---:|---:|---:|---|
| Capacity Rune | 120 | 1.55 | 20 | +25 Capacity |
| Luck Rune | 150 | 1.60 | 20 | +0.04 Luck |
| Roll Speed Rune | 180 | 1.65 | 15 | +1.2% Roll Speed |
| Pet Power Rune | 180 | 1.65 | 20 | +0.04 Pet Power Multiplier |

Current formulas:

```text
RuneCost(rune, currentLevel) =
  floor(BaseCost * CostGrowth ^ currentLevel)

RuneCapacityBonus =
  CapacityRuneLevel * 25

RuneLuckBonus =
  LuckRuneLevel * 0.04

RuneRollSpeedPercentBonus =
  RollSpeedRuneLevel * 1.2

RunePetPowerMultiplier =
  1 + PetPowerRuneLevel * 0.04
```

Current reset behavior:

- Rebirth keeps rune levels.
- Ascension resets rune levels.

Needs balancing:

- Rune unlock timing.
- Rune cost growth.
- Rune max levels.
- Whether rune bonuses are too small or too strong because Rebirth keeps them.
- Whether runes should be a mid-game bridge to Ascension.
- Whether Pet Power Rune should matter more than pure Luck/Capacity.
- Whether the current rune concept fits the game at all.
- Whether runes should be permanent Rebirth-layer upgrades, Ascension-reset
  temporary upgrades, zone-specific progression, or a smaller supporting system.
- Whether runes create interesting decisions or are just another Essence sink.
- Whether runes should help reduce grind, extend grind, or both depending on
  tier.
- Whether runes should stop being direct click-to-buy upgrades and instead
  become an AFK Rune Focus / Rune XP system.
- Whether capacity overflow should feed rune progress so AFK farming remains
  valuable after Essence is full.

## Current Pet System

Source: `src/shared/Config/PetConfig.luau`

Current equipped limit:

```text
MaxEquippedPets = 3
PetAttackInterval = 2 seconds
```

Current base pets:

| Base Pet | Rarity | Raw Roll Weight | Base Damage |
|---|---|---:|---:|
| ember_sprite | Common | 0.2200 | 2 |
| sun_sprite | Common | 0.1600 | 4 |
| moon_sprite | Common | 0.1200 | 6 |
| crystal_sprite | Rare | 0.0550 | 15 |
| crescent_sprite | Rare | 0.0400 | 20 |
| rune_stone | Rare | 0.0190 | 44 |
| crimson_glyph | Mythic | 0.0004 | 560 |

Current variants:

| Variant | Chance Divisor | Damage Multiplier |
|---|---:|---:|
| normal | 1.0 | 1.00 |
| glowy | 1.6 | 1.25 |
| golden | 2.4 | 1.50 |
| shadow | 3.2 | 1.75 |
| rainbow | 4.8 | 2.00 |

Current sizes:

| Size | Chance Divisor | Damage Multiplier | Visual Scale |
|---|---:|---:|---:|
| normal | 1.0 | 1.00 | 1.00 |
| big | 1.5 | 1.50 | 1.35 |
| huge | 2.0 | 2.00 | 1.80 |

Current final pet formula:

```text
FinalPetDamage =
  max(1, floor(BaseDamage * VariantDamageMultiplier * SizeDamageMultiplier + 0.5))

FinalPetChance =
  NormalizedBaseChance
  * NormalizedVariantWeight
  * NormalizedSizeWeight

NormalizedBaseChance =
  BaseRollChance / sum(BaseRollChance)

NormalizedVariantWeight =
  (1 / VariantChanceDivisor) / sum(1 / VariantChanceDivisor)

NormalizedSizeWeight =
  (1 / SizeChanceDivisor) / sum(1 / SizeChanceDivisor)

RarityScore =
  floor((1 / FinalPetChance) + 0.5)
```

Current normalized base pet probabilities before variants/sizes:

| Base Pet | Normalized Base Chance |
|---|---:|
| ember_sprite | 35.807% |
| sun_sprite | 26.042% |
| moon_sprite | 19.531% |
| crystal_sprite | 8.952% |
| crescent_sprite | 6.510% |
| rune_stone | 3.092% |
| crimson_glyph | 0.065% |

Current normalized variant probabilities:

| Variant | Normalized Variant Chance |
|---|---:|
| normal | 39.024% |
| glowy | 24.390% |
| golden | 16.260% |
| shadow | 12.195% |
| rainbow | 8.130% |

Current normalized size probabilities:

| Size | Normalized Size Chance |
|---|---:|
| normal | 46.154% |
| big | 30.769% |
| huge | 23.077% |

Example final odds at Luck 1:

| Final Pet Example | Approx Chance | Approx Odds |
|---|---:|---:|
| normal ember_sprite | 6.4493% | 1/15.5 |
| huge rainbow crimson_glyph | 0.001221% | 1/81,869 |

Current roll formula:

```text
RollAttempts =
  floor(Luck)
  + one extra attempt with probability fractionalPart(Luck)

Roll result =
  best sampled pet by RarityScore across RollAttempts
```

Important implementation issue:

- Luck currently scales roll CPU linearly because higher Luck means more roll
  attempts.
- Balance should define a bounded or diminishing-return Luck formula before Luck
  becomes large.

Needs balancing:

- Base pet odds.
- Variant odds.
- Size odds.
- Damage spread between pets.
- Whether Mythic damage is too large relative to earlier pets.
- Whether rare pets should be obtained through global pool only or zone-specific
  eggs/ritual pools later.
- Whether all zones should use one global pet pool.
- Whether pet damage should define progression or mostly speed up farming.
- Whether duplicates should matter after auto-equip chooses the best team.
- Whether pet damage should be capped, smoothed, or tiered by zone.
- Whether `MaxEquippedPets = 3` is correct long term.
- Whether attack interval should stay 2 seconds.

## Current Crystal Combat And Income

Source: `src/server/Systems/Ritual/CrystalCombat.luau`

Current crystal reward:

```text
CrystalReward =
  floor(
    ZoneCrystalEssenceReward
    * StoneStats.EssenceMultiplier
    * ActiveEssenceBoostMultiplier
  )

StoneStats.EssenceMultiplier =
  RebirthEssenceMultiplier
  * AscensionCrystalEssenceMultiplier

AwardedEssence =
  min(CrystalReward, Capacity - CurrentEssence)
```

Current pet damage:

```text
PetDamagePerHit =
  FinalPetDamage * RunePetPowerMultiplier

Each equipped pet attacks every 2 seconds while farming is active and capacity
is available.
```

Approximate farming model:

```text
TeamDamagePerWave =
  sum(EquippedPetDamage) * RunePetPowerMultiplier

WaveIntervalSeconds =
  2

ApproxCrystalBreakTimeSeconds =
  ceil(CrystalHealth / TeamDamagePerWave) * WaveIntervalSeconds

ApproxEssencePerMinute =
  (60 / ApproxCrystalBreakTimeSeconds) * CrystalReward
```

This is only approximate because pets can target different crystals and capacity
can stop farming.

Needs balancing:

- Crystal health versus expected pet damage curve.
- Essence reward versus upgrade and unlock costs.
- Whether capacity is reached too often.
- Whether early low-damage pets feel too slow.
- Whether high-roll pets skip too much progression.
- Whether crystals should have health tuned per zone, per run stage, or per
  expected pet power tier.

## Current Roll Speed

Source: `src/shared/Config/RitualStoneConfig.luau`

Current roll opening config:

| Value | Current |
|---|---:|
| Flash Steps | 16 |
| Base Step Delay | 0.045 |
| Step Delay Growth | 0.009 |
| Min Duration Scale | 0.25 |
| Max Duration Scale | 1.75 |
| Pet Reveal Seconds | 1.0 |

Current formula:

```text
DurationScale =
  clamp(100 / RollSpeedPercent, 0.25, 1.75)

RollOpeningDuration =
  sum from step 1 to 16 of
    (0.045 + step * 0.009) * DurationScale

RollOpeningCadence =
  RollOpeningDuration + 1.0
```

Current approximate cadence:

| Roll Speed Percent | Duration Scale | Opening Duration | Server Roll Cadence |
|---:|---:|---:|---:|
| 25% | 1.75 | 3.402s | 4.402s |
| 100% | 1.00 | 1.944s | 2.944s |
| 200% | 0.50 | 0.972s | 1.972s |
| 400% | 0.25 | 0.486s | 1.486s |

Roll Speed affects how quickly the server accepts another roll.

## Current Auto Roll

Sources:

- `src/client/Systems/UI/Hooks/useRollActions.luau`
- `src/client/Systems/UI/Components/Hud/RollScreenOverlay.luau`

Current behavior:

- Auto Roll is client-driven.
- It repeatedly calls the same server `RollPet` action as manual rolling.
- It respects the server roll cadence through `RollReadyAt`.
- After a successful roll, it waits the reveal time plus `0.2` seconds before
  requesting the next roll.
- If the server says the roll is busy, it waits the returned retry time, with a
  minimum retry delay of `0.05` seconds.
- Hide Rolls hides presentation only; it does not create a different server
  roll path.

Needs balancing:

- Roll cadence target at start.
- Roll cadence target at max practical Roll Speed.
- Whether Roll Speed is meaningful enough compared to Luck.
- Whether Auto Roll should be balanced around active play, idle play, or both.
- Whether Auto Roll should be free forever, gated by progression, or monetized.
- Whether Hide Rolls should affect perceived pacing but not reward pacing.

## Current Boosts And Potions

Sources:

- `src/shared/Config/BoostConfig.luau`
- `src/shared/Config/PotionConfig.luau`

Current boosts:

| Boost | Effect | Duration |
|---|---:|---:|
| 2x Essence | 2x crystal Essence rewards | 15 minutes |
| Lucky Ritual | 2x roll Luck | 15 minutes |

Current potions:

| Potion | Cost | Effect | Shop Enabled |
|---|---:|---|---|
| 2x Essence Potion | 25 Gems | 2x Essence for 15 minutes | Yes |
| Lucky Ritual Potion | 35 Gems | 2x Luck for 15 minutes | Yes |

Current active boost behavior:

```text
If a boost is already active:
  new EndsAtUnix = max(now, existing EndsAtUnix) + duration

Expired boosts are ignored.
```

Needs balancing:

- Potion Gem prices.
- Potion duration.
- Whether 2x is correct for both Essence and Luck.
- Free potion acquisition rate.
- Whether paid boost products should be separate from inventory potions.
- Whether boosts should be usable during Ascension runs without interruption.
- Whether Lucky Ritual should use the same bounded Luck formula once Luck is
  redesigned.
- How potions change actual gameplay behavior, not only raw stats.
- Whether players should save potions for Rebirth pushes, zone unlock pushes,
  Ascension pushes, Ritual Rush completion, or lucky rolling sessions.
- Whether potion effects make the grind feel better or only make non-boosted
  play feel bad.
- How much time a potion should save in early, mid, late, and post-Ascension
  play.
- Whether potion stacking by extending time is enough, or whether other stacking
  rules are needed.

## Store And Paid Acceleration Direction

The balance pass should research mobile games and Roblox simulator games for
paid items that reduce grind or speed progression.

This should be treated as a real monetization design pass. The question is not
only "what is fair"; it is also "what do these games commonly sell, how strong
is it, and how much pay-to-progress/pay-to-win are we willing to allow?"

Possible paid or Gem-based items to evaluate:

- Ritual Gem packs.
- Premium Ritual Rush.
- Timed 2x Essence boosts.
- Timed 2x Luck boosts.
- Timed Roll Speed boosts.
- Timed Pet Damage boosts.
- Extra equipped pet slots.
- Extra Essence capacity.
- Auto Roll access or upgraded Auto Roll.
- Faster roll opening or Hide Rolls convenience.
- Zone unlock shortcuts.
- Missing-Essence purchase shortcuts.
- Instant Rebirth or Rebirth helper packs.
- Ascension helper packs that do not skip the entire Ascension loop.
- Starter packs.
- Daily limited bundles.
- Piggy Bank break purchase.
- Offline earnings or offline bank.
- VIP-style permanent convenience.

Needs balancing:

- Which paid items should exist at all.
- Which items should use Robux directly versus Ritual Gems.
- Which items should be pure convenience versus direct power.
- Which items are acceptable pay-to-win/pay-to-progress for this game.
- How paid acceleration affects first Ascension timing.
- How paid acceleration affects leaderboard integrity.
- Whether paid power should be excluded from some leaderboards or just accepted.
- Whether free players can still make satisfying progress without boosts.
- How much grind reduction each item should give.
- Which store items should be launch-ready and which should wait.

## Current Ritual Rush

Source: `src/shared/Config/RitualRushConfig.luau`

Current event duration:

```text
24 hours
```

Current points:

| Source | Points |
|---|---:|
| Roll pet | 1 |
| Crystal broken | 3 |
| Buy stone upgrade | 10 |
| Unlock zone | 50 |
| Rebirth | 200 |

Current milestones:

| Points | Free Reward | Premium Reward |
|---:|---|---|
| 10 | 75 Essence | 3 Gems |
| 25 | 5 Gems | 125 Essence |
| 50 | 180 Essence + 1 Essence Potion | 8 Gems |
| 100 | 10 Gems + 1 Luck Potion | 350 Essence |
| 250 | 700 Essence | 20 Gems |
| 500 | 1500 Essence + 20 Gems | 40 Gems |
| 1000 | 4000 Essence + 50 Gems | 100 Gems |

Current reward behavior:

- Free and premium rewards are claimed from the same row action.
- Premium rewards require premium unlock.
- Essence rewards are capacity-clamped.
- Gem and potion rewards are not capacity-clamped.

Needs balancing:

- Daily point curve.
- Whether normal play can finish the track.
- Whether active players finish too quickly.
- Milestone spacing.
- Essence reward amounts relative to capacity.
- Gem reward amounts relative to potion prices and Gem packs.
- Premium track value.
- Whether Rebirth awarding 200 points dominates the daily event.
- Whether crystals awarding 3 points creates too much idle progress.

## Current Shop Product Catalog

Source: `src/shared/Config/ShopProductConfig.luau`

Current products:

| Product | Grant | Roblox Product Id |
|---|---|---:|
| 100 Gems | 100 Ritual Gems | 0 |
| 500 Gems | 500 Ritual Gems | 0 |
| 1500 Gems | 1500 Ritual Gems | 0 |
| Premium Rush | premium Rush reward row | 0 |
| 2x Essence | 2x Essence for 15 minutes | 0 |
| Lucky Ritual | 2x Luck for 15 minutes | 0 |

Needs balancing:

- Final Gem pack amounts.
- Robux prices for Gem packs.
- Whether direct boosts should remain in shop or only potions should exist.
- Premium Rush price.
- Whether Gem packs should map cleanly to potion costs and future sinks.
- How much free Gems should be given daily versus paid Gem packs.

## Current Ritual Power

Source: `src/server/Systems/Player/PlayerDerivedState.luau`

Current formula:

```text
RitualPower =
  floor(
    Capacity
    + Luck * 100
    + EquippedPetPower * 25
    + Rebirths * 500
    + AscensionRitualPowerBonus
  )
```

Current use:

- Leaderstats.
- Public player visuals.
- Leaderboards.
- UI flex stat.

Current non-use:

- Ritual Power is not a spendable currency.
- Ritual Power does not currently gate zones, Rebirth, Ascension, or rewards.

Needs balancing:

- Whether Ritual Power should remain display-only.
- Whether formula overweights pet damage, Luck, capacity, or Rebirths.
- Whether Ascension Ritual Power bonus is too high or too low.
- Whether Ritual Power should become a requirement for any content.

## Economy Surfaces That Need Balancing

Balance pass should cover all of these, even if the answer is "keep as current":

- Zone unlock costs.
- Zone crystal health.
- Zone crystal rewards.
- Crystal count per zone.
- Ritual Stone base stats.
- Ritual Stone upgrade costs, growth, amounts, and optional max levels.
- Rebirth requirement formula.
- Rebirth reset and permanent rewards.
- Exponential long-term grind curve for zones, Rebirths, and Ascensions.
- Major AFK progression loop and capacity-full behavior.
- Visual economy: simple currency visibility with active world feedback.
- Rune unlock condition.
- Rune costs, growth, max levels, and bonuses.
- Rune system role and whether the current rune design should change.
  If runes remain, strongly evaluate an AFK Rune Focus model instead of manual
  upgrade clicking.
- Ascension required zones.
- Ascension reset list.
- Ascension automatic bonuses.
- Ascension Star grant count.
- Ascension Star upgrade list and costs.
- Pet base odds.
- Pet variant odds.
- Pet size odds.
- Pet damage values.
- Max equipped pet count.
- Pet attack interval.
- Luck formula.
- Roll Speed formula and cap.
- Roll animation/cadence duration.
- Auto Roll access, retry pacing, and Hide Rolls behavior.
- Active boost multipliers and durations.
- Potion acquisition sources.
- Potion Gem costs.
- Potion gameplay impact and optimal-use cases.
- Tutorial/onboarding pacing and any tutorial rewards.
- Zone traversal time, teleport assumptions, and mobile movement forgiveness.
- Ritual Gems free earning.
- Ritual Gems paid pack sizes and pricing.
- Ritual Rush point sources.
- Ritual Rush milestone spacing.
- Ritual Rush free rewards.
- Ritual Rush premium rewards.
- Premium Rush value.
- Ritual Power formula.
- Leaderboard stat weighting.
- Piggy Bank fill rate, cap, and break value if it is added.
- Paid acceleration and pay-to-progress/pay-to-win store item design.
- Capacity pressure and overflow feel.
- Anti-skip constraints for very rare pet rolls.
- Performance cap for Luck and roll attempts.

## Important Balance Risks

### Luck Currently Has Linear CPU Cost

Current Luck directly increases roll attempts. A high-Luck player can cause many
samples per roll.

Balance should define a safer formula, for example:

```text
EffectiveAttempts =
  1 + floor(MaxAttempts * (1 - exp(-LuckBonus / CurveScale)))
```

or:

```text
RarityBias =
  1 + log(1 + LuckBonus) * LuckScale
```

The exact formula should be chosen after research and simulation.

### Mythic Pet Damage Can Skip Progression

`crimson_glyph` base damage is 560 before variant and size multipliers. A huge
rainbow version can reach:

```text
560 * 2.0 * 2.0 = 2240 damage
```

That can one-shot every current crystal. This may be fine as an ultra-rare
jackpot, but balance must decide if rare rolls are allowed to skip zones and
Rebirth pacing.

### Capacity Can Waste Rewards

Essence rewards are clamped by capacity. If capacity is too low relative to
crystal rewards, the player loses reward value and farming stops often.

This can be good if capacity upgrades are the main bottleneck. It is bad if it
feels like punishment for progressing to stronger zones.

### Rebirth And Ascension Multipliers Stack

Current Essence multiplier:

```text
EssenceMultiplier =
  (1 + Rebirths * 0.25)
  * (1 + Ascensions * 0.25)
  * ActiveEssenceBoostMultiplier
```

This can grow strongly over time. Balance should decide whether this is the
intended long-term acceleration curve.

### Ritual Rush Points May Reward The Wrong Behavior

Current Rush points reward:

- rolling
- crystal breaking
- stone upgrades
- zone unlocks
- Rebirths

Rebirth gives 200 points, which may dominate the daily event if Rebirths are
fast. Crystal breaking gives 3 points and may dominate if farming is idle.

### Current Gem Default Is Not Final

New profiles currently start with 1000 Ritual Gems for testing. This should not
be treated as final economy balance.

## Suggested Target Questions For Research

Research pass should answer these with concrete targets:

- What should the first 60 seconds feel like?
- How quickly should a new player get first pet, first upgrade, first crystal
  break, first zone unlock, first Rebirth, and first Ascension?
- Should first Ascension be a same-session goal, a multi-session goal, or a
  day-one goal?
- How long should Zone 1-5 take before and after Rebirth?
- How much faster should a post-Rebirth run feel?
- How much faster should a post-Ascension run feel?
- How many Rebirths should a normal player have before first Ascension?
- How much should a lucky rare pet accelerate progression?
- How much should an ultra-rare pet accelerate progression without destroying
  the economy?
- What is the expected Essence per minute at each zone for weak, normal, lucky,
  and whale-like/potion states?
- How often should the player hit capacity?
- How many rolls per minute should be normal at start, mid-game, and late-game?
- What should 2x Essence and 2x Luck be worth in Gems?
- How many free Gems should a normal active player earn per day?
- What should Premium Rush be worth compared to buying Gems directly?
- What should Ascension Star upgrades be, and how many stars should each cost?
- What exponential pacing curve should make the game increasingly grindy without
  making the player feel stuck?
- Do runes currently fit the game, or should they be redesigned?
- Should runes be earned through AFK farming/Rune Focus instead of being bought
  through another upgrade menu?
- How should potions change player behavior and session planning?
- What should players gain while AFK, and where should rewards go when Essence
  capacity is full?
- How can the game look active and satisfying without overwhelming the player
  with too many currencies, numbers, and UI panels?
- What paid acceleration items are common in mobile/Roblox simulators, and which
  ones should this game use?
- How much pay-to-progress/pay-to-win is acceptable for this game?

## Optional Easy Improvements To Consider

This section is optional. The balancing/research pass can suggest small,
low-complexity improvements that would make the game feel better without
requiring a large new system.

These ideas should be treated as suggestions only. The main balancing output
should still focus on formulas, pacing, rewards, and economy.

Examples of easy additions to evaluate:

- Daily login reward.
- Daily free Gems.
- First Rebirth of the day reward.
- Small achievement rewards for rolls, crystals, zones, Rebirths, and
  Ascensions.
- Rare crystal bonus spawn.
- Simple playtime reward chest.
- Simple starter pack.
- Free potion claim on a cooldown.
- Small quest list with 3 daily tasks.
- Zone completion bonus.
- First-time zone unlock reward.
- First-time pet rarity discovery reward.
- Pet collection index reward.
- Basic auto-delete filters for low-tier pets.
- Basic pet storage limit or inventory cleanup flow.
- Extra equipped pet slot unlocks.
- Small offline Essence bank.
- Simple VIP convenience bonuses.
- Better leaderboard categories.
- Cosmetic title for Rebirth or Ascension milestones.
- Clearer early tutorial rewards.
- Better HUD prompts when capacity is full.
- Better "what should I do next?" UI hinting.

For each optional idea, the pass should say:

- Is it easy, medium, or large to add?
- Does it improve retention, monetization, clarity, or moment-to-moment feel?
- Does it require code, config, UI, art, or only balance changes?
- Could it harm the core loop or add unnecessary complexity?
- Should it be launch scope or later backlog?

## Requested Output From The Balance Pass

The next balancing pass should produce:

1. A target progression timeline.

Example columns:

```text
Milestone | Target time new player | Target time after 1 Rebirth | Target time after 1 Ascension
```

2. A zone table for at least Zones 1-10, and preferably a scalable formula for
Zones 1-40.

Example columns:

```text
Zone | Unlock Cost | Crystal HP | Crystal Reward | Expected Team Damage | Expected Break Time | Expected Essence/min | Notes
```

3. Ritual Stone upgrade tables or formulas.

Example columns:

```text
Upgrade | Level | Cost | Stat After Purchase | Intended Purpose
```

4. Rebirth formula and expected Rebirth timeline.

Example columns:

```text
Rebirth | Required Essence | Expected Time | Permanent Bonus | Notes
```

5. Ascension formula and first Ascension implementation values.

Example columns:

```text
Ascension | Required Zone | Expected Time | Stars Granted | Automatic Bonus | Reset/Keep Notes
```

6. Ascension Star shop design.

Example columns:

```text
Upgrade | Effect Per Level | Max Level | Cost Formula | Why It Exists
```

7. Pet odds and damage proposal.

Example columns:

```text
Pet | Base Odds | Variant Odds | Size Odds | Damage | Expected Progression Impact
```

8. Luck formula proposal with performance cap.

Required:

- Formula.
- Why it feels good.
- How it avoids unbounded CPU cost.
- Expected odds improvement at Luck values such as 1, 2, 5, 10, 25, 50, 100.

9. Boost and potion economy.

Example columns:

```text
Potion | Effect | Duration | Free Sources | Gem Cost | Expected Use Case
```

10. Ritual Rush daily track proposal.

Example columns:

```text
Milestone | Points | Free Reward | Premium Reward | Expected Time | Notes
```

11. Gem economy.

Example columns:

```text
Source/Sink | Amount | Frequency | Player Type | Notes
```

12. Degenerate path analysis.

Include:

- Best possible early rare pet roll.
- Fastest possible Rebirth loop.
- Fastest possible Ritual Rush completion.
- Potion stacking behavior.
- Capacity overflow waste.
- High Luck performance.
- Whether paid users can trivialize first Ascension.

13. Implementation validation plan.

Include:

- Spreadsheet or script-friendly formulas for expected Essence/minute.
- Target values to compare against current config.
- Maximum acceptable server roll samples per roll.
- Maximum expected crystal breaks per minute per player.
- Expected Ritual Rush completion time for casual, active, and boosted players.
- A short list of config changes that should be made first.
- A short list of systems that need code changes, not only config changes.

14. Store and paid acceleration design.

Include:

- Robux products.
- Ritual Gem sinks.
- Boosts.
- Convenience items.
- Direct power items.
- Which items are effectively pay-to-win/pay-to-progress.
- Expected grind reduction per item.
- Which items should be launch items versus later additions.

15. Optional easy-improvement backlog.

Include small additions that would be easy to implement and likely improve the
game. Mark each as launch, later, or skip.

16. Major AFK gameplay design.

Include:

- AFK crystal farming loop.
- Capacity-full/overflow behavior.
- Rune Focus or another AFK rune acquisition model.
- Offline/away reward caps.
- Auto-spend or goal-based progression options.
- Potion and paid acceleration impact on AFK play.
- Abuse/performance limits.

17. Visual economy and screen feedback design.

Include:

- Which currencies should be visible by default.
- Which progress systems should be hidden in overlays.
- How to keep the world visually active during AFK farming.
- How to batch or throttle floating rewards.
- How Rune Focus, capacity full, Rebirth readiness, and Ascension readiness
  should be displayed.
- Which moments deserve large celebratory feedback.

## Candidate Design Direction To Evaluate

These are not final numbers. They are the local design direction that should be
tested against research and simulations.

- First roll: immediate.
- First upgrade: within 1-2 minutes.
- Zone 2: within 5-8 minutes for a normal player.
- Zone 3 and first Rebirth: within 15-30 minutes if actively playing.
- First Ascension: likely 60-120 minutes of active play, unless research
  suggests faster simulator pacing.
- Later progression should get exponentially longer and more grind-heavy. The
  player should move faster after each reset, but the next layer should still
  take longer overall.
- Rebirth should make the next Zone 1-3 run noticeably faster.
- Ascension should make the next full run feel much faster, but not remove the
  reason to upgrade again.
- Capacity should matter, but should not constantly waste major rewards.
- Lucky pets should create excitement and acceleration.
- Ultra-rare pets can skip some friction, but should not invalidate all future
  zones.
- Ascension Star upgrades should be simple stat upgrades, not a new complex
  crafting system.
- Runes should not become another repetitive click-upgrade panel if the game is
  meant to support major AFK play. Prefer a Rune Focus / charge-over-time model
  unless the balance pass finds a better low-click alternative.
- Keep the HUD simple, but make the world feel alive. The player should see pets
  farming, crystals reacting, Essence moving, and goals filling without needing
  many permanent currency counters on screen.

## Suggested Ascension Star Upgrade Ideas

Need final balancing before implementation.

Possible upgrade list:

| Upgrade | Why It Exists |
|---|---|
| Essence Gain | Makes every post-Ascension run faster. |
| Luck | Makes pet collection better without deleting the roll loop. |
| Starting Capacity | Reduces early post-reset friction. |
| Pet Power | Lets pets break higher-zone crystals faster. |
| Ritual Rush Points | Helps daily progression but should be capped carefully. |
| Roll Speed | Improves roll comfort and Auto Roll throughput. |

Possible constraints:

- Keep costs low early because first Ascension grants only 1 Star.
- Avoid too many choices before the player understands the system.
- Cap or tier upgrades so one stat cannot dominate forever.
- Do not require Ascension Star spending to make first post-Ascension run feel
  better; automatic Ascension bonuses should already help.

## Simulation Inputs Needed

A good balancing pass should simulate at least these player states:

### New Player

```text
Rebirths = 0
Ascensions = 0
Runes = 0
Luck = 1
Capacity = 100
Equipped pets = expected first few common pets
Boosts = none
```

### Early Rebirth Player

```text
Rebirths = 1-3
Ascensions = 0
Runes = partial
Equipped pets = common/rare mix
Boosts = none
```

### Lucky Early Player

```text
Rebirths = 0-1
Ascensions = 0
Equipped pets = one rare or mythic outlier
Boosts = none
```

### Boosted Player

```text
Rebirths = 1-5
Ascensions = 0
Boosts = 2x Essence and/or 2x Luck
Potions are time-limited
```

### Post-Ascension Player

```text
Rebirths = kept from first cycle
Ascensions = 1
Rune levels = reset
Stone levels = reset
Pets = kept
Automatic Ascension bonuses active
```

## Suggested ChatGPT Pro Prompt

Paste this document into ChatGPT Pro and ask:

```text
You are balancing a Roblox pet simulator / mobile-style progression game.
Use current Roblox/mobile simulator design patterns and web research where
needed. The attached document describes current implemented systems and
placeholder values.

Please produce a concrete balancing proposal, not generic advice.

Required output:

1. Target player progression timeline from minute 0 through first Ascension.
2. Formulas for zones, crystal HP, crystal rewards, zone unlock costs, stone
   upgrades, Rebirth, Ascension, runes, pets, Luck, Roll Speed, boosts, Ritual
   Rush, and Gems.
3. Tables for Zones 1-10 and scalable formulas for Zones 1-40.
4. Expected Essence/minute and time-to-break estimates for weak, normal, lucky,
   boosted, and post-Ascension players.
5. Pet odds and damage table that keeps rare rolls exciting without destroying
   progression.
6. A bounded or diminishing-return Luck formula that does not scale CPU linearly.
7. First Ascension values and Ascension Star shop design.
8. Ritual Rush daily track and reward proposal.
9. Boost and potion economy.
10. Ritual Gems sources, sinks, and potion pricing.
11. Degenerate path analysis and implementation risks.
12. Implementation validation plan with script/spreadsheet-friendly formulas.
13. A short list of config-only changes versus systems that require code
    changes.
14. Store and paid acceleration design based on mobile/Roblox simulator patterns:
    Robux products, Gem sinks, direct power, convenience, pay-to-progress,
    pay-to-win impact, and expected grind reduction.
15. Optional easy-improvement backlog: small additions that improve retention,
    clarity, monetization, or feel without requiring a large new system.
16. Major AFK gameplay design: AFK farming, capacity overflow, Rune Focus,
    offline/away caps, auto-spend or goal-based progress, and paid acceleration
    impact on AFK play.
17. Visual economy and screen feedback: simple currency visibility, active world
    motion, batched reward feedback, Rune Focus display, capacity-full display,
    and celebration hierarchy.

Assume the game should feel simple, readable, and mobile-friendly. Avoid adding
new currencies unless absolutely necessary. Do not recommend paid random reward
products. Keep recommendations implementable in Luau config tables.
```

## Source Files Read For This Brief

- `src/shared/Config/ZoneConfig.luau`
- `src/shared/Config/RitualStoneConfig.luau`
- `src/shared/Config/PetConfig.luau`
- `src/shared/Config/RuneConfig.luau`
- `src/shared/Config/AscensionConfig.luau`
- `src/shared/Config/RitualRushConfig.luau`
- `src/shared/Config/BoostConfig.luau`
- `src/shared/Config/PotionConfig.luau`
- `src/shared/Config/ShopProductConfig.luau`
- `src/shared/Config/TutorialConfig.luau`
- `src/server/Systems/Ritual/CrystalCombat.luau`
- `src/server/Systems/Ritual/RitualRushProgress.luau`
- `src/server/Systems/Player/ProfileTemplate.luau`
- `src/server/Systems/Player/PlayerDerivedState.luau`
- `src/server/Systems/Player/PlayerStateService.luau`
- `src/server/Systems/World/ZoneTravelService.luau`
- `src/client/Systems/UI/Hooks/useRollActions.luau`
- `src/client/Systems/UI/Components/Hud/RollScreenOverlay.luau`
- `design.md`
- `todo.md`
