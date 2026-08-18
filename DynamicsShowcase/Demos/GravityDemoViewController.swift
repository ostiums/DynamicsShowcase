import UIKit

/// UIGravityBehavior + UICollisionBehavior.
/// Тап — бросить шар. Пан — изменить направление гравитации (стрелка показывает вектор).
final class GravityDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let gravity = UIGravityBehavior()
    private let collision = UICollisionBehavior()
    private let bounce = UIDynamicItemBehavior()
    private var balls: [BallView] = []

    private let arrow = UIImageView(image: UIImage(
        systemName: "location.north.fill",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
    ))

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint("Тапай — шары падают.  Веди пальцем — меняешь направление гравитации")

        arrow.tintColor = UIColor.white.withAlphaComponent(0.35)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arrow)
        NSLayoutConstraint.activate([
            arrow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
        ])
        setArrow(direction: CGVector(dx: 0, dy: 1))

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    override func buildScene() {
        balls.removeAll()

        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionDelegate = self

        bounce.elasticity = 0.65
        bounce.friction = 0.15
        bounce.resistance = 0.1
        bounce.allowsRotation = true

        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(bounce)

        gravity.gravityDirection = CGVector(dx: 0, dy: 1)
        setArrow(direction: CGVector(dx: 0, dy: 1))

        // Стартовый «дождь» из шаров — красиво для записи с первой секунды.
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09) { [weak self] in
                guard let self else { return }
                // Спавним внутри границ: снаружи шар упёрся бы в верхнюю стенку коллизий.
                let x = CGFloat.random(in: 40...(self.view.bounds.width - 40))
                self.spawnBall(at: CGPoint(x: x, y: CGFloat.random(in: 130...300)))
            }
        }
    }

    private func spawnBall(at point: CGPoint) {
        let ball = BallView(diameter: .random(in: 34...64), color: Palette.randomNeon())
        ball.center = point
        contentView.addSubview(ball)
        balls.append(ball)

        gravity.addItem(ball)
        collision.addItem(ball)
        bounce.addItem(ball)

        ball.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) { ball.transform = .identity }

        // Держим сцену лёгкой: старые шары убираем.
        if balls.count > 26 {
            let old = balls.removeFirst()
            gravity.removeItem(old)
            collision.removeItem(old)
            bounce.removeItem(old)
            UIView.animate(withDuration: 0.2, animations: { old.alpha = 0 }) { _ in
                old.removeFromSuperview()
            }
        }
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        spawnBall(at: tap.location(in: contentView))
        Haptics.action()
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: view)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let length = max(1, hypot(dx, dy))
        let direction = CGVector(dx: dx / length, dy: dy / length)
        gravity.gravityDirection = direction
        setArrow(direction: direction)
    }

    private func setArrow(direction: CGVector) {
        // Стрелка исходно смотрит вверх (0, -1); поворачиваем её вдоль вектора гравитации.
        arrow.transform = CGAffineTransform(rotationAngle: atan2(direction.dx, -direction.dy))
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

    func collisionBehavior(_ behavior: UICollisionBehavior,
                           beganContactFor item: UIDynamicItem,
                           withBoundaryIdentifier identifier: NSCopying?,
                           at p: CGPoint) {
        (item as? BallView)?.flash()
        Haptics.collision(intensity: 0.7)
    }
}
