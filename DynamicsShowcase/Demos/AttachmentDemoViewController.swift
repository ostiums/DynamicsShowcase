import UIKit

/// UIAttachmentBehavior: цепь из шаров на жёстких связях.
/// Верхний шар прикреплён к точке-якорю, остальные — друг к другу.
/// Любой шар можно таскать пальцем — через ещё один attachment к точке касания.
final class AttachmentDemoViewController: DemoViewController {

    private var chain: [BallView] = []
    private let gravity = UIGravityBehavior()
    private let collision = UICollisionBehavior()
    private let properties = UIDynamicItemBehavior()
    private var dragAttachment: UIAttachmentBehavior?

    private let linkLayer = CAShapeLayer()
    private let anchorDot = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
    private var displayLink: CADisplayLink?

    private var anchorPoint: CGPoint {
        CGPoint(x: view.bounds.midX, y: view.safeAreaLayoutGuide.layoutFrame.minY + 60)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint("Тяни любой шар и отпускай.  Жёсткие связи + гравитация = маятник")

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(pan)

        displayLink = CADisplayLink(target: self, selector: #selector(redrawLinks))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
    }

    override func buildScene() {
        chain.removeAll()

        // Линии-звенья цепи рисуем под шарами.
        linkLayer.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        linkLayer.lineWidth = 2.5
        linkLayer.lineCap = .round
        linkLayer.fillColor = nil
        contentView.layer.addSublayer(linkLayer)

        anchorDot.backgroundColor = .white
        anchorDot.layer.cornerRadius = 7
        anchorDot.layer.shadowColor = UIColor.white.cgColor
        anchorDot.layer.shadowOpacity = 0.8
        anchorDot.layer.shadowRadius = 8
        anchorDot.layer.shadowOffset = .zero
        anchorDot.center = anchorPoint
        contentView.addSubview(anchorDot)

        collision.translatesReferenceBoundsIntoBoundary = true
        properties.elasticity = 0.35
        properties.resistance = 0.25
        properties.angularResistance = 0.4

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(properties)

        // Цепь выкладываем горизонтально: отпущенная, она красиво качнётся маятником.
        let diameters: [CGFloat] = [46, 42, 38, 34, 32, 44]
        let colors = [Palette.violet, Palette.cyan, Palette.magenta, Palette.mint, Palette.amber, Palette.coral]
        var previous: BallView?
        var x = anchorPoint.x

        for (i, diameter) in diameters.enumerated() {
            x += (i == 0 ? 52 : (diameter / 2 + diameters[i - 1] / 2 + 16))
            let ball = BallView(diameter: diameter, color: colors[i])
            ball.center = CGPoint(x: min(x, view.bounds.width - 30), y: anchorPoint.y)
            contentView.addSubview(ball)
            chain.append(ball)

            gravity.addItem(ball)
            collision.addItem(ball)
            properties.addItem(ball)

            if let previous {
                // Связь «элемент — элемент»: длина фиксируется по текущему расстоянию.
                animator.addBehavior(UIAttachmentBehavior(item: ball, attachedTo: previous))
            } else {
                // Первый шар висит на якорной точке.
                animator.addBehavior(UIAttachmentBehavior(item: ball, attachedToAnchor: anchorPoint))
            }
            previous = ball
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            guard let ball = nearestBall(to: location, maxDistance: 70) else { return }
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
}
