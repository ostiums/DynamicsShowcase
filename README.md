# DynamicsShowcase

A demo app showing **everything UIKit Dynamics can do** — the physics engine built right into UIKit (`UIDynamicAnimator`). Dark neon theme, designed both as a screen-recording showcase and as a readable reference for learning the API.

## Running

Open `DynamicsShowcase.xcodeproj` in Xcode → Run (⌘R). iOS 16+, no dependencies, no assets — everything is drawn in code.

Jumping straight to a screen for recording: set the `AUTO_OPEN_DEMO` environment variable to `0…7` in the scheme — the app opens that demo immediately.

## Screens and API coverage

| Screen | API |
|---|---|
| 🍎 Gravity | `UIGravityBehavior` (vector steered by finger, `magnitude` slider down to a zero-g freeze), `UICollisionBehavior` + `translatesReferenceBoundsIntoBoundary`, `UICollisionBehaviorDelegate` (flashes + haptics), elliptical collision bounds (`collisionBoundsType = .ellipse`) |
| 🧲 Snap | `UISnapBehavior` with adjustable `damping` |
| 🏗️ Wrecking Ball | `UIAttachmentBehavior` — a dense wrecking ball hangs from an anchor attachment that is only present while the cable is taut; it smashes a wall of bricks, each brick carrying a word (a "UIKit" ball vs. a wall of "UIKit is dead", "Use SwiftUI", "Legacy"…); drag via an attachment to the finger and flick to throw — the ball leaves with the gesture's velocity; a hard hit shatters a brick into snapshot shards, sends out a shockwave and shakes the screen; once nothing is left standing the payoff line drops in on a `UISnapBehavior` and the wall is rebuilt |
| 🎱 Push Impulses | `UIPushBehavior` — `.instantaneous` (billiards-style slingshot: force = pull distance, spin via `setTargetOffsetFromCenter`) and `.continuous` with a rotating vector; a white cue ball, six pockets that pot the balls, a cleared table respawns the rack; the "Real UI" mode swaps the rack for a live settings screen (labels, cards, a working `UISwitch`, buttons): every cell hangs on a spring (`UIAttachmentBehavior` with `frequency`/`damping`), weighs in proportion to its area, squashes on contact and shatters into snapshot shards under a hard hit |
| 🌀 Force Fields | `UIFieldBehavior` — all 10 types: radial, spring, vortex, noise, turbulence, velocity, linear, drag, electric, magnetic (charge via `UIDynamicItemBehavior.charge`), `UIRegion` |
| 🪐 Solar System | `radialGravityField(falloff: 2)` — a true inverse-square gravity well; planets on calibrated circular orbits (`linearVelocity(for:)`, `updateItem(usingCurrentState:)`) |
| ⚖️ Body Properties | `UIDynamicItemBehavior` — `elasticity`, `density`, `resistance` compared side by side, a floor boundary via `addBoundary(withIdentifier:from:to:)` |
| 🎉 Paywall Drop | any `UIView` is a dynamic item: a realistic paywall falls off the screen under gravity on "Continue" (`addLinearVelocity` scatter), a `UISnapBehavior` greeting slowed by `resistance`, `CAEmitterLayer` confetti |

## Architecture

Lightweight MVVM, adapted to the nature of UIKit Dynamics. The physics engine animates *views* directly, so the view controllers own the animator and the behaviors — hiding that behind bindings would only obscure the API this project exists to demonstrate. Everything else is pulled out of the controllers:

- **View models** (one per screen) hold the scene configuration (tuning constants, texts) and all the pure math — layout geometry, impulse conversion, target points. They never touch views, behaviors or the animator, so they are trivially unit-testable. The clearest example is `SolarSystemDemoViewModel`, which turns the field's calibrated strength into circular-orbit velocities.
- **Views** (`BallView`, `BoxView`, `DemoCardCell`, …) only draw themselves.
- **View controllers** wire gestures to view-model math and feed the results into UIKit Dynamics behaviors. Each controller's doc comment explains which part of the API the screen demonstrates.
- `DemoCatalog` is the single model of the demo list; `MenuViewModel` serves it to the menu.

