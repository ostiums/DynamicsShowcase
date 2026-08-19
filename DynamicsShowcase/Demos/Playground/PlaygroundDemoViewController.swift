import UIKit

/// The grand finale: several behaviors composed in one scene.
///
/// - Gravity + collisions with slanted ramp boundaries.
/// - Tap spawns a ball; long-press spawns a domino pair driven by
///   `UIDynamicItemGroup` (two views moving as one rigid body).
/// - Pan drags an item with an attachment and throws it with the
///   gesture velocity on release.
/// - Two-finger tap is a "magnet": temporary snaps gather everything
///   around the touch point, then release it back to gravity.
final class PlaygroundDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = PlaygroundDemoViewModel()

    private var gravity = UIGravityBehavior()
    private var collision = UICollisionBehavior()
    private var itemProperties = UIDynamicItemBehavior()

    private var items: [UIView] = []
    private var dragAttachment: UIAttachmentBehavior?
    private weak var draggedView: UIView?
    private var magnetSnaps: [UISnapBehavior] = []
    private var pendingSpawns: [DispatchWorkItem] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint(viewModel.hint)

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress)))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))

        let magnet = UITapGestureRecognizer(target: self, action: #selector(handleMagnet))
        magnet.numberOfTouchesRequired = 2
        view.addGestureRecognizer(magnet)
    }

    override func buildScene() {
        items.removeAll()
        magnetSnaps.removeAll()
        cancelPendingSpawns()

        gravity = UIGravityBehavior()

        collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self

        itemProperties = UIDynamicItemBehavior()
        itemProperties.elasticity = viewModel.elasticity
        itemProperties.friction = viewModel.friction
        itemProperties.resistance = viewModel.resistance

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(itemProperties)

        addRamps()
        scheduleOpeningRain()
    }

    /// Slanted ramps: collision boundary lines drawn as glowing layers.
    private func addRamps() {
        for (index, ramp) in viewModel.rampEndpoints(in: view.bounds).enumerated() {
            collision.addBoundary(
                withIdentifier: "ramp\(index)" as NSString,
                from: ramp.from,
                to: ramp.to
            )
            contentView.layer.addSublayer(CAShapeLayer.boundaryLine(from: ramp.from, to: ramp.to))
        }
    }

    // MARK: - Spawning

    /// Opening rain of balls. The spawns are kept as work items so a reset can
    /// cancel the ones still pending — otherwise they would rain into the scene
    /// that replaced them.
    private func scheduleOpeningRain() {
        for index in 0..<viewModel.initialBallCount {
            let spawn = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.spawnBall(at: self.viewModel.rainSpawnPoint(in: self.view.bounds))
            }
            pendingSpawns.append(spawn)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(index) * viewModel.spawnInterval,
                execute: spawn
            )
        }
    }

    private func cancelPendingSpawns() {
        pendingSpawns.forEach { $0.cancel() }
        pendingSpawns.removeAll()
    }

    private func spawnBall(at point: CGPoint) {
        let ball = BallView(
            diameter: .random(in: viewModel.ballDiameterRange),
            color: Palette.randomNeon()
        )
        ball.center = point
        contentView.addSubview(ball)
        items.append(ball)

        gravity.addItem(ball)
        collision.addItem(ball)
        itemProperties.addItem(ball)
        trimItems()
    }

    /// UIDynamicItemGroup: two squares move as a single rigid body.
    /// The group itself is added to the behaviors — not its members.
    private func spawnGroup(at point: CGPoint) {
        let size = viewModel.groupBoxSize
        let color = Palette.randomNeon()
        let left = BoxView(size: size, color: color)
        let right = BoxView(size: size, color: color.adjusted(brightnessBy: 1.4))
        left.center = CGPoint(x: point.x - size / 2, y: point.y)
        right.center = CGPoint(x: point.x + size / 2, y: point.y)
        contentView.addSubview(left)
        contentView.addSubview(right)
        items.append(left)
        items.append(right)

        let group = UIDynamicItemGroup(items: [left, right])
        gravity.addItem(group)
        collision.addItem(group)
        itemProperties.addItem(group)
    }

    /// Keeps the scene light by dropping the oldest ball.
    /// Group members (the BoxViews) are skipped rather than removed: a
    /// UIDynamicItemGroup member can't be taken out on its own, and dropping it
    /// from `items` would leave it in the scene untracked by the magnet and the drag.
    private func trimItems() {
        guard items.count > viewModel.maxItemCount,
              let oldestBallIndex = items.firstIndex(where: { $0 is BallView })
        else { return }
        let old = items.remove(at: oldestBallIndex)
        gravity.removeItem(old)
        collision.removeItem(old)
        itemProperties.removeItem(old)
        UIView.animate(withDuration: 0.2, animations: { old.alpha = 0 }) { _ in
            old.removeFromSuperview()
        }
    }

    // MARK: - Gestures

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        spawnBall(at: tap.location(in: contentView))
        Haptics.action()
    }

    @objc private func handleLongPress(_ press: UILongPressGestureRecognizer) {
        guard press.state == .began else { return }
        spawnGroup(at: press.location(in: contentView))
        Haptics.action()
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            // Group members can't be dragged individually — UIDynamicItemGroup owns them.
            let grabbable = items.filter { !($0 is BoxView) }
            guard let target = grabbable.nearest(to: location, within: viewModel.grabRadius)
            else { return }
            draggedView = target
            let attachment = UIAttachmentBehavior(item: target, attachedToAnchor: location)
            animator.addBehavior(attachment)
            dragAttachment = attachment

        case .changed:
            dragAttachment?.anchorPoint = location

        default:
            if let dragAttachment {
                animator.removeBehavior(dragAttachment)
                self.dragAttachment = nil
            }
            // Throw: hand the gesture velocity over to the item.
            if let draggedView {
                let velocity = pan.velocity(in: contentView)
                itemProperties.addLinearVelocity(
                    CGPoint(
                        x: velocity.x * viewModel.throwVelocityFactor,
                        y: velocity.y * viewModel.throwVelocityFactor
                    ),
                    for: draggedView
                )
                self.draggedView = nil
            }
        }
    }

    /// Magnet: every ball flies to the touch point, then falls again.
    @objc private func handleMagnet(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: contentView)
        Haptics.action()

        releaseMagnet()

        let balls = items.filter { $0 is BallView }
        let targets = viewModel.magnetTargets(around: point, count: balls.count)
        for (ball, target) in zip(balls, targets) {
            let snap = UISnapBehavior(item: ball, snapTo: target)
            snap.damping = viewModel.magnetDamping
            animator.addBehavior(snap)
            magnetSnaps.append(snap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + viewModel.magnetHoldDuration) { [weak self] in
            self?.releaseMagnet()
        }
    }

    /// Drops the snaps so the gathered items fall back under gravity.
    private func releaseMagnet() {
        magnetSnaps.forEach { animator.removeBehavior($0) }
        magnetSnaps.removeAll()
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item1: UIDynamicItem,
        with item2: UIDynamicItem,
        at p: CGPoint
    ) {
        reactToContact(item1, item2, intensity: 0.45)
    }
}
