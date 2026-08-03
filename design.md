# Ritual Core Simulator Current Implementation

This document is a descriptive snapshot of what the current source code
implements.

Source code is the only implementation truth. If this document and source
disagree, trust the source and update this document after reading the code.

This file primarily documents implemented behavior. Clearly marked planned
sections record agreed design direction that is not current source behavior yet;
other future ideas and unimplemented product direction belong in planning notes
such as `todo.md`.

Current source areas covered by this document:

- `default.project.json`
- `wally.toml`
- `wally.lock`
- `src/server/init.server.luau`
- `src/server/Systems/Player/*.luau`
- `src/server/Systems/Ritual/*.luau`
- `src/server/Systems/Shop/*.luau`
- `src/server/Systems/World/*.luau`
- `src/server/Systems/Leaderboard/*.luau`
- `src/shared/Config/*.luau`
- `src/shared/Net/Network.luau`
- `src/shared/Util/NumberFormatter.luau`
- `src/client/init.client.luau`
- `src/client/Systems/State/ClientStateStore.luau`
- `src/client/Systems/World/*.luau`
- `src/client/Systems/Ritual/*.luau`
- `src/client/Systems/UI/*.luau`
- `src/client/Systems/UI/**/*.luau`
- `assets/images/**`
- `assets/pets/**`

## Source-Reviewed Implementation Checklist

This broad documentation pass was checked against the current `src` tree on
June 4, 2026.

- [x] Server and client startup order is documented from the current init files.
- [x] Rojo service mapping and Wally dependencies are documented from the current
  project files.
- [x] ProfileStore session load, Studio mock storage, autosave, player removal
  release, and session-end kick behavior are implemented.
- [x] Durable profile version `5` stores core progression, first Ascension
  progress, Ritual Rush state, processed purchase ids, active boost records,
  tutorial progress, pets, and equipped pet ids.
- [x] Server mutation entry points checked in this pass use the per-player
  profile operation queue: gameplay actions, snapshot reads, zone/farming ticks,
  developer product receipts, autosave, and player removal.
- [x] `RequestAction`, `RequestSnapshot`, and `RequestPublicVisuals` are
  rate-limited server-side.
- [x] Client snapshots retry on startup and ignore stale revisions.
- [x] Pet model replication publishes configured base models from
  `ServerStorage/PetModels` into `ReplicatedStorage/PetModels`.
- [x] Pet rolls, best-team auto equip, inventory display, roll viewports, and
  local world pet visuals use the configured final pet table and Studio-authored
  base models.
- [x] Crystal combat, pet targeting, damage, reward clamping, and respawn are
  server-owned.
- [x] Owner-local pet attack/headbutt visuals are separate from public remote
  player pet follow visuals.
- [x] Ritual Stone upgrades, rune upgrades, zone unlocks, teleport requests,
  rebirth, leaderstats, and generated leaderboards are implemented.
- [x] First Ascension is implemented as a Zone 5 statue reset with permanent
  Luck, crystal Essence, and Ritual Power bonuses.
- [x] Ritual Rush points, free reward claims, premium reward claim behavior, and
  daily event reconciliation are implemented.
- [x] Shop product catalog and server developer-product receipt handling are
  scaffolded for Gem packs, Premium Rush, and two boost grants.
- [x] Potion inventory, Ritual Rush potion rewards, Gem potion purchases, potion
  use, and active boost timers are implemented.
- [x] HUD overlays for shop, pet inventory, Ritual Core, rebirth, teleport,
  Ritual Rush, and roll presentation are implemented.
- [x] Tutorial progress and server gameplay completion are implemented, while
  the client tutorial overlay remains disabled in source.

## Project Mapping And Packages

Rojo mapping lives in `default.project.json`.

Service mappings:

- `ReplicatedStorage/Shared` maps to `src/shared`.
- `ReplicatedStorage/Packages` maps to `Packages`.
- `ServerScriptService/Server` maps to `src/server`.
- `StarterPlayer/StarterPlayerScripts/Client` maps to `src/client`.

The project file enables `Workspace.FilteringEnabled`, sets Lighting properties,
and sets `SoundService.RespectFilteringEnabled = true`.

Wally package files:

- `wally.toml`
- `wally.lock`

Direct dependencies in `wally.toml`:

- `React = jsdotlua/react@17.2.1`
- `ReactRoblox = jsdotlua/react-roblox@17.2.1`

## High-Level Loop

The implemented gameplay loop is:

1. Player data loads through ProfileStore.
2. The server creates runtime crystal state for the player's current zone.
3. The player rolls pets through the server.
4. Rolled pets are stored as counts keyed by final pet id.
5. The server recalculates the best equipped pet team after each roll.
6. Equipped pets attack server-owned crystals when the character is inside an
   unlocked zone and Essence capacity is available.
7. Breaking crystals awards capacity-clamped Essence.
8. Essence buys Ritual Stone upgrades, rune upgrades, and zone unlocks.
9. Ritual Rush points are awarded by server-owned gameplay events.
10. Rebirth spends no separate item; it requires enough Essence, increments
   `Rebirths`, resets the current loop, and keeps longer-term data.
11. First Ascension is available from a Zone 5 statue, resets the current run,
   keeps collection/progression records, and grants permanent account bonuses.

The current game has:

- 5 zones
- 5 crystals per zone
- 3 Ritual Stone upgrades
- 4 runes
- Ritual Gems profile, HUD display, and Rush reward earning plumbing
- Ritual Rush point accrual, free and premium-track claiming, and snapshot
  plumbing
- first Ascension through Zone 5
- shared shop product catalog for Gem packs, Premium Rush, and two boost offers
- server developer-product receipt handling for configured shop products
- purchase idempotence through durable processed purchase ids
- durable active boost grant storage
- 7 base pets
- 5 pet variants
- 3 pet sizes
- 105 final pet outcomes
- server-owned crystal combat
- server-owned profile progression
- local client world and UI visuals
- public visual replication for other players' stones and equipped idle/follow
  pets

## Startup Order

Server startup in `src/server/init.server.luau`:

1. `PetModelReplicationService.start()`
2. `PlayerStateService.start()`
3. `ShopPurchaseService.start()`
4. `WorldService.start()`
5. `ZoneTravelService.start()`
6. `PlayerVisualReplicationService.start()`
7. `LeaderboardService.start()`
8. `RitualService.start()`

`PetModelReplicationService` publishes Studio-authored models from
`ServerStorage/PetModels` into `ReplicatedStorage/PetModels` before gameplay
systems start. Clients clone pet visuals from `ReplicatedStorage/PetModels`.
Only base pet ids listed in `PetConfig.BaseRollOrder` are published. Missing
required templates and unused extra children under `ServerStorage/PetModels`
warn during startup.

Client startup in `src/client/init.client.luau`:

1. `WorldController.start()`
2. `RitualStoneVisualController.start()`
3. `ReplicatedPlayerVisualController.start()`
4. `HudController.start()`

`ClientStateStore.start()` is idempotent and is called by client systems that
need snapshots or actions.

## Ownership

Server owns:

- profile sessions, sync, save, and release
- Essence
- pet rolls
- pet inventory and equipped pet ids
- best-team calculation
- Ritual Stone upgrades
- rune upgrades
- zone unlock state
- teleport requests
- current active zone state
- rebirths
- tutorial completion data
- crystal health, target assignment, attack timing, rewards, and respawns
- leaderstats
- generated leaderboards
- public visual payloads for other clients

Client owns:

- local crystal parts, crystal labels, hit movement, and Essence fly-in effects
- local unlock wall parts and unlock prompts
- local equipped pet follower visuals
- local equipped pet attack/headbutt visuals for the owning player's crystals
- local Ritual Stone visual
- remote-player stone and idle/follow pet visuals from server public visual
  payloads
- React Lua HUD, overlays, and roll presentation
- requests to the server through remotes

The client does not directly grant Essence, pets, upgrades, runes, zones,
rebirths, crystal damage, crystal rewards, or tutorial gameplay completion.

## Networking

Remote folder:

- `ReplicatedStorage/RitualCoreRemotes`

Remote events:

- `CrystalStateUpdated`
- `PublicVisualUpdated`
- `PublicVisualRemoved`

Remote functions:

- `RequestAction`
- `RequestSnapshot`
- `RequestPublicVisuals`

Action names sent through `RequestAction`:

