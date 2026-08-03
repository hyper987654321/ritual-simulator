# Ritual Core Simulator balance proposal

I treated the uploaded balancing brief as the current implemented baseline: 5 zones, 5 crystals per zone, 105 final pet outcomes, Rebirth, first Ascension at Zone 5, Ritual Rush, Ritual Gems, 2x Essence, and 2x Luck potions.

The main recommendation is to slow the economy by capacity and reset milestones, not by making crystals feel spongey. Players should break things often, see numbers climb quickly, and make frequent early decisions, while Rebirth and Ascension requirements prevent the fastest paths from collapsing the game.

Roblox policy is an important constraint: paid random items include direct Robux rolls and indirect paid-currency rolls, and odds must be disclosed numerically; paid luck modifiers also need their impact explained and odds updated while active. That strongly supports keeping pet rolls free, avoiding paid random pets at launch, and making paid products direct accelerators or guaranteed items. Roblox also distinguishes repeatable Developer Products such as currency and potions from one-time Passes such as permanent power-ups, so Gem packs and potions should be Developer Products, while VIP or extra equip slots should be Passes. Current Roblox pet-simulator monetization commonly sells extra equipped pets, teleport, faster opening, auto hatch/farm, storage, VIP, luck, and "hunter" passes; examples from Pet Simulator X/99 show these are familiar patterns, but many are direct power and should be labeled as pay-to-progress if used.

## 1. Target progression timeline
| Milestone | New player target | After 1 Rebirth | After 1 Ascension |
| --- | --- | --- | --- |
| First roll | 0:05-0:15 | Already available | Already available |
| First crystal break | 0:20-0:45 | 0:15-0:30 | 0:10-0:20 |
| First Ritual Stone upgrade | 0:45-1:30 | 0:30-1:00 | 0:20-0:45 |
| Full 3-pet team | 1-3 min | Immediate or <1 min | Immediate |
| Zone 2 | 5-7 min | 2-4 min | 1-2 min |
| Zone 3 | 14-18 min | 6-9 min | 3-5 min |
| First Rebirth | 18-24 min | Next Rebirth in 10-14 min | Rebirth loop in 5-8 min |
| Zone 4 first push | 35-45 min | 15-22 min | 8-12 min |
| Zone 5 first push | 65-85 min | 25-35 min | 15-25 min |
| First Ascension | 75-100 min active play | Requires 3+ Rebirths | Already complete |
| Daily Ritual Rush casual progress | 25-45 min to 40-60% | 20-35 min | 15-30 min |
| Daily Ritual Rush completion | 90-130 min active | 70-110 min | 55-90 min |

FTUE should be enabled but non-blocking. Roblox's own onboarding guidance emphasizes teaching the essentials, getting to the fun quickly, and using starter items or currency carefully, which fits this game's first-roll -> first break -> first upgrade funnel.

## 2. Zone formula and Zone 1-10 table
Recommended scalable formulas

Use "nice rounded" outputs in config, but generate from these curves:

ZoneUnlockCost(z) =
  if z == 1 then 0
  else nice(450 * 3.0^(z - 2) * 1.12^floor((z - 1) / 5))

CrystalHP(z) =
  nice(24 * 2.75^(z - 1) * 1.15^floor((z - 1) / 5))

CrystalReward(z) =
  nice(8 * 2.55^(z - 1) * 1.08^floor((z - 1) / 5))

BreakSeconds =
  ceil(CrystalHP / EffectiveTeamDamage) * 2

BaseEssencePerMinute =
  (60 / BreakSeconds) * CrystalReward

nice(x) should round to two significant digits for readable config values. The jump every 5 zones creates Ascension-era grind steps without adding another currency.

