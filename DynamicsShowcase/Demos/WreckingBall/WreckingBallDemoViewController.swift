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

    /// Draws the rope between the anchor and the balls, beneath them.
    private let linkLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        layer.lineWidth = 2.5
        layer.lineCap = .round
        layer.fillColor = nil
        return layer
    }()

    private var displayLink: CADisplayLink?

    private var anchorPoint: CGPoint {
        CGPoint(x: view.bounds.midX, y: view.safeAreaLayoutGuide.layoutFrame.minY + 60)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    // The link that redraws the chain runs only while the screen is visible.
    // A CADisplayLink retains its target, so one that lived as long as the
    // controller would keep the controller alive forever — deinit would never run.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDisplayLink()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopDisplayLink()
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(redrawLinks))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    override func buildScene() {
        chain.removeAll()

        gravity = UIGravityBehavior()
        collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self
        animator.addBehavior(gravity)
        animator.addBehavior(collision)

        // Added first so the balls drawn afterwards cover the rope ends.
        contentView.layer.addSublayer(linkLayer)

        addAnchorDot()

        let layout = viewModel.chainLayout(anchor: anchorPoint)
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
        let chainProperties = UIDynamicItemBehavior()
        chainProperties.elasticity = viewModel.chainElasticity
        chainProperties.resistance = viewModel.chainResistance
        chainProperties.angularResistance = viewModel.chainAngularResistance
        animator.addBehavior(chainProperties)

        var previous: BallView?
        for (index, link) in viewModel.chainBalls.enumerated() {
            let ball = BallView(diameter: link.diameter, color: link.color)
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
    }

    private func buildTower(chainLength: CGFloat) {
        let layout = viewModel.towerLayout(
            anchor: anchorPoint,
            chainLength: chainLength,
            in: view.bounds
        )

        // The pedestal is a line boundary; blocks rest on it until hit.
        collision.addBoundary(
            withIdentifier: "platform" as NSString,
            from: layout.platformStart,
            to: layout.platformEnd
        )
        contentView.layer.addSublayer(CAShapeLayer.boundaryLine(
            from: layout.platformStart,
            to: layout.platformEnd
        ))

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

    // MARK: - Gestures

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            guard let ball = chain.nearest(to: location, within: viewModel.grabRadius) else { return }
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

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item1: UIDynamicItem,
        with item2: UIDynamicItem,
        at p: CGPoint
    ) {
        reactToContact(item1, item2, intensity: 0.5)
    }
}

// MARK: - Screenshot snippet
//
// The physics core of this screen, stripped of layout and styling.
// This block goes on the code screenshot shown next to the recording.
/*

// The first ball hangs from a fixed point in space…
animator.addBehavior(UIAttachmentBehavior(
    item: balls[0],
    attachedToAnchor: anchor
))

// …the rest are linked to each other. Both attachments are rigid:
// the length locks at the distance between the items at creation time.
for (ball, previous) in zip(balls.dropFirst(), balls) {
    animator.addBehavior(UIAttachmentBehavior(
        item: ball,
        attachedTo: previous
    ))
}

// The last ball is much denser — that's what carries the momentum.
let wreckingBall = UIDynamicItemBehavior(items: [balls.last!])
wreckingBall.density = 2.5
animator.addBehavior(wreckingBall)

// Dragging is one more attachment whose anchor follows the finger.
dragAttachment.anchorPoint = pan.location(in: view)
*/
