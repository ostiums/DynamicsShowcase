import CoreGraphics

/// Configuration and selection state for the force-fields demo.
struct FieldsDemoViewModel {

    /// Currently selected field type.
    var selectedKind: FieldKind = .radial

    var hint: String { selectedKind.hint }

    let allKinds = FieldKind.allCases

    // Particle swarm tuning.
    let particleCount = 60
    let particleDiameterRange: ClosedRange<CGFloat> = 9...16
    let particleDensity: CGFloat = 0.4
    let particleResistance: CGFloat = 0.8
    /// Electric and magnetic fields act only on charged items.
    let particleCharge: CGFloat = 1.0

    /// Touches above this y move the selection chips, not the field.
    let minimumFieldY: CGFloat = 120

    func particleSpawnPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(x: .random(in: 20...(bounds.width - 20)),
                y: .random(in: 140...(bounds.height - 120)))
    }

    func initialFieldCenter(in bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY + 40)
    }

    /// A random velocity for one particle, used by the kinds that need motion.
    func kickVelocity(speed: CGFloat) -> CGPoint {
        let angle = CGFloat.random(in: 0 ..< .pi * 2)
        let magnitude = CGFloat.random(in: speed * 0.4 ... speed)
        return CGPoint(x: cos(angle) * magnitude, y: sin(angle) * magnitude)
    }
}