| Zone | Unlock Cost | Crystal HP | Base Reward | Expected Team Damage | Expected Break Time | Base Essence/min | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 24 | 8 | 12 | 4s | 120 | First break in under a minute even with one weak pet. |
| 2 | 450 | 66 | 20 | 60 | 4s | 300 | First real capacity check. |
| 3 | 1,400 | 180 | 52 | 115 | 4s | 780 | Unlocks Rebirth/rune planning. |
| 4 | 4,000 | 500 | 130 | 180 | 6s | 1,300 | First "push" zone. |
| 5 | 12,000 | 1,400 | 340 | 330 | 10s | 2,040 | First Ascension zone; should usually need 3+ Rebirths. |
| 6 | 41,000 | 4,300 | 930 | 650 | 14s | 3,986 | Post-Ascension expansion start. |
| 7 | 120,000 | 12,000 | 2,400 | 1,200 | 20s | 7,200 | Requires stronger capacity scaling. |
| 8 | 370,000 | 33,000 | 6,100 | 2,500 | 28s | 13,071 | Mid second-Ascension climb. |
| 9 | 1,100,000 | 90,000 | 15,000 | 5,000 | 36s | 25,000 | Boosts start mattering heavily. |
| 10 | 3,300,000 | 250,000 | 39,000 | 10,000 | 50s | 46,800 | Second Ascension target. |

For Zones 11-40, keep the same formula but add authored "tier moments" at Zones 10, 20, and 40. Zone 20 should feel like a multi-day objective for normal free players unless content volume is expanded substantially; Zone 40 should be long-tail/prestige content, not launch pacing.

## 3. Ritual Stone upgrade proposal

The current flat +75 Capacity model does not scale well with zone costs because players must hold enough Essence to buy a zone unlock. Replace capacity with a curved formula.

Capacity
Capacity(level, ascensions, runeBonus) =
  floor(120 * 1.16^level + 220 * level + 500 * ascensions + runeBonus)

CapacityUpgradeCost(currentLevel) =
  floor(12 * 1.18^currentLevel)

This keeps the first upgrades cheap, lets Zone 5 capacity happen around level 30, and allows Zones 6-10 without hundreds of linear levels.

Luck
DisplayedLuck =
  1
  + LuckStoneLevel * 0.12
  + Rebirths * 0.05
  + Ascensions * 0.35
  + RuneLuckBonus
  + StarLuckBonus

LuckUpgradeCost(currentLevel) =
  floor(25 * 1.35^currentLevel)

Luck should be useful but not the primary early sink.

Roll Speed
RollSpeedPercent =
  clamp(100 + RollSpeedLevel * 7 + RuneRollSpeedBonus + StarRollSpeedBonus, 100, 400)

RollSpeedUpgradeCost(currentLevel) =
  floor(20 * 1.32^currentLevel)

Keep the existing 400% cap. It is readable and prevents roll spam from becoming a server problem.

| Level | Capacity Next Cost | Capacity | Luck Next Cost | Luck | Roll Next Cost | Roll Speed |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 12 | 120 | 25 | 1.00 | 20 | 100% |
| 1 | 14 | 359 | 33 | 1.12 | 26 | 107% |
| 5 | 27 | 1,352 | 112 | 1.60 | 80 | 135% |
| 10 | 62 | 2,729 | 502 | 2.20 | 321 | 170% |
| 15 | 143 | 4,411 | 2,253 | 2.80 | 1,287 | 205% |
| 20 | 328 | 6,735 | 10,106 | 3.40 | 5,158 | 240% |
| 30 | 1,720 | 16,901 | 203,213 | 4.60 | 82,841 | 310% |
| 40 | 9,004 | 54,246 | 4,085,928 | 5.80 | 1,330,415 | 380% |

## 4. Rebirth formula and timeline

Current first Rebirth is too cheap for the desired 15-30 minute first reset. Use a higher requirement and add a small zone requirement to prevent degenerate Zone 1 loops.

RebirthRequiredEssence(rebirths) =
  nice(1500 * 1.72^rebirths)

RebirthRequiredZone(rebirths) =
  min(5, 3 + floor(rebirths / 2))

RebirthEssenceMultiplier =
  1 + Rebirths * 0.25

RebirthLuckBonus =
  Rebirths * 0.05

RebirthPetPowerBonus =
  1 + Rebirths * 0.03

Keep the current reset/keep structure: reset Essence, zone unlocks, current zone, Ritual Stone levels, and crystal runtime state; keep pets, equipped pets, runes, Gems, potions, Rush progress, records, and Ascension progress.

