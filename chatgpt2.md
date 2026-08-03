# Updated balance pass for the new brief

I treated the newly uploaded brief as the current balancing baseline. The big new design requirement is that Ritual Core Simulator should support major AFK progression: players choose a goal, pets farm automatically, progress accumulates, and the player returns to make occasional meaningful decisions instead of constantly clicking upgrade panels. The updated brief also adds a strong visual-economy goal: keep HUD currencies low, but make the world visibly alive through pets, crystals, Essence motion, goal bars, Rune Focus, and clear readiness moments.

The largest change from my previous pass is this:

Runes should stop being a normal Essence click-sink. Make them an AFK Rune Focus system.

That one change affects capacity overflow, Ritual Rush, offline rewards, potions, UI, and monetization.

Roblox monetization still strongly argues against paid random pet rolls at launch. Roblox's paid-random-item guidance covers both direct Robux purchases and indirect paid-currency purchases, and it specifically treats probability modifiers such as luck boosts as items whose impact must be numerically explained with true odds shown while active. So: free pet rolls are fine; paid random eggs are a launch skip; paid Luck potions require odds UI before they are sold directly or through purchasable Gems.

## 1. Main recommendation changes from previous pass

| Area | Previous recommendation | Updated recommendation |
| --- | --- | --- |
| Runes | Essence-purchased Rebirth-layer upgrades | Rune Focus AFK charge system; no repetitive Essence rune-buy menu. |
| Capacity full | Avoid waste by scaling capacity | Capacity still matters, but full-cap farming should continue into reduced Rune Focus charge, not dead stop. |
| AFK | Supported indirectly | Core loop should explicitly support AFK, away claim, goal selection, and overflow handling. |
| Rush | Active daily track with caps | Still capped, but online AFK earns some progress; offline claims should not finish Rush. |
| Luck potion | Sellable potion | Earned free until odds UI exists; sellable only once dynamic true-odds display is implemented. |
| Visual economy | General UX advice | Concrete HUD/default visibility, batching, and celebration hierarchy. |
| Piggy Bank | Later, Essence-based | Still later; use bonus Essence bank, not random, not Gems at launch. |
| First Ascension | 75-100 active minutes | Keep 75-110 active minutes, but allow 2-4 wall-clock hours for casual AFK/check-in players. |

## 2. Target progression timeline

The updated brief's candidate pacing says first roll should be immediate, first upgrade within 1-2 minutes, Zone 2 within 5-8 minutes, Zone 3 and first Rebirth within 15-30 minutes, and first Ascension around 60-120 active minutes. I would keep that direction, but tune toward the middle-upper part of the range so AFK systems have room to matter.

| Milestone | New active player | Casual AFK/check-in | After 1 Rebirth | After 1 Ascension |
| --- | --- | --- | --- | --- |
| First roll | 0:05-0:15 | 0:05-0:15 | Immediate | Immediate |
| First crystal break | 0:20-0:45 | 0:20-0:45 | 0:15-0:30 | 0:10-0:20 |
| First Ritual Stone upgrade | 0:45-1:30 | 1-3 min | 0:30-1:00 | 0:20-0:45 |
| Full 3-pet team | 1-3 min | 2-5 min | Immediate or <1 min | Immediate |
| Zone 2 | 5-8 min | 8-14 min | 2-4 min | 1-2 min |
| Zone 3 | 15-22 min | 25-40 min | 6-10 min | 3-6 min |
| First Rebirth | 18-28 min | 30-50 min | Next Rebirth 10-16 min | Rebirth loop 6-10 min |
| Rune Focus unlock | After first Rebirth + Zone 3 | Same day | 6-10 min after Rebirth | Immediate once Zone 3 reached |
| Zone 4 first push | 38-50 min | 60-90 min | 16-25 min | 8-14 min |
| Zone 5 first push | 70-95 min | 2-4 wall-clock hours | 28-40 min | 15-25 min |
| First Ascension | 75-110 active min | Day-one / 2-4 wall-clock hours | Needs 3+ Rebirths | Complete |
| Daily Rush 50% | 25-45 active min | 45-75 wall-clock min | 20-35 min | 15-30 min |
| Daily Rush complete | 90-130 active min | 2-4 wall-clock hours online/AFK | 70-110 min | 55-90 min |

First Ascension should be a day-one goal, not a tutorial goal. A strong player can hit it in one session; a casual AFK player can hit it through check-ins.

## 3. Zone formula and Zone 1-10 table

Use formulas for scalability, then override with rounded config values.

ZoneUnlockCost(z) =
  if z == 1 then 0
  else nice(500 * 3.05^(z - 2) * 1.14^floor((z - 1) / 5))

CrystalHP(z) =
  nice(24 * 2.8^(z - 1) * 1.18^floor((z - 1) / 5))

CrystalReward(z) =
  nice(8 * 2.6^(z - 1) * 1.10^floor((z - 1) / 5))

BreakSeconds =
  ceil(CrystalHP / EffectiveTeamDamage) * 2

EssencePerMinute =
  (60 / BreakSeconds) * CrystalReward * EssenceMultipliers

nice(x) should round to readable two-significant-digit values.

