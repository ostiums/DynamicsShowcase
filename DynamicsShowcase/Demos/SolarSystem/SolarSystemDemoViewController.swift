import UIKit

/// A solar system on UIKit Dynamics.
///
/// The sun is a `radialGravityField` with `falloff = 2` — a true
/// inverse-square law, just like Newtonian gravity. Planets are ordinary
/// dynamic items with zero resistance that get one tangential
/// `addLinearVelocity` kick at spawn and then coast on their orbits.
/// Touching the screen adds a second radial field — a wandering black
/// hole that bends and steals the orbits. Planets flung off screen are
/// quietly respawned on their home orbit.
final class SolarSystemDemoViewController: DemoViewController {

    private let viewModel = SolarSystemDemoViewModel()

    private var planetViews: [BallView] = []
    private var planetProperties = UIDynamicItemBehavior()
    private var sunField: UIFieldBehavior?
    private var blackHoleField: UIFieldBehavior?

    private var trailLayers: [CAShapeLayer] = []
    private var trailPoints: [[CGPoint]] = []
    private let blackHoleRing = CAShapeLayer()
    private var displayLink: CADisplayLink?

    private var sunCenter: CGPoint {
        CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint(viewModel.hint)

        // A long press with zero duration tracks the finger from the first
        // instant — the black hole appears on touch, follows, and evaporates
        // on release.
        let touch = UILongPressGestureRecognizer(target: self, action: #selector(handleTouch))
        touch.minimumPressDuration = 0
        view.addGestureRecognizer(touch)
    }

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
        blackHoleField = nil

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

        // The black hole ring, hidden until a touch.
        blackHoleRing.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        blackHoleRing.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        blackHoleRing.lineWidth = 1.5
        blackHoleRing.path = UIBezierPath(ovalIn: CGRect(x: -16, y: -16, width: 32, height: 32)).cgPath
        blackHoleRing.isHidden = true
        contentView.layer.addSublayer(blackHoleRing)
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
        blackHoleField?.addItem(ball)
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

    /// A planet slingshotted beyond the rescue radius silently returns
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

    // MARK: - Black hole

    @objc private func handleTouch(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: contentView)

        switch gesture.state {
        case .began:
            let hole = UIFieldBehavior.radialGravityField(position: location)
            hole.strength = viewModel.blackHoleStrength
            hole.falloff = viewModel.blackHoleFalloff
            hole.minimumRadius = viewModel.blackHoleMinimumRadius
            planetViews.forEach { hole.addItem($0) }
            animator.addBehavior(hole)
            blackHoleField = hole
            moveBlackHoleRing(to: location, hidden: false)
            Haptics.action()

        case .changed:
            blackHoleField?.position = location
            moveBlackHoleRing(to: location, hidden: false)

        default:
            if let blackHoleField {
                animator.removeBehavior(blackHoleField)
                self.blackHoleField = nil
            }
            moveBlackHoleRing(to: location, hidden: true)
        }
    }

    private func moveBlackHoleRing(to point: CGPoint, hidden: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blackHoleRing.position = point
        blackHoleRing.isHidden = hidden
        CATransaction.commit()
    }
}
