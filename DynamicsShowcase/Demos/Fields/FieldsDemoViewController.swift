import UIKit

/// Demonstrates UIFieldBehavior: all 10 field types acting on a swarm
/// of 60 particles. The field follows the finger; the type is picked
/// with the chips on top. Field construction lives in FieldFactory.
final class FieldsDemoViewController: DemoViewController {

    private var viewModel = FieldsDemoViewModel()

    private var particles: [BallView] = []
    private var particleProperties = UIDynamicItemBehavior()
    private var collision = UICollisionBehavior()
    private var activeFields: [UIFieldBehavior] = []

    private var fieldCenter: CGPoint = .zero
    private let ringLayer = CAShapeLayer()

    private let chipScroll = UIScrollView()
    private var chipButtons: [UIButton] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpChips()

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDrag)))
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleDrag)))
    }

    override func buildScene() {
        particles.removeAll()
        activeFields.removeAll()
        fieldCenter = viewModel.initialFieldCenter(in: view.bounds)

        addFieldRing()

        particleProperties = UIDynamicItemBehavior()
        particleProperties.density = viewModel.particleDensity
        particleProperties.resistance = viewModel.particleResistance
        particleProperties.allowsRotation = false
        particleProperties.charge = viewModel.particleCharge

        collision = UICollisionBehavior()
        collision.translatesReferenceBoundsIntoBoundary = true
        // Particles collide with each other too, so attracting fields form a
        // pretty round cluster instead of collapsing into a single point.

        animator.addBehavior(particleProperties)
        animator.addBehavior(collision)

        for _ in 0..<viewModel.particleCount {
            let particle = BallView(diameter: .random(in: viewModel.particleDiameterRange),
                                    color: Palette.randomNeon())
            particle.center = viewModel.particleSpawnPoint(in: view.bounds)
            contentView.addSubview(particle)
            particles.append(particle)
            particleProperties.addItem(particle)
            collision.addItem(particle)
        }

        apply(kind: viewModel.selectedKind)
    }

    // MARK: - Chips

    private func setUpChips() {
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chipScroll)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(stack)

        for (index, kind) in viewModel.allKinds.enumerated() {
            var config = UIButton.Configuration.filled()
            config.title = kind.rawValue
            config.cornerStyle = .capsule
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
            config.baseForegroundColor = .white
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            let button = UIButton(configuration: config)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold).rounded()
            button.tag = index
            button.addTarget(self, action: #selector(chipTapped), for: .touchUpInside)
            stack.addArrangedSubview(button)
            chipButtons.append(button)
        }

        NSLayoutConstraint.activate([
            chipScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            chipScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chipScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chipScroll.heightAnchor.constraint(equalToConstant: 44),
            stack.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor, constant: -8),
        ])
    }

    @objc private func chipTapped(_ button: UIButton) {
        Haptics.action()
        apply(kind: viewModel.allKinds[button.tag])
        chipScroll.scrollRectToVisible(button.frame.insetBy(dx: -40, dy: 0), animated: true)
    }

    private func highlightSelectedChip() {
        for (index, button) in chipButtons.enumerated() {
            let selected = viewModel.allKinds[index] == viewModel.selectedKind
            button.configuration?.baseBackgroundColor = selected
                ? Palette.amber.withAlphaComponent(0.55)
                : UIColor.white.withAlphaComponent(0.1)
        }
    }

    // MARK: - Fields

    private func apply(kind: FieldKind) {
        viewModel.selectedKind = kind
        showHint(viewModel.hint)
        highlightSelectedChip()

        activeFields.forEach { animator.removeBehavior($0) }
        activeFields.removeAll()

        for field in FieldFactory.makeFields(for: kind, at: fieldCenter) {
            // A field affects only the items explicitly added to it.
            particles.forEach { field.addItem($0) }
            animator.addBehavior(field)
            activeFields.append(field)
        }

        if let speed = kind.kickSpeed {
            for particle in particles {
                particleProperties.addLinearVelocity(viewModel.kickVelocity(speed: speed),
                                                     for: particle)
            }
        }
    }

    /// Pulsing ring that marks the field position.
    private func addFieldRing() {
        ringLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        ringLayer.fillColor = nil
        ringLayer.lineWidth = 1.5
        ringLayer.path = UIBezierPath(ovalIn: CGRect(x: -55, y: -55, width: 110, height: 110)).cgPath
        contentView.layer.addSublayer(ringLayer)
        ringLayer.position = fieldCenter

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.85
        pulse.toValue = 1.1
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ringLayer.add(pulse, forKey: "pulse")
    }

    // MARK: - Moving the field

    @objc private func handleDrag(_ gesture: UIGestureRecognizer) {
        let location = gesture.location(in: contentView)
        guard location.y > viewModel.minimumFieldY else { return }
        fieldCenter = location

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.position = fieldCenter
        CATransaction.commit()

        // Point-based fields follow the finger; infinite ones (noise, linear) don't care.
        for field in activeFields {
            field.position = fieldCenter
        }
    }
}