| Zone | Unlock Cost | Crystal HP | Crystal Reward | Expected Team Damage | Expected Break Time | Base Essence/min | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 24 | 8 | 18 | 4s | 120 | First break should happen fast even with weak pets. |
| 2 | 500 | 67 | 21 | 55 | 4s | 315 | First real capacity/upgrade check. |
| 3 | 1,500 | 190 | 54 | 120 | 4s | 810 | First Rebirth and Rune Focus setup zone. |
| 4 | 4,700 | 530 | 140 | 240 | 6s | 1,400 | First push zone. |
| 5 | 14,000 | 1,500 | 370 | 400 | 8s | 2,775 | First Ascension target. |
| 6 | 49,000 | 4,900 | 1,000 | 750 | 14s | 4,286 | Post-Ascension expansion. |
| 7 | 150,000 | 14,000 | 2,700 | 1,400 | 20s | 8,100 | Requires pet/rune/Ascension scaling. |
| 8 | 460,000 | 38,000 | 7,100 | 2,800 | 28s | 15,214 | Mid second-Ascension climb. |
| 9 | 1,400,000 | 110,000 | 18,000 | 5,500 | 40s | 27,000 | Boosts and AFK planning matter. |
| 10 | 4,300,000 | 300,000 | 48,000 | 11,000 | 56s | 51,429 | Second Ascension gate. |

For Zones 11-40, keep the same growth family but expect content gates. Zone 20 should be multi-day for normal free players. Zone 40 should be long-tail prestige, not launch pacing.

## 4. Expected farming states

These values are before capacity clamping. Real income should be lower when the player is careless about capacity or does not enable a goal/auto-spend option.

| Player State | Assumption | Zone 1 | Zone 3 | Zone 5 |
| --- | --- | --- | --- | --- |
| Weak new player | 12 team damage, no boosts | 4s / 120 EPM | 32s / 101 EPM | Not intended |
| Normal active player | Expected zone-appropriate pets | 4s / 120 EPM | 4s / 810 EPM | 8s / 2,775 EPM |
| Lucky rare player | Early rare-heavy team, ~150 damage | 2s / 240 EPM | 4s / 810 EPM | 20s / 1,110 EPM |
| Mythic outlier | One capped Mythic outlier, ~380 team damage | 2s / 240 EPM | 2s / 1,620 EPM | 8s / 2,775 EPM |
| Boosted push | Normal team + 2x Essence + Pet Power potion | 4s / 240 EPM | 4s / 1,620 EPM | 6s / 7,400 EPM |
| Post-Ascension | Rebirths kept, 1 Ascension, pets kept | 2-4s / 250-500 EPM | 2-4s / 1,700-3,400 EPM | 6-8s / 5,900-7,900 EPM |

The important design target: a lucky Mythic should erase early friction, not erase Ascension content.

## 5. Ritual Stone upgrades

Capacity should remain the main run-layer gate, but it must support AFK better. The current flat +75 Capacity does not scale well into Zone 5+ because the player needs to hold large zone unlock costs. Replace it with a curved stat.

Capacity(level, ascensions, runeBonus, starBonus) =
  floor(120 * 1.16^level + 220 * level + 500 * ascensions + runeBonus + starBonus)

CapacityUpgradeCost(level) =
  floor(12 * 1.18^level)

Luck =
  1
  + LuckStoneLevel * 0.12
  + Rebirths * 0.05
  + Ascensions * 0.35
  + RuneLuckBonus
  + StarLuckBonus

LuckUpgradeCost(level) =
  floor(25 * 1.35^level)

RollSpeedPercent =
  clamp(100 + RollSpeedLevel * 7 + RuneRollSpeedBonus + StarRollSpeedBonus, 100, 400)

RollSpeedUpgradeCost(level) =
  floor(20 * 1.32^level)

| Level | Capacity Cost | Capacity | Luck Cost | Luck | Roll Cost | Roll Speed |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 12 | 120 | 25 | 1.00 | 20 | 100% |
| 1 | 14 | 359 | 33 | 1.12 | 26 | 107% |
| 5 | 27 | 1,352 | 112 | 1.60 | 80 | 135% |
| 10 | 62 | 2,729 | 502 | 2.20 | 321 | 170% |
| 15 | 143 | 4,411 | 2,253 | 2.80 | 1,287 | 205% |
| 20 | 328 | 6,735 | 10,106 | 3.40 | 5,158 | 240% |
| 30 | 1,720 | 16,901 | 203,213 | 4.60 | 82,841 | 310% |
| 40 | 9,004 | 54,246 | 4,085,928 | 5.80 | 1,330,415 | 380% |

The 400% roll-speed cap is still good. It keeps server roll cadence bounded around ~40 rolls/minute.

## 6. Rebirth formula

Add a zone requirement so players cannot loop low-zone Rebirths. This is especially important once AFK overflow and Rune Focus exist.

RebirthRequiredEssence(rebirths) =
  nice(1700 * 1.72^rebirths)

RebirthRequiredZone(rebirths) =
  min(5, 3 + floor(rebirths / 2))

RebirthEssenceMultiplier =
  1 + Rebirths * 0.25

RebirthLuckBonus =
  Rebirths * 0.05