| Rebirth # | Required Essence | Required Zone | Expected Time | Permanent Bonus |
| --- | --- | --- | --- | --- |
| 1 | 1,500 | 3 | 18-24 min | +25% Essence, +0.05 Luck, +3% pet power |
| 2 | 2,600 | 3 | 10-14 min | Same stack |
| 3 | 4,400 | 4 | 9-13 min | Same stack |
| 4 | 7,600 | 4 | 12-17 min | Same stack |
| 5 | 13,000 | 5 | 14-20 min | Same stack |
| 6 | 23,000 | 5 | 18-26 min | Same stack |
| 7 | 39,000 | 5 | 24-35 min | Same stack |
| 8 | 67,000 | 5 | 35-50 min | Same stack |

Expected first Ascension should happen after 3-4 Rebirths, not on the first run.

## 5. Ascension design

Keep the readable zone milestones, but add Rebirth requirements so Ascension represents a completed layer rather than a single zone purchase.

AscensionNumber = Ascensions + 1
RequiredAscensionZone(ascensions) =
  5 * 2^ascensions

RequiredRebirthsForAscension(ascensions) =
  3 + 4 * ascensions + ascensions * (ascensions - 1)

StarsGranted(ascensionNumber) =
  ascensionNumber

AscensionEssenceMultiplier =
  1 + Ascensions * 0.22

AscensionPetPowerMultiplier =
  1 + Ascensions * 0.18

AscensionLuckBonus =
  Ascensions * 0.35

AscensionStartingCapacityBonus =
  Ascensions * 500

AscensionRitualPowerBonus =
  Ascensions * 2500
| Ascension | Required Zone | Required Rebirths | Target Time | Stars | Reset/Keep Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | 5 | 3 | 75-100 min active | 1 | Reset run layer and runes; keep pets, Rebirth count, Gems, potions, records. |
| 2 | 10 | 7 | 4-8 active hours after A1 | 2 | Requires Zones 6-10 content. |
| 3 | 20 | 13 | Multi-day | 3 | Needs more content and more star choices. |
| 4 | 40 | 21 | Long-tail prestige | 4 | Should not be launch-scope. |

Ascension should reset runes. Runes become the Rebirth-layer bridge; Ascension Stars become the permanent account layer.

## 6. Ascension Star shop

Keep the first shop small and obvious. First Ascension gives only 1 Star, so every starting choice must feel good.

| Upgrade | Effect Per Level | Max Level | Cost Sequence | Why It Exists |
| --- | --- | --- | --- | --- |
| Essence Mastery | +6% Essence | 10 | 1,1,2,2,3,3,4,4,5,5 | Main post-Ascension acceleration. |
| Starting Capacity | +100 starting capacity | 8 | 1,1,2,2,3,3,4,4 | Reduces reset friction. |
| Pet Power | +5% pet damage | 10 | 1,1,2,2,3,3,4,4,5,5 | Helps crystals without inflating rewards. |
| Ritual Luck | +0.12 Luck | 8 | 1,1,2,2,3,3,4,4 | Improves collection without removing roll loop. |
| Roll Flow | +4% Roll Speed | 8 | 1,1,2,2,3,3,4,4 | Comfort and auto-roll throughput. |
| Rush Focus | +2% Ritual Rush points | 5 | 1,2,3,4,5 | Daily engagement; keep capped. |

Do not require star spending for the first post-Ascension run to feel better. Automatic Ascension bonuses should carry that.

## 7. Rune redesign

Runes should remain Rebirth-layer upgrades that survive Rebirth and reset on Ascension. That gives players a mid-layer goal without creating another permanent currency.

RunesUnlock =
  Rebirths >= 1 and HighestUnlockedZone >= 3
| Rune | Base Cost | Growth | Max | Bonus | Role |
| --- | --- | --- | --- | --- | --- |
| Capacity Rune | 250 | 1.55 | 12 | +40 Capacity | Helps Rebirth pushes. |
| Luck Rune | 300 | 1.60 | 10 | +0.08 Luck | Collection bridge. |
| Roll Speed Rune | 350 | 1.60 | 10 | +2% Roll Speed | Comfort bridge. |
| Pet Power Rune | 250 | 1.55 | 15 | +5% pet power | Main crystal-speed bridge. |