```
DynamicsShowcase/
├── App/                    AppDelegate, SceneDelegate
├── Core/                   Theme, Haptics, item views, shared geometry helpers,
│                           DemoViewController (base class: gradient background,
│                           animator, reset button, collision response)
├── Menu/                   DemoCatalog (model), MenuViewModel, MenuViewController, DemoCardCell
└── Demos/
    ├── Gravity/            GravityDemoViewModel + ViewController
    ├── Snap/               SnapDemoViewModel + ViewController
    ├── WreckingBall/       WreckingBallDemoViewModel (wall geometry, rope tension) + ViewController
    ├── Push/               PushDemoViewModel + ViewController
    ├── Fields/             FieldCatalog (FieldKind + FieldFactory), FieldsDemoViewModel + ViewController
    ├── SolarSystem/        SolarSystemDemoViewModel (orbital math) + ViewController
    ├── Properties/         PropertiesDemoViewModel + ViewController
    └── Paywall/            PaywallDemoViewModel + ViewController
```

### UIKit Dynamics gotchas encoded in this project

- A `UIFieldBehavior` affects only items explicitly added to it with `addItem(_:)` — adding the behavior to the animator is not enough.
- With `translatesReferenceBoundsIntoBoundary`, an item spawned outside the reference view lands *on top of* the boundary instead of entering the screen — always spawn inside the bounds.
- Behaviors keep referencing their items after the views are removed; on every scene reset the behaviors are created fresh (`buildScene()`).
- Members of a `UIDynamicItemGroup` must not be given individual behaviors — the group is the dynamic item.
- A "rigid" `UIAttachmentBehavior` is a rod, not a rope: it resists compression as much as stretching, so an item on one can't be dragged toward the anchor, and above the anchor the rod props the item up instead of letting it fall. For a cable that goes slack, keep the attachment only while it pulls: the wrecking ball's comes off for a drag and whenever the rope tension `v²/L + g·cosθ` drops to zero, and goes back on the moment the ball reaches its full reach heading outward.
- Rigid attachments are still stiff springs inside the solver, and links in series add up their compliance: a heavy ball on a chain of small links gets squeezed off its arc when it plows into a pile. One attachment straight to the anchor holds.
- A rigid attachment to a finger that has stopped for even one frame brings the item to a halt, so whether a flick "takes" depends on which frame the touch ended in. Throw explicitly: on release, hand the item the pan's velocity with `addLinearVelocity(_:for:)`.
- Contact friction combines both items' `friction`: a slick ball (`friction = 0`) sheds the bricks that land on it, whatever their own friction.
- An item can have only one active `UISnapBehavior`; replace, don't stack.

## Recording script (~60 sec)

1. **Menu** (2 s) — scroll through the cards.
2. **Gravity** (8 s) — tap a few times, then run a finger in circles: all the balls pour along the walls following the gravity vector.
3. **Snap** (6 s) — tap the corners on "Bouncy 0.2", switch to "Stiff 0.9", tap again.
4. **Wrecking Ball** (10 s) — flick the UIKit ball at the wall of "UIKit is dead": bricks shatter, "STILL ALIVE" drops in and the wall stands back up. A flick up and to the right sends it on a long arc that comes down on the wall.
5. **Push** (9 s) — pull back and release to fire the white cue ball into the rack; sink a few balls into the pockets, switch the mode control to "2" (a slowly rotating continuous force), then to "3" and smash the fake settings screen.
6. **Force Fields** (13 s) — the showstopper: Radial → drag the finger around (the swarm chases it) → Vortex (whirlpool) → Spring (pulsing cloud) → Velocity (fountain).
7. **Solar System** (8 s) — an orrery running on real inverse-square gravity: planets glide along their rings, trails curving behind.
8. **Body Properties** (4 s) — tap a couple of times: the elasticity difference is instantly visible.
9. **Paywall Drop** (6 s) — the finale: tap "Start My 3-Day Free Trial" and the whole paywall falls off the screen, confetti rains, "You're all set" drifts in.

Tip: the simulator has no haptics; for a recording with sound, use a physical device + QuickTime.

## License

MIT — see [LICENSE](LICENSE).