RebirthPetPowerBonus =
  1 + Rebirths * 0.03

RebirthRuneChargeBonus =
  1 + min(0.40, Rebirths * 0.025)

| Rebirth # | Required Essence | Required Zone | Expected Time | Permanent Bonus |
| --- | --- | --- | --- | --- |
| 1 | 1,700 | 3 | 18-28 min | +25% Essence, +0.05 Luck, +3% pet power |
| 2 | 2,900 | 3 | 10-16 min | Same stack |
| 3 | 5,000 | 4 | 12-18 min | Same stack |
| 4 | 8,700 | 4 | 14-22 min | Same stack |
| 5 | 15,000 | 5 | 18-28 min | Same stack |
| 6 | 26,000 | 5 | 24-36 min | Same stack |
| 7 | 44,000 | 5 | 35-50 min | Same stack |
| 8 | 76,000 | 5 | 45-65 min | Same stack |

First Ascension should usually require 3 Rebirths minimum, with many normal players doing 4 before they feel ready.

## 7. Ascension formula and first Ascension

Keep the milestone zones from the current implementation: 5, 10, 20, 40. The current brief says only Zone 5 exists now, so first Ascension is the only reachable one at launch unless Zones 6-10 are added.

RequiredAscensionZone(ascensions) =
  floor(5 * 2^ascensions)

RequiredRebirthsForAscension(ascensions) =
  3 + 4 * ascensions + ascensions * (ascensions - 1)

StarsGranted(ascensionNumber) =
  min(5, ascensionNumber)

AscensionEssenceMultiplier =
  1 + Ascensions * 0.22

AscensionPetPowerMultiplier =
  1 + Ascensions * 0.18

AscensionLuckBonus =
  Ascensions * 0.35

AscensionStartingCapacityBonus =
  Ascensions * 500

AscensionRuneChargeMultiplier =
  1 + Ascensions * 0.15

AscensionOfflineCapBonusHours =
  Ascensions * 2

| Ascension | Required Zone | Required Rebirths | Target Time | Stars | Reset/Keep |
| --- | --- | --- | --- | --- | --- |
| 1 | 5 | 3 | 75-110 active min | 1 | Reset Essence, zones, stone levels, runes, crystals. Keep pets, Rebirths, Gems, potions, records. |
| 2 | 10 | 7 | 4-8 active hours after A1 | 2 | Requires Zones 6-10. |
| 3 | 20 | 13 | Multi-day | 3 | Needs broader content. |
| 4 | 40 | 21 | Long-tail prestige | 4 | Not launch scope. |

Ascension should grant a visible flex reward beyond stats: title, aura tier, statue glow, or core skin. Do not make this another currency.

## 8. Ascension Star shop

First Ascension gives only 1 Star, so every first choice must feel good. The brief explicitly wants simple stat upgrades and warns not to require spending for the first post-Ascension run to feel better.

| Upgrade | Effect Per Level | Max | Cost Sequence | Why |
| --- | --- | --- | --- | --- |
| Essence Mastery | +6% Essence | 10 | 1,1,2,2,3,3,4,4,5,5 | Main permanent acceleration. |
| Starting Capacity | +125 starting capacity | 8 | 1,1,2,2,3,3,4,4 | Reduces reset friction. |
| Pet Power | +5% pet damage | 10 | 1,1,2,2,3,3,4,4,5,5 | Helps higher-zone crystals. |
| Ritual Luck | +0.12 Luck | 8 | 1,1,2,2,3,3,4,4 | Improves collection without deleting roll loop. |
| Roll Flow | +4% Roll Speed | 8 | 1,1,2,2,3,3,4,4 | Comfort and auto-roll throughput. |
| Rune Flow | +5% Rune Charge | 8 | 1,1,2,2,3,3,4,4 | Supports AFK direction directly. |
| Away Ritual | +30 min offline cap | 6 | 1,2,2,3,3,4 | AFK account progression. |
| Rush Focus | +2% Rush points | 5 | 1,2,3,4,5 | Daily progression; must stay capped. |

Recommended first-Star default suggestions in UI:

Want faster runs? Pick Essence Mastery.
Want smoother resets? Pick Starting Capacity.
Want better AFK/Rune play? Pick Rune Flow.

## 9. Rune Focus redesign

The updated brief strongly points away from "another repetitive click-upgrade panel" and toward Rune Focus / charge-over-time. I agree. Runes should become the Rebirth-layer AFK bridge: they persist through Rebirth, reset on Ascension, and are charged by crystal farming.

Unlock
RuneFocusUnlock =
  Rebirths >= 1
  and HighestUnlockedZone >= 3
Player choice

The player chooses one active focus:

Capacity / Pet Power / Luck / Roll Speed

Only one focus is active at launch. Add a second focus later through Ascension Stars or VIP only after live data proves the system is not too fast.

Rune Charge gain
BaseRuneChargePerBreak(zone) =
  floor(4 + 2.5 * zone + 0.75 * sqrt(BaseCrystalReward(zone)))

RuneChargeGain =
  BaseRuneChargePerBreak(zone)
  * RebirthRuneChargeBonus
  * AscensionRuneChargeMultiplier
  * StarRuneChargeMultiplier
  * ActiveRunePotionMultiplier
  * CapacityStateMultiplier

