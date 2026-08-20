import UIKit

/// Configuration and orbital math for the solar-system scene.
struct SolarSystemDemoViewModel {

    struct Planet {
        let orbitRadius: CGFloat
        let diameter: CGFloat
        let color: UIColor
    }

    // Orbit radii are capped so the whole system fits a phone screen:
    // the outermost ring stays inside the screen's half-width.
    let planets: [Planet] = [
        Planet(orbitRadius: 52, diameter: 9, color: Palette.mint),
        Planet(orbitRadius: 78, diameter: 12, color: Palette.amber),
        Planet(orbitRadius: 104, diameter: 16, color: Palette.cyan),
        Planet(orbitRadius: 130, diameter: 11, color: Palette.coral),
        Planet(orbitRadius: 155, diameter: 14, color: Palette.violet),
        Planet(orbitRadius: 180, diameter: 8, color: Palette.magenta),
    ]

    let sunDiameter: CGFloat = 48

    // The sun's gravity: a radial field with a true inverse-square falloff.
    let sunFieldStrength: CGFloat = 2.3
    let sunFieldFalloff: CGFloat = 2
    let sunMinimumRadius: CGFloat = 40

    /// Empirical gravitational parameter of the sun's field: circular orbital
    /// speed is `orbitSpeedFactor / sqrt(radius)`. UIKit doesn't document the
    /// field's force units, so this constant was calibrated by measurement —
    /// a free-fall run with logged radius and velocity gives the parameter,
    /// and its square root closes a circular orbit.
    let orbitSpeedFactor: CGFloat = 1510

    /// How many recent positions each planet's trail keeps.
    let trailLength = 40
    /// Beyond this distance from the sun a planet counts as lost to space
    /// and is respawned on its home orbit.
    let rescueRadius: CGFloat = 700

    /// Starting position and velocity for a planet: a point on its orbit
    /// (angles spread evenly around the circle) and the tangential velocity
    /// that closes a circular orbit in the sun's field.
    func initialState(around sun: CGPoint, planetAt index: Int) -> (center: CGPoint, velocity: CGPoint) {
        let planet = planets[index]
        let angle = CGFloat(index) * (.pi * 2 / CGFloat(planets.count))
        let center = CGPoint(
            x: sun.x + cos(angle) * planet.orbitRadius,
            y: sun.y + sin(angle) * planet.orbitRadius
        )
        return (center, velocity(at: center, around: sun))
    }

    /// Circular orbital velocity at `position`, aimed counterclockwise.
    /// Used both at spawn and to rescue a planet lost off screen.
    func velocity(at position: CGPoint, around sun: CGPoint) -> CGPoint {
        let dx = position.x - sun.x
        let dy = position.y - sun.y
        let radius = max(1, hypot(dx, dy))
        let speed = orbitSpeedFactor / sqrt(radius)
        return CGPoint(x: -dy / radius * speed, y: dx / radius * speed)
    }
}
