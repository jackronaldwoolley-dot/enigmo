# Enigmo (one-shot tribute)

A from-scratch SwiftUI + SpriteKit remake of the classic Pangea puzzle game **Enigmo**.
Droppers spray water, oil, and lava. You place parts to steer every droplet into the
matching bucket. Fill every bucket to finish the level. Finish under par for three stars.

## Play it in a browser

**https://jackronaldwoolley-dot.github.io/enigmo/**

That's the web port in `docs/index.html`: one HTML file with its own physics engine, the same
24 levels, parts, stars, achievements, tutorial, and sound. It runs on phones and desktops.

## Run the iOS app

1. Open `Enigmo.xcodeproj` in Xcode 16 or newer.
2. Pick any iPhone simulator (or your device with your own signing team).
3. Press Run.

Or from the terminal:

```bash
xcodebuild -project Enigmo.xcodeproj -scheme Enigmo -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build
```

## What's in the game

- **24 levels in 4 chapters.** Chapters unlock with stars, so replaying early levels faster is always worth it.
- **Three-star ratings.** Every level has a par time. Under par is three stars, under 1.6x par is two.
- **Guided first level.** Three short prompts teach drag, rotate, and fill. Replay it from Settings.
- **16 achievements** with in-game unlock toasts, plus lifetime stats.
- **Five parts:** Bumper, Slider, Sponge, Accelerator, Gravity Well.
- **Sound and haptics** you can switch off. All sounds are synthesized at launch, so there are no audio files.
- **Progress is saved** automatically. One "Continue" button always takes you to the next open level.

## How to play

- Drag a part out of the tray at the bottom onto the playfield.
- Tap a placed part to select it, then drag its **knob** to rotate it. Drag the knob far
  from the part for fine control.
- Drag a part back onto the tray to return it.
- Buckets only accept their own liquid. A wrong droplet **removes** one collected droplet.
- Droplets that come to rest evaporate, so a flat slider never clogs.

## Parts

| Part | Behaviour |
| --- | --- |
| Bumper | Bouncy. Droplets rebound at full speed. |
| Slider | Slick. Droplets slide along it with no bounce. |
| Sponge | Absorbs any droplet that touches it. |
| Accelerator | Fires droplets in the direction of its arrow. |
| Gravity Well | Pulls nearby droplets toward it. Place it beside a stream to bend it. |

## Code map

| File | What it does |
| --- | --- |
| `Enigmo/Levels.swift` | Chapters and level data. Coordinates are fractions of the playfield. |
| `Enigmo/Nodes.swift` | Droplet, part, bucket, and dropper nodes with their physics bodies. |
| `Enigmo/GameScene.swift` | The SpriteKit scene: emission, contacts, tray, touch handling, events. |
| `Enigmo/GameModel.swift` | Game flow, star scoring, tutorial steps, achievement checks. |
| `Enigmo/Progress.swift` | Saved progress, run stats, and the event types the scene sends. |
| `Enigmo/Achievements.swift` | Achievement definitions. Add one line to add an achievement. |
| `Enigmo/SoundKit.swift` | Tiny synthesizer for sound effects, plus haptics. |
| `Enigmo/ContentView.swift` | Menu, HUD, tutorial, results, achievements, settings, toasts. |
| `docs/index.html` | The web port, served by GitHub Pages. |

## Adding a level

Append a `Level` to `Level.all` in `Levels.swift` and widen the last chapter's `levelRange`.
Droppers take a position, an angle in degrees (`-90` is straight down), a speed, and a liquid.
Containers take a bottom-center position and a liquid. Walls are rectangles. `tools` is the
tray inventory, `target` is droplets per bucket, and `par` is the three-star time in seconds.