CapacityStateMultiplier =
  if EssenceAwarded > 0 then 1.00
  else 0.55

This means capacity-full farming still matters, but it is not optimal compared with spending Essence and continuing progression. The player sees it as overflow feeding the Rune Focus, not as wasted dead time.

Rune levels
RuneChargeRequired(rune, currentLevel) =
  floor(BaseRuneRequirement[rune] * Growth[rune]^currentLevel)

| Rune | Base Requirement | Growth | Max | Bonus Per Level | Role |
| --- | --- | --- | --- | --- | --- |
| Capacity Focus | 120 | 1.55 | 15 | +90 Capacity | Best for AFK and zone unlock prep. |
| Pet Power Focus | 140 | 1.60 | 20 | +4.5% pet power | Best for crystal speed and Ascension push. |
| Roll Flow Focus | 160 | 1.60 | 15 | +2% Roll Speed | Comfort and collection throughput. |
| Luck Focus | 190 | 1.65 | 15 | +0.07 Luck | Slow collector path. |
Automatic or claimable?

Use automatic level-up, not claimable. A claim button creates one more chore. The "reward moment" should be a small rune pulse, sound, and HUD chip: Pet Power Rune reached Level 4.

## 10. Capacity-full and AFK behavior

Current Essence is capacity-clamped and farming stops at cap, which the brief identifies as a possible waste/dead-time problem. For an AFK simulator, full capacity should mean "your current goal is ready," not "the game is off."

Recommended behavior

| State | Essence | Crystal farming | Rune Focus | Rush points | Visual |
| --- | --- | --- | --- | --- | --- |
| Below capacity | Award normal Essence | Active | 100% charge | Normal capped source points | Essence wisps + capacity fill |
| Partially overflowing | Award remaining Essence | Active | 70-100% charge | Normal capped source points | "Overflow to Rune" pulse |
| Full capacity, Rune Focus unlocked | 0 Essence | Active | 55% charge | Crystal source still capped | Capacity full glow + Rune altar glow |
| Full capacity, no Rune Focus | 0 Essence | Stop or slow idle | None | None | Clear "Spend Essence" prompt |
| Rebirth ready | Essence stays capped | Optional farming to Rune only | 55% charge | Capped | Big Rebirth-ready treatment |
| Ascension ready | Essence irrelevant | Optional farming to Rune only | 40% charge | No extra Ascension points | Big Ascension-ready treatment |

This preserves capacity as a pacing gate while avoiding dead AFK sessions.

## 11. Offline / away rewards

Offline rewards should support check-in play, but they should not finish the whole game without online presence.

AwayCapMinutes =
  min(
    480,
    30
    + Rebirths * 15
    + Ascensions * 120
    + AwayRitualStarLevel * 30
    + VIPOfflineBonusMinutes
  )

OfflineEssence =
  min(
    Capacity * 0.65,
    OnlineEssencePerMinuteAtLastValidZone * AwayMinutes * 0.20
  )

OfflineRuneCharge =
  OnlineRuneChargePerMinuteAtLastValidZone * AwayMinutes * 0.45

OfflineRushPoints =
  0

Key rules:

| Area | Recommendation |
| --- | --- |
| Essence cap | Offline claim can fill up to 65% of current capacity, not over cap. |
| Rune charge | Offline can charge Rune Focus because that supports AFK identity. |
| Rush | No offline Rush completion. Rush should reward online/active/AFK presence. |
| Potions | Active potions keep counting down while offline but do not multiply offline claims at launch. |
| Anti-abuse | Snapshot last valid unlocked zone, team power, and multipliers at logout. Do not simulate every crystal. |
| Presentation | One return summary: Essence gained, Rune charge gained, cap reached, suggested next goal. |

## 12. Goal-based auto-spend

Avoid full automation at install. Use progression-gated goal tools.

| Feature | Unlock | Behavior | Why |
| --- | --- | --- | --- |
| Suggested Goal | New player | UI says "Upgrade Capacity," "Unlock Zone 2," etc. | Clarity without automation. |
| Auto Capacity | Rebirth 1 | If enough Essence, buys next Capacity level while farming. | Best AFK quality-of-life. |
| Rune Focus | Rebirth 1 + Zone 3 | Player chooses rune; farming charges it. | Meaningful AFK choice. |
| Goal Reminder | Zone 3 | When enough Essence for chosen zone/upgrade, pulse goal chip. | Keeps decisions manual. |
| Auto Stone Preset | Ascension 1 | Player chooses Capacity-first / balanced / roll-focused. | Reduces repeated reset friction. |
| Auto Zone Unlock | Later / optional | Only for already-cleared zones after Ascension. | Avoids removing first-time exploration. |

Do not auto-Rebirth or auto-Ascend at launch. Those should be deliberate moments.

## 13. Pet odds and damage

Keep 105 final outcomes, but reduce Mythic damage. The brief calls out current crimson_glyph damage as a major skip risk: current huge rainbow Mythic can reach 2,240 damage and one-shot all current crystals.

Base pet table

