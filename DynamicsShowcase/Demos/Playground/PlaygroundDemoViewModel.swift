import Foundation
import CoreGraphics

/// Configuration and layout math for the playground scene.
struct PlaygroundDemoViewModel {

    let initialBallCount = 6
    let spawnInterval: TimeInterval = 0.12
    let maxItemCount = 34
    let ballDiameterRange: ClosedRange<CGFloat> = 32...58
    let groupBoxSize: CGFloat = 34

    // Shared physics.
    let elasticity: CGFloat = 0.55
    let friction: CGFloat = 0.2
    let resistance: CGFloat = 0.1
    /// Fraction of the gesture velocity handed to a thrown item.
    let throwVelocityFactor: CGFloat = 0.8
    /// Radius within which a pan grabs the nearest item.
    let grabRadius: CGFloat = 80

    // Magnet.
    let magnetHoldDuration: TimeInterval = 1.1
    let magnetDamping: CGFloat = 0.4

    /// Two slanted ramps the balls roll down.
    func rampEndpoints(in bounds: CGRect) -> [(from: CGPoint, to: CGPoint)] {
        let w = bounds.width
        let h = bounds.height
        return [
            (CGPoint(x: 0, y: h * 0.32), CGPoint(x: w * 0.62, y: h * 0.42)),
            (CGPoint(x: w, y: h * 0.55), CGPoint(x: w * 0.38, y: h * 0.67)),
        ]
    }

    /// Spawn point for the opening balls — inside the collision bounds,
    /// above the first ramp.
    func rainSpawnPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: .random(in: 40...(bounds.width - 40)),
            y: .random(in: 110...200)
        )
    }

    /// Ring targets around the magnet point, spread over a few radii
    /// so gathered items form a loose flower instead of one clump.
    func magnetTargets(around point: CGPoint, count: Int) -> [CGPoint] {
        (0..<count).map { index in
            let angle = CGFloat(index) * (.pi * 2 / CGFloat(max(count, 1)))
            let radius = CGFloat(40 + (index % 3) * 34)
            return CGPoint(
                x: point.x + cos(angle) * radius,
                y: point.y + sin(angle) * radius
            )
        }
    }
}
