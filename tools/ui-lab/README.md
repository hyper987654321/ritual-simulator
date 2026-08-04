# UI Lab

UI Lab is a separate Rojo project for clean-slate Roblox-native React-Luau
stories. It is not mounted by `default.project.json`, and its client entry
point is not part of normal game startup.

## Run locally

From the `ritual-simulator` repository root:

```text
rojo serve ui-lab.project.json
```

Open the separate lab place in Studio and connect the Rojo plugin. The lab
creates its own `UILabMount` ScreenGui under the local player. No product UI is
imported or required.

The toolbar switches the deterministic story registry, fixture states
(`empty`, `loading`, `populated`, `locked`, `error`), and device presets:
desktop 1440x900, laptop 1280x720, tablet 1024x768, and mobile 390x844. The
safe-area frame, visible diagnostics panel, and Run diagnostics action are
part of the workbench chrome.

## Adding a clean-slate V2 story

1. Add a stable descriptor to `shared/StoryRegistry.luau`.
2. Add a component under `client/` accepting fixture and preset metadata.
3. Select it from `client/App.luau`; never require `src/client` or existing UI.
4. Give intentional root panels stable names (`SafeArea`, `Diagnostics`,
   `Card…`, or `Anatomy`) and intentional blank content the `AllowBlank`
   attribute so diagnostics stay useful.
5. Build with Rojo and manually inspect every device preset in Studio before
   promoting any story into a product screen.

The included gallery is neutral: tokens, buttons, cards, and modal anatomy
only. It is not a production screen.
