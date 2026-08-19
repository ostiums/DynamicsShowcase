# DynamicsShowcase

A demo app showing **everything UIKit Dynamics can do** — the physics engine built right into UIKit (`UIDynamicAnimator`). Dark neon theme, designed both as a screen-recording showcase and as a readable reference for learning the API.

## Running

Open `DynamicsShowcase.xcodeproj` in Xcode → Run (⌘R). iOS 16+, no dependencies, no assets — everything is drawn in code.

Jumping straight to a screen for recording: set the `AUTO_OPEN_DEMO` environment variable to `0…6` in the scheme — the app opens that demo immediately.

## Screens and API coverage

| Screen | API |
|---|---|
| 🌍 Gravity | `UIGravityBehavior` (vector steered by finger), `UICollisionBehavior` + `translatesReferenceBoundsIntoBoundary`, `UICollisionBehaviorDelegate` (flashes + haptics), elliptical collision bounds (`collisionBoundsType = .ellipse`) |
| 🧲 Snap | `UISnapBehavior` with adjustable `damping` |
| ⛓️ Wrecking Ball | `UIAttachmentBehavior` — anchor and item-to-item rigid links; a dense wrecking ball smashes a block tower; drag via an attachment to the finger |
| 🚀 Push Impulses | `UIPushBehavior` — `.instantaneous` (force = flick velocity, spin via `setTargetOffsetFromCenter`) and `.continuous` with a rotating vector |
| 🌀 Force Fields | `UIFieldBehavior` — all 10 types: radial, spring, vortex, noise, turbulence, velocity, linear, drag, electric, magnetic (charge via `UIDynamicItemBehavior.charge`), `UIRegion` |
| ⚖️ Body Properties | `UIDynamicItemBehavior` — `elasticity`, `density`, `resistance` compared side by side, a floor boundary via `addBoundary(withIdentifier:from:to:)` |
| 🎪 Playground | everything at once + `UIDynamicItemGroup` (domino pairs on long-press), ramp boundaries, a two-finger magnet, `addLinearVelocity` for throwing |

## Architecture

Lightweight MVVM, adapted to the nature of UIKit Dynamics. The physics engine animates *views* directly, so the view controllers own the animator and the behaviors — hiding that behind bindings would only obscure the API this project exists to demonstrate. Everything else is pulled out of the controllers:

- **View models** (one per screen) hold the scene configuration (tuning constants, texts) and all the pure math — layout geometry, impulse conversion, target points. They never touch views, behaviors or the animator, so they are trivially unit-testable. The clearest example is `WreckingBallDemoViewModel`, which derives the chain layout and the tower placement from the swing arc.
- **Views** (`BallView`, `BoxView`, `DemoCardCell`, …) only draw themselves.
- **View controllers** wire gestures to view-model math and feed the results into UIKit Dynamics behaviors. Each controller's doc comment explains which part of the API the screen demonstrates.
- `DemoCatalog` is the single model of the demo list; `MenuViewModel` serves it to the menu.

```
DynamicsShowcase/
├── App/                    AppDelegate, SceneDelegate
├── Core/                   Theme, Haptics, item views, shared geometry helpers,
│                           DemoViewController (base class: gradient background,
│                           animator, hint pill, reset button, collision response)
├── Menu/                   DemoCatalog (model), MenuViewModel, MenuViewController, DemoCardCell
└── Demos/
    ├── Gravity/            GravityDemoViewModel + ViewController
    ├── Snap/               SnapDemoViewModel + ViewController
    ├── WreckingBall/       WreckingBallDemoViewModel (chain & tower geometry) + ViewController
    ├── Push/               PushDemoViewModel + ViewController
    ├── Fields/             FieldCatalog (FieldKind + FieldFactory), FieldsDemoViewModel + ViewController
    ├── Properties/         PropertiesDemoViewModel + ViewController
    └── Playground/         PlaygroundDemoViewModel + ViewController
```

### UIKit Dynamics gotchas encoded in this project

- A `UIFieldBehavior` affects only items explicitly added to it with `addItem(_:)` — adding the behavior to the animator is not enough.
- With `translatesReferenceBoundsIntoBoundary`, an item spawned outside the reference view lands *on top of* the boundary instead of entering the screen — always spawn inside the bounds.
- Behaviors keep referencing their items after the views are removed; on every scene reset the behaviors are created fresh (`buildScene()`).
- Members of a `UIDynamicItemGroup` must not be given individual behaviors — the group is the dynamic item.
- An item can have only one active `UISnapBehavior`; replace, don't stack.

## Recording script (~60 sec)

1. **Menu** (2 s) — scroll through the cards.
2. **Gravity** (8 s) — tap a few times, then run a finger in circles: all the balls pour along the walls following the gravity vector.
3. **Snap** (6 s) — tap the corners on "Bouncy 0.2", switch to "Stiff 0.9", tap again.
4. **Wrecking Ball** (8 s) — let the opening swing smash the tower, then grab the ball and wreck what's left.
5. **Push** (7 s) — a couple of sharp flicks, pucks ricochet; switch to "Continuous force" for a few seconds.
6. **Force Fields** (15 s) — the showstopper: Radial → drag the finger around (the swarm chases it) → Vortex (whirlpool) → Spring (pulsing cloud) → Velocity (fountain).
7. **Body Properties** (5 s) — tap a couple of times: the elasticity difference is instantly visible.
8. **Playground** (9 s) — pour balls onto the ramps, hold a long-press (domino group), finale — two-finger tap: everything flies into the "magnet" and scatters.

Tip: the simulator has no haptics; for a recording with sound, use a physical device + QuickTime.

## License

MIT — see [LICENSE](LICENSE).