- `RollPet`
- `BuyStoneUpgrade`
- `UnlockZone`
- `SelectZone`
- `Rebirth`
- `Ascend`
- `BuyRune`
- `CompleteTutorialStep`
- `ClaimRitualRushReward`
- `ClaimRitualRushFreeReward`
- `UsePotion`
- `BuyPotionWithGems`

`Network.getRemoteEvent(name)` and `Network.getRemoteFunction(name)` create the
remote on the server when it is missing. On the client they wait for the remote
inside `ReplicatedStorage/RitualCoreRemotes`.

`RitualService` owns the `RequestAction` and `RequestSnapshot` server handlers.
`PlayerVisualReplicationService` owns the `RequestPublicVisuals` server
handler.

Action payload keys:

- `BuyStoneUpgrade`: `UpgradeId`
- `UnlockZone`: `ZoneId`
- `SelectZone`: `ZoneId`
- `BuyRune`: `RuneId`
- `CompleteTutorialStep`: `StepId`, `CompletionMode`
- `ClaimRitualRushReward`: `MilestoneId`
- `ClaimRitualRushFreeReward`: `MilestoneId`
- `UsePotion`: `PotionId`
- `BuyPotionWithGems`: `PotionId`

`RollPet`, `Rebirth`, and `Ascend` do not require payload fields. The client
sends an empty table for actions with no payload. The server reads payload keys
only when the payload is a table.

`RequestAction(player, actionName, payload)`:

1. validates that `actionName` is a string and configured action
2. rate-limits malformed/unknown requests with a stricter per-player bucket
3. rate-limits known actions with a generous per-player bucket
4. dispatches allowed known action names to the matching `PlayerStateService`
   action
5. wraps table action results with `SnapshotPublisher.attach` unless
   `result.Ok == false` and `result.Roll` is a table, which is the roll-busy
   response
6. returns the result to the caller

Current `RequestAction` rate limits:

- known actions: capacity `10`, refill `5` tokens per second
- malformed or unknown actions: capacity `4`, refill `1` token per second
- minimum retry-after value `0.05` seconds

Current snapshot/public visual rate limits:

- `RequestSnapshot`: capacity `4`, refill `1` token per second
- `RequestPublicVisuals`: capacity `3`, refill `0.5` tokens per second

Per-player rate-limit buckets are cleared on `Players.PlayerRemoving`.

Malformed, unknown, throttled, non-table action failures, and roll-busy results
return directly and are not wrapped with `SnapshotPublisher.attach`.

`RequestAction` is wrapped in `pcall`. If action processing errors, the server
warns and returns `{ Ok = false, Message = "Action failed." }`.

`SnapshotPublisher.attach`:

1. increments `SnapshotRevision`
2. syncs the profile session through `ProfilePersistence.sync`
3. updates leaderstats from the committed profile state
4. publishes the player's public visual payload
5. attaches a fresh snapshot as `result.Snapshot`

`SnapshotPublisher.publishCrystalUpdate` uses the same committed profile path,
then fires `CrystalStateUpdated` with the incremental crystal update.

There is no `SnapshotUpdated` remote event in the current network module.
Full snapshots are returned by `RequestSnapshot` and by `RequestAction` results
that are wrapped with `SnapshotPublisher.attach`. Incremental crystal-related
changes are sent with `CrystalStateUpdated`.

`RequestSnapshot` waits up to the default profile-load timeout (`10` seconds)
and returns `PlayerStateService.getSnapshot(player)`. It does not increment
revision, sync the profile, update leaderstats, or publish public visuals. If
the per-player snapshot rate limit is exceeded, it returns `nil`.

`RequestPublicVisuals` returns public visual payloads for other players, not the
requesting player. If the per-player public visual request rate limit is
exceeded, it returns an empty list.

There is no client crystal-claim remote.

## Profile Data

The profile template is in
`src/server/Systems/Player/ProfileTemplate.luau`.

ProfileStore data store name:

- `RitualCoreProfiles_v1`

Data version:

- `5`

Storage selection:

- Studio uses `baseProfileStore.Mock`.
- Non-Studio uses `baseProfileStore`.

Durable profile fields:

- `Version`
- `Essence`
- `RitualGems`
- `Rolls`
- `BestRitualPower`
- `HighestCapacity`
- `RarestPetId`
- `RarestPetScore`
- `CurrentZone`
- `UnlockedZones`
- `StoneLevels`
- `RuneLevels`
- `Rebirths`
- `Ascensions`
- `AscensionStars`
- `AscensionUpgrades`
- `RitualRush`
- `ProcessedPurchaseIds`
- `ActiveBoosts`
- `Potions`
- `TutorialCompletedSteps`
- `Pets`
- `EquippedPetIds`

New profile defaults:

- `Version = 5`
- `Essence = 0`
- `RitualGems = 1000`
- `Rolls = 0`
- `BestRitualPower = 0`
- `HighestCapacity = RitualStoneConfig.BaseStats.Capacity`
- `RarestPetId = nil`
- `RarestPetScore = 0`
- `CurrentZone = 1`
- `UnlockedZones[1] = true`
- `StoneLevels.Capacity = 0`
- `StoneLevels.Luck = 0`
- `StoneLevels.RollSpeed = 0`
- `RuneLevels.capacity = 0`
- `RuneLevels.luck = 0`
- `RuneLevels.ritual_speed = 0`
- `RuneLevels.pet_power = 0`
- `Rebirths = 0`
- `Ascensions = 0`
- `AscensionStars = 0`
- `AscensionUpgrades = {}`
- `RitualRush.EventId = current Ritual Rush event id`
- `RitualRush.Points = 0`
- `RitualRush.PremiumUnlocked = false`
- `RitualRush.ClaimedFreeMilestones = {}`
- `RitualRush.ClaimedPremiumMilestones = {}`
- `ProcessedPurchaseIds = {}`
- `ActiveBoosts = {}`
- `Potions = {}`
- `TutorialCompletedSteps = {}`
- `Pets = {}`
- `EquippedPetIds = {}`

Runtime fields added by `ProfileTemplate.applyRuntimeDefaults`:

- `RollReadyAt = 0`
- `CrystalState = nil`
- `CrystalAttackState = {}`
- `CrystalAttackSequence = 0`
- `LastCrystalAttacks = {}`
- `CrystalFarmingActive = false`
- `SnapshotRevision = 0`

`ProfileTemplate.applyRuntimeDefaults` reconciles `RitualRush` to the current
daily event id. Existing or stale Rush progress resets when the event id
changes. It also ensures `ProcessedPurchaseIds`, `ActiveBoosts`, and `Potions`
are tables when loading older or malformed profile data, then normalizes active
boosts through `BoostConfig`, potion inventory through `PotionConfig`, and
Ascension numeric/table fields through runtime defaults.

`CrystalState` is runtime-only in the current template. `ProfilePersistence`
copies only keys from the durable profile template into ProfileStore session
data, so crystal records are not currently saved as durable profile data.

Saved pet inventory shape:

```text
Pets[finalPetId] = count
```

Saved equipped pet shape:

```text
EquippedPetIds = { finalPetId, finalPetId, ... }
```

The same final pet id can appear more than once in `EquippedPetIds` when the
player owns multiple copies.

Saved Ascension shape:

```text
Ascensions = number
AscensionStars = number
AscensionUpgrades = {}
```

`AscensionUpgrades` is saved for future upgrade-shop use. Current source applies
automatic permanent bonuses from `Ascensions`; it does not spend stars yet.

Saved processed purchase shape:

```text
ProcessedPurchaseIds[purchaseId] = true
```

Saved active boost shape:

```text
ActiveBoosts[boostId] = {
  BoostId = boostId,
  Multiplier = multiplier,
  EndsAtUnix = unixTimestamp,
}
```

Active boost records are normalized by `BoostConfig`. Expired or unknown boost
records are ignored by gameplay and pruned when runtime defaults or persistence
commit paths touch the profile. Player snapshots expose active boosts as a
sanitized `ActiveBoosts` array with display text, icon id, multiplier, expiry,
and remaining seconds. Public visual snapshots do not include boost state.

Saved potion inventory shape:

```text
Potions[potionId] = count
```

Potion inventory records are normalized by `PotionConfig`. Unknown potion ids
and non-positive counts are ignored. Player snapshots expose a sanitized
`Potions` array with potion display data, owned count, Gem cost, shop
availability, and the boost grant the potion applies when used.

## Profile Load And Save

`ProfilePersistence.startSession`:

