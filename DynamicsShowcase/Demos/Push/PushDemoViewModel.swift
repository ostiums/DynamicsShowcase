import UIKit

/// Configuration and impulse math for the push demo.
struct PushDemoViewModel {

    /// The two faces of UIPushBehavior.
    enum Mode: Int, CaseIterable {
        case impulse
        case continuous

        var title: String {
            switch self {
            case .impulse: return "Impulse"
            case .continuous: return "Continuous force"
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
    let density: CGFloat = 0.6

    /// Pulls shorter than this don't fire a shot.
    let minimumPullDistance: CGFloat = 20
    /// Scales the pull distance (pt) down to push magnitude units.
    let pullForceDivisor: CGFloat = 30
    /// Cap so a pull across the whole screen doesn't launch a puck into orbit.
    let maximumPushMagnitude: CGFloat = 8
    /// Cap for the spin offset so pucks don't spin absurdly fast.
    let maxSpinOffset: CGFloat = 20

    let continuousMagnitude: CGFloat = 0.4
    /// Radians added to the continuous push angle every display frame.
    let continuousRotationStep: CGFloat = 0.02

    // Pockets: six of them, billiards-style — four corners plus one in
    // the middle of each side rail.
    let pocketRadius: CGFloat = 30
    /// A puck whose center gets this close to a pocket center is potted.
    let pocketCaptureDistance: CGFloat = 27
    /// Pause before a fresh rack replaces a fully potted one.
    let rackRespawnDelay: TimeInterval = 0.9

    /// Pocket centers. `topY` is where the playfield starts — below the
    /// navigation bar and the mode control.
    func pocketCenters(in bounds: CGRect, topY: CGFloat) -> [CGPoint] {
        let inset: CGFloat = 26
        let left = inset
        let right = bounds.width - inset
        let bottom = bounds.height - inset
        let middle = (topY + bottom) / 2
        return [
            CGPoint(x: left, y: topY),
            CGPoint(x: right, y: topY),
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
