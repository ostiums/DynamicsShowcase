import UIKit

/// Demonstrates UIAttachmentBehavior.
///
/// - The first ball hangs from an anchor point: `UIAttachmentBehavior(item:attachedToAnchor:)`.
/// - The rest are linked to each other: `UIAttachmentBehavior(item:attachedTo:)`.
///   Both are rigid links: the length is fixed at the distance between the
///   items at the moment the attachment is created.
/// - Dragging works through one more attachment whose `anchorPoint`
///   follows the finger.
/// - The dense wrecking ball at the end of the chain smashes a tower of
///   blocks standing on a pedestal (a line boundary of the collision behavior).
final class WreckingBallDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = WreckingBallDemoViewModel()

    private var chain: [BallView] = []
    private var gravity = UIGravityBehavior()
    private var collision = UICollisionBehavior()
    private var dragAttachment: UIAttachmentBehavior?

    private let linkLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?

    private var anchorPoint: CGPoint {
        CGPoint(x: view.bounds.midX, y: view.safeAreaLayoutGuide.layoutFrame.minY + 60)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint(viewModel.hint)

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))

        // Redraws the chain links every frame while the physics runs.
        displayLink = CADisplayLink(target: self, selector: #selector(redrawLinks))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
    }

    override func buildScene() {
        chain.removeAll()

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

        addAnchorDot()

        let layout = viewModel.chainLayout(anchor: anchorPoint, in: view.bounds)
        buildTower(chainLength: layout.length)
        buildChain(with: layout)
    }

    // MARK: - Scene

    private func addAnchorDot() {
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
        dot.backgroundColor = .white
        dot.layer.cornerRadius = 7
        dot.layer.shadowColor = UIColor.white.cgColor
        dot.layer.shadowOpacity = 0.8
        dot.layer.shadowRadius = 8
        dot.layer.shadowOffset = .zero
        dot.center = anchorPoint
        contentView.addSubview(dot)
    }

    private func buildChain(with layout: WreckingBallDemoViewModel.ChainLayout) {
        let colors = [Palette.violet, Palette.cyan, Palette.magenta, Palette.mint, Palette.amber]

        let chainProperties = UIDynamicItemBehavior()
        chainProperties.elasticity = viewModel.chainElasticity
        chainProperties.resistance = viewModel.chainResistance
        chainProperties.angularResistance = viewModel.chainAngularResistance
        animator.addBehavior(chainProperties)

        var previous: BallView?
        for (index, diameter) in viewModel.ballDiameters.enumerated() {
            let ball = BallView(diameter: diameter, color: colors[index])
            ball.center = layout.ballCenter(at: index, anchor: anchorPoint)
            contentView.addSubview(ball)
            chain.append(ball)

            gravity.addItem(ball)
            collision.addItem(ball)
            chainProperties.addItem(ball)

            if let previous {
                // Item-to-item link; its length is fixed at the current distance.
                animator.addBehavior(UIAttachmentBehavior(item: ball, attachedTo: previous))
            } else {
                // The first ball hangs from the anchor point.
                animator.addBehavior(UIAttachmentBehavior(item: ball, attachedToAnchor: anchorPoint))
            }
            previous = ball
        }

        guard let wreckingBall = chain.last else { return }

        let ballProperties = UIDynamicItemBehavior(items: [wreckingBall])
        ballProperties.density = viewModel.wreckingBallDensity
        animator.addBehavior(ballProperties)

        // Kick along the swing arc so the scene opens with a smash.
        ballProperties.addLinearVelocity(
            viewModel.launchVelocity(chainDirection: layout.direction),
            for: wreckingBall
        )
    }

    private func buildTower(chainLength: CGFloat) {
        let layout = viewModel.towerLayout(anchor: anchorPoint,
                                           chainLength: chainLength,
                                           in: view.bounds)

        // The pedestal is a line boundary; blocks rest on it until hit.
        collision.addBoundary(withIdentifier: "platform" as NSString,
                              from: layout.platformStart,
                              to: layout.platformEnd)
        drawPlatform(from: layout.platformStart, to: layout.platformEnd)

        let blockProperties = UIDynamicItemBehavior()
        blockProperties.density = viewModel.blockDensity
        blockProperties.friction = viewModel.blockFriction
        blockProperties.elasticity = viewModel.blockElasticity
        animator.addBehavior(blockProperties)

        for center in layout.blockCenters {
            let block = BoxView(size: viewModel.blockSize, color: Palette.coral)
            block.center = center
            contentView.addSubview(block)
            gravity.addItem(block)
            collision.addItem(block)
            blockProperties.addItem(block)
        }
    }

    private func drawPlatform(from start: CGPoint, to end: CGPoint) {
        let line = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        line.path = path.cgPath
        line.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        line.lineWidth = 3
        line.lineCap = .round
        line.shadowColor = Palette.cyan.cgColor
        line.shadowOpacity = 0.8
        line.shadowRadius = 6
        line.shadowOffset = .zero
        contentView.layer.addSublayer(line)
    }

    // MARK: - Gestures

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

    // MARK: - Link drawing

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
