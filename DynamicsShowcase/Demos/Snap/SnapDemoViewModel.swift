import CoreGraphics

/// Configuration and target-point math for the snap demo.
struct SnapDemoViewModel {

    let hint = "Tap anywhere — the tiles fly there.  UISnapBehavior(damping:)"

    let tileLetters = ["S", "N", "A", "P"]
    let tileSize: CGFloat = 66
    let tileSpacing: CGFloat = 14

    /// Damping options offered by the segmented control.
    /// 0 — maximum oscillation, 1 — no oscillation at all.
    let dampingOptions: [(title: String, value: CGFloat)] = [
        ("Bouncy 0.2", 0.2),
        ("Medium 0.5", 0.5),
        ("Stiff 0.9", 0.9),
    ]

    /// Radius of the circle the tiles land on around the tap point.
    let ringRadius: CGFloat = 74

    /// Initial tile centers: a horizontal row in the middle of the screen.
    func initialTileCenters(in bounds: CGRect) -> [CGPoint] {
        let count = tileLetters.count
        let totalWidth = CGFloat(count) * tileSize + CGFloat(count - 1) * tileSpacing
        let startX = (bounds.width - totalWidth) / 2 + tileSize / 2
        return (0..<count).map { index in
            CGPoint(x: startX + CGFloat(index) * (tileSize + tileSpacing),
                    y: bounds.midY)
        }
    }

    /// Snap targets: a circle around the tap point, rotated randomly on every
    /// tap so repeated taps keep the motion interesting. Targets are clamped
    /// so the tiles never snap under the navigation bar or off screen.
    func snapTargets(around point: CGPoint, in bounds: CGRect) -> [CGPoint] {
        let count = tileLetters.count
        let baseAngle = CGFloat.random(in: 0 ..< .pi * 2)
        return (0..<count).map { index in
            let angle = baseAngle + CGFloat(index) * (.pi * 2 / CGFloat(count))
            let target = CGPoint(x: point.x + cos(angle) * ringRadius,
                                 y: point.y + sin(angle) * ringRadius)
            return clamp(target, in: bounds)
        }
    }

    private func clamp(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, 50), bounds.width - 50),
                y: min(max(point.y, 140), bounds.height - 120))
    }
}