- starts a ProfileStore session with key `Player_<UserId>`
- cancels session start if the player leaves before loading completes
- adds the user id
- runs ProfileStore `Reconcile`
- creates a runtime profile copy
- copies durable template fields back into the ProfileStore session data

`PlayerStateService.loadProfileForPlayer` then:

- backfills tutorial progress from existing `Rebirths`, stone upgrades, or rolls
- ensures runtime `CrystalState` exists
- clears crystal attack, last-attack, sequence, and farming-active runtime state
- commits best-progress records
- syncs the profile session
- stores the runtime profile in `profilesByPlayer`
- updates leaderstats
- publishes public visuals
- teleports the character to `profile.CurrentZone`

If profile loading fails while the player is still present, the server kicks the
player with a rejoin message. If an active profile session ends while the player
is still present, the server clears the runtime profile and kicks the player.

Autosave runs every `60` seconds and calls `savePlayer` for loaded profiles.

On player removal, the server commits progress records, copies durable fields to
the ProfileStore session, and ends the session.

`ProfilePersistence.sync` copies durable fields into active session data but
does not call `session:Save()`. `ProfilePersistence.save` copies durable fields
and then calls `session:Save()`. Both return `false` when there is no active
session.

The current code does not contain a custom legacy migration pass. ProfileStore
reconciliation supplies missing default fields, and durable sync copies only the
current template keys.

## Profile Operation Queue

`PlayerStateService.withProfileLock(player, callback)` serializes current
per-player profile work with a FIFO table queue and `task.wait()` polling while
the caller waits for its token to reach the front of the queue.

The source entry points checked in this pass use this queue for profile reads or
mutations that can overlap:

- `RequestAction`
- `RequestSnapshot`
- `ZoneTravelService` zone and crystal-farming ticks
- `ShopPurchaseService` developer product receipt processing
- autosave
- `Players.PlayerRemoving` release

The queue is a simple serialization helper, not a separate data model. Callback
errors are rethrown after the token is removed, and empty queues are cleared from
`profileOperationQueuesByPlayer`.

## Snapshots

`PlayerStateService.getSnapshot(player)` reads the loaded profile and delegates
full client snapshot construction to `PlayerDerivedState.getSnapshot(profile)`.
`PlayerDerivedState` also owns read-only public visual, crystal update, roll
state, derived ritual runtime, eligibility, and leaderstats payload construction.

Snapshot fields:

- `Essence`
- `RitualGems`
- `Rolls`
- `CurrentZone`
- `Zones`
- `StoneLevels`
- `StoneStats`
- `RebirthRequirement`
- `NextUpgradeCosts`
- `RuneUnlock`
- `Roll`
- `Runes`
- `Rebirths`
- `Ascensions`
- `AscensionStars`
- `Ascension`
- `RitualRush`
- `ActiveBoosts`
- `Potions`
- `Tutorial`
- `Crystal`
- `BestRitualPower`
- `HighestCapacity`
- `RarestPetId`
- `RarestPetScore`
- `Pets`
- `EquippedPetIds`
- `EquippedPets`
- `MaxEquippedPets`
- `RitualPower`
- `Revision`

Nested snapshot shapes:

- `StoneLevels[upgradeId] = level`
- `NextUpgradeCosts[upgradeId] = cost`
- `RebirthRequirement`: `RequiredEssence`, `CanRebirth`
- `RuneUnlock`: `IsUnlocked`, `RequiredZone`, `RequiredRebirths`
- `Ascension`: `Ascensions`, `AscensionStars`, `RequiredZone`,
  `RequiredZoneExists`, `CanAscend`, `StarReward`, `Bonus`, `NextBonus`,
  `BonusDelta`
- `Roll`: `IsBusy`, `RetryAfter`
- `Zones[]`: `ZoneId`, `DisplayName`, `IsUnlocked`, `IsCurrent`, `CanUnlock`,
  `UnlockCost`, `CrystalHealth`, `CrystalEssenceReward`
- `Runes[]`: `RuneId`, `DisplayName`, `Description`, `Level`, `MaxLevel`,
  `NextCost`, `IsMaxed`, `IsUnlocked`
- `RitualRush`: `EventId`, `DisplayName`, `StartsAtUnix`, `EndsAtUnix`,
  `Points`, `PremiumUnlocked`, `NextMilestone`, `Milestones`
- `RitualRush.NextMilestone`: `MilestoneId`, `RequiredPoints`,
  `RemainingPoints`
- `RitualRush.Milestones[]`: `MilestoneId`, `RequiredPoints`, `FreeReward`,
  `PremiumReward`, `IsReached`, `IsFreeClaimed`, `IsPremiumClaimed`
- `RitualRush.Milestones[].FreeReward`: `Essence`, `RitualGems`, `Potions`
- `RitualRush.Milestones[].PremiumReward`: `Essence`, `RitualGems`,
  `Potions`
- `ActiveBoosts[]`: `BoostId`, `DisplayName`, `ShortDisplayName`,
  `Description`, `IconId`, `Multiplier`, `EndsAtUnix`, `RemainingSeconds`
- `Potions[]`: `PotionId`, `DisplayName`, `ShortDisplayName`, `Description`,
  `IconId`, `Count`, `GemCost`, `IsShopEnabled`, `BoostGrant`
- `Pets[]`: `PetId`, `Count`, `EquippedCount`, `StoredCount`, `IsEquipped`
- `EquippedPets[]`: `Uid`, `SlotId`, `PetId`

Snapshot building does not intentionally mutate gameplay state. It does not
roll pets, collect crystal rewards, process farming, save, sync, or publish
public visuals.

`PlayerStateService.getCrystalUpdate(player)` delegates to
`PlayerDerivedState.getCrystalUpdate(profile)` and returns an incremental
update with:

- `Essence`
- `RitualGems`
- `CurrentZone`
- `Zones`
- `RebirthRequirement`
- `StoneLevels`
- `StoneStats`
- `Ascensions`
- `AscensionStars`
- `Ascension`
- `RitualRush`
- `ActiveBoosts`
- `Potions`
- `Crystal`
- `Roll`
- `RitualPower`
- `Revision`

`ClientStateStore` keeps the latest snapshot and ignores stale full snapshots or
crystal updates when their numeric `Revision` is lower than the current revision.

## Ritual Stone Stats

Base stats:

- `Capacity = 100`
- `Luck = 1`
- `RollSpeedPercent = 100`

Roll speed clamp:

- minimum `25`
- maximum `400`

Stone upgrades:

- `Capacity`
  - base cost `12`
  - cost growth `1.35`
  - amount `+75 Capacity`
- `Luck`
  - base cost `18`
  - cost growth `1.42`
  - amount `+0.1 Luck`
- `RollSpeed`
  - base cost `22`
  - cost growth `1.45`
  - amount `+5 RollSpeedPercent`

Stone upgrade cost formula:

```text
floor(BaseCost * CostGrowth ^ currentLevel)
```

Stat formulas:

```text
Capacity =
  100
  + CapacityLevel * 75
  + RuneCapacityBonus

Luck =
  1
  + LuckLevel * 0.1
  + Rebirths * 0.05
  + RuneLuckBonus

RollSpeedPercent =
  clamp(100 + RollSpeedLevel * 5 + RuneRollSpeedPercentBonus, 25, 400)

RebirthMultiplier =
  1 + Rebirths * 0.25
```

Equipped pet power:

```text
sum(PetConfig.getPetPower(equippedPetId) * RunePetPowerMultiplier)
```

Ritual Power:

```text
floor(Capacity + Luck * 100 + EquippedPetPower * 25 + Rebirths * 500)
```

Progress records update from current runtime stats:

- `BestRitualPower` keeps the highest Ritual Power seen by commit paths.
- `HighestCapacity` keeps the highest capacity seen by commit paths.
- `RarestPetId` and `RarestPetScore` keep the rarest owned pet by rarity score.

## Roll Timing

Roll opening config:

- `FlashSteps = 16`
- `BaseStepDelay = 0.045`
- `StepDelayGrowth = 0.009`
- `MinDurationScale = 0.25`
- `MaxDurationScale = 1.75`
- `PetRevealSeconds = 1`

Duration scale:

```text
clamp(100 / RollSpeedPercent, 0.25, 1.75)
```

Roll opening duration:

```text
sum over steps 1..16 of
  (0.045 + step * 0.009) * durationScale
```

Server roll cadence:

```text
rollOpeningDuration + 1 second reveal time
```

The server stores the next allowed roll time in runtime field `RollReadyAt`.
`RollReadyAt` is not durable profile data.

## Essence

Essence is stored on durable field `profile.Essence`.

Crystal rewards are clamped to current capacity:

```text
Essence = min(Capacity, Essence + max(0, awardAmount))
```

If remaining capacity is `0`, pets do not attack crystals and crystal snapshots
do not expose active pet targets.

If a crystal reward is larger than the remaining capacity, the player receives
only the amount that fits. The crystal still respawns after the awarded amount is
applied.

## Zones

Zone data lives in `src/shared/Config/ZoneConfig.luau`.

Implemented zones:

1. `Starter Zone`
   - unlock cost `0`
   - origin `(0, 0, 0)`
   - bounds offset `(0, 0, -5)`
   - bounds size `(58, 0, 66)`
   - crystal health `12`
   - crystal reward `6`
   - crystal count `5`
2. `Moon Ruins`
   - unlock cost `200`
   - origin `(72, 0, 0)`
   - bounds offset `(0, 0, -5)`
   - bounds size `(62, 0, 68)`
   - crystal health `34`
   - crystal reward `28`
   - crystal count `5`
3. `Rune Grounds`
   - unlock cost `600`
   - origin `(148, 0, 0)`
   - bounds offset `(0, 0, -5)`
   - bounds size `(66, 0, 70)`
   - crystal health `95`
   - crystal reward `82`
   - crystal count `5`
4. `Solar Grove`
   - unlock cost `1600`
   - origin `(228, 0, 0)`
   - bounds offset `(0, 0, -5)`
   - bounds size `(70, 0, 72)`
   - crystal health `260`
   - crystal reward `220`
   - crystal count `5`
5. `Ascension Court`
   - unlock cost `4200`
   - origin `(312, 0, 0)`
   - bounds offset `(0, 0, -5)`
   - bounds size `(74, 0, 74)`
   - crystal health `720`
   - crystal reward `620`
   - crystal count `5`

Bounds checks use `ZoneConfig.isPositionInsideBounds`.

The configured bounds have `Y` size `0`, so zone detection behaves as an X/Z
area check for the current zones.

`ZoneTravelService` polls every `0.25` seconds. Each poll:

1. resolves the character root position
2. calls `enterActiveZone` if the position is inside a configured zone
3. calls `exitActiveZone` if the position is outside all configured zones
4. calls `processCrystalFarming`
5. asks `SnapshotPublisher` to commit player state and publish a
   `CrystalStateUpdated` event when zone state or farming state changed

Entering an unlocked zone:

- changes `CurrentZone` if the zone differs from the previous current zone
- resets runtime crystal state for the new zone
- marks crystal farming active

Entering a locked zone:

- does not change `CurrentZone`
- marks crystal farming inactive

Leaving all zone bounds:

- leaves `CurrentZone` as the last current zone
- marks crystal farming inactive

Zone unlock requirements:

- `zoneId` must be a number
- the zone must exist
- the previous configured zone must be unlocked when there is a previous zone
- the character must be near that zone's unlock wall
- current Essence must cover the zone cost

If the requested zone is already unlocked, `UnlockZone` returns success with an
"already unlocked" message and does not spend Essence.

Successful zone unlock:

- subtracts the zone unlock cost from Essence
- sets `profile.UnlockedZones[zoneId] = true`
- awards `+50` Ritual Rush points
- does not teleport the character
- does not directly make the client authoritative for farming

`SelectZone` is a teleport request for already-unlocked zones. It validates that
the zone exists and is unlocked, pivots the character to the configured zone
spawn CFrame when possible, then resolves active zone state from the character's
server-side position.

## Generated World

`WorldService` creates `Workspace/GeneratedRitualWorld`.

On start, `WorldService` destroys an existing `GeneratedRitualWorld` folder
before recreating it.

For each configured zone, `WorldService` creates a non-colliding visible bounds
marker named `Zone<id>Bounds`.

For zone 1, `WorldService` also creates an invisible `SpawnLocation` named
`PlayerSpawn`.

The server-generated world does not create zone pads or unlock walls. Current
unlock walls are client-local visuals created by `WorldController` from snapshot
zone state.

`WorldController` creates `Workspace/LocalRitualPreview` on the client and owns:

- local crystals
- local unlock walls
- local unlock prompts
- local equipped pet visuals
- local pet attack movement
- Essence fly-in parts

Client unlock walls are presentation and local collision. Server unlock
validation still checks the character position against `ZoneConfig`.

## Crystal Combat

Crystal combat is implemented in
`src/server/Systems/Ritual/CrystalCombat.luau`.

Current crystal state is runtime profile data:

- `CrystalState.ZoneId`
- `CrystalState.Crystals`
- `CrystalState.NextCrystalId`

Each crystal record has:

- `CrystalId`
- `Health`
- `Position`

Crystal records sent to the client also include `MaxHealth`.

Runtime combat fields:

- `CrystalAttackState`
- `CrystalAttackSequence`
- `LastCrystalAttacks`
- `CrystalFarmingActive`

Crystal state is created or reset when:

- runtime state is missing
- runtime state zone does not match `CurrentZone`
- `CurrentZone` changes through unlocked-zone entry
- rebirth resets to zone 1
- Ascension resets to zone 1

`CrystalCombat.ensureState` repairs runtime crystal state by falling back to
zone 1 when `CurrentZone` is not configured, trimming or filling the crystal
array to the configured count, assigning missing crystal ids, clamping health,
and replacing missing or out-of-bounds crystal positions.

Server attack behavior:

1. Farming only processes when `CrystalFarmingActive == true`.
2. The current zone's runtime crystal state is ensured before processing.
3. If available capacity is `0`, attacks stop with reason
   `StoneCapacityFull`.
4. Attack state is kept per equipped slot id.
5. Each equipped slot gets one target crystal when it has no valid target.
6. A newly assigned pet target schedules first damage for `now + 2` seconds.
7. Each ready pet applies direct damage to its current target.
8. Damage uses `PetConfig.getPetDamage(petId, RunePetPowerMultiplier)`.
9. If a target reaches `0` health, the server awards clamped Essence and
   immediately respawns that crystal slot with a new crystal id and position.
10. Pets targeting a broken crystal are retargeted and wait at least one attack
    interval before their next hit.

Pet attack interval:

```text
PetConfig.BaseAttackInterval = 2
```

Crystal reward formula:

```text
floor(zone.CrystalEssenceReward * StoneStats.EssenceMultiplier * ActiveEssenceBoostMultiplier)
```

`StoneStats.EssenceMultiplier` is the permanent run multiplier, currently
`RebirthMultiplier * AscensionEssenceMultiplier`. Temporary Essence potion
boosts are applied separately through `ActiveEssenceBoostMultiplier`.

Crystal snapshot fields:

- `ZoneId`
- `IsFarmingActive`
- `Crystals`
- `CurrentCrystalReward`
- `CanStoreCurrentCrystalReward`
- `AvailableCapacity`
- `MissingCapacity`
- `AttackSequence`
- `LastAttacks`
- `PetTargets`

`AttackSequence` increments only when the server creates one or more attack
payloads. `LastAttacks` is replaced on each crystal combat step.

Each attack payload can include:

- `PetUid`
- `CrystalId`
- `Damage`
- `RemainingHealth`
- `Position`
- `DidBreak`
- `EssenceAwarded`
- `RespawnedCrystalId`

The client uses crystal snapshots and attack payloads for visuals only.

## Crystal Settlement Around Actions

The helper `syncAndCollectCrystalReward` calls
`CrystalCombat.collectFinishedReward` with current stats.

Current action settlement behavior:

- `buyStoneUpgrade` validates the upgrade first, then settles before checking
  Essence and applying the upgrade.
- `buyRune` validates profile, payload type, rune unlock, and rune existence,
  then settles before checking max level and cost.
- `rebirth` settles before checking the Essence rebirth requirement.
- `rollPet` checks roll cadence before settlement; busy rolls return without
  calling settlement.
- `usePotion` settles before consuming the potion and applying the boost.
- `buyPotionWithGems` does not call settlement because buying only changes Gems
  and potion inventory.
- `unlockZone` does not call settlement.
- `selectZone` does not call settlement.

After a successful stone upgrade or rune purchase, the server tries crystal
reward collection again with updated stats.