| Pet | Rarity | Base Odds | Proposed Base Damage | Progression Impact |
| --- | --- | --- | --- | --- |
| ember_sprite | Common | 35.807% | 3 | Starter floor. |
| sun_sprite | Common | 26.042% | 5 | Early upgrade. |
| moon_sprite | Common | 19.531% | 8 | Good early common. |
| crystal_sprite | Rare | 8.952% | 14 | Noticeable early speedup. |
| crescent_sprite | Rare | 6.510% | 22 | Strong Zone 2-3 pet. |
| rune_stone | Rare | 3.092% | 38 | Rebirth-push pet. |
| crimson_glyph | Mythic | 0.065% | 110 | Jackpot, not economy breaker. |
Variant table

| Variant | Chance | Damage Multiplier |
| --- | --- | --- |
| normal | 45% | 1.00x |
| glowy | 25% | 1.15x |
| golden | 16% | 1.35x |
| shadow | 8% | 1.60x |
| rainbow | 6% | 1.90x |
Size table

| Size | Chance | Damage Multiplier | Visual Scale |
| --- | --- | --- | --- |
| normal | 57% | 1.00x | 1.00 |
| big | 28% | 1.35x | 1.35 |
| huge | 15% | 1.75x | 1.80 |
FinalPetDamage =
  max(1, floor(BaseDamage * VariantMultiplier * SizeMultiplier + 0.5))

A huge rainbow crimson_glyph becomes about 366 damage. That is still a huge early jackpot, but it does not invalidate Zone 5+.

## 14. Luck formula with bounded CPU cost

The current Luck system scales roll attempts linearly, which the brief flags as a performance risk. Replace it with one-roll weighted sampling.

QualityPower(Luck) =
  0.35 * (1 - exp(-(max(1, Luck) - 1) / 18))

AdjustedWeight(outcome, Luck) =
  BaseFinalChance(outcome) ^ (1 - QualityPower(Luck))

FinalChance(outcome, Luck) =
  AdjustedWeight(outcome, Luck) / sum(AdjustedWeight(all outcomes, Luck))

Implementation:

Server samples exactly 1 outcome per roll.
All 105 outcome weights are precomputed and cached by Luck bucket.
LuckBucket = floor(Luck * 10 + 0.5) / 10
Max random samples per roll = 1

| Luck | Rare+ Chance | Any crimson_glyph | Huge rainbow crimson |
| --- | --- | --- | --- |
| 1 | 18.6% | 0.065% / 1 in 1,538 | 0.00059% / 1 in 170,938 |
| 2 | 19.0% | 0.073% / 1 in 1,379 | 0.00068% / 1 in 146,479 |
| 5 | 20.2% | 0.097% / 1 in 1,028 | 0.00103% / 1 in 96,916 |
| 10 | 21.9% | 0.144% / 1 in 695 | 0.00178% / 1 in 56,039 |
| 25 | 25.0% | 0.285% / 1 in 351 | 0.00463% / 1 in 21,592 |
| 50 | 27.1% | 0.422% / 1 in 237 | 0.00796% / 1 in 12,560 |
| 100 | 27.7% | 0.476% / 1 in 210 | 0.00941% / 1 in 10,623 |

Luck still feels good, but CPU does not scale with Luck.

## 15. Roll Speed, Auto Roll, and Hide Rolls

| System | Recommendation |
| --- | --- |
| Auto Roll | Keep free. This is core simulator behavior, especially for mobile and AFK. |
| Hide Rolls | Keep free and presentation-only. It should not change server cadence. |
| Roll Speed cap | Keep 400%. |
| Min cadence | About 1.45-1.50s per accepted server roll. |
| Max practical rolls/min | ~40 per player. |
| Paid Auto Roll | Skip. Monetizing core automation fights the updated AFK direction. |
| Paid convenience | Later: saved filters, favorite outcomes, auto-delete presets, cosmetic roll effects. |

## 16. Boost and potion economy

Because paid Luck modifiers trigger Roblox odds-disclosure requirements, launch carefully. Roblox's paid-random-item policy says paid probability modifiers such as luck boosts must have their numerical impact explained and odds updated while active.

| Potion | Effect | Duration | Gem Cost | Free Sources | Sell for Gems before odds UI? |
| --- | --- | --- | --- | --- | --- |
| Essence Potion | 2x Essence | 15 min | 35 Gems | Rush, login streak, starter quest | Yes |
| Roll Flow Potion | +50% Roll Speed | 15 min | 30 Gems | Rush, weekly chest | Yes |
| Pet Power Potion | +50% pet damage | 15 min | 40 Gems | Rush, starter pack | Yes |
| Rune Flow Potion | +50% Rune Charge | 15 min | 40 Gems | Rush, achievements | Yes |
| Lucky Ritual Potion | 2x displayed Luck | 15 min | 45 Gems | Free track, achievements | No, unless true odds UI exists |

Boost stacking:

If boost already active:
  EndsAtUnix = min(now + 8 hours, max(now, EndsAtUnix) + duration)

Potions should be strong enough to plan around, not so strong that non-boosted play feels pointless.

## 17. Ritual Rush daily track

