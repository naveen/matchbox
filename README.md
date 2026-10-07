# Matchbox

A Mac app that teaches kids how to use the trackpad.

Matchbox cars, motoring, motor skills. The idea: a MacBook trackpad can do a
lot (tap, click, press and hold, double tap, two-finger scroll, pinch, rotate,
three- and four-finger swipes, force click) and none of it is obvious to a
seven-year-old. Matchbox shows them what the trackpad sees and celebrates when
they get a gesture right.

A sibling app, Letterbox, will do the same for typing.

## What works today

- **Missions.** The main event. Each session is five short missions, one at a
  time: a prompt with an emoji toy, a progress ring that fills as the child
  does the gesture, confetti and a sound on success, and a sticker. After five,
  a finish screen. There is no failure state: do the thing and get the sticker,
  or don't and nothing bad happens. A hint appears after eight quiet seconds.
  Each new session picks up where the last one left off in the gesture list,
  and wraps around.
- **Adapts to this Mac.** At launch, Matchbox reads the trackpad settings for
  the logged-in account and builds the mission list from them. Tap missions
  only exist if tap-to-click is on. Pinch, rotate, force click and secondary
  click missions only exist if those gestures are on. Scroll prompts say which
  way to slide fingers based on whether natural scrolling is on. The drag
  prompt changes if three-finger drag is on.
- **Stickers.** Every emoji earned, saved on this Mac.
- **Free Play.** A trackpad-shaped mirror shows a glowing dot for every finger
  touching the trackpad, live. A toy reacts to every gesture, and a log names
  what the trackpad saw.
- **Grown-ups.** Under Matchbox > Settings (Cmd+,): every trackpad setting on
  this Mac in plain words, with a hint for the child. Read-only.

The window opens nearly full-screen because a seven-year-old doesn't resize
windows yet.

## Building

Requires Xcode 26 and macOS 26.

```sh
open Matchbox.xcodeproj
```

The project file is generated from `project.yml` with
[XcodeGen](https://github.com/yonas/XcodeGen). If you add files, either open
the project in Xcode and add them there, or run `xcodegen generate` and commit
the regenerated project.

Command-line build and tests:

```sh
xcodebuild -project Matchbox.xcodeproj -scheme Matchbox -configuration Debug build
xcodebuild -project Matchbox.xcodeproj -scheme Matchbox -configuration Debug test
```

## Design notes

- **Native, not web.** A browser only sees pointer and wheel events. AppKit
  exposes individual finger touches through `NSTouch`, which is what makes the
  finger mirror possible.
- **Not sandboxed.** Reading the trackpad preferences
  (`com.apple.AppleMultitouchTrackpad` and a few global keys) is not allowed
  from a sandboxed app. This means Matchbox can't ship on the App Store as-is.
- **Tap versus click.** Tap-to-click never produces pressure events, and a
  physical press always does. Matchbox uses that to tell the child which one
  they did.
- **System gestures.** Four-finger swipes, pinch to Launchpad and three-finger
  space switching are consumed by macOS. Matchbox sees the fingers land and
  move, then gets a cancel. Those missions will be "watch what happens" rather
  than verified.
- **Lessons adapt to settings.** If tap-to-click is off, the tap mission should
  teach that tapping does nothing, not fail the child.

## Developer flags

```sh
Matchbox.app/Contents/MacOS/Matchbox --room freeplay
```

`--room` picks the starting screen (`missions`, `freeplay`, `stickers`).

## Roadmap

1. Animated hint: a little hand doing the gesture on a trackpad picture, so
   the child doesn't have to read the hint.
2. Voice prompts via the system speech synthesizer.
3. Per-mission scenes instead of the generic ring (drive into the garage,
   lift the balloon, and so on).
4. App icon.
5. Optional: global raw touches through the private MultitouchSupport
   framework so system-owned gestures (Mission Control, Launchpad) can be
   verified.
