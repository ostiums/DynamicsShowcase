import UIKit

/// UIPushBehavior: air hockey.
/// Flick — an instantaneous impulse (.instantaneous) with spin via the force
/// application point. "Continuous" mode — a constant force with a rotating vector.
final class PushDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private var pucks: [BallView] = []
    private var collision = UICollisionBehavior()
    private var properties = UIDynamicItemBehavior()

    private let modeControl = UISegmentedControl(items: ["Impulse", "Continuous force"])
    private var continuousPush: UIPushBehavior?
    private var rotationLink: CADisplayLink?

    private let flickLayer = CAShapeLayer()
    private var flickStart: CGPoint = .zero
    private weak var flickTarget: BallView?

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint("Flick a puck — an instantaneous impulse.  Force = gesture velocity")

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
        properties = UIDynamicItemBehavior()

        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self

        properties.elasticity = 0.9
        properties.friction = 0.02
        properties.resistance = 0.35
        properties.density = 0.6
        properties.allowsRotation = true

        animator.addBehavior(collision)
        animator.addBehavior(properties)

        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for i in 0..<5 {
            let angle = CGFloat(i) * (.pi * 2 / 5) - .pi / 2
            let puck = BallView(diameter: 54, color: Palette.neon[i])
            puck.center = CGPoint(x: center.x + cos(angle) * 110,
                                  y: center.y + sin(angle) * 110)
            contentView.addSubview(puck)
            pucks.append(puck)
            collision.addItem(puck)
            properties.addItem(puck)
        }

        if modeControl.selectedSegmentIndex == 1 {
            startContinuousPush()
        }
    }

    // MARK: - Flick (instantaneous)

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard modeControl.selectedSegmentIndex == 0 else { return }
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
            guard let puck = flickTarget else { return }
            let velocity = pan.velocity(in: contentView)
            let speed = hypot(velocity.x, velocity.y)
            guard speed > 100 else { return }

            let push = UIPushBehavior(items: [puck], mode: .instantaneous)
            push.pushDirection = CGVector(dx: velocity.x / 700, dy: velocity.y / 700)

            // Applying the force off-center makes the puck spin.
            let offset = UIOffset(horizontal: (flickStart.x - puck.center.x).clamped(to: -20...20),
                                  vertical: (flickStart.y - puck.center.y).clamped(to: -20...20))
            push.setTargetOffsetFromCenter(offset, for: puck)

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

    // MARK: - Continuous force

    @objc private func modeChanged() {
        if modeControl.selectedSegmentIndex == 1 {
            showHint("UIPushBehavior(.continuous) — constant force with a slowly rotating vector")
            startContinuousPush()
        } else {
            showHint("Flick a puck — an instantaneous impulse.  Force = gesture velocity")
            stopContinuousPush()
        }
    }

    private func startContinuousPush() {
        stopContinuousPush()
        let push = UIPushBehavior(items: pucks, mode: .continuous)
        push.magnitude = 0.4
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
        continuousPush?.angle += 0.02
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

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
