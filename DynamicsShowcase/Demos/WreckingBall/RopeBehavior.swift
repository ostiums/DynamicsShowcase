import UIKit

/// A rope between a fixed anchor and a dynamic item.
///
/// `UIAttachmentBehavior` can't play this part: rigid or springy, it works
/// both ways and pushes the item away as readily as it pulls it in. A rope
/// only ever pulls. Shorter than its length it is slack and the item flies
/// free; stretched past it, it acts as a damped spring along its own line.
///
/// The pull is applied as a velocity change on every animator step, so it
/// is an acceleration and doesn't depend on the item's mass.
final class RopeBehavior: UIDynamicBehavior {

    let anchor: CGPoint
    let length: CGFloat
    /// Natural frequency of the stretched rope, Hz.
    let frequency: CGFloat
    /// 0 rings forever, 1 doesn't ring at all.
    let dampingRatio: CGFloat

    private let item: UIDynamicItem
    /// Reads and changes the item's velocity. The item must belong to it.
    private weak var body: UIDynamicItemBehavior?
    private var lastStepTime: TimeInterval?
    /// A paused rope pulls nothing; for freezing the scene.
    var isPaused = false

    init(
        item: UIDynamicItem,
        body: UIDynamicItemBehavior,
        anchor: CGPoint,
        length: CGFloat,
        frequency: CGFloat,
        dampingRatio: CGFloat
    ) {
        self.item = item
        self.body = body
        self.anchor = anchor
        self.length = length
        self.frequency = frequency
        self.dampingRatio = dampingRatio
        super.init()
        action = { [weak self] in self?.step() }
    }

    /// How far the rope is stretched past its length; negative while slack.
    var stretch: CGFloat {
        hypot(item.center.x - anchor.x, item.center.y - anchor.y) - length
    }

    /// Acceleration along the rope, positive away from the anchor: a spring
    /// on the stretch plus a damper on the speed the rope is lengthening at.
    /// Never positive — a rope recoiling faster than its damper allows
    /// simply goes limp, it doesn't push.
    static func pull(
        stretch: CGFloat,
        radialSpeed: CGFloat,
        frequency: CGFloat,
        dampingRatio: CGFloat
    ) -> CGFloat {
        guard stretch > 0 else { return 0 }
        let omega = 2 * .pi * frequency
        return min(0, -omega * omega * stretch - 2 * dampingRatio * omega * radialSpeed)
    }

    private func step() {
        guard let animator = dynamicAnimator, let body else { return }
        let now = animator.elapsedTime
        defer { lastStepTime = now }
        guard !isPaused, let lastStepTime else { return }
        // The animator's clock stands still while the scene is at rest;
        // a long first step after a pause must not turn into a kick.
        let dt = min(now - lastStepTime, 1.0 / 30)
        guard dt > 0 else { return }

        let dx = item.center.x - anchor.x
        let dy = item.center.y - anchor.y
        let distance = hypot(dx, dy)
        guard distance > length else { return }

        let velocity = body.linearVelocity(for: item)
        let radialSpeed = (velocity.x * dx + velocity.y * dy) / distance
        let acceleration = Self.pull(
            stretch: distance - length,
            radialSpeed: radialSpeed,
            frequency: frequency,
            dampingRatio: dampingRatio
        )
        body.addLinearVelocity(
            CGPoint(x: dx / distance * acceleration * dt, y: dy / distance * acceleration * dt),
            for: item
        )
    }
}