Pet Power Rune should be the most attractive rune for first Ascension pushes. Capacity Rune should be useful but not mandatory once capacity formula is fixed.

## 8. Pet odds and damage proposal

The biggest current risk is the Mythic damage gap. A crimson_glyph can currently reach 2,240 damage in huge rainbow form, which can one-shot current crystals. Keep Mythic exciting, but reduce its ability to invalidate the economy.

Base pet table
| Pet | Rarity | Base Odds | Approx Odds | Proposed Base Damage | Progression Impact |
| --- | --- | --- | --- | --- | --- |
| ember_sprite | Common | 35.807% | 1/3 | 3 | Starter floor. |
| sun_sprite | Common | 26.042% | 1/4 | 5 | Early upgrade. |
| moon_sprite | Common | 19.531% | 1/5 | 8 | Good early common. |
| crystal_sprite | Rare | 8.952% | 1/11 | 14 | Noticeable early speedup. |
| crescent_sprite | Rare | 6.510% | 1/15 | 22 | Strong Zone 2-3 pet. |
| rune_stone | Rare | 3.092% | 1/32 | 38 | Rebirth-push pet. |
| crimson_glyph | Mythic | 0.065% | 1/1,538 | 110 | Jackpot, but not economy-breaking. |
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

A huge rainbow crimson becomes about 366 damage, not 2,240. It still creates a huge early advantage, but it does not erase Zone 5+.

## 9. Bounded Luck formula

Replace "Luck = number of roll attempts" with a rarity-weighted single-roll CDF. This avoids linear CPU cost.

QualityPower(Luck) =
  0.35 * (1 - exp(-(max(1, Luck) - 1) / 18))

AdjustedWeight(petOutcome, Luck) =
  BaseChance(petOutcome) ^ (1 - QualityPower(Luck))

FinalChance(petOutcome, Luck) =
  AdjustedWeight / sum(AllAdjustedWeights)

Implementation notes:

Server samples exactly one outcome per roll.
Cache CDF by rounded Luck bucket, e.g. floor(Luck * 10 + 0.5) / 10.
Max evaluated outcomes = 105.
Max random samples per roll = 1.
| Luck | QualityPower | Rare+ Chance | Any crimson_glyph | Huge rainbow crimson |
| --- | --- | --- | --- | --- |
| 1 | 0.000 | 18.6% | 0.065% / 1 in 1,538 | 0.00059% / 1 in 170,938 |
| 2 | 0.019 | 19.0% | 0.073% / 1 in 1,379 | 0.00068% / 1 in 146,479 |
| 5 | 0.070 | 20.2% | 0.097% / 1 in 1,028 | 0.00103% / 1 in 96,916 |
| 10 | 0.138 | 21.9% | 0.144% / 1 in 695 | 0.00178% / 1 in 56,039 |
| 25 | 0.258 | 25.0% | 0.285% / 1 in 351 | 0.00463% / 1 in 21,592 |
| 50 | 0.327 | 27.1% | 0.422% / 1 in 237 | 0.00796% / 1 in 12,560 |
| 100 | 0.349 | 27.7% | 0.476% / 1 in 210 | 0.00941% / 1 in 10,623 |

This feels good because Luck improves the whole rare tail without making the server perform 100 roll attempts at Luck 100.

## 10. Boosts and potion economy

Keep current stacking behavior: using a potion extends the end time from max(now, existingEndTime) + duration. Add an 8-hour active-duration cap per boost to avoid extreme stacked timers.

| Potion | Effect | Duration | Gem Cost | Free Sources | Expected Use Case |
| --- | --- | --- | --- | --- | --- |
| Essence Potion | 2x Essence | 15 min | 35 Gems | Rush, login streak, starter quests | Zone/Rebirth/Ascension push. |
| Lucky Ritual Potion | 2x displayed Luck | 15 min | 45 Gems | Rush, achievements, rare daily reward | Focused roll session. |
| Roll Flow Potion | +50% Roll Speed | 15 min | 30 Gems | Rush premium, weekly chest | Collection session. |
| Pet Power Potion | +50% pet damage | 15 min | 40 Gems | Rush premium, starter pack | High-zone crystal push. |

