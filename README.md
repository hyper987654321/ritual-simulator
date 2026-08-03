# Ritual Simulator

This repository contains the Roblox product project for Ritual Simulator.
Private orchestration and asset-authoring workspaces are kept outside the
product repository.

## Local setup

The required tools are already installed on the current machine and the
dependencies are already present in `Packages/`. You do not need to run the
setup commands again for this checkout.

For a fresh machine or fresh checkout, run these one-time setup commands from
the repository root:

```powershell
rokit install
wally install
```

During normal development, start the live Rojo sync server:

```powershell
rojo serve default.project.json
```

Then connect Roblox Studio to the Rojo server and open the local Studio place.
The repository does not upload, publish, or assign production asset IDs.

`rokit.toml` pins the expected Rojo, Wally, and package-type tool versions.
`wally.lock` pins Lua dependencies. `Packages/` is included so the current
prototype can be opened immediately; rerun `wally install` only after changing
dependencies or when setting up another machine, and review the resulting diff.

## Repository boundaries

- `src/` - Rojo-synced Luau product code.
- `Packages/` - pinned runtime dependencies installed by Wally.
- `default.project.json` - Rojo mapping.

Local-only prototype references, authoring files, and imported source assets
are kept in `.local-reference/`. That directory is ignored by Git and is not
included by the Rojo mapping. Keep private production tooling and review
material outside this repository.

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
