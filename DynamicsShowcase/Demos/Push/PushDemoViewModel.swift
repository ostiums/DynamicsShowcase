import UIKit

/// Configuration and impulse math for the push demo.
struct PushDemoViewModel {

    /// The two faces of UIPushBehavior, plus the proof-of-concept mode
    /// where the targets are ordinary UIButtons.
    enum Mode: Int, CaseIterable {
        case impulse
        case continuous
        case ui

        var title: String {
            switch self {
            case .impulse: return "1"
            case .continuous: return "2"
            case .ui: return "3"
            }
        }
    }

    /// A billiards rack: rows of 1, 2 and 3 balls.
    let puckCount = 6
    let puckDiameter: CGFloat = 44

    // Puck physics: nearly frictionless, very bouncy — air hockey.
    let elasticity: CGFloat = 0.9
    let friction: CGFloat = 0.02
    let resistance: CGFloat = 0.35
    /// Heavy balls read as real billiards; the push forces below are
    /// scaled up to match the tripled mass.
    let density: CGFloat = 1.8

    /// Pulls shorter than this don't fire a shot.
    let minimumPullDistance: CGFloat = 20
    /// Scales the pull distance (pt) down to push magnitude units.
    let pullForceDivisor: CGFloat = 10
    /// Cap so a pull across the whole screen doesn't launch a puck into orbit.
    let maximumPushMagnitude: CGFloat = 24
    /// Cap for the spin offset so pucks don't spin absurdly fast.
    let maxSpinOffset: CGFloat = 20

    let continuousMagnitude: CGFloat = 1.2
    /// Radians added to the continuous push angle every display frame.
    let continuousRotationStep: CGFloat = 0.02

    // Pockets: six of them, billiards-style — four corners plus one in
    // the middle of each side rail.
    let pocketRadius: CGFloat = 30
    /// A puck whose center gets this close to a pocket center is potted.
    let pocketCaptureDistance: CGFloat = 27
    /// Pause before a fresh rack replaces a fully potted one.
    let rackRespawnDelay: TimeInterval = 0.9

    /// Pocket centers, tucked into the corners and side rails of the
    /// table. `tableTop` is the top edge of the playfield — the bottom
    /// of the navigation bar.
    func pocketCenters(in bounds: CGRect, tableTop: CGFloat) -> [CGPoint] {
        let inset: CGFloat = 26
        let left = inset
        let right = bounds.width - inset
        // The top row sits fully below the rail line, not across it.
        let top = tableTop + pocketRadius + 8
        let bottom = bounds.height - inset
        let middle = (top + bottom) / 2
        return [
            CGPoint(x: left, y: top),
            CGPoint(x: right, y: top),
            CGPoint(x: left, y: middle),
            CGPoint(x: right, y: middle),
            CGPoint(x: left, y: bottom),
            CGPoint(x: right, y: bottom),
        ]
    }

    /// Vertical shift of the rack above the screen center — leaves room
    /// for the cue ball below, billiards-style.
    let rackOffsetY: CGFloat = -70

    /// Initial puck centers: a billiards rack — a tight triangle with the
    /// apex on top, slightly above the screen center.
    func puckCenters(in bounds: CGRect) -> [CGPoint] {
        let spacing = puckDiameter + 2
        let rowHeight = spacing * 0.87 // √3 / 2 — rows of a close-packed rack
        var centers: [CGPoint] = []
        var row = 0
        while centers.count < puckCount {
            for column in 0...row where centers.count < puckCount {
                centers.append(CGPoint(
                    x: bounds.midX + (CGFloat(column) - CGFloat(row) / 2) * spacing,
                    y: bounds.midY + rackOffsetY + (CGFloat(row) - 1) * rowHeight
                ))
            }
            row += 1
        }
        return centers
    }

