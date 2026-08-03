# Ritual Simulator

This repository contains the Roblox product project for Ritual Simulator. It
is intentionally separate from the private `game-pipeline` orchestration
repository and from the external asset-authoring repositories.

## Local setup

Run these commands from this repository root:

```powershell
rokit install
wally install
rojo serve default.project.json
```

Then connect Roblox Studio to the Rojo server and open the local Studio place.
The repository does not upload, publish, or assign production asset IDs.

`rokit.toml` pins the expected Rojo, Wally, and package-type tool versions.
`wally.lock` pins Lua dependencies. `Packages/` is included so the current
prototype can be opened immediately; rerun `wally install` after dependency
changes and review the resulting diff.

## Repository boundaries

- `src/` — Rojo-synced Luau product code.
- `assets/` — approved or locally staged product assets.
- `vfx/` and root `.rbxmx` files — local Studio-authored references and review
  material retained from the prototype.
- `plugins/` — authoring-time Studio plugins.
- `docs/` — product and authoring documentation.
- `default.project.json` — Rojo mapping.

The external pipeline owns orchestration, private prompts, generator
implementations, credentials, manifests, and internal review history. Do not
copy those into this repository. Product code must remain understandable and
reviewable without the pipeline.

## Development rules

Read `AGENTS.md` before changing the project. Server code remains authoritative
for persistence, economy, rewards, progression, purchases, and anti-exploit
validation. Client code handles presentation and input only.

The existing prototype is reference material, not a guarantee that behavior is
correct. Changes should be focused, committed coherently, and checked in
Roblox Studio. Local v1 may keep config-gated diagnostics and placeholders;
final model art, uploads, and publishing are separate human gates.

The local Studio place file and generated `sourcemap.json` are intentionally
ignored. They are machine-local artifacts, not the product source of truth.