The current Rush gives points for rolling, crystals, upgrades, zones, and Rebirths, and the brief flags that Rebirth and crystal points may dominate. Add source caps and add Rune Focus as an AFK-friendly but capped source.

Points

| Source | Points | Daily Cap | Notes |
| --- | --- | --- | --- |
| Roll pet | 1 | 500 | Supports roll loop. |
| Crystal broken online | 2 | 650 | Online AFK helps but cannot finish alone. |
| Stone upgrade bought | 8 | 400 | Includes auto-spend upgrades. |
| Rune Focus level gained | 50 | 250 | Rewards AFK goal play. |
| Zone unlock | 45 | 360 | Milestone reward. |
| Rebirth | 125 | 500 | Strong but capped. |
| First Rebirth of day | +75 | 75 | Retention hook. |
| Ascension | 500 | 500 | Rare celebration. |
| Offline claim | 0 | 0 | Prevents offline-only Rush completion. |
Milestones

| Milestone | Points | Free Reward | Premium Reward | Expected Time |
| --- | --- | --- | --- | --- |
| 1 | 25 | 60 Essence | 3 Gems | 2-4 min |
| 2 | 75 | 5 Gems | 100 Essence | 5-8 min |
| 3 | 160 | 1 Essence Potion | 8 Gems | 10-15 min |
| 4 | 325 | 250 Essence + 8 Gems | 1 Roll Flow Potion | 20-30 min |
| 5 | 650 | 700 Essence | 20 Gems | 35-50 min |
| 6 | 1,100 | 1 Lucky Potion + 15 Gems | 1 Essence Potion + 35 Gems | 55-80 min |
| 7 | 1,650 | 2,000 Essence + 30 Gems | 75 Gems | 75-105 min |
| 8 | 2,400 | 50 Gems + title progress | 150 Gems + 1 Essence, Roll, Pet, Rune potion | 90-130 min |

If paid/premium rewards include Luck potions, add odds-disclosure UI first. Otherwise replace the premium Luck potion with Rune Flow or Pet Power.

## 18. Ritual Gems economy

The current 1000 new-profile Gems value is a test placeholder, not a final economy value.

| Source/Sink | Amount | Frequency | Notes |
| --- | --- | --- | --- |
| New profile | 0 or 20 Gems | Once | I prefer 20 so players can see Gems without buying. |
| Tutorial total | 15 Gems | Once | Small taste, not enough to buy many potions. |
| Daily login | 5-20 Gems | Daily | 5,5,10,10,15,15,20 loop. |
| Rush free track | 80-110 Gems + potions | Daily active | Main free source. |
| First Rebirth of day | 10 Gems | Daily | Reinforces reset loop. |
| Achievements | 5-100 Gems | One-time | Rolls, zones, Rebirths, Ascensions. |
| Essence Potion | -35 Gems | Repeat | Main progression sink. |
| Roll Flow Potion | -30 Gems | Repeat | Collection comfort. |
| Pet Power Potion | -40 Gems | Repeat | Zone push. |
| Rune Flow Potion | -40 Gems | Repeat | AFK/rune push. |
| Lucky Ritual Potion | -45 Gems | Locked behind odds UI | Probability modifier. |
| Cosmetic aura/title | -100 to -500 Gems | Optional | Non-power sink. |
Gem packs

Roblox Developer Products are appropriate for repeatable purchases such as currency or consumables, while Passes are appropriate for one-time privileges such as VIP or extra slots.

| Product | Gems | Suggested Robux | Notes |
| --- | --- | --- | --- |
| Small Pouch | 80 | 49 | About two potions. |
| Ritual Cache | 250 | 149 | First real pack. |
| Gem Trove | 650 | 349 | Mid pack. |
| Ancient Hoard | 1,400 | 699 | Better value. |
| Ascendant Vault | 3,200 | 1,499 | Whale pack; not needed for normal play. |

## 19. Store and paid acceleration

Mobile F2P commonly uses direct currency packs, timed boosts, premium reward tracks, limited-time bundles, VIP systems, and piggy-bank-style offers. Piggy banks work best when they fill from play and have a cap, because the cap creates a predictable value moment.

| Product | Type | Price | Effect | P2W / P2Progress | Launch? |
| --- | --- | --- | --- | --- | --- |
| Gem packs | Developer Product | 49-1,499 Robux | Guaranteed Gems | Pay-to-progress | Yes |
| Premium Rush | Developer Product | 149 Robux | Current daily premium row | Pay-to-progress | Yes |
| Starter Pack | One-time product | 99 Robux | 250 Gems + Essence/Roll/Pet potion + title | Pay-to-progress | Yes |
| Essence Potion direct | Developer Product | 19-29 Robux | Guaranteed potion item | Pay-to-progress | Yes |
| Rune Flow Potion direct | Developer Product | 19-29 Robux | Guaranteed potion item | Pay-to-progress/AFK | Yes |
| Pet Power Potion direct | Developer Product | 29-39 Robux | Guaranteed potion item | Pay-to-progress | Yes |
| Lucky Ritual Potion direct | Developer Product | 29-39 Robux | Luck potion | Compliance-sensitive | Only after odds UI |
| VIP | Pass | 299 Robux | Daily 20 Gems, tag, +5% Essence, +1h offline cap | Mild P2Progress | Soft launch |
| +1 Equipped Pet Slot | Pass | 399 Robux | 4 equipped pets | P2W/P2Progress | Later / test only |
| Offline Bank+ | Pass | 249 Robux | +2h away cap, +10% offline Essence | P2Progress | Later |
| Advanced Auto Roll | Pass | 149 Robux | Saved filters, auto-delete presets | Convenience | Later |
| Zone skip | Product | - | Unlocks zone | Heavy P2W | Skip |
| Instant Rebirth | Product | - | Rebirth instantly | Heavy P2W | Skip |
| Paid random egg | Product | - | Random pet | Compliance/trust risk | Skip launch |