`collectFinishedReward` only handles existing crystals with `Health <= 0`.
Normal attack processing respawns a killed crystal immediately in the same
server step.

When action settlement or the post-upgrade collection pass collects a finished
crystal reward, the server also awards Ritual Rush crystal-break points.

## Ritual Rush Progression

Ritual Rush config lives in `src/shared/Config/RitualRushConfig.luau`.

Event id:

- daily id with prefix `ritual_rush_`

Event duration:

- `24` hours

Point sources:

- successful pet roll: `+1`
- crystal broken: `+3`
- successful Ritual Stone upgrade: `+10`
- successful zone unlock: `+50`
- successful rebirth: `+200`

Milestone thresholds:

- `10`: `75` Essence
- `25`: `5` Ritual Gems
- `50`: `180` Essence and one `2x Essence Potion`
- `100`: `10` Ritual Gems and one `Lucky Ritual Potion`
- `250`: `700` Essence
- `500`: `1500` Essence and `20` Ritual Gems
- `1000`: `4000` Essence and `50` Ritual Gems

Rush progress is durable profile data under `RitualRush`.

Rush progress reconciles against the current daily event id. When the daily
event id changes, stale progress is replaced with fresh progress for the new
event.

The server owns all Rush point awards. The client receives Rush progress in
full snapshots and crystal updates, but there is no client action that grants
Rush points.

Crystal break points are awarded by `PlayerStateService` after
`CrystalCombat.step` reports a `BreakCount`, keeping crystal combat independent
from Ritual Rush progression.

Ritual Rush reward claiming uses the milestone-level `ClaimRitualRushReward`
action. The legacy `ClaimRitualRushFreeReward` action delegates to the same
milestone claim so older call sites stay valid. The server validates that the
milestone exists and the player has enough Rush points. A claim applies the free
reward if it is unclaimed, and also applies the premium bonus when durable
`PremiumUnlocked` is already true and that premium milestone bonus is unclaimed.

Ritual Rush rewards currently support only Essence and Ritual Gems. Essence
rewards are capacity-clamped like crystal Essence rewards: a claim can succeed
at full capacity, but any Essence that does not fit is discarded. Ritual Gems
are not capacity-clamped.

## Pets

Pet data lives in `src/shared/Config/PetConfig.luau`.

Max equipped pets:

- `3`

Base attack interval:

- `2` seconds

Base roll/model order:

- `ember_sprite`
- `sun_sprite`
- `moon_sprite`
- `crystal_sprite`
- `crescent_sprite`
- `rune_stone`
- `crimson_glyph`

Runtime pet visuals use these base ids to clone Studio-authored model templates
from `ReplicatedStorage/PetModels`, which is populated from
`ServerStorage/PetModels` at server startup. Historical or generated image files
under `assets/images/pets/**` and local source/model files under `assets/pets/**`
are not runtime pet configuration and can include names that are not present in
`PetConfig.BaseRollOrder`.

Current base pet table:

Common:

- `ember_sprite`: Ember Sprite, Common, chance `0.22`, damage `2`
- `sun_sprite`: Sun Sprite, Common, chance `0.16`, damage `4`
- `moon_sprite`: Moon Sprite, Common, chance `0.12`, damage `6`

Rare:

- `crystal_sprite`: Crystal Sprite, Rare, chance `0.055`, damage `15`
- `crescent_sprite`: Crescent Sprite, Rare, chance `0.04`, damage `20`
- `rune_stone`: Rune Stone, Rare, chance `0.019`, damage `44`

Mythic:

- `crimson_glyph`: Crimson Glyph, Mythic, chance `0.0004`, damage `560`

Variants:

- `normal`: chance divisor `1`, damage multiplier `1`
- `glowy`: chance divisor `1.6`, damage multiplier `1.25`
- `golden`: chance divisor `2.4`, damage multiplier `1.5`
- `shadow`: chance divisor `3.2`, damage multiplier `1.75`
- `rainbow`: chance divisor `4.8`, damage multiplier `2`

Sizes:

- `normal`: chance divisor `1`, damage multiplier `1`, scale `1`
- `big`: chance divisor `1.5`, damage multiplier `1.5`, scale `1.35`
- `huge`: chance divisor `2`, damage multiplier `2`, scale `1.8`

Final pet id:

```text
<size prefix>_<variant prefix>_<basePetId>
```

Normal size and normal variant omit their prefixes.

Final pet damage:

```text
max(1, floor(BaseDamage * VariantDamageMultiplier * SizeDamageMultiplier + 0.5))
```

Rarity score:

```text
floor((1 / FinalChance) + 0.5)
```

## Pet Rolls

Pet rolling uses one global final-pet table. Current code does not choose
different pet pools per zone or rebirth.

Final chance is normalized from:

- base pet roll chance
- variant weight from chance divisor
- size weight from chance divisor

Luck controls roll attempts:

- `Luck` is clamped to at least `1`
- whole-number Luck gives that many guaranteed attempts
- the fractional Luck part is a chance for one extra attempt
- the rarest result by rarity score is kept

Examples:

```text
Luck 1.0 -> 1 guaranteed attempt
Luck 1.3 -> 1 guaranteed attempt and 30% chance for a second attempt
Luck 2.0 -> 2 guaranteed attempts
```

Roll validation:

- profile must exist
- server computes current stats
- roll cadence must not be busy
- the final pet table must return a pet id

Successful roll:

- sets `RollReadyAt` from current time plus server cadence
- increments `Rolls`
- completes tutorial through `first_roll`
- adds one count to the final pet id
- recalculates the best equipped team
- clears crystal attack runtime for changed equipped slots
- awards `+1` Ritual Rush point
- returns the rolled pet id and owned count

Rolls are free in current code.

Auto Roll is client-driven by repeatedly calling the same `RollPet` action as
the manual roll button. The server cadence still gates each successful roll, and
the client waits 0.2 seconds after a successful roll reveal before requesting the
next roll.

## Equipping Pets

Pets are automatically equipped into the best available team after each
successful roll. There are no manual equip or equip-best client actions.

The internal best-team helper sorts owned pet stacks by:

1. `PetConfig.getPetPower(petId)`, descending
2. rarity score, descending
3. pet id, ascending

It can equip multiple copies of the same final pet up to the owned count and
`PetConfig.MAX_EQUIPPED`.

The current HUD pet inventory overlay displays equipped and stored pets with
tooltips only.

## Rebirth

Rebirth config:

- base Essence requirement `180`
- Essence growth `1.65`
- multiplier per rebirth `0.25`
- Luck per rebirth `0.05`

Current rebirth requirement:

```text
RequiredEssence = floor(180 * 1.65 ^ Rebirths)
```

`canRebirth` checks only current Essence against `RequiredEssence`.

The current code does not require a specific current zone or capacity value for
rebirth.

Successful rebirth:

- increments `Rebirths`
- completes tutorial through `first_rebirth`
- awards `+200` Ritual Rush points
- sets Essence to `0`
- sets `CurrentZone` to `1`
- resets `UnlockedZones` to only zone 1
- resets stone levels to zero
- resets runtime crystal state to zone 1
- marks crystal farming inactive
- defers teleporting the player to zone 1

Rebirth keeps:

- pets
- equipped pet ids
- rune levels
- rolls
- best progress records
- tutorial completion

## Runes

Rune data lives in `src/shared/Config/RuneConfig.luau`.

Rune unlock rule:

```text
Rebirths >= 1 and UnlockedZones[3] == true
```

Current runes:

- `capacity`
  - display `Capacity Rune`
  - base cost `120`
  - cost growth `1.55`
  - max level `20`
  - bonus `+25 Capacity` per level
- `luck`
  - display `Luck Rune`
  - base cost `150`
  - cost growth `1.6`
  - max level `20`
  - bonus `+0.04 Luck` per level
- `ritual_speed`
  - display `Roll Speed Rune`
  - base cost `180`
  - cost growth `1.65`
  - max level `15`
  - bonus `+1.2 RollSpeedPercent` per level
- `pet_power`
  - display `Pet Power Rune`
  - base cost `180`
  - cost growth `1.65`
  - max level `20`
  - bonus `+0.04 PetPowerMultiplier` per level

Rune cost:

```text
floor(BaseCost * CostGrowth ^ level)
```

Buying a rune:

- profile must exist
- rune id must be a string
- runes must be unlocked
- rune must exist
- current level must be below max
- Essence must cover cost
- Essence is reduced by cost
- rune level increments by 1