Do not sell "random potion packs" at launch. Sell individual, guaranteed potions or Gem packs.

## 11. Ritual Rush daily track

The current track risks being dominated by Rebirth points or idle crystal breaks. Use source caps so active players finish the track, but AFK crystal farming alone does not.

Points
| Source | Points | Daily Cap | Notes |
| --- | --- | --- | --- |
| Roll pet | 1 | 400 | Keeps rolling relevant. |
| Crystal broken | 2 | 600 | Prevents pure idle completion. |
| Buy stone upgrade | 8 | 400 | Good active progression signal. |
| Unlock zone | 40 | 400 | Big milestone. |
| Rebirth | 120 | 480 | Strong, but not dominant. |
| First Rebirth of day bonus | +80 | 80 | Retention hook. |
| Ascension | 500 | 500 | Rare celebration. |
Milestones
| Milestone | Points | Free Reward | Premium Reward | Expected Time |
| --- | --- | --- | --- | --- |
| 1 | 25 | 60 Essence | 3 Gems | 2-4 min |
| 2 | 75 | 5 Gems | 100 Essence | 5-8 min |
| 3 | 150 | 1 Essence Potion | 8 Gems | 10-15 min |
| 4 | 300 | 250 Essence + 8 Gems | 1 Luck Potion | 20-30 min |
| 5 | 600 | 700 Essence | 20 Gems | 35-50 min |
| 6 | 1,000 | 1 Luck Potion + 15 Gems | 1 Essence Potion + 35 Gems | 55-80 min |
| 7 | 1,500 | 2,000 Essence + 30 Gems | 75 Gems | 75-105 min |
| 8 | 2,200 | 50 Gems + daily title progress | 150 Gems + 1 of each potion | 90-130 min |

Code improvement: make Essence rewards dynamic, such as min(configAmount, floor(CurrentCapacity * 0.35)), or let Rush Essence overflow capacity into a temporary claim inbox. Otherwise, capacity clamping makes rewards feel wasted.

## 12. Ritual Gems economy

Set new profiles to 0 or 20 Gems, not 1,000. The current 1,000 should remain test-only.

| Source/Sink | Amount | Frequency | Player Type | Notes |
| --- | --- | --- | --- | --- |
| Tutorial total | 15 Gems | Once | All | Enough to taste premium currency, not buy many potions. |
| Daily login | 5-20 Gems | Daily | Casual+ | 5, 5, 10, 10, 15, 15, 20 loop. |
| Ritual Rush free | 80-110 Gems + potions | Daily if active | Active | Main free source. |
| First Rebirth of day | 10 Gems | Daily | Engaged | Reinforces reset loop. |
| Achievements | 5-100 Gems | One-time | All | Rolls, zones, Rebirths, Ascensions. |
| Essence Potion | -35 Gems | Repeat sink | All | Main progression sink. |
| Luck Potion | -45 Gems | Repeat sink | Collectors | Main collection sink. |
| Roll Flow Potion | -30 Gems | Repeat sink | Roll-focused | Comfort sink. |
| Pet Power Potion | -40 Gems | Repeat sink | Pushers | Zone-push sink. |
| Cosmetic title/aura | -100 to -500 Gems | Optional | Collectors | Non-power sink. |
| Piggy Bank break | Robux, not Gems | Later | Spenders | Direct purchase, not random. |
Gem packs
| Product | Gems | Suggested Robux | Notes |
| --- | --- | --- | --- |
| Small Pouch | 80 | 49 | Entry pack; about 2 potions. |
| Ritual Cache | 250 | 149 | Good first real pack. |
| Gem Trove | 650 | 349 | Mid pack. |
| Ancient Hoard | 1,400 | 699 | Better value. |
| Ascendant Vault | 3,200 | 1,499 | Whale pack, not needed for normal play. |

These prices should be A/B tested after live telemetry.

## 13. Store and paid acceleration design

Mobile F2P patterns commonly rely on direct currency, boosters, limited-time offers, battle/season passes, piggy banks, and VIP-style systems; GameRefinery notes limited-time IAP offers are very common in top-grossing mobile games, and piggy banks/VIP systems are common genre-dependent monetization mechanics. Piggy banks work by filling from play and offering better value than standard store purchases, usually after players are already engaged rather than immediately at install.