Do not monetize basic Auto Roll or Teleport. Teleport should stay free for unlocked zones.

## 20. Piggy Bank

Keep Piggy Bank out of the first balancing release. The brief already says it should come after Rush and Gems are stable, and I agree.

| Setting | Recommendation |
| --- | --- |
| Launch scope | Later. |
| Stored value | Bonus Essence only, not Gems at launch. |
| Fill source | 8% of earned Essence + 4% of full-cap overflow value. |
| Does it subtract from player? | No. |
| Capacity | max(2 * NextZoneCost, 4 * CurrentCapacity), capped by bank tier. |
| Break price | 79-99 Robux early. |
| Free break | One free break after first Ascension, then rare event-only free breaks. |
| Randomness | None. Direct value only. |

## 21. Ritual Power

Keep Ritual Power display-only. Do not use it to gate content. If pet damage is reduced as proposed, the current structure is acceptable, but I would slightly reduce pet dominance and add zone/rune identity.

RitualPower =
  floor(
    Capacity
    + Luck * 120
    + EquippedPetPower * 18
    + Rebirths * 650
    + Ascensions * 4000
    + TotalRuneLevels * 120
    + HighestZoneUnlocked * 200
  )

This makes Ritual Power a readable flex stat rather than a progression requirement.

## 22. Visual economy and screen feedback

The updated brief is clear: few HUD currencies, lots of world feedback.

Default HUD

| Element | Visibility |
| --- | --- |
| Essence / Capacity | Always visible, primary. |
| Current Goal | Always visible. |
| Current Zone | Always visible or compact. |
| Boost chips | Visible only when active. |
| Gems | Secondary; visible in shop/top bar, not dominant. |
| Rush points | Rush widget only, pulse on progress/claim. |
| Ascension Stars | Ascension shop only. |
| Rune progress | Goal/Rune Focus bar, not a currency row. |
| Potions | Inventory + active timers only. |
World feedback

| System | Feedback |
| --- | --- |
| Pets | Move, attack, return, idle, react to break. |
| Crystals | Crack by HP stage, pulse on hit, flash on break, respawn/restore. |
| Essence | Wisps travel to player/core; merge during heavy farming. |
| Capacity | Fill bar with strong "near full" and "full" state. |
| Rune Focus | Altar/core glow, slow bar, level-up pulse. |
| Rush | Small pulse only when points earned or reward ready. |
| Rebirth ready | Large but non-spammy core/altar state. |
| Ascension ready | Biggest persistent readiness treatment. |
Batching rules
Max floating Essence numbers per player = 4 per second
Merge Essence gains within 0.5 seconds per zone
Max Rush pulse frequency = once every 1.5 seconds
Max Rune charge pulse frequency = once every 2 seconds
Rare pet celebration overrides normal roll feedback
Offline return uses summary panel, not replayed rewards
Celebration hierarchy

| Tier | Event | Feedback Size |
| --- | --- | --- |
| 1 | Normal crystal break, normal roll | Small |
| 2 | Stone upgrade, Rune charge pulse | Small-medium |
| 3 | Rune level, zone unlock, rare pet | Medium |
| 4 | Rebirth ready/complete, Rush complete | Large |
| 5 | Mythic pet, first Ascension, new Ascension tier | Biggest |

## 23. Degenerate path analysis

| Risk | Recommendation |
| --- | --- |
| Best possible early Mythic | Huge rainbow Mythic becomes ~366 damage, not 2,240. It can skip early friction but not all Ascension content. |
| Fast Rebirth loop | Require Zone 3/4/5 by Rebirth count. Essence alone is not enough. |
| Full-cap AFK rune farming | Full capacity gives 55% Rune Charge, so it is useful but not optimal. |
| Offline abuse | Offline rewards are capped by time, capacity, last valid zone, and reduced efficiency. No offline Rush. |
| Rush AFK completion | Crystal and roll points have daily source caps. Online AFK helps but cannot finish alone. |
| High Luck CPU | One roll sample per roll; 105 CDF outcomes cached by Luck bucket. |
| Paid users trivializing first Ascension | Gem packs + potions may reduce first Ascension to ~40-60 min, but no instant Rebirth, zone skip, or paid random pets. |
| Luck potion compliance | Do not sell paid Luck modifiers until the game can display true numerical odds dynamically. |
| Leaderboard integrity | Either accept paid-progress leaderboards or add "free-track" seasonal leaderboards later. |

