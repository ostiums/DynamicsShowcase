import UIKit

/// Configuration and orbital math for the solar-system scene.
struct SolarSystemDemoViewModel {

    let hint = "Planets orbit a true 1/r² field.  Touch — a wandering black hole bends the orbits"

    struct Planet {
        let orbitRadius: CGFloat
        let diameter: CGFloat
        let color: UIColor
        /// 1 — circular orbit; below 1 the planet falls sunward into an ellipse.
        /// The last "comet" is launched slow on purpose for a stretched orbit.
        let speedFactor: CGFloat
    }

    let planets: [Planet] = [
        Planet(orbitRadius: 70, diameter: 10, color: Palette.mint, speedFactor: 1.0),
        Planet(orbitRadius: 105, diameter: 14, color: Palette.amber, speedFactor: 0.97),
        Planet(orbitRadius: 145, diameter: 18, color: Palette.cyan, speedFactor: 1.0),
        Planet(orbitRadius: 190, diameter: 12, color: Palette.coral, speedFactor: 0.94),
        Planet(orbitRadius: 240, diameter: 16, color: Palette.violet, speedFactor: 1.0),
        Planet(orbitRadius: 300, diameter: 9, color: Palette.magenta, speedFactor: 0.6),
    ]

    let sunDiameter: CGFloat = 56

    // The sun's gravity: a radial field with a true inverse-square falloff.
    let sunFieldStrength: CGFloat = 2.3
    let sunFieldFalloff: CGFloat = 2
    let sunMinimumRadius: CGFloat = 40

    /// Empirical gravitational parameter of the sun's field: circular orbital
    /// speed is `orbitSpeedFactor / sqrt(radius)`. UIKit doesn't document the
    /// field's force units, so this constant is calibrated by eye — bigger
    /// values make planets swing outward, smaller values make them spiral in.
    let orbitSpeedFactor: CGFloat = 1510

    // The black hole under the finger.
    let blackHoleStrength: CGFloat = 1.5
    let blackHoleFalloff: CGFloat = 2
    let blackHoleMinimumRadius: CGFloat = 30

    /// How many recent positions each planet's trail keeps.
    let trailLength = 40
    /// Beyond this distance from the sun a planet counts as lost to space
    /// and is respawned on its home orbit.
    let rescueRadius: CGFloat = 700

    /// Starting position and velocity for a planet: a point on its orbit
    /// (angles spread around the circle) and a tangential velocity that
    /// closes the orbit in the sun's field.
    func initialState(around sun: CGPoint, planetAt index: Int) -> (center: CGPoint, velocity: CGPoint) {
        let planet = planets[index]
        let angle = CGFloat(index) * (.pi * 2 / CGFloat(planets.count)) + .random(in: -0.3...0.3)
        let center = CGPoint(
            x: sun.x + cos(angle) * planet.orbitRadius,
            y: sun.y + sin(angle) * planet.orbitRadius
        )
        return (center, velocity(at: center, around: sun, planetAt: index))
    }

    /// Tangential velocity for a planet at `position`, aimed counterclockwise.
    /// Used both at spawn and to rescue a planet lost off screen.
    func velocity(at position: CGPoint, around sun: CGPoint, planetAt index: Int) -> CGPoint {
        let planet = planets[index]
        let dx = position.x - sun.x
        let dy = position.y - sun.y
        let radius = max(1, hypot(dx, dy))
        let speed = planet.speedFactor * orbitSpeedFactor / sqrt(radius)
        return CGPoint(x: -dy / radius * speed, y: dx / radius * speed)
    }
}