    /// The white cue ball spawns below the rack.
    func cueBallCenter(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY + 170)
    }

    /// In the "Real UI" mode the cue ball starts near the bottom edge,
    /// well clear of the fake screen it is about to smash.
    func uiCueBallCenter(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.height - 130)
    }

    /// The wrecking cue ball of the "Real UI" mode: heavy enough to plow
    /// through the fake screen without losing speed.
    let uiCueBallDensity: CGFloat = 5
    /// The shot impulse is boosted by the same factor as the mass, so the
    /// heavy ball launches at the familiar speed.
    var uiImpulseBoost: CGFloat { uiCueBallDensity / density }

    // The "Real UI" mode: a fake settings screen in place of the rack —
    // proof that the physics runs on plain UIKit views, not sprites.
    let uiScreenTitle = "Settings"
    let uiProfileName = "Jane Appleseed"
    let uiProfileDetail = "Apple Account, iCloud & more"
    let uiProfileInitials = "JA"
    let uiToggleTitle = "Dark Mode"
    let uiLinkTitle = "Wi-Fi"
    let uiLinkValue = "Home"
    let uiPrimaryTitle = "Upgrade to Pro"
    let uiSecondaryTitle = "Rate the App"
    let uiDestructiveTitle = "Sign Out"

    // Target physics: each cell hangs on an invisible spring at its home
    // spot — a hit rocks it, jelly-like, and it settles back instead of
    // flying off. Density grows with area, so the small elements dart
    // away while the big profile cell barely budges.
    let targetElasticity: CGFloat = 0.5
    let targetFriction: CGFloat = 0.3
    let targetResistance: CGFloat = 0.5
    let targetSpringFrequency: CGFloat = 2.2
    let targetSpringDamping: CGFloat = 0.55

    /// Density proportional to the element's area (1 at ~110 × 110 pt):
    /// the Sign Out link flies like a bullet, the profile cell shrugs
    /// the same hit off. That size-to-weight honesty is what makes the
    /// scene read as physically real.
    func targetDensity(forArea area: CGFloat) -> CGFloat {
        (area / 12_000).clamped(to: 0.3...4)
    }

    // Shattering: a hard-enough hit breaks the cell into snapshot shards.
    /// Cue-ball speed (pt/s) at contact that shatters a cell instead of
    /// just rocking it on its spring.
    let shatterSpeedThreshold: CGFloat = 900
    /// Radial burst added to every shard, away from the cell's center.
    let shardBurstSpeed: ClosedRange<CGFloat> = 120...320
    let shardSpinRange: ClosedRange<CGFloat> = -8...8
    let shardResistance: CGFloat = 0.6
    /// By this time the shards have rained off the screen.
    let shardCleanupDelay: TimeInterval = 3.5

    /// Billiards-style shot: the puck flies opposite to the pull, and the
    /// farther the finger is pulled back, the harder the shot. Returns nil
    /// when the pull is too short. UIPushBehavior treats the vector's
    /// length as the force magnitude.
    func impulseVector(pullingFrom location: CGPoint, puckCenter: CGPoint) -> CGVector? {
        let dx = puckCenter.x - location.x
        let dy = puckCenter.y - location.y
        let distance = hypot(dx, dy)
        guard distance > minimumPullDistance else { return nil }

        let magnitude = min(distance / pullForceDivisor, maximumPushMagnitude)
        return CGVector(
            dx: dx / distance * magnitude,
            dy: dy / distance * magnitude
        )
    }

    /// Offset of the force application point from the puck's center — where
    /// the "cue" struck. An off-center push adds angular velocity: the puck spins.
    func spinOffset(fromGrab grab: CGPoint, puckCenter: CGPoint) -> UIOffset {
        UIOffset(
            horizontal: (grab.x - puckCenter.x).clamped(to: -maxSpinOffset...maxSpinOffset),
            vertical: (grab.y - puckCenter.y).clamped(to: -maxSpinOffset...maxSpinOffset)
        )
    }
}
