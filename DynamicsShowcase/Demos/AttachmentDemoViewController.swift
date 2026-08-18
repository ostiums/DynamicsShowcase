import UIKit

/// UIAttachmentBehavior: a wrecking ball on a chain of rigid links.
/// The chain hangs from an anchor point (anchor attachment), the balls are linked
/// to each other (item-to-item attachments). Released from an angle, the heavy
/// ball swings down and smashes a tower of blocks standing on a pedestal.
/// Any ball can be dragged — via one more attachment that follows the finger.
final class AttachmentDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private var chain: [BallView] = []
    private var blocks: [BoxView] = []
    private var gravity = UIGravityBehavior()
    private var collision = UICollisionBehavior()
    private var dragAttachment: UIAttachmentBehavior?

    private let linkLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?

    private var anchorPoint: CGPoint {
        CGPoint(x: view.bounds.midX, y: view.safeAreaLayoutGuide.layoutFrame.minY + 60)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint("Drag the ball and smash the tower.  Anchor + item-to-item rigid links")

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))

        displayLink = CADisplayLink(target: self, selector: #selector(redrawLinks))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
    }

    override func buildScene() {
        chain.removeAll()
        blocks.removeAll()

        gravity = UIGravityBehavior()
        collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self
        animator.addBehavior(gravity)
        animator.addBehavior(collision)

        // Chain links are drawn beneath the balls.
        linkLayer.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        linkLayer.lineWidth = 2.5
        linkLayer.lineCap = .round
        linkLayer.fillColor = nil
        contentView.layer.addSublayer(linkLayer)

        let anchorDot = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
        anchorDot.backgroundColor = .white
        anchorDot.layer.cornerRadius = 7
        anchorDot.layer.shadowColor = UIColor.white.cgColor
        anchorDot.layer.shadowOpacity = 0.8
        anchorDot.layer.shadowRadius = 8
        anchorDot.layer.shadowOffset = .zero
        anchorDot.center = anchorPoint
        contentView.addSubview(anchorDot)

        // Chain geometry: distances of each ball from the anchor.
        let diameters: [CGFloat] = [32, 30, 28, 26, 64]
        let gap: CGFloat = 14
        var distances: [CGFloat] = []
        var reach: CGFloat = 70
        for (i, diameter) in diameters.enumerated() {
            if i > 0 { reach += diameters[i - 1] / 2 + diameter / 2 + gap }
            distances.append(reach)
        }
        let chainLength = distances.last!

        buildTower(chainLength: chainLength)

        // Lay the chain at an angle so it starts swinging on its own,
        // capping the angle so the last ball stays on screen.
        let maxDx = view.bounds.width - anchorPoint.x - diameters.last! / 2 - 12
        let sinAngle = min(0.85, maxDx / chainLength)
        let direction = CGVector(dx: sinAngle, dy: sqrt(1 - sinAngle * sinAngle))

        let colors = [Palette.violet, Palette.cyan, Palette.magenta, Palette.mint, Palette.amber]
        let chainProps = UIDynamicItemBehavior()
        chainProps.elasticity = 0.3
        chainProps.resistance = 0.1
        chainProps.angularResistance = 0.2
        animator.addBehavior(chainProps)

        var previous: BallView?
        for (i, diameter) in diameters.enumerated() {
            let ball = BallView(diameter: diameter, color: colors[i])
            ball.center = CGPoint(x: anchorPoint.x + direction.dx * distances[i],
                                  y: anchorPoint.y + direction.dy * distances[i])
            contentView.addSubview(ball)
            chain.append(ball)

            gravity.addItem(ball)
            collision.addItem(ball)
            chainProps.addItem(ball)

            if let previous {
                // Item-to-item link; its length is fixed at the current distance.
                animator.addBehavior(UIAttachmentBehavior(item: ball, attachedTo: previous))
            } else {
                // The first ball hangs from the anchor point.
                animator.addBehavior(UIAttachmentBehavior(item: ball, attachedToAnchor: anchorPoint))
            }
            previous = ball
        }

        // The wrecking ball is much denser — that's what carries the momentum.
        let ballProps = UIDynamicItemBehavior(items: [chain.last!])
        ballProps.density = 2.5
        animator.addBehavior(ballProps)

        // A tangential kick along the swing arc guarantees a spectacular first hit.
        ballProps.addLinearVelocity(
            CGPoint(x: -direction.dy * 260, y: direction.dx * 260),
            for: chain.last!
        )
    }

    /// A pedestal with a tower of blocks, placed exactly within the chain's swing arc.
    private func buildTower(chainLength: CGFloat) {
        let towerX: CGFloat = 90
        let dx = towerX - anchorPoint.x
        let sweepY = anchorPoint.y + sqrt(max(0, chainLength * chainLength - dx * dx))
        // Clearance below the ball's sweep so the platform never blocks the swing;
        // the platform also must not reach toward the arc's lowest point.
        let platformY = min(sweepY + 48, view.bounds.height - 140)

        collision.addBoundary(withIdentifier: "platform" as NSString,
                              from: CGPoint(x: towerX - 70, y: platformY),
                              to: CGPoint(x: towerX + 40, y: platformY))
        let line = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: towerX - 70, y: platformY))
        path.addLine(to: CGPoint(x: towerX + 40, y: platformY))
        line.path = path.cgPath
        line.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        line.lineWidth = 3
        line.lineCap = .round
        line.shadowColor = Palette.cyan.cgColor
        line.shadowOpacity = 0.8
        line.shadowRadius = 6
        line.shadowOffset = .zero
        contentView.layer.addSublayer(line)

        let blockProps = UIDynamicItemBehavior()
        blockProps.density = 0.5
        blockProps.friction = 0.5
        blockProps.elasticity = 0.25
        animator.addBehavior(blockProps)

        let size: CGFloat = 30
        for row in 0..<3 {
            for column in 0..<2 {
                let block = BoxView(size: size, color: Palette.coral)
                block.center = CGPoint(x: towerX + (column == 0 ? -17 : 17),
                                       y: platformY - size / 2 - CGFloat(row) * (size + 2))
                contentView.addSubview(block)
                blocks.append(block)
                gravity.addItem(block)
                collision.addItem(block)
                blockProps.addItem(block)
            }
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            guard let ball = nearestBall(to: location, maxDistance: 80) else { return }
            let attachment = UIAttachmentBehavior(item: ball, attachedToAnchor: location)
            animator.addBehavior(attachment)
            dragAttachment = attachment
            Haptics.action()

        case .changed:
            dragAttachment?.anchorPoint = location

        default:
            if let dragAttachment {
                animator.removeBehavior(dragAttachment)
                self.dragAttachment = nil
            }
        }
    }

    private func nearestBall(to point: CGPoint, maxDistance: CGFloat) -> BallView? {
        chain
            .map { ($0, hypot($0.center.x - point.x, $0.center.y - point.y)) }
            .filter { $0.1 < maxDistance }
            .min { $0.1 < $1.1 }?
            .0
    }

    @objc private func redrawLinks() {
        guard !chain.isEmpty else {
            linkLayer.path = nil
            return
        }
        let path = UIBezierPath()
        path.move(to: anchorPoint)
        for ball in chain {
            path.addLine(to: ball.center)
        }
        linkLayer.path = path.cgPath
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item1: UIDynamicItem,
                           with item2: UIDynamicItem,
                           at p: CGPoint) {
        (item1 as? BallView)?.flash()
        (item2 as? BallView)?.flash()
        Haptics.collision(intensity: 0.5)
    }
}
