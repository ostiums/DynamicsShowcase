import UIKit

/// UIFieldBehavior: все 10 типов силовых полей на рое из 60 частиц.
/// Поле следует за пальцем; тип выбирается чипами сверху.
final class FieldsDemoViewController: DemoViewController {

    private enum FieldKind: String, CaseIterable {
        case radial = "Radial"
        case spring = "Spring"
        case vortex = "Vortex"
        case noise = "Noise"
        case turbulence = "Turbulence"
        case velocity = "Velocity"
        case linear = "Linear"
        case drag = "Drag"
        case electric = "Electric"
        case magnetic = "Magnetic"

        var hint: String {
            switch self {
            case .radial: return ".radialGravityField — частицы стягиваются к пальцу"
            case .spring: return ".springField — пружина к центру поля, рой пульсирует"
            case .vortex: return ".vortexField — закручивает частицы вокруг пальца"
            case .noise: return ".noiseField — случайная сила, броуновское движение"
            case .turbulence: return ".turbulenceField — турбулентность, сила зависит от скорости"
            case .velocity: return ".velocityField — струя вверх + гравитация = фонтан"
            case .linear: return ".linearGravityField — линейная гравитация в области поля"
            case .drag: return ".dragField — зона вязкости: внутри круга частицы вязнут"
            case .electric: return ".electricField — заряженные частицы (charge) притягиваются"
            case .magnetic: return ".magneticField — сила ⊥ скорости, траектории закручиваются"
            }
        }
    }

    private var particles: [BallView] = []
    private let properties = UIDynamicItemBehavior()
    private let collision = UICollisionBehavior()
    private var activeFields: [UIFieldBehavior] = []
    private var extraBehaviors: [UIDynamicBehavior] = []

    private var fieldCenter: CGPoint = .zero
    private let ringLayer = CAShapeLayer()
    private var currentKind: FieldKind = .radial

    private let chipScroll = UIScrollView()
    private var chipButtons: [UIButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chipScroll)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(stack)