After a rune purchase, the server tries crystal reward collection again with
updated stats.

## Tutorial

Tutorial config lives in `src/shared/Config/TutorialConfig.luau`.

Step order:

1. `intro`
2. `first_roll`
3. `first_stone_upgrade`
4. `first_rebirth`

Step completion sources:

- `intro`: client
- `first_roll`: server gameplay
- `first_stone_upgrade`: server gameplay
- `first_rebirth`: server gameplay

Durable tutorial field:

- `TutorialCompletedSteps`

Tutorial snapshot fields:

- `CurrentStepId`
- `IsComplete`
- `CompletedStepIds`
- `Steps`

Each tutorial step snapshot has:

- `StepId`
- `DisplayName`
- `IsComplete`

`CompleteTutorialStep`:

- requires a valid step id
- accepts completion mode `complete` or `skip`
- only operates on the currently active tutorial step
- skip is allowed for all current steps because no step sets `CanSkip = false`
- normal client completion is accepted only for client-completable steps

Gameplay actions complete tutorial through milestones:

- successful roll completes through `first_roll`
- successful stone upgrade completes through `first_stone_upgrade`
- successful rebirth completes through `first_rebirth`

Profile load backfill:

- `Rebirths > 0` completes through `first_rebirth`
- otherwise any stone upgrade completes through `first_stone_upgrade`
- otherwise any roll completes through `first_roll`

Client tutorial overlay code exists, but `TutorialOverlay.Enabled = false` in
the current file. Because of that flag, the HUD does not currently render
tutorial overlay steps or run the intro auto-completion flow.

## Shop Product Catalog And Receipts

Shop product configuration lives in
`src/shared/Config/ShopProductConfig.luau`.

Configured product types:

- `GemPack`
- `RitualRushPremium`
- `Boost`

Configured product ids:

- `gems_100`
- `gems_500`
- `gems_1500`
- `ritual_rush_premium`
- `boost_essence_2x_15m`
- `boost_luck_2x_15m`

Configured sections:

- `GemPacks`
- `Featured`

All configured products currently have `RobloxProductId = 0`. Because
`ShopProductConfig.getRobloxProductId` only returns positive integer ids, every
current product resolves to `nil` for live purchasing.

`ShopPurchaseService.start()`:

1. logs catalog issues from `ShopProductConfig.getCatalogIssues()`
2. assigns `MarketplaceService.ProcessReceipt`

Receipt handling:

1. resolves the receipt product by `receiptInfo.ProductId`
2. returns `NotProcessedYet` for unrecognized, duplicate-id, missing-player, or
   not-loaded-profile receipts
3. runs `PlayerStateService.processShopReceipt` inside the per-player profile
   operation queue
4. returns `PurchaseGranted` only when the profile grant and save succeed

`PlayerStateService.processShopReceipt` validates:

- receipt table shape
- non-empty `PurchaseId`
- positive receipt `ProductId`
- matching configured Roblox product id
- matching `receiptInfo.PlayerId`
- loaded profile

Purchase idempotence:

- `ProcessedPurchaseIds[purchaseId] = true` is stored durably after a grant.
- A duplicate processed purchase returns success only after the profile save path
  succeeds again.

Implemented receipt grants:

- Gem packs add durable `RitualGems`.
- Premium Rush sets `profile.RitualRush.PremiumUnlocked = true`.
- Boost grants create or extend durable `ActiveBoosts[boostId]` records.

## Current Potion Boost Behavior

Potion config lives in `src/shared/Config/PotionConfig.luau`. Potions are saved
inventory items under `Potions[potionId] = count`. Using a potion consumes one
owned item and applies or extends the configured active boost.

Configured potions:

- `essence_potion_2x_15m`
  - Display: `2x Essence Potion`
  - Cost: `25` Ritual Gems
  - Grant: `EssenceMultiplier`, `2x`, `15` minutes
- `luck_potion_2x_15m`
  - Display: `Lucky Ritual Potion`
  - Cost: `35` Ritual Gems
  - Grant: `LuckMultiplier`, `2x`, `15` minutes

Potion boost effects:

- `EssenceMultiplier`
  - Effect: multiply crystal Essence rewards only, before the capacity clamp
  - Does not multiply Ritual Gems, Robux purchases, Ritual Rush reward claims,
    future Piggy Bank purchase payouts, or other non-crystal grants
- `LuckMultiplier`
  - Effect: multiply server roll luck used by `RollPet`
  - Does not permanently affect `StoneStats.Luck`, leaderboards, best progress
    records, rebirth math, or saved stone/rune stats

Inventory, stacking, and timers:

- `BuyPotionWithGems` validates the potion id, shop availability, configured
  positive Gem cost, and current Ritual Gems balance server-side.
- `UsePotion` validates the potion id, confirms the player owns at least one,
  consumes one item, and applies the potion boost server-side.
- Before applying a used potion's boost, `UsePotion` calls
  `syncAndCollectCrystalReward` so an already-broken crystal is paid at the old
  reward multiplier.
- Same boost id extends time instead of multiplying power.
- Different boost ids can run at the same time.
- Boost time uses `EndsAtUnix`, so time continues passing while the player is
  offline.
- Expired boosts are ignored by gameplay and can be pruned opportunistically when
  profiles are touched.

Implemented acquisition sources:

- Ritual Rush `points_50` free reward grants one `2x Essence Potion`.
- Ritual Rush `points_100` free reward grants one `Lucky Ritual Potion`.
- Shop potion cards can buy configured potions with Ritual Gems.
- Developer-product receipt grants can activate or extend boosts, but current
  configured product ids are `0`, so those products are not live purchases.

Future acquisition sources:

- Later sources can include daily claim rewards and rare crystal bonuses.
- Robux products can sell direct potion activations after real product ids and
  client purchase prompts exist.

Avoid:

- paid random potion chests
- pet damage boosts
- roll speed boosts
- `2x Ritual Points`
- instant `+250 Ritual Points`

## Ascension

Ascension is implemented as a larger reset layer above regular Rebirth. Regular
Rebirth is the short-loop reset; Ascension is the long-loop reset that asks the
player to push to a major zone milestone and restart faster with permanent
account progress.

Ascension config lives in `src/shared/Config/AscensionConfig.luau`.

Current requirement formula:

```text
RequiredZone = 5 * 2 ^ Ascensions
```

Current source config has Zones 1-5, so only the first Ascension is reachable:

```text
Ascension 1: reach Zone 5
Next configured requirement after ascending once: Zone 10
```

Current Ascension reward:

- `+1 AscensionStars`
- `+1 Ascensions`
- `+0.50` permanent Luck per Ascension
- `+25%` permanent crystal Essence multiplier per Ascension
- `+2500` permanent Ritual Power per Ascension

Ascension trigger flow:

- `WorldController` creates a local placeholder cube statue in the required zone
  when that required zone exists.
- The statue prompt is enabled once the required zone is unlocked.
- The prompt opens `AscensionOverlay`.
- `AscensionOverlay` shows the requirement, reward, kept progress, reset
  progress, and the Ascend action.
- `Ascend` is sent through `RequestAction`.
- The server validates the profile, required zone, required-zone unlock, and
  character proximity to the configured statue position before mutating state.

Ascension keeps:

- pets
- equipped pets
- pet inventory counts
- Rebirths
- Ritual Gems
- potions
- active boosts
- rolls and best-progress records
- rarest pet records
- tutorial progress
- Ritual Rush progress
- purchase and receipt history

Ascension resets:

- Essence
- current zone, back to Zone 1
- unlocked zones, back to Zone 1 only
- Ritual Stone upgrade levels
- rune levels
- runtime crystal state, attack state, farming state, and target state

Ascension does not currently spend `AscensionStars`. `AscensionUpgrades` is a
saved field reserved for a future Ascension Star upgrade shop.

## HUD And UI

The HUD is mounted by `HudController` into `PlayerGui/RitualCoreHud` using
React Lua from `ReplicatedStorage.Packages`.

Normal HUD pieces:

- loading label while no snapshot exists
- stats panel with zone, Essence, Ritual Power, Luck, roll speed, and rolls
- rune panel
- currency display with Essence / Capacity and Ritual Gems
- active boost timer list above the currency display
- bottom icon bar for pets, roll, and Ritual Core
- right icon bar for shop, Ritual Rush, rebirth, and teleport
- shop overlay
- pet inventory overlay
- Ritual Core upgrade overlay
- rebirth overlay
- Ascension overlay, opened by the Zone 5 statue prompt
- teleport overlay
- Ritual Rush overlay
- roll screen overlay