Launch products
| Product | Type | Price | Effect | P2W / P2Progress? | Expected Grind Reduction | Launch? |
| --- | --- | --- | --- | --- | --- | --- |
| Gem packs | Developer Product | 49-1,499 Robux | Guaranteed Gems | Pay-to-progress | Depends on potions | Yes |
| Premium Rush | Developer Product | 149 Robux | Unlock premium row for current daily track | Pay-to-progress | 10-25% daily value boost | Yes |
| Starter Pack | One-time tracked product | 99 Robux | 250 Gems + 1 Essence Potion + 1 Luck Potion + title | Pay-to-progress | 20-35% faster first hour | Yes |
| Essence Potion direct | Developer Product | 19-29 Robux | Grants 1 potion, not instant activation | Pay-to-progress | Up to 2x during 15 min | Yes |
| Luck Potion direct | Developer Product | 29-39 Robux | Grants 1 potion | Pay-to-collect | Better rare odds | Yes |
| VIP | Pass | 299 Robux | Daily 20 Gems, VIP tag, +5% Essence | Mild P2Progress | 5-10% long-term | Soft launch |
| +1 Equipped Pet Slot | Pass | 399 Robux | 4 equipped pets instead of 3 | Pay-to-win/progress | 25-40% farming speed | Later or soft launch only |
| Auto Roll+ | Pass | 149 Robux | Saved filters, priority UI, no reward advantage | Convenience | 0% power | Later |
| Teleport Pass | Pass | - | Not recommended | - | - | Skip; teleport should stay free for unlocked zones |
| Zone unlock shortcut | Developer Product | - | Not recommended | Heavy P2W | Too high | Skip |
| Instant Rebirth | Developer Product | - | Not recommended | Heavy P2W | Too high | Skip |

Auto Roll should stay free. Hide Rolls should stay presentation-only and free. Monetizing basic automation would make the core loop feel hostile on mobile.

Piggy Bank, later
| Setting | Recommendation |
| --- | --- |
| Launch scope | Later, after Rush/Gems telemetry. |
| Fill source | Bonus Essence equal to 12% of earned Essence. Does not subtract from normal earnings. |
| Cap | max(1.5 * next zone unlock cost, 2 * current capacity), rounded. |
| Break price | 79-99 Robux early; scale only by bank tier, not by exact contents. |
| Free break | One free break after first Ascension, then weekly event-only free cracks. |
| Value | Better soft-currency value than Gem packs, but not premium currency at launch. |

## 14. Degenerate path analysis
| Risk | Analysis | Recommendation |
| --- | --- | --- |
| Best possible early pet | Proposed huge rainbow crimson is ~366 damage. It one-shots Zones 1-4 but not Zone 5+ by itself. | Accept as jackpot. Do not let one pet one-shot Ascension content. |
| Fastest first Rebirth | Without zone requirement, a lucky player could loop low zones. | Require Zone 3 for first two Rebirths, Zone 4 for Rebirths 3-4. |
| Fastest Ritual Rush | Rebirths and crystals can dominate. | Cap points by source. Keep completion around 45-60 min for boosted/lucky, 90-130 min normal active. |
| Potion stacking | Current extension behavior is good. | Add 8-hour cap per boost. |
| Capacity overflow | If reward is too large relative to remaining capacity, players feel punished. | Keep intended-zone crystal reward under ~25% of expected capacity; add "capacity full" prompt. |
| High Luck server cost | Current Luck creates linear roll attempts. | Replace with one-roll weighted CDF. Max samples per roll = 1. |
| Paid trivialization | +1 equip + potions + starter pack could cut first Ascension to 35-50 min. | Accept as pay-to-progress only if no instant Rebirth/Ascension/zone skips are sold. |
| Leaderboards | Paid equip slots and boosts affect Ritual Power and progress. | Either accept P2W leaderboards or add "free-progress" seasonal boards later. |

