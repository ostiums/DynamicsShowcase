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
                return "Flick a puck — an instantaneous impulse.  Force = gesture velocity"
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

    /// Gestures slower than this don't produce a push.
    let minimumFlickSpeed: CGFloat = 100
    /// Scales gesture velocity (pt/s) down to push magnitude units.
    let flickForceDivisor: CGFloat = 700
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
            return CGPoint(x: center.x + cos(angle) * ringRadius,
                           y: center.y + sin(angle) * ringRadius)
        }
    }

    /// Push vector for a flick, or nil when the gesture was too slow.
    /// UIPushBehavior treats the vector's length as the force magnitude.
    func impulseVector(forGestureVelocity velocity: CGPoint) -> CGVector? {
        guard hypot(velocity.x, velocity.y) > minimumFlickSpeed else { return nil }
        return CGVector(dx: velocity.x / flickForceDivisor,
                        dy: velocity.y / flickForceDivisor)
    }

    /// Offset of the force application point from the puck's center.
    /// An off-center push adds angular velocity — the puck spins.
    func spinOffset(fromTouch touch: CGPoint, puckCenter: CGPoint) -> UIOffset {
        UIOffset(horizontal: (touch.x - puckCenter.x).clamped(to: -maxSpinOffset...maxSpinOffset),
                 vertical: (touch.y - puckCenter.y).clamped(to: -maxSpinOffset...maxSpinOffset))
    }
}
