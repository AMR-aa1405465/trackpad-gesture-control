# Trackpad Gesture Control

Turn your Mac's trackpad into a remote control. Pinch, swipe or press a keyboard shortcut, and your Mac launches an app, presses a key, or clicks for you.

Everything runs from the terminal. No windows, no menu bar icon, no clutter.

## What you can do

- **Pinch in/out and swipe** with any number of fingers
- **Launch any app** you have installed
- **Press a shortcut** like `Escape` or `Cmd+W` for you
- **Trigger actions from keyboard shortcuts** too (for example `Cmd+T` opens your favorite app)
- **Start automatically at login**

## Install

You need a Mac (macOS 12 or newer) with the Swift tools, which come with Xcode or the Command Line Tools:

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/AMR-aa1405465/trackpad-gesture-control.git
cd trackpad-gesture-control
./trackpad
```

The first run builds the app (about a minute). After that it starts instantly.

## Use it

`./trackpad` listens for gestures **and** opens a simple menu in the same window:

1. Choose **Add or change a gesture binding**.
2. Perform the gesture on your trackpad (or pick it from a list).
3. Choose what it should do: press a shortcut, launch an app (type the first letters and press Tab), or click.

Changes work immediately. Press `Ctrl+C` to quit.

Handy extras:

```bash
./trackpad autostart on    # start at every login (off to stop)
./trackpad debug           # show what it detects, great for troubleshooting
./trackpad doctor          # check that permissions are set up
./trackpad help            # all commands
```

## One-time permission

To press keys or click for you, macOS needs your OK: **System Settings → Privacy & Security → Accessibility**, then switch on the app you run this in (Terminal, iTerm, ...). Restart that app afterwards.

## Good to know

- A keyboard shortcut you bind becomes yours system-wide while the app runs (binding `Cmd+T` means browsers stop getting it).
- macOS already uses some 3 and 4 finger gestures. Turn those off in System Settings → Trackpad if they get in the way.
- Trackpad input uses a private Apple framework, so a future macOS update could break it.

## For developers

Written in Swift with a small, layered design: each part (touch input, gesture detection, actions, config, terminal commands) is its own module, and adding a new gesture or action means adding one class. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Contributions and ideas are welcome.
