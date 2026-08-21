import UIKit

/// Demonstrates UIPushBehavior in both of its modes.
///
/// - `.instantaneous` — a one-shot impulse, billiards-style: pull back from
///   a puck and release, and it shoots in the opposite direction; the farther
///   the pull, the harder the shot. Grabbing off-center adds spin via
///   `setTargetOffsetFromCenter(_:for:)`.
/// - `.continuous` — a constant force applied every frame; here its angle
///   slowly rotates, swirling all the pucks around the table.
/// - Six pockets, billiards-style: a ball that reaches one is potted, and
///   once the table is cleared a fresh rack rolls out.
/// - The white cue ball is the one you shoot — pull back anywhere on the
///   table. A potted cue ball respawns on its spot after a pause.
final class PushDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = PushDemoViewModel()

    private var pucks: [BallView] = []
    private var collision = UICollisionBehavior()
    private var puckProperties = UIDynamicItemBehavior()

    private let modeControl = UISegmentedControl()
    private var continuousPush: UIPushBehavior?
    private var rotationLink: CADisplayLink?

    private var cueBall: BallView?
    private var pocketCenters: [CGPoint] = []
    private var pocketLink: CADisplayLink?
    private var pendingRespawn: DispatchWorkItem?
    private var pendingCueRespawn: DispatchWorkItem?

    private var allBalls: [BallView] {
        if let cueBall { return pucks + [cueBall] }
        return pucks
    }

    private let aimLayer = CAShapeLayer()
    private var grabPoint: CGPoint = .zero
    private weak var aimedPuck: BallView?

    private var mode: PushDemoViewModel.Mode {
        PushDemoViewModel.Mode(rawValue: modeControl.selectedSegmentIndex) ?? .impulse
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // The billiards table speaks for itself — no navigation title.
        navigationItem.largeTitleDisplayMode = .never
        title = nil

        for (index, mode) in PushDemoViewModel.Mode.allCases.enumerated() {
            modeControl.insertSegment(withTitle: mode.title, at: index, animated: false)
        }
        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = Palette.mint.withAlphaComponent(0.5)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeControl)
        NSLayoutConstraint.activate([
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])

        // Dashed pull-back line: finger → puck.
        aimLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        aimLayer.lineWidth = 2
        aimLayer.lineDashPattern = [4, 6]
        aimLayer.fillColor = nil
        view.layer.addSublayer(aimLayer)

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    // A CADisplayLink retains its target, so it only runs while the screen is on
    // screen — otherwise it would keep this controller alive forever.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if continuousPush != nil {
            startRotationLink()
        }
        startPocketLink()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopRotationLink()
        stopPocketLink()
    }

    override func buildScene() {
        pucks.removeAll()
        cueBall = nil
        continuousPush = nil
        stopRotationLink()
        pendingRespawn?.cancel()
        pendingRespawn = nil
        pendingCueRespawn?.cancel()
        pendingCueRespawn = nil

        collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self

        puckProperties = UIDynamicItemBehavior()
        puckProperties.elasticity = viewModel.elasticity
        puckProperties.friction = viewModel.friction
        puckProperties.resistance = viewModel.resistance
        puckProperties.density = viewModel.density
        puckProperties.allowsRotation = true

        animator.addBehavior(collision)
        animator.addBehavior(puckProperties)

        pocketCenters = viewModel.pocketCenters(
            in: view.bounds,
            topY: view.safeAreaLayoutGuide.layoutFrame.minY + 70
        )
        addPocketViews()
        spawnRack()
        spawnCueBall()

        if mode == .continuous {
            startContinuousPush()
        }
    }

    private func spawnRack() {
        for (index, center) in viewModel.puckCenters(in: view.bounds).enumerated() {
            let puck = BallView(diameter: viewModel.puckDiameter, color: Palette.neon[index])
            pucks.append(puck)
            place(puck, at: center)
        }
    }

    private func spawnCueBall() {
        let ball = BallView(diameter: viewModel.puckDiameter, color: .white)
        cueBall = ball
        place(ball, at: viewModel.cueBallCenter(in: view.bounds))
        // A cue ball respawned mid-swirl joins the continuous force too.
        continuousPush?.addItem(ball)
    }

    private func place(_ ball: BallView, at center: CGPoint) {
        ball.center = center
        contentView.addSubview(ball)
        collision.addItem(ball)
        puckProperties.addItem(ball)

        ball.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) { ball.transform = .identity }
    }

    // MARK: - Slingshot (.instantaneous)

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard mode == .impulse else { return }
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            grabPoint = location
            // Billiards: the shot always fires the white cue ball.
            aimedPuck = cueBall

        case .changed:
            guard let puck = aimedPuck else { return }
            drawAimLine(from: location, to: puck.center)

        case .ended:
            aimLayer.path = nil
            guard let puck = aimedPuck,
                  let impulse = viewModel.impulseVector(pullingFrom: location, puckCenter: puck.center)
            else { return }

            let push = UIPushBehavior(items: [puck], mode: .instantaneous)
            push.pushDirection = impulse
            push.setTargetOffsetFromCenter(
                viewModel.spinOffset(fromGrab: grabPoint, puckCenter: puck.center),
                for: puck
            )

            // An instantaneous push fires once — remove the behavior afterwards.
            push.action = { [weak self, weak push] in
                if let push, !push.active {
                    self?.animator.removeBehavior(push)
                }
            }
            animator.addBehavior(push)
            Haptics.action()

        default:
            aimLayer.path = nil
        }
    }

    /// The pull-back segment: finger → puck. The shot goes the opposite way.
    private func drawAimLine(from location: CGPoint, to puckCenter: CGPoint) {
        let path = UIBezierPath()
        path.move(to: location)
        path.addLine(to: puckCenter)
        aimLayer.path = path.cgPath
    }

    // MARK: - Continuous force (.continuous)

    @objc private func modeChanged() {
        if mode == .continuous {
            startContinuousPush()
        } else {
            stopContinuousPush()
        }
    }

    private func startContinuousPush() {
        stopContinuousPush()
        let push = UIPushBehavior(items: allBalls, mode: .continuous)
        push.magnitude = viewModel.continuousMagnitude
        push.angle = -.pi / 2
        animator.addBehavior(push)
        continuousPush = push
        startRotationLink()
    }

    private func stopContinuousPush() {
        if let continuousPush {
            animator.removeBehavior(continuousPush)
            self.continuousPush = nil
        }
        stopRotationLink()
    }

    private func startRotationLink() {
        stopRotationLink()
        let link = CADisplayLink(target: self, selector: #selector(rotatePushVector))
        link.add(to: .main, forMode: .common)
        rotationLink = link
    }

    private func stopRotationLink() {
        rotationLink?.invalidate()
        rotationLink = nil
    }

    @objc private func rotatePushVector() {
        continuousPush?.angle += viewModel.continuousRotationStep
    }

    // MARK: - Pockets

    private func addPocketViews() {
        let radius = viewModel.pocketRadius
        for center in pocketCenters {
            let pocket = UIView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            pocket.center = center
            pocket.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            pocket.layer.cornerRadius = radius
            pocket.layer.borderWidth = 2
            pocket.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            contentView.addSubview(pocket)
        }
    }

    private func startPocketLink() {
        stopPocketLink()
        let link = CADisplayLink(target: self, selector: #selector(checkPockets))
        link.add(to: .main, forMode: .common)
        pocketLink = link
    }

    private func stopPocketLink() {
        pocketLink?.invalidate()
        pocketLink = nil
    }

    /// A ball whose center reaches a pocket is potted.
    @objc private func checkPockets() {
        for ball in allBalls {
            let pocket = pocketCenters.first { center in
                hypot(ball.center.x - center.x, ball.center.y - center.y)
                    < viewModel.pocketCaptureDistance
            }
            if let pocket {
                pot(ball, into: pocket)
            }
        }
    }

    /// Takes the ball out of the simulation and swallows it into the pocket.
    private func pot(_ ball: BallView, into pocket: CGPoint) {
        if ball === cueBall {
            cueBall = nil
            scheduleCueRespawn()
        } else {
            pucks.removeAll { $0 === ball }
            if pucks.isEmpty {
                scheduleRackRespawn()
            }
        }
        collision.removeItem(ball)
        puckProperties.removeItem(ball)
        continuousPush?.removeItem(ball)
        Haptics.collision(intensity: 0.9)

        UIView.animate(
            withDuration: 0.25,
            animations: {
                ball.center = pocket
                ball.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                ball.alpha = 0
            },
            completion: { _ in
                ball.removeFromSuperview()
            }
        )
    }

    /// The table is cleared — roll out a fresh rack after a short pause.
    private func scheduleRackRespawn() {
        pendingRespawn?.cancel()
        let respawn = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.spawnRack()
            if self.mode == .continuous {
                self.startContinuousPush()
            }
        }
        pendingRespawn = respawn
        DispatchQueue.main.asyncAfter(
            deadline: .now() + viewModel.rackRespawnDelay,
            execute: respawn
        )
    }

    /// A potted (scratched) cue ball comes back to its spot.
    private func scheduleCueRespawn() {
        pendingCueRespawn?.cancel()
        let respawn = DispatchWorkItem { [weak self] in
            self?.spawnCueBall()
        }
        pendingCueRespawn = respawn
        DispatchQueue.main.asyncAfter(
            deadline: .now() + viewModel.rackRespawnDelay,
            execute: respawn
        )
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item1: UIDynamicItem,
        with item2: UIDynamicItem,
        at p: CGPoint
    ) {
        reactToContact(item1, item2, intensity: 0.6)
    }

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item: UIDynamicItem,
        withBoundaryIdentifier identifier: NSCopying?,
        at p: CGPoint
    ) {
        reactToContact(item, intensity: 0.4)
    }
}

// MARK: - Screenshot snippet
//
// The physics core of this screen, stripped of layout and styling.
// This block goes on the code screenshot shown next to the recording.
/*

// Billiards-style slingshot: the puck flies opposite to the pull.
// UIPushBehavior treats the vector's length as the force magnitude.
let magnitude = min(pullDistance / 30, 8)
let push = UIPushBehavior(items: [puck], mode: .instantaneous)
push.pushDirection = CGVector(
    dx: (puck.center.x - finger.x) / pullDistance * magnitude,
    dy: (puck.center.y - finger.y) / pullDistance * magnitude
)

// Grabbing off-center spins the puck — a cue striking off-center.
push.setTargetOffsetFromCenter(grabOffset, for: puck)
animator.addBehavior(push)

// The other mode, .continuous, applies the force every frame;
// slowly rotating its angle swirls all the pucks around the table.
continuousPush.angle += 0.02
*/
