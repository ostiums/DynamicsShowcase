import UIKit

/// Tiny haptics helper used across the demos.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static var lastFire: CFTimeInterval = 0

    /// Collision tick. Collisions fire dozens of times per second,
    /// so this is throttled to keep the Taptic Engine responsive.
    static func collision(intensity: CGFloat = 0.6) {
        let now = CACurrentMediaTime()
        guard now - lastFire > 0.06 else { return }
        lastFire = now
        light.impactOccurred(intensity: intensity)
    }

    /// A firmer tick for direct user actions (spawn, snap, flick).
    static func action() {
        rigid.impactOccurred(intensity: 0.8)
    }
}
