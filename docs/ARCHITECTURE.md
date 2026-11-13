# Architecture

CLI-only macOS app (no UI). Swift Package, layered; dependencies point downward only.

```
TrackpadGestureControl   executable, composition root (main.swift, no logic)
  GestureCLI             CLI engine: CommandRouter + Command types (run, monitor, gestures, actions, bindings, init)
    GestureConfig        Config engine: ConfigurationLoader (JSON -> bindings), ConfigurationStore (edit file)
      GestureActions     Action engine: ActionFactory, ActionDispatcher, concrete Actions
    GestureEngine        Recognition engine: GestureEngine, Recognizers, TouchSources (OS input)
      GestureCore        Domain: models + protocols only
```

## One engine per concern
| Concern | Engine | Extension point |
|---|---|---|
| OS touch input | `TouchSource` impls (`MultitouchTouchSource`, `ReplayTouchSource`) | new class conforming to `TouchSource` |
| Gesture detection | `GestureEngine` + `GestureRecognizer`s | new `GestureRecognizer` (Strategy) |
| Keyboard-shortcut triggers | `HotkeyRegistrar` impls (`CarbonHotkeyRegistrar`), `Hotkey` model, `KeyCodes` table (shared with key-press actions) | new `HotkeyRegistrar` (e.g. an event-tap based one) |
| Doing things | `ActionDispatcher` + `ActionFactory` | `factory.register(type, usage:, builder:)` (Command + Factory) |
| Configuration | `ConfigurationLoader` / `ConfigurationStore` | `GestureConfiguration` schema |
| Terminal | `CommandRouter` | new `Command` type, registered in `CLIApplication` |
| Live session | `GestureSession` (engine + dispatcher + live reload + gesture capture), `StartCommand` (menu thread + run loop on main) |
| Interactive setup | `ActionPrompter`s, `AppCatalog`, `ShortcutParser`, `Terminal` (libedit Tab completion via `CEditline`) | new `ActionPrompter` (menu entry for a new action type), registered in `CLIApplication` |

## Threading
- OS input thread(s): MultitouchSupport calls us per frame. Each trackpad has its own recognizer instances (`GestureEngine` keys them by `TouchFrame.deviceID`), so devices never share state.
- Actions never run on the input thread: `ActionDispatcher` hands them to a serial queue (ordered, non-blocking).
- Main thread runs an AppKit loop (`MainLoop`, accessory policy, no Dock icon): Carbon hotkey events are only delivered by a real application event loop.
- Menu thread blocks on the keyboard; the main thread only keeps the run loop alive.
- Single listener: `InstanceLock` (flock) lets only one process own the trackpad; others run config-only. The login service is a LaunchAgent (`LaunchAgentManager`) running `run`, which hot-reloads the config file.
- Output is silent unless started with `./trackpad debug`.

## Rules
- `GestureCore` imports Foundation only. Layers never import upward.
- The only seam between recognition and actions is the `GestureHandler` protocol.
- Private Apple API (`MultitouchSupport`) is confined to `MultitouchTouchSource.swift`.
- New gesture / action / command = add one type + register it. No edits to existing engines.

## Adding things
- **Gesture**: add case to `GestureKind` (+ name mapping), write a recognizer, add it in `PipelineBuilder`.
- **Action**: add a struct conforming to `Action`, register it in `ActionFactory.standard()`.
- **Menu option for an action**: add an `ActionPrompter` in `Sources/GestureCLI/Interactive`, register it in `CLIApplication` (and the action itself in `ActionFactory`).
- **Command**: add a `Command` type in `Sources/GestureCLI/Commands`, register in `CLIApplication`.

## Runtime requirements
macOS 12+. Accessibility permission for the terminal app (key press / click actions).