        for (i, kind) in FieldKind.allCases.enumerated() {
            var config = UIButton.Configuration.filled()
            config.title = kind.rawValue
            config.cornerStyle = .capsule
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
            config.baseForegroundColor = .white
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            let button = UIButton(configuration: config)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold).rounded()
            button.tag = i
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

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrag))
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDrag))
        view.addGestureRecognizer(tap)
    }

    override func buildScene() {
        particles.removeAll()
        activeFields.removeAll()
        extraBehaviors.removeAll()
        fieldCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY + 40)

        // Кольцо показывает позицию поля.
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

        properties.density = 0.4
        properties.resistance = 0.8
        properties.allowsRotation = false
        properties.charge = 1.0 // нужно для electric и magnetic полей

        collision.translatesReferenceBoundsIntoBoundary = true
        collision.collisionMode = .boundaries // частицы не сталкиваются между собой

        animator.addBehavior(properties)
        animator.addBehavior(collision)

        for _ in 0..<60 {
            let particle = BallView(diameter: .random(in: 9...16), color: Palette.randomNeon())
            particle.center = CGPoint(x: .random(in: 20...(view.bounds.width - 20)),
                                      y: .random(in: 140...(view.bounds.height - 120)))
            contentView.addSubview(particle)
            particles.append(particle)
            properties.addItem(particle)
            collision.addItem(particle)
        }

        apply(kind: currentKind)
    }

    // MARK: - Настройка полей

    @objc private func chipTapped(_ button: UIButton) {
        Haptics.action()
        apply(kind: FieldKind.allCases[button.tag])
        chipScroll.scrollRectToVisible(button.frame.insetBy(dx: -40, dy: 0), animated: true)
    }

    private func apply(kind: FieldKind) {
        currentKind = kind
        showHint(kind.hint)
        highlightChip()

        activeFields.forEach { animator.removeBehavior($0) }
        extraBehaviors.forEach { animator.removeBehavior($0) }
        activeFields.removeAll()
        extraBehaviors.removeAll()

        switch kind {
        case .radial:
            let field = UIFieldBehavior.radialGravityField(position: fieldCenter)
            field.strength = 12
            field.falloff = 1
            field.minimumRadius = 50
            addField(field)

        case .spring:
            let field = UIFieldBehavior.springField()
            field.position = fieldCenter
            field.strength = 0.6
            addField(field)

        case .vortex:
            let vortex = UIFieldBehavior.vortexField()
            vortex.position = fieldCenter
            vortex.strength = 0.006
            addField(vortex)
            // Слабое радиальное притяжение удерживает воронку от разлёта.
            let hold = UIFieldBehavior.radialGravityField(position: fieldCenter)
            hold.strength = 5
            hold.falloff = 1
            hold.minimumRadius = 50
            addField(hold)

        case .noise:
            let field = UIFieldBehavior.noiseField(smoothness: 0.9, animationSpeed: 1)
            field.strength = 0.4
            addField(field)

        case .turbulence:
            let field = UIFieldBehavior.turbulenceField(smoothness: 0.4, animationSpeed: 6)
            field.strength = 6
            addField(field)
            kickParticles(speed: 250)

        case .velocity:
            let jet = UIFieldBehavior.velocityField(direction: CGVector(dx: 0, dy: -1.6))
            jet.position = fieldCenter
            jet.region = UIRegion(radius: 110)
            addField(jet)
            let fall = UIFieldBehavior.linearGravityField(direction: CGVector(dx: 0, dy: 1))
            fall.strength = 0.7
            addField(fall)

        case .linear:
            let field = UIFieldBehavior.linearGravityField(direction: CGVector(dx: 0, dy: 1))
            field.strength = 1
            addField(field)

        case .drag:
            let drag = UIFieldBehavior.dragField()
            drag.position = fieldCenter
            drag.region = UIRegion(radius: 130)
            drag.strength = 8
            addField(drag)
            // Шум снаружи разгоняет частицы, зона drag их «засасывает» в желе.
            let stir = UIFieldBehavior.noiseField(smoothness: 0.9, animationSpeed: 1)
            stir.strength = 0.5
            addField(stir)

        case .electric:
            let field = UIFieldBehavior.electricField()
            field.position = fieldCenter
            field.strength = -6 // отрицательная сила притягивает положительный заряд
            field.falloff = 1
            field.minimumRadius = 50
            addField(field)

        case .magnetic:
            let field = UIFieldBehavior.magneticField()
            field.position = fieldCenter
            field.strength = 1.5
            addField(field)
            kickParticles(speed: 350)
        }
    }

    private func addField(_ field: UIFieldBehavior) {
        animator.addBehavior(field)
        activeFields.append(field)
    }

    private func kickParticles(speed: CGFloat) {
        for particle in particles {
            let angle = CGFloat.random(in: 0 ..< .pi * 2)
            let magnitude = CGFloat.random(in: speed * 0.4 ... speed)
            properties.addLinearVelocity(
                CGPoint(x: cos(angle) * magnitude, y: sin(angle) * magnitude),
                for: particle
            )
        }
    }

    private func highlightChip() {
        for (i, button) in chipButtons.enumerated() {
            let selected = FieldKind.allCases[i] == currentKind
            button.configuration?.baseBackgroundColor = selected
                ? Palette.amber.withAlphaComponent(0.55)
                : UIColor.white.withAlphaComponent(0.1)
        }
    }

    // MARK: - Перемещение поля

    @objc private func handleDrag(_ gesture: UIGestureRecognizer) {
        let location = gesture.location(in: contentView)
        guard location.y > 120 else { return }
        fieldCenter = location

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.position = fieldCenter
        CATransaction.commit()

        // Поля с точкой (position) переносим за пальцем; глобальные (noise, linear) не трогаем.
        for field in activeFields {
            field.position = fieldCenter
        }
    }
}
