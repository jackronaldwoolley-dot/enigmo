# Enigmo (one-shot tribute)

A from-scratch SwiftUI + SpriteKit remake of the classic Pangea puzzle game **Enigmo**.
Droppers spray water, oil, and lava. You place parts to steer every droplet into the
matching bucket. Fill every bucket to finish the level. The bonus counts down while you play,
so faster solutions score more.

## Run it

1. Open `Enigmo.xcodeproj` in Xcode 16 or newer.
2. Pick any iPhone simulator (or your device with your own signing team).
3. Press Run.

Or from the terminal:

```bash
xcodebuild -project Enigmo.xcodeproj -scheme Enigmo -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build
```

## How to play

- Drag a part out of the tray at the bottom onto the playfield.
- Tap a placed part to select it, then drag its **knob** to rotate it. Drag the knob far
  from the part for fine control.
- Drag a part back onto the tray to return it.
- Buckets only accept their own liquid. A wrong droplet **removes** one collected droplet.

## Parts

| Part | Behaviour |
| --- | --- |
| Bumper | Bouncy. Droplets rebound at full speed. |
| Slider | Slick. Droplets slide along it with no bounce. |
| Sponge | Absorbs any droplet that touches it. |
| Accelerator | Fires droplets in the direction of its arrow. |

## Code map

| File | What it does |
| --- | --- |
| `Enigmo/Levels.swift` | Level data. Coordinates are fractions of the playfield, so levels are easy to add. |
| `Enigmo/Nodes.swift` | Droplet, tool, container, and dropper nodes plus their physics bodies. |
| `Enigmo/GameScene.swift` | The SpriteKit scene: emission, contacts, tray, touch handling, win check. |
| `Enigmo/GameModel.swift` | Game state, level progress, and best scores (saved in UserDefaults). |
| `Enigmo/ContentView.swift` | SwiftUI menu, HUD, level-complete screen, and the SKView host. |

## Adding a level

Append a `Level` to `Level.all` in `Levels.swift`. Droppers take a position, an angle in
degrees (`-90` is straight down), a speed, and a liquid. Containers take a bottom-center
position and a liquid. Walls are rectangles. `tools` is the tray inventory and `target` is
how many droplets each bucket needs.
