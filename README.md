# Bike Gear Calculator

An iOS app for calculating and comparing bicycle gear ratios across road, mountain, and fixed gear drivetrains.

## Features

### Bike Modes
- **Road** — single or double chainring with cassette presets; Drops/Hoods/Upright position picker for cadence-based speed estimates
- **Mountain** — wide-range cassettes with 1x/2x/3x support
- **Fixed Gear** — single-ratio calculator with optional side-by-side comparison of two setups

### Gear Analysis
- Calculates gear inches and development (meters per pedal stroke) for every chainring/cog combination
- Highlights duplicate ratios across chainrings (within 1 gear inch)
- Speed estimates at 80, 90, and 100 rpm cadence
- Interactive charts showing gear inches and speed curves (Road & MTB)

### Gear Finder
Work backwards from a goal: pick a target speed and cadence, and the app computes the required gear inches and suggests the ten closest chainring/cog combinations, with each suggestion's actual speed and error shown.

### Cassette Presets
42 presets covering common groupsets:

| Brand | Speeds | Series |
|---|---|---|
| Shimano | 8–12sp | Road (Claris → Dura-Ace) + MTB (Deore, SLX, XT, XTR) |
| SRAM | 10–12sp | Road (Rival, Force, Red) + MTB (NX, GX, X01, XX1 Eagle) |
| Campagnolo | 11–13sp | Veloce, Chorus, Record, Super Record Wireless, Ekar |

### Units & Settings
- Imperial (inches, lbs, mph) and metric (cm, kg, km/h) — toggle on the results screen
- Rider weight and height persist between sessions
- Save and reload named configurations

### Wheel Sizes
700c road, 650b, 26", 27.5", and 29" MTB including plus (2.8") and fat (3.0") tires.

## Requirements

- iOS 17+
- Xcode 15+

## Building

1. Clone the repo
2. Open `BikeGearCalculator.xcodeproj` in Xcode
3. Select a simulator or device and run (⌘R)

No external dependencies — standard SwiftUI + Swift Charts only.

## Project Structure

```
BikeGearCalculator/
├── Models.swift          — GearCombo, WheelSize, CassettePreset, RiderSettings, BikeType
├── GearCalculator.swift  — Gear inch math, duplicate detection, fixed gear comparison
├── GearStore.swift       — Persistence (UserDefaults), saved configs, cross-tab navigation
├── CalculatorView.swift  — Main input form, results screen, speed/gear charts
├── ContentView.swift     — Tab bar (Calculator, Presets, Saved)
├── PresetsView.swift     — Browse and load gear presets
└── SavedView.swift       — Manage saved configurations
```
