import UIKit

/// Glowing neon ball. Its physics boundary is an ellipse (collisionBoundsType).
final class BallView: UIView {
    let color: UIColor

    /// `label` is stamped on the ball in dark type — the wrecking ball wears its name.
    init(diameter: CGFloat, color: UIColor, label: String? = nil) {
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

        if let label {
            let text = UILabel(frame: bounds.insetBy(dx: diameter * 0.1, dy: diameter * 0.1))
            text.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            text.text = label
            text.numberOfLines = 0
            text.textAlignment = .center
            text.font = UIFont.systemFont(ofSize: diameter * 0.2, weight: .black).rounded()
            text.textColor = Palette.backgroundTop
            text.adjustsFontSizeToFitWidth = true
            text.minimumScaleFactor = 0.6
            addSubview(text)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var collisionBoundsType: UIDynamicItemCollisionBoundsType { .ellipse }

    /// Glow pulse on collision.
    func flash() {
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.55
        pulse.duration = 0.3
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(pulse, forKey: "flash")
    }
}

/// Rounded tile with an optional letter.
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

/// A brick of the wrecking-ball wall: a wide neon tile with a word on it.
final class BrickView: UIView {
    let color: UIColor

    init(size: CGSize, color: UIColor, text: String) {
        self.color = color
        super.init(frame: CGRect(origin: .zero, size: size))
        isUserInteractionEnabled = false

        backgroundColor = color.withAlphaComponent(0.2)
        layer.cornerRadius = size.height * 0.25
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = color.cgColor
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 8
        layer.shadowOffset = .zero

        let label = UILabel(frame: bounds.insetBy(dx: 6, dy: 2))
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.text = text
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: size.height * 0.42, weight: .bold).rounded()
        label.textColor = .white
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.65
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A short jelly squash plus a white border flash the instant the brick
    /// is hit. Layer animations override the model values the animator keeps
    /// writing, so they play cleanly mid-flight.
    func squash() {
        let squashX = CAKeyframeAnimation(keyPath: "transform.scale.x")
        squashX.values = [1.0, 1.08, 0.96, 1.0]
        let squashY = CAKeyframeAnimation(keyPath: "transform.scale.y")
        squashY.values = [1.0, 0.88, 1.05, 1.0]
        for animation in [squashX, squashY] {
            animation.keyTimes = [0, 0.35, 0.7, 1]
            animation.duration = 0.22
        }
        let border = CABasicAnimation(keyPath: "borderColor")
        border.fromValue = UIColor.white.cgColor
        border.toValue = color.cgColor
        border.duration = 0.35

        layer.add(squashX, forKey: "squashX")
        layer.add(squashY, forKey: "squashY")
        layer.add(border, forKey: "squashBorder")
    }
}

extension UIView {
    /// Slices the view's live snapshot into a grid of pieces, each placed in
    /// `container` exactly where that part of the view is on screen. The
    /// pieces are ready to be handed to the animator as debris; the view
    /// itself is left untouched. Nil when there is nothing to snapshot.
    func makeShards(in container: UIView, columns: Int, rows: Int) -> [UIView]? {
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return nil }

        let pieceWidth = size.width / CGFloat(columns)
        let pieceHeight = size.height / CGFloat(rows)

        var shards: [UIView] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: CGFloat(column) * pieceWidth,
                    y: CGFloat(row) * pieceHeight,
                    width: pieceWidth,
                    height: pieceHeight
                )
                guard let shard = resizableSnapshotView(
                    from: rect,
                    afterScreenUpdates: false,
                    withCapInsets: .zero
                ) else { continue }
                shard.center = convert(CGPoint(x: rect.midX, y: rect.midY), to: container)
                shard.transform = transform
                container.addSubview(shard)
                shards.append(shard)
            }
        }
        return shards.isEmpty ? nil : shards
    }
}