Stats, rune panel, overlays, and the right icon bar are hidden while the roll
screen is visible.

Shop overlay:

- opens from the right-side Shop HUD action
- shows the current Ritual Gems balance
- lists Gem pack product cards
- lists potion cards with owned count, Gem buy action, and use action
- calls `BuyPotionWithGems` for potion purchases and `UsePotion` for potion use
- Gem pack product cards display non-purchasing "Soon" actions because current
  products have `RobloxProductId = 0` and `HudApp` does not pass an
  `OnProductActivated` purchase callback to `ShopOverlay`

Pet inventory overlay:

- shows equipped pets as "Your Best Pets"
- shows stored pets under "All Pets"
- sorts visible stacks by rarity
- displays tooltip information
- uses the shared `Common/PetViewport` component for model previews cloned from
  `ReplicatedStorage/PetModels`
- has no equip or unequip actions

Ritual Core overlay:

- displays a viewport Ritual Stone
- shows current Essence and core stats
- shows Capacity, Luck, Roll Speed, and Ritual Power
- exposes buttons for the three stone upgrades

Rebirth overlay:

- shows current rebirth count
- shows stat gains from the next rebirth
- shows only the Essence requirement
- exposes the rebirth button when `snapshot.RebirthRequirement.CanRebirth` is
  true

Teleport overlay:

- lists snapshot zones in a vertical scrolling list
- labels current, unlocked, and locked zones
- calls `SelectZone` only for unlocked non-current zones

Ascension overlay:

- opens from the local Ascension statue prompt, not from a HUD icon
- shows the current Ascension count and saved Ascension Stars
- shows the required zone and whether Ascension is ready
- shows the automatic permanent bonuses gained by ascending
- shows what is kept and reset
- calls `Ascend` only from the confirmation button
- closes after a successful server-accepted Ascension

Ritual Rush overlay:

- opens from the right-side Ritual Rush HUD action
- shows current Rush points, next milestone progress, and event countdown
- lists compact milestone rows with free rewards, premium bonus information,
  and one claim button
- labels each free reward as claimable, claimed, or locked
- displays the premium bonus in the same row as information, not as a second
  button
- calls `ClaimRitualRushReward` only from the single row claim button

Roll screen:

- starts a roll when opened from the roll button
- shows roulette-style roll presentation
- has Auto Roll and Hide Rolls controls
- uses the server result as the final revealed pet

Common UI helpers:

- `UIThemeConfig.Font` is `Enum.Font.FredokaOne`.
- `HudPrimitives` creates basic HUD labels, panels, buttons, strokes, corners,
  and stat rows.
- `AnimatedScaleButton` wraps button content with hover and press scale tweens
  and cancels active tweens on unmount.
- `HudIconBar` builds icon toolbars from `UIIconConfig`, scales controls to the
  viewport, and caps touch-device control scale at `0.9`.
- `OverlayPanel` owns the shared framed overlay shell and optional close button.
- `GameOverlay` wraps `OverlayPanel`, optional background images, titles, and
  a shared fit scale that applies to the panel shell, close button, title, and
  content.
- `useViewportSize` tracks `Workspace.CurrentCamera.ViewportSize` and reconnects
  when `Workspace.CurrentCamera` changes.

## Client State Store

`ClientStateStore`:

- retries `RequestSnapshot` on start until a snapshot is received
- subscribes to `CrystalStateUpdated`
- invokes `RequestAction` for all gameplay actions
- stores the latest full snapshot
- applies `result.Snapshot` from action results when present
- merges crystal updates into the current snapshot
- notifies subscribers on snapshot changes

`ClientStateStore` wraps `RequestAction:InvokeServer` in `pcall`. If the invoke
fails it returns `{ Ok = false, Message = "Could not complete action request." }`.

Client action methods:

- `rollPet`
- `buyStoneUpgrade`
- `unlockZone`
- `selectZone`
- `rebirth`
- `ascend`
- `buyRune`
- `completeTutorialStep`
- `claimRitualRushReward`
- `claimRitualRushFreeReward`

Only methods called by current UI or world code create player-facing behavior.

## Local Crystal And Pet Visuals

`WorldController` creates local crystals from `snapshot.Crystal.Crystals`.

On start, `WorldController` destroys an existing `Workspace/LocalRitualPreview`
folder before recreating it.

Local unlock walls:

- are `Part` instances named `LocalZoneUnlockWall_<zoneId>`
- are created for locked zones other than zone 1
- contain a `ProximityPrompt` named `UnlockPrompt`
- enable the prompt only when `zoneInfo.CanUnlock == true`
- call `ClientStateStore.unlockZone(zoneId)` when triggered

Local Ascension statue:

- is a placeholder `Part` named `LocalAscensionStatue`
- is created in the current required Ascension zone when that zone exists
- currently appears in Zone 5 for the first Ascension
- contains a `ProximityPrompt` named `AscensionPrompt`
- enables the prompt only when `snapshot.Ascension.CanAscend == true`
- opens the Ascension confirmation overlay through `ClientUiSignals`
- does not decide rewards or reset state; the server validates statue proximity
  again in `PlayerStateService.ascend`

Crystal visuals:

- are `Part` instances named `EnergyCrystal<id>`
- use the current zone crystal color
- display labels for HP, "Roll a pet", or "Full capacity"
- are cleared when snapshot crystal zone does not match current zone

Pet visuals:

- are cloned from `ReplicatedStorage/PetModels`
- use equipped slot `Uid`
- follow the player by `PetFollowerLayout`
- move toward assigned crystal targets from `snapshot.Crystal.PetTargets`
- play hit travel visuals from `snapshot.Crystal.LastAttacks`

Breaking visuals:

- keep a broken crystal locally until hit travel completes
- remove the local crystal after the delay
- spawn up to `6` Essence fly-in orbs for awarded Essence

These visuals do not affect server rewards.

Crystal parts, pet target movement, and pet attack/headbutt visuals are
owner-local presentation. They are not published as public player visuals because
each player only renders their own crystal field. Other clients should only
render that player's public stone and equipped pet idle/follow visuals.

## Ritual Stone Visuals

Local player's stone:

- folder `Workspace/LocalRitualStone`
- controller `RitualStoneVisualController`
- factory `RitualStoneVisualFactory`
- existing folder is destroyed and recreated on controller start

Remote players' stones:

- folder `Workspace/LocalRemotePlayerVisuals`
- controller `ReplicatedPlayerVisualController`
- same visual factory
- existing folder is destroyed and recreated on controller start

Ritual Stone visual config:

- follow offset `(4.5, 3.2, 1.5)`
- tier is `floor(Rebirths / 5)`
- Essence fill ratio controls core scale, core color, glow brightness, and ring
  transparency
- label shows Ritual Power

Stone visuals are client-side presentation.

## Public Player Visual Replication

`PlayerVisualReplicationService` publishes public visual payloads for other
players.

Public visual payload fields:

- `UserId`
- `PlayerName`
- `RitualPower`
- `Rebirths`
- `StoneStats.Capacity`
- `EquippedPets`

Equipped pet public payload fields:

- `Uid`
- `SlotId`
- `PetId`

The server sends `PublicVisualUpdated` only to other players. It sends
`PublicVisualRemoved` to all clients when a published player leaves.

Clients also call `RequestPublicVisuals` on startup to get existing remote
player visuals. `ReplicatedPlayerVisualController` makes up to `3` bounded
startup attempts, waiting up to `4` seconds per attempt and `1` second between
attempts. Live `PublicVisualUpdated` events remain the ongoing update path.

The server keeps a signature for each public visual payload and skips
`PublicVisualUpdated` when the payload has not changed.

Public visual payloads intentionally do not include crystal state, pet target
positions, attack sequence data, or `LastAttacks`. Remote-player pets are
expected to idle/follow only. Do not add remote attack/headbutt replication
unless the game starts rendering other players' crystals.

## Leaderstats And Leaderboards

Leaderstats folder values:

- `Power`
- `Rebirths`
- `Rolls`

If an older `Essence` leaderstat value exists, `LeaderstatsService.ensure`
removes it.

Leaderboards are generated under `Workspace/GeneratedLeaderboards`.

On start, `LeaderboardService` destroys an existing `GeneratedLeaderboards`
folder before recreating it.

