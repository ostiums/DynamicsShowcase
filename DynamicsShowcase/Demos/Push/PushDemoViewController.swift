import UIKit

/// Demonstrates UIPushBehavior in both of its modes.
///
/// - `.instantaneous` — a one-shot impulse: flick a puck and the gesture
///   velocity becomes the push vector; pushing off-center adds spin via
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

    private let flickLayer = CAShapeLayer()
    private var flickStart: CGPoint = .zero
    private weak var flickTarget: BallView?

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
        showHint(mode.hint)

        // Dashed aiming line shown while flicking.
        flickLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        flickLayer.lineWidth = 2
        flickLayer.lineDashPattern = [4, 6]
        flickLayer.fillColor = nil
        view.layer.addSublayer(flickLayer)

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    deinit {
        rotationLink?.invalidate()
    }

    override func buildScene() {
        pucks.removeAll()
        continuousPush = nil
        rotationLink?.invalidate()
        rotationLink = nil

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

    // MARK: - Flick (.instantaneous)

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard mode == .impulse else { return }
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            flickStart = location
            flickTarget = pucks
                .map { ($0, hypot($0.center.x - location.x, $0.center.y - location.y)) }
                .min { $0.1 < $1.1 }?
                .0

        case .changed:
            guard let puck = flickTarget else { return }
            let path = UIBezierPath()
            path.move(to: puck.center)
            path.addLine(to: location)
            flickLayer.path = path.cgPath

        case .ended:
            flickLayer.path = nil
            guard let puck = flickTarget,
                  let impulse = viewModel.impulseVector(forGestureVelocity: pan.velocity(in: contentView))
            else { return }

            let push = UIPushBehavior(items: [puck], mode: .instantaneous)
            push.pushDirection = impulse
            push.setTargetOffsetFromCenter(
                viewModel.spinOffset(fromTouch: flickStart, puckCenter: puck.center),
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
            flickLayer.path = nil
        }
    }

    // MARK: - Continuous force (.continuous)

    @objc private func modeChanged() {
        showHint(mode.hint)
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

        rotationLink = CADisplayLink(target: self, selector: #selector(rotatePushVector))
        rotationLink?.add(to: .main, forMode: .common)
    }

    private func stopContinuousPush() {
        if let continuousPush {
            animator.removeBehavior(continuousPush)
            self.continuousPush = nil
        }
        rotationLink?.invalidate()
        rotationLink = nil
    }

    @objc private func rotatePushVector() {
        continuousPush?.angle += viewModel.continuousRotationStep
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item1: UIDynamicItem,
                           with item2: UIDynamicItem,
                           at p: CGPoint) {
        (item1 as? BallView)?.flash()
        (item2 as? BallView)?.flash()
        Haptics.collision()
    }

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item: UIDynamicItem,
                           withBoundaryIdentifier identifier: NSCopying?,
                           at p: CGPoint) {
        (item as? BallView)?.flash()
        Haptics.collision(intensity: 0.4)
    }
}
