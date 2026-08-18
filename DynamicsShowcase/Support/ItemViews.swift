import UIKit

/// Неоновый шар со свечением. Физическая граница — эллипс (collisionBoundsType).
final class BallView: UIView {
    let color: UIColor

    init(diameter: CGFloat, color: UIColor) {
        self.color = color
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        isUserInteractionEnabled = false

        let gradient = CAGradientLayer()
        gradient.type = .radial
        gradient.colors = [
            color.adjusted(brightnessBy: 1.5).cgColor,
            color.cgColor,
            color.adjusted(brightnessBy: 0.55).cgColor
        ]
        gradient.locations = [0, 0.55, 1]
        gradient.startPoint = CGPoint(x: 0.32, y: 0.28)
        gradient.endPoint = CGPoint(x: 1.15, y: 1.15)
        gradient.frame = bounds
        gradient.cornerRadius = diameter / 2
        gradient.masksToBounds = true
        layer.addSublayer(gradient)

        layer.shadowColor = color.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = max(6, diameter * 0.25)
        layer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var collisionBoundsType: UIDynamicItemCollisionBoundsType { .ellipse }

    /// Вспышка свечения при столкновении.
    func flash() {
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.55
        pulse.duration = 0.3
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(pulse, forKey: "flash")
    }
}

/// Плитка со скруглением и (опционально) буквой.
final class BoxView: UIView {
    let color: UIColor

    init(size: CGFloat, color: UIColor, letter: String? = nil) {
        self.color = color
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        isUserInteractionEnabled = false

        backgroundColor = color.withAlphaComponent(0.22)
        layer.cornerRadius = size * 0.22
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = color.cgColor
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 10
        layer.shadowOffset = .zero

        if let letter {
            let label = UILabel(frame: bounds)
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            label.text = letter
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: size * 0.45, weight: .heavy).rounded()
            label.textColor = color
            addSubview(label)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
