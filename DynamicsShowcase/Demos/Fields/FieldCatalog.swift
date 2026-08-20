import UIKit

/// All ten field types offered by UIFieldBehavior.
enum FieldKind: String, CaseIterable {
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

    /// Some kinds only reveal their effect on moving particles;
    /// they get a random velocity kick of this speed on selection.
    var kickSpeed: CGFloat? {
        switch self {
        case .turbulence: return 250
        case .magnetic: return 350
        default: return nil
        }
    }
}

/// Builds configured UIFieldBehavior instances for every field kind.
/// Some kinds pair two fields to look their best (for example the
/// velocity jet needs gravity to turn into a fountain).
///
/// Important: a field affects only the items explicitly added to it
/// with `addItem(_:)` — the controller does that after creation.
enum FieldFactory {

    static func makeFields(for kind: FieldKind, at position: CGPoint) -> [UIFieldBehavior] {
        switch kind {
        case .radial:
            let field = UIFieldBehavior.radialGravityField(position: position)
            field.strength = 12
            field.falloff = 1
            field.minimumRadius = 50
            return [field]

        case .spring:
            let field = UIFieldBehavior.springField()
            field.position = position
            field.strength = 0.6
            return [field]

        case .vortex:
            let vortex = UIFieldBehavior.vortexField()
            vortex.position = position
            vortex.strength = 0.006
            // A weak radial pull keeps the funnel from flying apart.
            let hold = UIFieldBehavior.radialGravityField(position: position)
            hold.strength = 5
            hold.falloff = 1
            hold.minimumRadius = 50
            return [vortex, hold]

        case .noise:
            let field = UIFieldBehavior.noiseField(smoothness: 0.9, animationSpeed: 1)
            field.strength = 0.4
            return [field]

        case .turbulence:
            // Turbulence force scales with the item's velocity, so on its own it
            // dies out: resistance slows the particles, the force fades with the
            // speed, and the swarm freezes. A soft spring toward the field center
            // keeps the particles perpetually falling through it — and that motion
            // is what the turbulence scatters into a boiling swarm.
            let field = UIFieldBehavior.turbulenceField(smoothness: 0.4, animationSpeed: 6)
            field.strength = 4
            let hold = UIFieldBehavior.springField()
            hold.position = position
            hold.strength = 0.15
            return [field, hold]

        case .velocity:
            // A local upward jet plus global gravity — a fountain.
            let jet = UIFieldBehavior.velocityField(direction: CGVector(dx: 0, dy: -1.6))
            jet.position = position
            jet.region = UIRegion(radius: 110)
            let fall = UIFieldBehavior.linearGravityField(direction: CGVector(dx: 0, dy: 1))
            fall.strength = 0.7
            return [jet, fall]

        case .linear:
            let field = UIFieldBehavior.linearGravityField(direction: CGVector(dx: 0, dy: 1))
            field.strength = 1
            return [field]

        case .drag:
            // Noise stirs the particles; the drag zone traps them like jelly.
            let drag = UIFieldBehavior.dragField()
            drag.position = position
            drag.region = UIRegion(radius: 130)
            drag.strength = 8
            let stir = UIFieldBehavior.noiseField(smoothness: 0.9, animationSpeed: 1)
            stir.strength = 0.5
            return [drag, stir]

        case .electric:
            let field = UIFieldBehavior.electricField()
            field.position = position
            field.strength = -6 // negative strength attracts a positive charge
            field.falloff = 1
            field.minimumRadius = 50
            return [field]

        case .magnetic:
            let field = UIFieldBehavior.magneticField()
            field.position = position
            field.strength = 1.5
            return [field]
        }
    }
}
