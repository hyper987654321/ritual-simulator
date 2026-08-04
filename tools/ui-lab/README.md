# UI Lab

UI Lab is a separate Rojo project for clean-slate Roblox-native React-Luau
stories. It is not mounted by `default.project.json`, and its client entry
point is not part of normal game startup.

## Run locally

From the `ritual-simulator` repository root:

```text
rojo serve ui-lab.project.json
```

Open the separate lab place in Studio and connect the Rojo plugin. The client
entry creates exactly one `UILabMount` ScreenGui and renders the App Frame into
it. The ScreenGui uses Global ZIndexBehavior explicitly.

The toolbar is a horizontal ScrollingFrame, so it remains usable below the
1240 pixel workbench width. It switches the deterministic story registry,
fixture states (`empty`, `loading`, `populated`, `locked`, `error`), and device
presets: desktop 1440x900, laptop 1280x720, tablet 1024x768, and mobile
390x844. Every story renders on an exact fixed design canvas and receives a
calculated UIScale. The toolbar exposes both design size and display scale.

## Diagnostics

Run diagnostics after the story settles. The report receives only the named
`StoryRoot` design canvas. Root panel overlap checks use explicit registration
from the story module and ignore ancestor/descendant containment. The report
checks viewport bounds, blank layout sizes, missing text or image content, and
visible Global ZIndex relationships where a child falls below an opaque
visible ancestor. Toolbar and diagnostics chrome are excluded.

## Adding a clean-slate V2 story

1. Add a descriptor to `shared/StoryRegistry.luau` with a stable `Id`, label,
   description, and `Module` name.
2. Add `client/stories/<Module>.luau` that returns a React component accepting
   `fixture`, `preset`, and `storyRootRef`.
3. Register intentional root panels with
   `Diagnostics.registerRootPanel("ExactInstanceName")` in that story module.
4. Keep the story module independent of `src/client` and existing UI. App only
   resolves the descriptor module and supplies the fixture and preset.
5. Run the Rojo build and manually inspect every device preset in Studio before
   promoting any story into a product screen.

The included gallery is neutral: tokens, buttons, cards, and modal anatomy
only. It is not a production screen.
