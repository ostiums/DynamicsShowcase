import UIKit

/// A model solar system on UIKit Dynamics.
///
/// The sun is a `radialGravityField` with `falloff = 2` — a true
/// inverse-square law, just like Newtonian gravity. Planets are ordinary
/// dynamic items with zero resistance that get one tangential
/// `addLinearVelocity` kick at spawn and then coast on circular orbits.
/// A planet that somehow drifts off screen is quietly respawned on its
/// home orbit.
final class SolarSystemDemoViewController: DemoViewController {

    private let viewModel = SolarSystemDemoViewModel()

    private var planetViews: [BallView] = []
    private var planetProperties = UIDynamicItemBehavior()
    private var sunField: UIFieldBehavior?

    private var trailLayers: [CAShapeLayer] = []
    private var trailPoints: [[CGPoint]] = []
    private var displayLink: CADisplayLink?

    private var sunCenter: CGPoint {
        CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    // MARK: - Lifecycle

    // The link that draws trails and rescues lost planets runs only while the
    // screen is visible: a CADisplayLink retains its target.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDisplayLink()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopDisplayLink()
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    override func buildScene() {
        planetViews.removeAll()
        trailLayers.removeAll()
        trailPoints.removeAll()

        drawOrbitGuides()

        // Frictionless space: no resistance, nothing to slow the planets down.
        planetProperties = UIDynamicItemBehavior()
        planetProperties.resistance = 0
        planetProperties.friction = 0
        planetProperties.elasticity = 0
        planetProperties.allowsRotation = false
        animator.addBehavior(planetProperties)

        // The sun: an inverse-square gravity well.
        let field = UIFieldBehavior.radialGravityField(position: sunCenter)
        field.strength = viewModel.sunFieldStrength
        field.falloff = viewModel.sunFieldFalloff
        field.minimumRadius = viewModel.sunMinimumRadius
        animator.addBehavior(field)
        sunField = field

        addSunView()

        for index in viewModel.planets.indices {
            spawnPlanet(at: index)
        }
    }

    // MARK: - Scene

    private func addSunView() {
        let sun = BallView(diameter: viewModel.sunDiameter, color: Palette.amber)
        sun.center = sunCenter
        // The sun is scenery, not a dynamic item — the field does its work.
        contentView.addSubview(sun)
    }

    private func drawOrbitGuides() {
        for planet in viewModel.planets {
            let guide = CAShapeLayer()
            guide.path = UIBezierPath(ovalIn: CGRect(
                x: sunCenter.x - planet.orbitRadius,
                y: sunCenter.y - planet.orbitRadius,
                width: planet.orbitRadius * 2,
                height: planet.orbitRadius * 2
            )).cgPath
            guide.strokeColor = UIColor.white.withAlphaComponent(0.06).cgColor
            guide.fillColor = nil
            guide.lineWidth = 1
            contentView.layer.addSublayer(guide)
        }
    }

    private func spawnPlanet(at index: Int) {
        let planet = viewModel.planets[index]
        let state = viewModel.initialState(around: sunCenter, planetAt: index)

        let ball = BallView(diameter: planet.diameter, color: planet.color)
        ball.center = state.center
        contentView.addSubview(ball)
        planetViews.append(ball)

        planetProperties.addItem(ball)
        sunField?.addItem(ball)
        planetProperties.addLinearVelocity(state.velocity, for: ball)

        let trail = CAShapeLayer()
        trail.strokeColor = planet.color.withAlphaComponent(0.28).cgColor
        trail.fillColor = nil
        trail.lineWidth = 2
        trail.lineCap = .round
        contentView.layer.insertSublayer(trail, at: 0)
        trailLayers.append(trail)
        trailPoints.append([])
    }

    // MARK: - Every frame

    @objc private func tick() {
        guard planetViews.count == trailPoints.count else { return }

        for (index, ball) in planetViews.enumerated() {
            trailPoints[index].append(ball.center)
            if trailPoints[index].count > viewModel.trailLength {
                trailPoints[index].removeFirst()
            }

            let path = UIBezierPath()
            if let first = trailPoints[index].first {
                path.move(to: first)
                for point in trailPoints[index].dropFirst() {
                    path.addLine(to: point)
                }
            }
            trailLayers[index].path = path.cgPath

            rescueIfLost(ball, at: index)
        }
    }

    /// A planet that drifted beyond the rescue radius silently returns
    /// to its home orbit with a fresh circular velocity.
    private func rescueIfLost(_ ball: BallView, at index: Int) {
        let distance = hypot(ball.center.x - sunCenter.x, ball.center.y - sunCenter.y)
        guard distance > viewModel.rescueRadius else { return }

        let state = viewModel.initialState(around: sunCenter, planetAt: index)
        ball.center = state.center
        animator.updateItem(usingCurrentState: ball)

        // There is no velocity setter — add the delta to the current velocity.
        let current = planetProperties.linearVelocity(for: ball)
        planetProperties.addLinearVelocity(
            CGPoint(x: state.velocity.x - current.x, y: state.velocity.y - current.y),
            for: ball
        )
        trailPoints[index].removeAll()
    }
}

// MARK: - Screenshot snippet
//
// The physics core of this screen, stripped of layout and styling.
// This block goes on the code screenshot shown next to the recording.
/*

// The sun: a radial field with falloff 2 — a true inverse-square
// law, exactly Newtonian gravity.
let sun = UIFieldBehavior.radialGravityField(position: center)
sun.strength = 2.3
sun.falloff = 2
planets.forEach { sun.addItem($0) }
animator.addBehavior(sun)

// Frictionless space: nothing slows the planets down.
let space = UIDynamicItemBehavior(items: planets)
space.resistance = 0
animator.addBehavior(space)

// One tangential kick closes a circular orbit: v = √(GM / r).
let speed = orbitSpeedFactor / sqrt(orbitRadius)
space.addLinearVelocity(
    CGPoint(x: -dy / r * speed, y: dx / r * speed),
    for: planet
)
*/