Boards:

- Top Ritual Power
- Top Rebirths
- Highest Capacity
- Rarest Pet Found
- Most Rituals

Boards update every `5` seconds and show up to `5` rows.

Leaderboard metrics:

- power: `BestRitualPower` or current `RitualPower`
- rebirths: `Rebirths`
- capacity: `HighestCapacity` or current capacity
- rarest: `RarestPetScore` and `RarestPetId`
- rolls: `Rolls`

## UI Assets

Uploaded asset ids are configured in shared code.

Icon ids live in `UIIconConfig.luau`:

- `Shop`
- `RollDice`
- `RitualCore`
- `AutoRoll`
- `AutoRollColored`
- `Rebirth`
- `PetInventory`
- `Teleporter`
- `Essence`
- `Close`
- `RollViewHidden`

Overlay background ids live in `UIBackgroundConfig.luau`:

- `PetInventory`
- `RitualCore`
- `Rebirth`

Local source and resized image files live under `assets/images`.

`assets/images/icons/README.md` documents the current icon resize output
folders and command.

## Shared Utilities

`NumberFormatter` provides:

- `compact(value)`: upper-case suffix output such as `K`, `M`, and `B`
- `compactLower(value)`: lower-case suffix output such as `k`, `m`, and `b`
- `decimal(value, places)`: fixed decimal string output

## Current Anti-Exploit Model

Crystal reward safety comes from server authority:

- server owns crystal state
- server owns attack timing
- server owns pet target assignment
- server owns damage calculation
- server owns Essence mutation
- server owns zone farming activity
- there is no client crystal-claim remote

Progression safety comes from server actions:

- rolls use server RNG and server cadence
- upgrades check server Essence
- rune purchases check server unlock, level, and Essence
- zone unlocks check server position and server Essence
- teleport requests validate zone unlocks server-side
- rebirth checks server Essence
- Ascension checks the required zone, required-zone unlock state, live character
  state, and full 3D character proximity to the configured Ascension statue
  position server-side
- Ritual Rush reward claims validate milestone progress, free/premium claim
  state, premium unlock state, and Essence capacity server-side
- potion purchases validate potion config, shop eligibility, Gem cost, and Gem
  balance server-side
- potion use validates potion config and owned count server-side before
  consuming one item and applying the boost
- tutorial gameplay steps are completed by server gameplay actions

Client visuals can request actions, but they do not decide durable rewards or
progression.

## Current Limitations

These are current code facts:

- `CrystalState` is runtime-only in the current profile template and is recreated
  on load.
- Runtime pet attack targets, cooldowns, last attacks, farming active state, and
  snapshot revision are not durable profile data.
- ProfileStore mock storage is used in Studio; non-Studio uses the configured
  ProfileStore.
- `RequestAction`, `RequestSnapshot`, and `RequestPublicVisuals` are
  rate-limited.
- `ClientStateStore` retries the initial `RequestSnapshot` call with `pcall`
  until a snapshot is received.
- The tutorial overlay is disabled by `TutorialOverlay.Enabled = false`.
- The Shop overlay can buy and use configured potions with Ritual Gems, but it
  does not prompt Robux purchases. Server receipt handling exists for configured
  developer products, but every current configured `RobloxProductId` is `0` and
  `HudApp` does not wire a client purchase callback.
- The pet inventory overlay is intentionally display-only.
- Server-generated world content is currently bounds markers plus the zone 1
  spawn, not full authored zone geometry.
- Ascension currently supports only the first reachable milestone because the
  source has zones 1-5; the next requirement after one Ascension is Zone 10.
- `AscensionStars` are saved but not spendable yet.
- Client unlock walls are local; server validation still controls unlocks and
  farming activity.
- Ritual Rush event reset is reconciled on Rush snapshot/progress access; there
  is no standalone server tick that pushes a reset snapshot exactly at the daily
  boundary.
- There is no project-owned automated test suite under `src`. Third-party
  package folders may contain their own package specs.

## Not Implemented In Current Source

The current `src` tree does not implement:

- quests
- trading
- pet fusion
- pet sacrifice
- pet passives
- pet auto-delete
- pet storage limits
- shared multiplayer crystal health
- Ritual Gems spending outside configured potion purchases
- live Ritual Gems purchase prompts with real product ids
- live Ritual Rush premium purchase prompt with a real product id
- client Shop purchase prompts and real product ids
- daily claim rewards
- first-rebirth-of-the-day rewards
- achievements
- grand reset reward
- rare crystal bonus reward
- Piggy Bank
- Ascension Star upgrade shop
- Ascension milestones beyond the first reachable Zone 5 milestone
- zones beyond Zone 5
- live monetization purchases from the current client

## Manual Validation Checklist

Networking:

- Confirm `Network.RemoteFunctions` contains `RequestAction`,
  `RequestSnapshot`, and `RequestPublicVisuals`.
- Confirm gameplay actions go through `RequestAction`.
- Confirm there is no client crystal-claim remote.

Profile:

- In Studio, confirm ProfileStore uses mock storage.
- Confirm durable saves contain only current `ProfileTemplate.create()` keys.
- Rejoin and confirm crystals are recreated rather than restored from durable
  profile data.

Crystals:

- With no equipped pets, crystal HP should not decrease.
- With equipped pets and available capacity, pets should target crystals and hit
  on the server attack interval.
- When a crystal breaks, Essence should increase by the clamped reward and a new
  crystal id should appear.
- At full capacity, pets should stop attacking and labels should show full
  capacity.

Zones:

- Walking into an unlocked zone should update `CurrentZone` and reset runtime
  crystal state for that zone.
- Walking into a locked zone should make farming inactive without changing
  `CurrentZone`.
- Unlocking a zone should require standing near the unlock wall and enough
  Essence.
- Teleporting should work only for unlocked zones.

Rolls:

- A roll should return exactly one server-selected final pet id.
- Fast repeated roll requests should return the busy result until cadence
  expires.
- Auto Roll should use the same server action as a manual roll, respect the
  server cadence, and wait 0.2 seconds after a successful reveal before the next
  request.

Rebirth:

- Rebirth should become available when current Essence reaches the formula
  requirement.
- Rebirth should reset Essence, zones, stone levels, and runtime crystal state.
- Rebirth should keep pets, equipped pets, rune levels, rolls, progress records,
  and tutorial completion.

Ascension:

- Zone 4 and Zone 5 should generate bounds and unlock walls like earlier zones.
- The Zone 5 Ascension statue should show a prompt only after Zone 5 is
  unlocked.
- Pressing the statue prompt should open the Ascension overlay, not immediately
  reset the player.
- Ascending should require a live character near the Zone 5 statue server-side.
- Ascending should add one Ascension and one Ascension Star.
- Ascending should reset Essence, zones, stone levels, rune levels, and runtime
  crystal state.
- Ascending should keep pets, equipped pets, Rebirths, Ritual Gems, potions,
  active boosts, Ritual Rush progress, and records.
- After the first Ascension, the next required zone should be Zone 10 and no
  second statue should appear until more zones exist.

UI:

- Pet inventory should display pets but not equip or unequip them.
- Teleport overlay should scroll and show Zones 1-5.
- The Shop icon should open the Shop overlay.
- Potion cards should show owned count, Gem buy button state, and use button
  state.
- Gem pack product buttons should show "Soon" while configured
  `RobloxProductId` values remain `0` and no `OnProductActivated` callback is
  passed from `HudApp`.
- Tutorial overlay should not appear while `TutorialOverlay.Enabled` is false.

Potions:

- Claiming Ritual Rush `points_50` should add one `2x Essence Potion` without
  activating the boost.
- Claiming Ritual Rush `points_100` should add one `Lucky Ritual Potion`
  without activating the boost.
- Buying a potion with enough Ritual Gems should subtract Gems and increase the
  owned potion count.
- Buying a potion without enough Ritual Gems should fail server-side.
- Using a potion should consume one item and start or extend the matching active
  boost timer.
- Using a potion when none are owned should fail server-side.
- An already-broken crystal should be collected before a newly used Essence
  potion affects later crystal rewards.

Shop receipts:

- If real product ids are configured later, confirm `ShopPurchaseService`
  recognizes each configured developer product receipt.
- Confirm duplicate receipt `PurchaseId` values do not grant rewards twice.
- Confirm boost receipts extend `ActiveBoosts`, update active boost snapshots,
  and apply only to their documented crystal Essence or roll luck paths.