## 15. Implementation validation plan
Spreadsheet/script formulas
EffectivePetDamage =
  sum(EquippedPetFinalDamage)
  * RunePetPowerMultiplier
  * RebirthPetPowerMultiplier
  * AscensionPetPowerMultiplier
  * ActivePetPowerBoostMultiplier
  * StarPetPowerMultiplier

BreakSeconds =
  ceil(CrystalHP / EffectivePetDamage) * PetAttackIntervalSeconds

CrystalRewardActual =
  floor(BaseCrystalReward * RebirthEssenceMultiplier * AscensionEssenceMultiplier * ActiveEssenceBoostMultiplier * StarEssenceMultiplier)

EssencePerMinute =
  (60 / BreakSeconds) * CrystalRewardActual

TimeToTargetCostMinutes =
  max(0, TargetCost - CurrentEssence) / EssencePerMinute
  + TravelAndMenuTaxMinutes

CapacityWastePercent =
  max(0, CrystalRewardActual - (Capacity - CurrentEssence)) / CrystalRewardActual
Validation targets
| Metric | Target |
| --- | --- |
| Server roll samples per roll | 1 |
| Roll CDF outcomes evaluated | 105, cached by Luck bucket |
| Max practical rolls/min/player | ~40 at 400% Roll Speed |
| Max crystal breaks/min/player | 30 hard practical target |
| Capacity waste in intended zone | <10% normally, <25% when careless |
| First upgrade | 0:45-1:30 |
| Zone 2 | 5-7 min |
| Zone 3 | 14-18 min |
| First Rebirth | 18-24 min |
| First Ascension | 75-100 min |
| Ritual Rush casual progress | 40-60% in 25-45 min |
| Ritual Rush active completion | 90-130 min |
| Boosted first Ascension | 35-60 min, not instant |
Config-only first changes
Set new profile Gems to 0 or 20, not 1,000.
Tune Zones 1-5 to the new table.
Reduce Mythic damage and variant/size multipliers.
Update potion costs to 35/45 Gems.
Update Ritual Rush points and milestones.
Add real product IDs only for direct, guaranteed products.
Code changes needed
Replace linear Luck roll attempts with bounded weighted CDF.
Add curved capacity formula.
Add Rebirth minimum zone requirement.
Add Ascension minimum Rebirth requirement.
Add Rush point caps by source.
Add Ascension Star shop.
Add dynamic Rush Essence rewards or reward inbox.
Add boost duration cap.
Add analytics events for first roll, first break, first upgrade, Zone 2, Zone 3, first Rebirth, first Ascension, potion use, capacity full, and Rush completion.

## 16. Optional easy-improvement backlog
| Idea | Scope | Helps | Risk | Recommendation |
| --- | --- | --- | --- | --- |
| Capacity full HUD prompt | Easy | Clarity, feel | Low | Launch |
| Daily login Gems | Easy | Retention | Low | Launch |
| First Rebirth of day reward | Easy | Retention | Low | Launch |
| First-time zone unlock reward | Easy | Progression joy | Low | Launch |
| Tutorial overlay re-enabled | Medium | FTUE | Can annoy repeat players | Launch, skippable |
| Three daily quests | Medium | Retention | Adds UI | Launch if UI time exists |
| Playtime chest | Easy/Medium | Session length | Can feel AFK-focused | Later |
| Rare crystal bonus spawn | Medium | Moment-to-moment fun | Needs VFX/content | Later |
| Pet collection index rewards | Medium | Collection motivation | Needs UI | Later |
| Auto-delete filters | Medium | Inventory clarity | Requires pet inventory UX | Later |
| Extra equip slot unlocks from play | Medium | Retention | Balance impact | Later |
| Offline Essence bank | Medium/Large | Return loop | Can distort pacing | Later |
| Pet fusion/sacrifice | Large | Long-term depth | Adds complexity | Later |
| Paid random eggs | Large/compliance | Monetization | Policy and trust risk | Skip for launch |
| Zone skip purchase | Easy | Monetization | Destroys progression | Skip |
| Instant Ascension helper | Easy | Monetization | Destroys core loop | Skip |

The first implementation pass should focus on capacity curve, bounded Luck, Zone 1-5 values, Rebirth gating, pet damage, and Ritual Rush caps. Those changes address the biggest economy risks without adding a large new system.
