# Roblox Project AGENTS.md

## Purpose

This file tells AI coding agents how to work safely in this repository.

Keep this file focused on repository workflow, source-of-truth rules, ownership
boundaries, and validation expectations. Do not put game design, balance values,
feature scope, or current implementation details here.

Existing source code is the only implementation truth. Documentation is
reference material and can be stale.

## Agent Role

Act as a careful Roblox/Rojo/Luau engineer.

Match the scope of the user request.

- If the user asks for a small fix, make a focused fix.
- If the user asks for a full feature, implement the full feature coherently.
- If the user asks for architecture/design only, do not edit code.

Prefer simple, readable systems over speculative abstractions. Do not redesign
unrelated systems while completing a task.

## Source Of Truth

When making implementation decisions, inspect the source code first. The source
tree is the only authority for current behavior.

Implementation truth includes:

1. Existing source code.
2. Shared modules and configuration used by both client and server.
3. Project mapping, package, and tool wiring files when the task touches
   structure or dependencies.

Documentation is reference material only. If documentation conflicts with code,
follow the code and mention the mismatch in the final response.

## Roblox Ownership

Keep the Roblox client/server boundary clear.

- Server code owns authoritative gameplay decisions, persistence, economy,
  inventory, rewards, purchases, unlocks, validation, and anti-exploit checks.
- Client code owns presentation, local input, UI, previews, animation, local
  feedback, and other non-authoritative visuals.
- Shared code owns data, utilities, constants, and network names that are used
  on both sides.

Do not move authoritative state or durable decisions from server to client.

## Rojo And Luau

Follow the existing Rojo project mapping and folder structure.

Script conventions:

- `*.server.luau` = Roblox `Script`
- `*.client.luau` = Roblox `LocalScript`
- plain `*.luau` = Roblox `ModuleScript`

Do not casually edit:

- Rojo project mappings
- package layout
- dependency lockfiles
- top-level source structure

Ask or clearly call out risk before changing package or tool wiring.

## Project Structure

Use the existing ownership folders and startup entry points. Do not add large
flat scripts when the project already has a structured module layout.

When touching startup, preserve the existing initialization order unless the
task requires changing it.

## Networking

Before adding or changing a remote:

1. Search existing remotes.
2. Reuse an existing remote if it already fits the action.
3. Add a new remote only when the behavior is genuinely new.
4. Keep remote names in the existing shared-network location or pattern.
5. Update server and client call sites together.
6. Validate payloads server-side.

Do not silently rename existing remotes.

Never let client remotes directly grant durable rewards, currency, inventory,
upgrades, unlocks, purchases, or progression. Treat all client payloads as
untrusted. Add server-side validation and rate limiting where client-triggered
work can be spammed or abused.

Before accepting any network-related change, record a lightweight security and
performance check: server authority, payload validation, rate limits, replay or
idempotency behavior, bounded request frequency, and absence of unnecessary
per-frame or repeated work. Keep the controls cheap enough for normal gameplay.

## Persistence

When changing saved data:

1. Inspect the existing profile template or save schema.
2. Inspect all readers and writers for the fields being changed.
3. Keep saved data minimal and explicit.
4. Prefer additive changes.
5. Preserve backward compatibility once live data may exist.
6. Mention any save-shape change in the final response.

Do not add complex migration machinery until the project actually needs it.

ProfileStore may be restored if its available local source/version is inspected
and approved. Preserve the agreed profile contract and backward-compatible
defaults; do not download or install a replacement automatically.

## UI

Follow the local UI framework and component patterns already used by the
project.

Keep UI readable, Roblox-appropriate, and usable on mobile. Establish reusable
primitives only when they reduce real duplication.

Do not add unrelated visual redesigns while implementing a requested feature.

## Assets And Studio Authored Content

Some Roblox content may be Studio-authored and may not exist as normal source
files.

Do not assume missing source files mean unused content. Before changing asset
paths, folder names, template assumptions, or model expectations, inspect the
relevant services and call sites.

## Command Policy

Read-only inspection is allowed.

Keep routine agent runs lean. Do not run git commands, add tests, run tests,
run lint, run builds, run Rojo sync/build commands, or run package commands
unless the user explicitly asks.

Do not claim that tests, lint, build, Rojo sync, Studio validation, or package
installs passed unless they actually ran.

Ask or clearly call out risk before running:

- package installs
- dependency updates
- broad formatting passes
- commands that overwrite generated place files
- destructive cleanup commands

If validation was not run, say so in the final response.

## Code Style

Follow the style of the files being edited.

Prefer:

- clear names
- explicit validation
- shared config for shared data
- focused modules
- cleanup of connections and instances
- simple data shapes
- server-side authority checks

Avoid:

- speculative abstraction
- unrelated rewrites
- unexplained magic numbers
- duplicated systems
- hidden client authority
- warning spam
- production complexity copied from another project without need

Local v1 may use config-gated verbose diagnostics and invariant checks to make
Studio failures visible. Do not log secrets, unnecessary player-identifying
data, or unbounded warning spam. Keep the simplest design that follows KISS,
DRY, and SOLID pragmatically.

## Documentation

Update this file only for durable repo-level agent rules.

Do not update this file for:

- balance numbers
- temporary TODOs
- feature designs
- UI layouts
- asset ids
- content tables
- economy values

Use source comments for narrow code context and normal project documentation for
descriptive notes or planning material.

## Final Response

When finishing a coding task, report:

- what changed
- files changed
- important behavior notes
- validation performed
- validation not performed
- manual Studio checks recommended, if relevant

Be honest. Do not say something was tested, built, synced, or validated unless
it actually was.

## Private Tooling Boundary

This repository contains the Roblox product only. Private orchestration,
generator implementations, prompts, credentials, and internal review history
must remain outside this project.

- Rojo syncs this project's Luau source; private tooling is not a runtime
  dependency.
- Treat `src/` and promoted `assets/` as product code/content that must remain
  understandable and reviewable to the game team.
- Do not add private scripts, generator recipes, manifests, or machine-local
  paths to this repository merely to automate an external step.
- Local handoffs must write only explicitly approved target paths and must
  preserve unrelated Studio-authored content.
- Local file staging is the default. Roblox import, upload, publishing,
  production asset IDs, and place changes remain explicit human gates.

## Shared Git History Rules

Commit frequently at coherent milestones so gameplay, UI, and asset-handoff
changes are easy to inspect, revert, and understand. Stage only intended files
when unrelated user work is present. Use focused commit subjects and do not
amend, force-push, or rewrite history without explicit instruction.
