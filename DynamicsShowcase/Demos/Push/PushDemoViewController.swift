import UIKit

/// Demonstrates UIPushBehavior in both of its modes.
///
/// - `.instantaneous` — a one-shot impulse, billiards-style: pull back from
///   a puck and release, and it shoots in the opposite direction; the farther
///   the pull, the harder the shot. Grabbing off-center adds spin via
///   `setTargetOffsetFromCenter(_:for:)`.
/// - `.continuous` — a constant force applied every frame; here its angle
///   slowly rotates, swirling all the pucks around the table.
final class PushDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = PushDemoViewModel()

    private var pucks: [BallView] = []
    private var collision = UICollisionBehavior()
    private var puckProperties = UIDynamicItemBehavior()

    private let modeControl = UISegmentedControl()
    private var continuousPush: UIPushBehavior?
    private var rotationLink: CADisplayLink?

    private let aimLayer = CAShapeLayer()
    private var grabPoint: CGPoint = .zero
    private weak var aimedPuck: BallView?

    private var mode: PushDemoViewModel.Mode {
        PushDemoViewModel.Mode(rawValue: modeControl.selectedSegmentIndex) ?? .impulse
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

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
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopRotationLink()
    }

    override func buildScene() {
        pucks.removeAll()
        continuousPush = nil
        stopRotationLink()

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

        for (index, center) in viewModel.puckCenters(in: view.bounds).enumerated() {
            let puck = BallView(diameter: viewModel.puckDiameter, color: Palette.neon[index])
            puck.center = center
            contentView.addSubview(puck)
            pucks.append(puck)
            collision.addItem(puck)
            puckProperties.addItem(puck)
        }

        if mode == .continuous {
            startContinuousPush()
        }
    }

    // MARK: - Slingshot (.instantaneous)

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard mode == .impulse else { return }
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            grabPoint = location
            aimedPuck = pucks.nearest(to: location)

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
        let push = UIPushBehavior(items: pucks, mode: .continuous)
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