## 24. Implementation validation formulas
EffectiveTeamDamage =
  sum(EquippedPetFinalDamage)
  * RunePetPowerMultiplier
  * RebirthPetPowerMultiplier
  * AscensionPetPowerMultiplier
  * StarPetPowerMultiplier
  * ActivePetPowerBoostMultiplier

BreakSeconds =
  ceil(CrystalHP / EffectiveTeamDamage) * PetAttackIntervalSeconds

CrystalRewardActual =
  floor(
    BaseCrystalReward
    * RebirthEssenceMultiplier
    * AscensionEssenceMultiplier
    * StarEssenceMultiplier
    * ActiveEssenceBoostMultiplier
  )

AwardedEssence =
  min(CrystalRewardActual, Capacity - CurrentEssence)

EssencePerMinute =
  (60 / BreakSeconds) * CrystalRewardActual

CapacityWastePercent =
  max(0, CrystalRewardActual - AwardedEssence) / CrystalRewardActual

RuneChargePerMinute =
  (60 / BreakSeconds)
  * BaseRuneChargePerBreak(zone)
  * RuneChargeMultipliers
  * CapacityStateMultiplier

OfflineEssence =
  min(Capacity * 0.65, OnlineEssencePerMinute * AwayMinutes * 0.20)

OfflineRuneCharge =
  OnlineRuneChargePerMinute * AwayMinutes * 0.45

Validation targets:

| Metric | Target |
| --- | --- |
| Server roll samples per roll | 1 |
| Roll CDF outcomes evaluated | 105, cached |
| Max practical rolls/min/player | ~40 |
| Max practical crystal breaks/min/player | 30 |
| Floating reward bursts | <=4 Essence numbers/sec/player |
| First upgrade | 0:45-1:30 |
| Zone 2 | 5-8 min |
| Zone 3 | 15-22 min |
| First Rebirth | 18-28 min |
| First Ascension | 75-110 active min |
| Offline cap new player | 30 min |
| Offline cap after 1 Rebirth | 45 min |
| Offline cap after 1 Ascension | 2.5-3h |
| Rush casual progress | 40-60% in 25-45 active min |
| Rush active completion | 90-130 active min |
| Boosted first Ascension | 40-60 min, not instant |

## 25. First implementation pass
Config-only changes
Set new-profile Ritual Gems to 0 or 20, not 1,000.
Tune Zones 1-5 to the new zone table.
Reduce crimson_glyph damage and variant/size multipliers.
Raise first Rebirth requirement and add zone requirements.
Raise Zone 5 unlock cost enough to require Rebirth planning.
Add source caps to Ritual Rush.
Update potion Gem costs.
Keep Auto Roll and Hide Rolls free.
Remove paid/direct Luck potion sale until odds UI is implemented.
Code changes
Replace Luck roll attempts with bounded CDF sampling.
Add curved capacity formula.
Add Rebirth zone requirement.
Add Ascension Rebirth requirement.
Replace Rune Essence purchases with Rune Focus charge.
Allow full-cap farming to continue into reduced Rune Charge after Rune Focus unlock.
Add offline/away reward claim.
Add goal UI and Auto Capacity.
Add Rush source caps.
Add dynamic odds UI before any paid Luck modifier.
Add batched reward visuals and capacity-full feedback.
Add analytics events for first roll, first break, first upgrade, Zone 2, Zone 3, first Rebirth, Rune Focus unlock, first Rune level, first Ascension, capacity full, away claim, potion use, and Rush completion.

## 26. Optional backlog

| Idea | Scope | Helps | Risk | Recommendation |
| --- | --- | --- | --- | --- |
| Capacity full HUD prompt | Easy | Clarity | Low | Launch |
| Daily login Gems | Easy | Retention | Low | Launch |
| First Rebirth of day reward | Easy | Retention | Low | Launch |
| First-time zone unlock reward | Easy | Moment-to-moment feel | Low | Launch |
| Goal hint chip | Easy/Medium | Clarity | Low | Launch |
| Auto Capacity | Medium | AFK quality | Low | Launch |
| Rune Focus | Medium/Large | Core AFK identity | Medium | Launch if possible |
| Offline claim | Medium | AFK/check-in loop | Medium | Launch or fast follow |
| Rare crystal bonus spawn | Medium | Watching AFK feel | Low | Later |
| Pet collection index rewards | Medium | Collection motivation | Medium | Later |
| Auto-delete filters | Medium | Inventory clarity | Low | Later |
| VIP | Medium | Monetization | P2Progress | Soft launch |
| Extra equip slot | Easy/Medium | Monetization | P2W | Later/test |
| Piggy Bank | Medium/Large | Monetization | Balance risk | Later |
| Paid random eggs | Large/compliance | Monetization | High | Skip launch |
| Zone skips | Easy | Monetization | Destroys pacing | Skip |
| Instant Ascension | Easy | Monetization | Destroys core loop | Skip |

The updated direction is stronger than the previous one: make Ritual Core an AFK-first pet simulator with a simple HUD, visible world progress, bounded randomness, and direct paid acceleration. The first serious implementation pass should prioritize Rune Focus, full-cap overflow, bounded Luck, Rebirth gating, pet damage normalization, Rush caps, and the capacity curve.
