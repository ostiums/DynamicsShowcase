import UIKit

/// Demonstrates UIGravityBehavior and UICollisionBehavior.
///
/// - Tap drops a ball.
/// - Pan steers `UIGravityBehavior.gravityDirection` (the arrow shows the vector).
/// - `translatesReferenceBoundsIntoBoundary` turns the screen edges into walls.
/// - `UICollisionBehaviorDelegate` reacts to contacts with flashes and haptics.
final class GravityDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = GravityDemoViewModel()

    private var gravity = UIGravityBehavior()
    private var collision = UICollisionBehavior()
    private var ballProperties = UIDynamicItemBehavior()
    private var balls: [BallView] = []
    private var pendingSpawns: [DispatchWorkItem] = []

    private let arrow = UIImageView(image: UIImage(
        systemName: "location.north.fill",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
    ))

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint(viewModel.hint)

        arrow.tintColor = UIColor.white.withAlphaComponent(0.35)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arrow)
        NSLayoutConstraint.activate([
            arrow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    override func buildScene() {
        balls.removeAll()
        cancelPendingSpawns()

        gravity = UIGravityBehavior()

        collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self

        ballProperties = UIDynamicItemBehavior()
        ballProperties.elasticity = viewModel.elasticity
        ballProperties.friction = viewModel.friction
        ballProperties.resistance = viewModel.resistance
        ballProperties.allowsRotation = true

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(ballProperties)

        updateArrow()
        scheduleOpeningRain()
    }

    // MARK: - Scene

    /// Opening rain of balls — looks great from the first second of a recording.
    /// The spawns are kept as work items so a reset can cancel the ones still
    /// pending; otherwise they would rain into the scene that replaced them.
    private func scheduleOpeningRain() {
        for index in 0..<viewModel.initialBallCount {
            let spawn = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.spawnBall(at: self.viewModel.rainSpawnPoint(in: self.view.bounds))
            }
            pendingSpawns.append(spawn)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * viewModel.spawnInterval,
                                          execute: spawn)
        }
    }

    private func cancelPendingSpawns() {
        pendingSpawns.forEach { $0.cancel() }
        pendingSpawns.removeAll()
    }

    private func spawnBall(at point: CGPoint) {
        let ball = BallView(diameter: .random(in: viewModel.ballDiameterRange),
                            color: Palette.randomNeon())
        ball.center = point
        contentView.addSubview(ball)
        balls.append(ball)

        gravity.addItem(ball)
        collision.addItem(ball)
        ballProperties.addItem(ball)

        ball.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) { ball.transform = .identity }

        // Keep the scene light: drop the oldest balls.
        if balls.count > viewModel.maxBallCount {
            let old = balls.removeFirst()
            gravity.removeItem(old)
            collision.removeItem(old)
            ballProperties.removeItem(old)
            UIView.animate(withDuration: 0.2, animations: { old.alpha = 0 }) { _ in
                old.removeFromSuperview()
            }
        }
    }

    private func updateArrow() {
        arrow.transform = CGAffineTransform(
            rotationAngle: viewModel.arrowRotation(for: gravity.gravityDirection)
        )
    }

    // MARK: - Gestures

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        spawnBall(at: tap.location(in: contentView))
        Haptics.action()
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        gravity.gravityDirection = viewModel.gravityDirection(from: center,
                                                              toward: pan.location(in: view))
        updateArrow()
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item1: UIDynamicItem,
                           with item2: UIDynamicItem,
                           at p: CGPoint) {
        reactToContact(item1, item2, intensity: 0.5)
    }

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item: UIDynamicItem,
                           withBoundaryIdentifier identifier: NSCopying?,
                           at p: CGPoint) {
        reactToContact(item, intensity: 0.7)
    }
}
