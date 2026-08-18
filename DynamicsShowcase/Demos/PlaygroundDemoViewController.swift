import UIKit

/// Финальный плейграунд: всё вместе.
/// Гравитация, наклонные рампы-границы, шары по тапу, спарки-«домино» (UIDynamicItemGroup)
/// по долгому нажатию, перетаскивание любого предмета, магнит по тапу двумя пальцами.
final class PlaygroundDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let gravity = UIGravityBehavior()
    private let collision = UICollisionBehavior()
    private let properties = UIDynamicItemBehavior()

    private var items: [UIView] = []
    private var groups: [UIDynamicItemGroup] = []
    private var dragAttachment: UIAttachmentBehavior?
    private weak var draggedView: UIView?
    private var magnetSnaps: [UISnapBehavior] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint("Тап — шар · долгий тап — домино-группа · тяни и бросай · два пальца — магнит")

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress)))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))

        let magnet = UITapGestureRecognizer(target: self, action: #selector(handleMagnet))
        magnet.numberOfTouchesRequired = 2
        view.addGestureRecognizer(magnet)
    }

    override func buildScene() {
        items.removeAll()
        groups.removeAll()
        magnetSnaps.removeAll()

        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self
        properties.elasticity = 0.55
        properties.friction = 0.2
        properties.resistance = 0.1

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(properties)

        addRamps()

        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                guard let self else { return }
                self.spawnBall(at: CGPoint(x: .random(in: 40...(self.view.bounds.width - 40)),
                                           y: .random(in: 110...200)))
            }
        }
    }

    /// Наклонные рампы: линии-границы коллизий, нарисованные светящимися слоями.
    private func addRamps() {
        let w = view.bounds.width
        let h = view.bounds.height
        let ramps: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: h * 0.32), CGPoint(x: w * 0.62, y: h * 0.42)),
            (CGPoint(x: w, y: h * 0.55), CGPoint(x: w * 0.38, y: h * 0.67)),
        ]

        for (i, ramp) in ramps.enumerated() {
            collision.addBoundary(withIdentifier: "ramp\(i)" as NSString, from: ramp.0, to: ramp.1)

            let line = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: ramp.0)
            path.addLine(to: ramp.1)
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
    }

    // MARK: - Создание объектов

    private func spawnBall(at point: CGPoint) {
        let ball = BallView(diameter: .random(in: 32...58), color: Palette.randomNeon())
        ball.center = point
        contentView.addSubview(ball)
        items.append(ball)

        gravity.addItem(ball)
        collision.addItem(ball)
        properties.addItem(ball)
        trimItems()
    }

    /// UIDynamicItemGroup: два квадрата движутся как одно жёсткое тело.
    private func spawnGroup(at point: CGPoint) {
        let size: CGFloat = 34
        let color = Palette.randomNeon()
        let left = BoxView(size: size, color: color)
        let right = BoxView(size: size, color: color.adjusted(brightnessBy: 1.4))
        left.center = CGPoint(x: point.x - size / 2, y: point.y)
        right.center = CGPoint(x: point.x + size / 2, y: point.y)
        contentView.addSubview(left)
        contentView.addSubview(right)
        items.append(left)
        items.append(right)

        let group = UIDynamicItemGroup(items: [left, right])
        groups.append(group)
        gravity.addItem(group)
        collision.addItem(group)
        properties.addItem(group)
    }

    private func trimItems() {
        guard items.count > 34 else { return }
        let old = items.removeFirst()
        guard !(old is BoxView) else { return } // группы не разбираем, убираем только шары
        gravity.removeItem(old)
        collision.removeItem(old)
        properties.removeItem(old)
        UIView.animate(withDuration: 0.2, animations: { old.alpha = 0 }) { _ in
            old.removeFromSuperview()
        }
    }

    // MARK: - Жесты

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        spawnBall(at: tap.location(in: contentView))
        Haptics.action()
    }

    @objc private func handleLongPress(_ press: UILongPressGestureRecognizer) {
        guard press.state == .began else { return }
        spawnGroup(at: press.location(in: contentView))
        Haptics.action()
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            // Участников групп не таскаем поодиночке — ими управляет UIDynamicItemGroup.
            guard let target = items
                .filter({ !($0 is BoxView) })
                .map({ ($0, hypot($0.center.x - location.x, $0.center.y - location.y)) })
                .filter({ $0.1 < 80 })
                .min(by: { $0.1 < $1.1 })?
                .0
            else { return }
            draggedView = target
            let attachment = UIAttachmentBehavior(item: target, attachedToAnchor: location)
            animator.addBehavior(attachment)
            dragAttachment = attachment

        case .changed:
            dragAttachment?.anchorPoint = location

        default:
            if let dragAttachment {
                animator.removeBehavior(dragAttachment)
                self.dragAttachment = nil
            }
            // Бросок: скорость жеста передаём предмету.
            if let draggedView {
                let velocity = pan.velocity(in: contentView)
                properties.addLinearVelocity(
                    CGPoint(x: velocity.x * 0.8, y: velocity.y * 0.8),
                    for: draggedView
                )
                self.draggedView = nil
            }
        }
    }

    /// Магнит: все предметы слетаются к точке касания, через секунду снова падают.
    @objc private func handleMagnet(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: contentView)
        Haptics.action()

        magnetSnaps.forEach { animator.removeBehavior($0) }
        magnetSnaps.removeAll()

        let balls = items.filter { $0 is BallView }
        for (i, item) in balls.enumerated() {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(max(balls.count, 1)))
            let radius = CGFloat(40 + (i % 3) * 34)
            let target = CGPoint(x: point.x + cos(angle) * radius,
                                 y: point.y + sin(angle) * radius)
            let snap = UISnapBehavior(item: item, snapTo: target)
            snap.damping = 0.4
            animator.addBehavior(snap)
            magnetSnaps.append(snap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self else { return }
            self.magnetSnaps.forEach { self.animator.removeBehavior($0) }
            self.magnetSnaps.removeAll()
        }
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item1: UIDynamicItem,
                           with item2: UIDynamicItem,
                           at p: CGPoint) {
        (item1 as? BallView)?.flash()
        (item2 as? BallView)?.flash()
        Haptics.collision(intensity: 0.45)
    }
}
