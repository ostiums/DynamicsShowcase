import UIKit

/// Demonstrates UIDynamicItemBehavior — the behavior that carries the
/// physical properties of items.
///
/// - "Elasticity": identical balls with different `elasticity` dropped at
///   once bounce to visibly different heights.
/// - "Density": the same `UIPushBehavior` impulse moves balls of different
///   `density` (mass) by visibly different distances.
///
/// Each ball gets its own UIDynamicItemBehavior — that per-item control
/// is exactly what this demo is about.
final class PropertiesDemoViewController: DemoViewController {

    private var viewModel = PropertiesDemoViewModel()
    private let modeControl = UISegmentedControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        for (index, mode) in PropertiesDemoViewModel.Mode.allCases.enumerated() {
            modeControl.insertSegment(withTitle: mode.title, at: index, animated: false)
        }
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
        viewModel.mode = PropertiesDemoViewModel.Mode(rawValue: modeControl.selectedSegmentIndex) ?? .elasticity
        replay()
    }

    @objc private func replay() {
        Haptics.action()
        animator.removeAllBehaviors()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        buildScene()
    }

    override func buildScene() {
        showHint(viewModel.hint)
        switch viewModel.mode {
        case .elasticity: buildElasticityScene()
        case .density: buildDensityScene()
        }
    }

    // MARK: - Elasticity

    private func buildElasticityScene() {
        let values = viewModel.elasticityValues
        let colors = [Palette.coral, Palette.amber, Palette.mint, Palette.cyan]
        let laneWidth = view.bounds.width / CGFloat(values.count)

        let gravity = UIGravityBehavior()
        let collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        animator.addBehavior(gravity)
        animator.addBehavior(collision)

        // A visible "floor" above the captions and the hint.
        let floorY = view.bounds.height - viewModel.floorInset
        collision.addBoundary(withIdentifier: "floor" as NSString,
                              from: CGPoint(x: 0, y: floorY),
                              to: CGPoint(x: view.bounds.width, y: floorY))
        drawFloorLine(at: floorY)

        for (index, elasticity) in values.enumerated() {
            let x = laneWidth * (CGFloat(index) + 0.5)

            let ball = BallView(diameter: viewModel.ballDiameter, color: colors[index])
            ball.center = CGPoint(x: x, y: view.safeAreaInsets.top + 130)
            contentView.addSubview(ball)

            let properties = UIDynamicItemBehavior(items: [ball])
            properties.elasticity = elasticity
            animator.addBehavior(properties)

            gravity.addItem(ball)
            collision.addItem(ball)

            addCaption(String(format: "%.2f", elasticity), color: colors[index],
                       at: CGPoint(x: x, y: floorY + 28))
        }
    }

    // MARK: - Density

    private func buildDensityScene() {
        let values = viewModel.densityValues
        let colors = [Palette.cyan, Palette.mint, Palette.amber, Palette.coral]
        let topY = view.safeAreaInsets.top + 150

        let collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        animator.addBehavior(collision)

        for (index, density) in values.enumerated() {
            let y = topY + CGFloat(index) * viewModel.laneHeight

            let separator = UIView(frame: CGRect(x: 16, y: y + viewModel.laneHeight / 2 - 8,
                                                 width: view.bounds.width - 32, height: 1))
            separator.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            contentView.addSubview(separator)

            let ball = BallView(diameter: viewModel.ballDiameter, color: colors[index])
            ball.center = CGPoint(x: 60, y: y)
            contentView.addSubview(ball)

            let properties = UIDynamicItemBehavior(items: [ball])
            properties.density = density
            properties.resistance = viewModel.densityResistance
            properties.elasticity = viewModel.densityElasticity
            animator.addBehavior(properties)
            collision.addItem(ball)

            // The exact same impulse for every ball.
            let push = UIPushBehavior(items: [ball], mode: .instantaneous)
            push.pushDirection = viewModel.sharedImpulse
            animator.addBehavior(push)

            addCaption(String(format: "density %.1f", density), color: colors[index],
                       at: CGPoint(x: 76, y: y - 42))
        }
    }

    // MARK: - Decorations

    private func drawFloorLine(at y: CGFloat) {
        let line = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 16, y: y))
        path.addLine(to: CGPoint(x: view.bounds.width - 16, y: y))
        line.path = path.cgPath
        line.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        line.lineWidth = 3
        line.lineCap = .round
        contentView.layer.addSublayer(line)
    }

    private func addCaption(_ text: String, color: UIColor, at point: CGPoint) {
        let label = UILabel()
        label.text = text
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = color.withAlphaComponent(0.9)
        label.sizeToFit()
        label.center = point
        contentView.addSubview(label)
    }
}
