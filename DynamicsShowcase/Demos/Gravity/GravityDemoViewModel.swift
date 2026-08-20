import Foundation
import CoreGraphics

/// Configuration and pure geometry for the gravity demo.
/// Knows nothing about views or behaviors — the controller reads values
/// from here and feeds them into UIKit Dynamics.
struct GravityDemoViewModel {

    // Scene tuning.
    let initialBallCount = 10
    let spawnInterval: TimeInterval = 0.09
    let maxBallCount = 26
    let ballDiameterRange: ClosedRange<CGFloat> = 34...64

    // Gravity strength driven by the slider; 1 is UIKit's default pull.
    // At zero the demo also cancels the balls' velocity, freezing them mid-air.
    let gravityMagnitudeRange: ClosedRange<CGFloat> = 0...3
    let defaultGravityMagnitude: CGFloat = 1

    // Physical properties shared by all balls (UIDynamicItemBehavior).
    let elasticity: CGFloat = 0.65
    let friction: CGFloat = 0.15
    let resistance: CGFloat = 0.1

    /// Unit vector from the screen center toward the touch —
    /// becomes UIGravityBehavior.gravityDirection.
    func gravityDirection(from center: CGPoint, toward point: CGPoint) -> CGVector {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let length = max(1, hypot(dx, dy))
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// Rotation for an arrow image that points up by default,
    /// so that it ends up pointing along the gravity vector.
    func arrowRotation(for direction: CGVector) -> CGFloat {
        atan2(direction.dx, -direction.dy)
    }

    /// Random spawn point for the opening "rain". Kept inside the bounds:
    /// an item spawned above the screen would land on top of the outer
    /// collision boundary instead of falling into view.
    func rainSpawnPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: .random(in: 40...(bounds.width - 40)),
            y: .random(in: 130...300)
        )
    }
}
