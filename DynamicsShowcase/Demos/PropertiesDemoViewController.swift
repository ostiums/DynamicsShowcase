import UIKit

/// UIDynamicItemBehavior: how physical properties change the way bodies move.
/// "Elasticity" — identical balls with different elasticity dropped at once.
/// "Density" — the same impulse moves bodies of different density differently.
final class PropertiesDemoViewController: DemoViewController {

    private let modeControl = UISegmentedControl(items: ["Elasticity", "Density"])
    private var labels: [UILabel] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = Palette.coral.withAlphaComponent(0.55)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeControl)
        NSLayoutConstraint.activate([
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(replay)))
    }

    @objc private func modeChanged() {
        replay()
    }

    @objc private func replay() {
        Haptics.action()
        animator.removeAllBehaviors()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        labels.removeAll()
        buildScene()
    }

    override func buildScene() {
        if modeControl.selectedSegmentIndex == 0 {
            buildElasticityScene()
        } else {
            buildDensityScene()
        }
    }

    // MARK: - Elasticity

    private func buildElasticityScene() {
        showHint("elasticity 0.1 → 0.95 — same balls, different bounciness.  Tap to replay")

        let values: [CGFloat] = [0.1, 0.4, 0.7, 0.95]
        let colors = [Palette.coral, Palette.amber, Palette.mint, Palette.cyan]
        let laneWidth = view.bounds.width / CGFloat(values.count)

        let gravity = UIGravityBehavior()
        let collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        animator.addBehavior(gravity)
        animator.addBehavior(collision)

        // A visible "floor" above the captions and the hint.
        let floorY = view.bounds.height - 180
        collision.addBoundary(withIdentifier: "floor" as NSString,
                              from: CGPoint(x: 0, y: floorY),
                              to: CGPoint(x: view.bounds.width, y: floorY))
        let floorLine = CAShapeLayer()
        let floorPath = UIBezierPath()
        floorPath.move(to: CGPoint(x: 16, y: floorY))
        floorPath.addLine(to: CGPoint(x: view.bounds.width - 16, y: floorY))
        floorLine.path = floorPath.cgPath
        floorLine.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        floorLine.lineWidth = 3
        floorLine.lineCap = .round
        contentView.layer.addSublayer(floorLine)

        for (i, elasticity) in values.enumerated() {
            let x = laneWidth * (CGFloat(i) + 0.5)

            let ball = BallView(diameter: 52, color: colors[i])
            ball.center = CGPoint(x: x, y: view.safeAreaInsets.top + 130)
            contentView.addSubview(ball)

            // Each ball gets its own behavior — that's the whole point of the demo.
            let props = UIDynamicItemBehavior(items: [ball])
            props.elasticity = elasticity
            animator.addBehavior(props)

            gravity.addItem(ball)
            collision.addItem(ball)

            addCaption(String(format: "%.2f", elasticity), color: colors[i],
                       at: CGPoint(x: x, y: floorY + 28))
        }
    }

    // MARK: - Density

    private func buildDensityScene() {
        showHint("density 0.3 → 2.4 — same impulse, different mass.  Tap to replay")

        let values: [CGFloat] = [0.3, 0.8, 1.5, 2.4]
        let colors = [Palette.cyan, Palette.mint, Palette.amber, Palette.coral]
        let topY = view.safeAreaInsets.top + 150
        let laneHeight: CGFloat = 110

        let collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        animator.addBehavior(collision)

        for (i, density) in values.enumerated() {
            let y = topY + CGFloat(i) * laneHeight

            let separator = UIView(frame: CGRect(x: 16, y: y + laneHeight / 2 - 8,
                                                 width: view.bounds.width - 32, height: 1))
            separator.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            contentView.addSubview(separator)

            let ball = BallView(diameter: 50, color: colors[i])
            ball.center = CGPoint(x: 60, y: y)
            contentView.addSubview(ball)

            let props = UIDynamicItemBehavior(items: [ball])
            props.density = density
            props.resistance = 1.6
            props.elasticity = 0.4
            animator.addBehavior(props)
            collision.addItem(ball)

            // The exact same impulse for everyone.
            let push = UIPushBehavior(items: [ball], mode: .instantaneous)
            push.pushDirection = CGVector(dx: 1.6, dy: 0)
            animator.addBehavior(push)

            addCaption(String(format: "density %.1f", density), color: colors[i],
                       at: CGPoint(x: 76, y: y - 42))
        }
    }

    private func addCaption(_ text: String, color: UIColor, at point: CGPoint) {
        let label = UILabel()
        label.text = text
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = color.withAlphaComponent(0.9)
        label.sizeToFit()
        label.center = point
        contentView.addSubview(label)
        labels.append(label)
    }
}
