import UIKit

/// The app's color palette: a dark background with a set of neon accents.
enum Palette {
    static let backgroundTop = UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1)
    static let backgroundBottom = UIColor(red: 0.10, green: 0.06, blue: 0.20, alpha: 1)
    static let tint = UIColor(red: 0.45, green: 0.80, blue: 1.0, alpha: 1)

    static let cyan = UIColor(red: 0.20, green: 0.90, blue: 1.00, alpha: 1)
    static let magenta = UIColor(red: 1.00, green: 0.30, blue: 0.75, alpha: 1)
    static let violet = UIColor(red: 0.62, green: 0.45, blue: 1.00, alpha: 1)
    static let mint = UIColor(red: 0.30, green: 1.00, blue: 0.65, alpha: 1)
    static let amber = UIColor(red: 1.00, green: 0.75, blue: 0.25, alpha: 1)
    static let coral = UIColor(red: 1.00, green: 0.45, blue: 0.38, alpha: 1)

    static let neon: [UIColor] = [cyan, magenta, violet, mint, amber, coral]

    static func randomNeon() -> UIColor { neon.randomElement()! }
}

extension UIFont {
    /// The same font with the SF Rounded design, when available.
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension UIColor {
    /// A lighter (factor > 1) or darker (factor < 1) variant of the color,
    /// used to shade the radial gradients of the balls.
    func adjusted(brightnessBy factor: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h,
                       saturation: max(0, min(1, s * (factor < 1 ? 0.9 : 0.75))),
                       brightness: max(0, min(1, b * factor)),
                       alpha: a)
    }
}

/// Dark gradient background shared by every screen.
final class GradientBackgroundView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [Palette.backgroundTop.cgColor, Palette.backgroundBottom.cgColor]
        gradient.startPoint = CGPoint(x: 0.1, y: 0)
        gradient.endPoint = CGPoint(x: 0.9, y: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Bottom-of-screen hint pill.
final class HintLabel: UILabel {
    private let insets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.systemFont(ofSize: 13, weight: .semibold).rounded()
        textColor = UIColor.white.withAlphaComponent(0.85)
        backgroundColor = UIColor.white.withAlphaComponent(0.08)
        textAlignment = .center
        numberOfLines = 0
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
