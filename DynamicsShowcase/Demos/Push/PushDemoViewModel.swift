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

        var hint: String {
            switch self {
            case .impulse:
                return "Pull back from a puck and release — it shoots the other way, billiards-style"
            case .continuous:
                return "UIPushBehavior(.continuous) — constant force with a slowly rotating vector"
            }
        }
    }

    let puckCount = 5
    let puckDiameter: CGFloat = 54
    let ringRadius: CGFloat = 110

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

    /// Initial puck centers: a pentagon around the screen center.
    func puckCenters(in bounds: CGRect) -> [CGPoint] {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return (0..<puckCount).map { index in
            let angle = CGFloat(index) * (.pi * 2 / CGFloat(puckCount)) - .pi / 2
            return CGPoint(
                x: center.x + cos(angle) * ringRadius,
                y: center.y + sin(angle) * ringRadius
            )
        }
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
