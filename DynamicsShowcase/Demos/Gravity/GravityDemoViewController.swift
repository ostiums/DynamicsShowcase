import UIKit

/// Demonstrates UIGravityBehavior and UICollisionBehavior.
///
/// - Tap drops a ball.
/// - Pan steers `UIGravityBehavior.gravityDirection` (the arrow shows the vector).
/// - The slider scales `UIGravityBehavior.magnitude` — down to zero, where the
///   balls also get their velocity cancelled and freeze mid-air.
/// - `translatesReferenceBoundsIntoBoundary` turns the screen edges into walls.
/// - `UICollisionBehaviorDelegate` reacts to contacts with flashes and haptics.
final class GravityDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = GravityDemoViewModel()

    private var gravity = UIGravityBehavior()
    private var collision = UICollisionBehavior()
    private var ballProperties = UIDynamicItemBehavior()
    private var balls: [BallView] = []

    /// Unit direction of gravity, kept separately from the behavior:
    /// `gravityDirection` and `magnitude` are one and the same vector
    /// (its length is the strength), so assigning a unit direction would
    /// silently reset the slider's magnitude back to 1.
    private var gravityUnitDirection = CGVector(dx: 0, dy: 1)

    private let arrow = UIImageView(image: UIImage(
        systemName: "location.north.fill",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
    ))

    private let magnitudeSlider = UISlider()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        arrow.tintColor = UIColor.white.withAlphaComponent(0.35)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arrow)
        NSLayoutConstraint.activate([
            arrow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrow.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        magnitudeSlider.minimumValue = Float(viewModel.gravityMagnitudeRange.lowerBound)
        magnitudeSlider.maximumValue = Float(viewModel.gravityMagnitudeRange.upperBound)
        magnitudeSlider.value = Float(viewModel.defaultGravityMagnitude)
        magnitudeSlider.minimumTrackTintColor = Palette.cyan
        magnitudeSlider.tintColor = UIColor.white.withAlphaComponent(0.7)
        magnitudeSlider.minimumValueImage = UIImage(systemName: "snowflake")
        magnitudeSlider.maximumValueImage = UIImage(systemName: "globe.americas.fill")
        magnitudeSlider.addTarget(self, action: #selector(magnitudeChanged), for: .valueChanged)
        magnitudeSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(magnitudeSlider)
        NSLayoutConstraint.activate([
            magnitudeSlider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            magnitudeSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            magnitudeSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    override func buildScene() {
        balls.removeAll()

        gravity = UIGravityBehavior()
        gravityUnitDirection = CGVector(dx: 0, dy: 1)
        applyGravityVector()

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

    /// Opening rain of balls — looks great from the first second of a
    /// recording. Scheduled via the base class, so a reset cancels the
    /// spawns still pending instead of raining them into the new scene.
    private func scheduleOpeningRain() {
        for index in 0..<viewModel.initialBallCount {
            schedule(after: Double(index) * viewModel.spawnInterval) { [weak self] in
                guard let self else { return }
                self.spawnBall(at: self.viewModel.rainSpawnPoint(in: self.view.bounds))
            }
        }
    }

    private func spawnBall(at point: CGPoint) {
        let ball = BallView(
            diameter: .random(in: viewModel.ballDiameterRange),
            color: Palette.randomNeon()
        )
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

    /// The single writer of the behavior's vector: direction × slider value.
    private func applyGravityVector() {
        let magnitude = CGFloat(magnitudeSlider.value)
        gravity.gravityDirection = CGVector(
            dx: gravityUnitDirection.dx * magnitude,
            dy: gravityUnitDirection.dy * magnitude
        )
    }

    private func updateArrow() {
        arrow.transform = CGAffineTransform(
            rotationAngle: viewModel.arrowRotation(for: gravityUnitDirection)
        )
    }

    // MARK: - Gestures

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        spawnBall(at: tap.location(in: contentView))
        Haptics.action()
    }

    @objc private func magnitudeChanged() {
        applyGravityVector()
        if magnitudeSlider.value == 0 {
            freezeBalls()
        }
    }

    /// Zero gravity turns the scene into stopped time: every ball's velocity
    /// is cancelled out, so they hang exactly where the slider caught them.
    /// There is no velocity setter — the inverse is added instead.
    private func freezeBalls() {
        for ball in balls {
            let velocity = ballProperties.linearVelocity(for: ball)
            ballProperties.addLinearVelocity(
                CGPoint(x: -velocity.x, y: -velocity.y),
                for: ball
            )
            ballProperties.addAngularVelocity(
                -ballProperties.angularVelocity(for: ball),
                for: ball
            )
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        gravityUnitDirection = viewModel.gravityDirection(
            from: center,
            toward: pan.location(in: view)
        )
        applyGravityVector()
        updateArrow()
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item1: UIDynamicItem,
        with item2: UIDynamicItem,
        at p: CGPoint
    ) {
        reactToContact(item1, item2, intensity: 0.5)
    }

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item: UIDynamicItem,
        withBoundaryIdentifier identifier: NSCopying?,
        at p: CGPoint
    ) {
        reactToContact(item, intensity: 0.7)
    }
}

// MARK: - Screenshot snippet
//
// The physics core of this screen, stripped of layout and styling.
// This block goes on the code screenshot shown next to the recording.
/*

let animator = UIDynamicAnimator(referenceView: view)

let gravity = UIGravityBehavior()
let collision = UICollisionBehavior()
collision.translatesReferenceBoundsIntoBoundary = true  // screen edges become walls
animator.addBehavior(gravity)
animator.addBehavior(collision)

// Every tap hands one more ball over to the simulation.
gravity.addItem(ball)
collision.addItem(ball)

// Pan steers the vector, the slider scales it. Direction and strength
// are one CGVector: its length IS the magnitude (1 is UIKit's default),
// so assigning a unit direction would reset the strength back to 1.
gravity.gravityDirection = CGVector(
    dx: cos(angle) * magnitude,
    dy: sin(angle) * magnitude
)

// At zero gravity the balls freeze mid-air: cancel their velocity
// (there is no setter — add the inverse of the current value).
let velocity = ballProperties.linearVelocity(for: ball)
ballProperties.addLinearVelocity(
    CGPoint(x: -velocity.x, y: -velocity.y),
    for: ball
)
*/
