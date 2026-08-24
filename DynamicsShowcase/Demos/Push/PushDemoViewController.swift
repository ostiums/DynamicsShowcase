import UIKit

/// Demonstrates UIPushBehavior in both of its modes.
///
/// - `.instantaneous` — a one-shot impulse, billiards-style: pull back from
///   a puck and release, and it shoots in the opposite direction; the farther
///   the pull, the harder the shot. Grabbing off-center adds spin via
///   `setTargetOffsetFromCenter(_:for:)`.
/// - `.continuous` — a constant force applied every frame; here its angle
///   slowly rotates, swirling all the pucks around the table.
/// - Six pockets, billiards-style: a ball that reaches one is potted, and
///   once the table is cleared a fresh rack rolls out.
/// - The white cue ball is the one you shoot — pull back anywhere on the
///   table. A potted cue ball respawns on its spot after a pause.
/// - "Real UI" mode is the proof of the whole showcase: the target is a
///   live fake settings screen — labels, cards, a working UISwitch,
///   buttons — ordinary UIKit views, not sprites. Each cell hangs on an
///   invisible spring, weighs in proportion to its area, and squashes
///   with a flash when the cue ball slams into it — and a hard enough
///   shot shatters the cell into spinning snapshot shards.
final class PushDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = PushDemoViewModel()

    private var pucks: [BallView] = []
    private var collision = UICollisionBehavior()
    private var puckProperties = UIDynamicItemBehavior()

    private let modeControl = UISegmentedControl()
    private var continuousPush: UIPushBehavior?
    private var rotationLink: CADisplayLink?

    private var cueBall: BallView?
    /// Boundary-free collisions between the cue ball and the fake-screen
    /// targets ("Real UI" mode only).
    private var targetCollision: UICollisionBehavior?
    /// The behaviors owned by one intact fake-screen element.
    private struct TargetSimulation {
        let body: UIDynamicItemBehavior
        let spring: UIAttachmentBehavior
    }

    /// Per-element simulations, so a shattered element can be pulled out
    /// of the animator cleanly.
    private var targetSimulations: [UIView: TargetSimulation] = [:]
    /// The extra-density behavior of the "Real UI" cue ball.
    private var cueHeavyBehavior: UIDynamicItemBehavior?
    /// The cue ball's velocity sampled one frame before a contact —
    /// beganContact fires after the collision is resolved, when the
    /// ball has already bounced and slowed down.
    private var lastCueVelocity: CGPoint = .zero
    private var pendingCleanups: [DispatchWorkItem] = []
    private var pocketCenters: [CGPoint] = []
    private var pocketLink: CADisplayLink?
    private var pendingRespawn: DispatchWorkItem?
    private var pendingCueRespawn: DispatchWorkItem?
    /// Which furniture the current scene was built with (rack vs. buttons).
    private var uiLayoutActive = false

    private var allBalls: [BallView] {
        if let cueBall { return pucks + [cueBall] }
        return pucks
    }

    private let aimLayer = CAShapeLayer()
    private var grabPoint: CGPoint = .zero
    private weak var aimedPuck: BallView?

    private var mode: PushDemoViewModel.Mode {
        PushDemoViewModel.Mode(rawValue: modeControl.selectedSegmentIndex) ?? .impulse
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // The billiards table speaks for itself — no navigation title.
        navigationItem.largeTitleDisplayMode = .never
        title = nil

        // Burgundy felt instead of the standard gradient, in every mode.
        let felt = FeltBackgroundView(frame: view.bounds)
        felt.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(felt, belowSubview: contentView)

        for (index, mode) in PushDemoViewModel.Mode.allCases.enumerated() {
            modeControl.insertSegment(withTitle: mode.title, at: index, animated: false)
        }
        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = Palette.mint.withAlphaComponent(0.5)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeControl)
        NSLayoutConstraint.activate([
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])

        // Dashed pull-back line: finger → puck.
        aimLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        aimLayer.lineWidth = 2
        aimLayer.lineDashPattern = [4, 6]
        aimLayer.fillColor = nil
        view.layer.addSublayer(aimLayer)

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    // A CADisplayLink retains its target, so it only runs while the screen is on
    // screen — otherwise it would keep this controller alive forever.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if continuousPush != nil {
            startRotationLink()
        }
        startPocketLink()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopRotationLink()
        stopPocketLink()
    }

    override func buildScene() {
        pucks.removeAll()
        cueBall = nil
        targetCollision = nil
        targetSimulations.removeAll()
        cueHeavyBehavior = nil
        lastCueVelocity = .zero
        continuousPush = nil
        stopRotationLink()
        pendingRespawn?.cancel()
        pendingRespawn = nil
        pendingCueRespawn?.cancel()
        pendingCueRespawn = nil
        pendingCleanups.forEach { $0.cancel() }
        pendingCleanups.removeAll()

        collision = UICollisionBehavior()
        collision.collisionDelegate = self

        // The playfield ends at the navigation bar: an explicit rect
        // boundary instead of translatesReferenceBoundsIntoBoundary,
        // which would let the balls fly up under the bar.
        let tableTop = view.safeAreaLayoutGuide.layoutFrame.minY
        collision.addBoundary(
            withIdentifier: "table" as NSString,
            for: UIBezierPath(rect: CGRect(
                x: 0,
                y: tableTop,
                width: view.bounds.width,
                height: view.bounds.height - tableTop
            ))
        )
        // A thin rail line so the top wall the balls bounce off is visible.
        contentView.layer.addSublayer(CAShapeLayer.boundaryLine(
            from: CGPoint(x: 0, y: tableTop),
            to: CGPoint(x: view.bounds.width, y: tableTop),
            color: UIColor.white.withAlphaComponent(0.25),
            glow: nil
        ))

        puckProperties = UIDynamicItemBehavior()
        puckProperties.elasticity = viewModel.elasticity
        puckProperties.friction = viewModel.friction
        puckProperties.resistance = viewModel.resistance
        puckProperties.density = viewModel.density
        puckProperties.allowsRotation = true

        animator.addBehavior(collision)
        animator.addBehavior(puckProperties)

        uiLayoutActive = (mode == .ui)
        if uiLayoutActive {
            pocketCenters = []
            spawnUITargets()
        } else {
            pocketCenters = viewModel.pocketCenters(
                in: view.bounds,
                tableTop: tableTop
            )
            addPocketViews()
            spawnRack()
        }
        spawnCueBall()

        if mode == .continuous {
            startContinuousPush()
        }
    }

    private func spawnRack() {
        for (index, center) in viewModel.puckCenters(in: view.bounds).enumerated() {
            let puck = BallView(diameter: viewModel.puckDiameter, color: Palette.neon[index])
            pucks.append(puck)
            place(puck, at: center)
        }
    }

    private func spawnCueBall() {
        let ball = BallView(diameter: viewModel.puckDiameter, color: .white)
        cueBall = ball
        let center = uiLayoutActive
            ? viewModel.uiCueBallCenter(in: view.bounds)
            : viewModel.cueBallCenter(in: view.bounds)
        place(ball, at: center)
        // The cue ball also collides with the fake-screen targets…
        targetCollision?.addItem(ball)
        // …and a cue ball respawned mid-swirl joins the continuous force.
        continuousPush?.addItem(ball)

        if uiLayoutActive {
            // Extra mass for the wrecking job: the most specific
            // UIDynamicItemBehavior wins, overriding the shared density.
            let heavy = UIDynamicItemBehavior(items: [ball])
            heavy.density = viewModel.uiCueBallDensity
            animator.addBehavior(heavy)
            cueHeavyBehavior = heavy
        }
    }

    private func place(_ ball: BallView, at center: CGPoint) {
        ball.center = center
        contentView.addSubview(ball)
        collision.addItem(ball)
        puckProperties.addItem(ball)

        ball.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) { ball.transform = .identity }
    }

    /// The point of the whole showcase in one scene: the targets are a live
    /// fake settings screen — labels, cards, a real UISwitch, buttons of
    /// every kind — and they all collide like any other dynamic item.
    private func spawnUITargets() {
        // The targets stay out of the table boundary — it's their springs,
        // not walls, that keep them on screen. This boundary-free behavior
        // makes the cue ball collide with them (it joins in spawnCueBall)
        // and them with each other.
        let smashCollision = UICollisionBehavior()
        smashCollision.collisionMode = .items
        smashCollision.collisionDelegate = self
        animator.addBehavior(smashCollision)
        targetCollision = smashCollision

        for target in FakeSettingsScreen.makeElements(
            content: viewModel,
            in: view.bounds,
            topY: view.safeAreaLayoutGuide.layoutFrame.minY + 56
        ) {
            contentView.addSubview(target)
            smashCollision.addItem(target)

            // Per-element body: the density scales with the element's
            // area, so a toggle row and the profile cell take the same
            // hit very differently. Rotation stays off — the spring is
            // anchored at the center and exerts no torque, so a spun
            // cell would settle crooked instead of straightening out.
            let body = UIDynamicItemBehavior(items: [target])
            body.density = viewModel.targetDensity(
                forArea: target.bounds.width * target.bounds.height
            )
            body.elasticity = viewModel.targetElasticity
            body.friction = viewModel.targetFriction
            body.resistance = viewModel.targetResistance
            body.allowsRotation = false
            animator.addBehavior(body)

            // The invisible spring that rocks the cell and pulls it back
            // to its home spot after every hit.
            let spring = UIAttachmentBehavior(item: target, attachedToAnchor: target.center)
            spring.length = 0
            spring.frequency = viewModel.targetSpringFrequency
            spring.damping = viewModel.targetSpringDamping
            animator.addBehavior(spring)

            targetSimulations[target] = TargetSimulation(body: body, spring: spring)
        }
    }

    // MARK: - Slingshot (.instantaneous)

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard mode != .continuous else { return }
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            grabPoint = location
            // Billiards: the shot always fires the white cue ball.
            aimedPuck = cueBall

        case .changed:
            guard let puck = aimedPuck else { return }
            drawAimLine(from: location, to: puck.center)

        case .ended:
            aimLayer.path = nil
            guard let puck = aimedPuck,
                  var impulse = viewModel.impulseVector(pullingFrom: location, puckCenter: puck.center)
            else { return }

            if uiLayoutActive {
                // The wrecking ball is heavier — boost the shot to match.
                impulse.dx *= viewModel.uiImpulseBoost
                impulse.dy *= viewModel.uiImpulseBoost
            }

            let push = UIPushBehavior(items: [puck], mode: .instantaneous)
            push.pushDirection = impulse
            push.setTargetOffsetFromCenter(
                viewModel.spinOffset(fromGrab: grabPoint, puckCenter: puck.center),
                for: puck
            )

            // An instantaneous push fires once — remove the behavior afterwards.
            push.action = { [weak self, weak push] in
                if let push, !push.active {
                    self?.animator.removeBehavior(push)
                }
            }
            animator.addBehavior(push)
            Haptics.action()

        default:
            aimLayer.path = nil
        }
    }

    /// The pull-back segment: finger → puck. The shot goes the opposite way.
    private func drawAimLine(from location: CGPoint, to puckCenter: CGPoint) {
        let path = UIBezierPath()
        path.move(to: location)
        path.addLine(to: puckCenter)
        aimLayer.path = path.cgPath
    }

    // MARK: - Continuous force (.continuous)

    @objc private func modeChanged() {
        // Entering or leaving "Real UI" swaps the furniture — rebuild the
        // scene. Impulse ↔ continuous just toggles the force.
        if (mode == .ui) != uiLayoutActive {
            resetScene()
            return
        }
        if mode == .continuous {
            startContinuousPush()
        } else {
            stopContinuousPush()
        }
    }

    private func startContinuousPush() {
        stopContinuousPush()
        let push = UIPushBehavior(items: allBalls, mode: .continuous)
        push.magnitude = viewModel.continuousMagnitude
        push.angle = -.pi / 2
        animator.addBehavior(push)
        continuousPush = push
        startRotationLink()
    }

    private func stopContinuousPush() {
        if let continuousPush {
            animator.removeBehavior(continuousPush)
            self.continuousPush = nil
        }
        stopRotationLink()
    }

    private func startRotationLink() {
        stopRotationLink()
        let link = CADisplayLink(target: self, selector: #selector(rotatePushVector))
        link.add(to: .main, forMode: .common)
        rotationLink = link
    }

    private func stopRotationLink() {
        rotationLink?.invalidate()
        rotationLink = nil
    }

    @objc private func rotatePushVector() {
        continuousPush?.angle += viewModel.continuousRotationStep
    }

    // MARK: - Pockets

    private func addPocketViews() {
        let radius = viewModel.pocketRadius
        for center in pocketCenters {
            let pocket = UIView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            pocket.center = center
            pocket.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            pocket.layer.cornerRadius = radius
            pocket.layer.borderWidth = 2
            pocket.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            contentView.addSubview(pocket)
        }
    }

    private func startPocketLink() {
        stopPocketLink()
        let link = CADisplayLink(target: self, selector: #selector(tableTick))
        link.add(to: .main, forMode: .common)
        pocketLink = link
    }

    private func stopPocketLink() {
        pocketLink?.invalidate()
        pocketLink = nil
    }

    /// Every frame: remember the cue ball's pre-contact velocity (the
    /// shatter check needs it) and pot any ball that reached a pocket.
    @objc private func tableTick() {
        if let cueBall {
            lastCueVelocity = puckProperties.linearVelocity(for: cueBall)
        }
        checkPockets()
    }

    /// A ball whose center reaches a pocket is potted.
    private func checkPockets() {
        guard !pocketCenters.isEmpty else { return }
        for ball in allBalls {
            let pocket = pocketCenters.first { center in
                hypot(ball.center.x - center.x, ball.center.y - center.y)
                    < viewModel.pocketCaptureDistance
            }
            if let pocket {
                pot(ball, into: pocket)
            }
        }
    }

    /// Takes the ball out of the simulation and swallows it into the pocket.
    private func pot(_ ball: BallView, into pocket: CGPoint) {
        if ball === cueBall {
            cueBall = nil
            // Symmetric to spawnCueBall: leave every behavior it joined.
            targetCollision?.removeItem(ball)
            if let cueHeavyBehavior {
                animator.removeBehavior(cueHeavyBehavior)
                self.cueHeavyBehavior = nil
            }
            scheduleCueRespawn()
        } else {
            pucks.removeAll { $0 === ball }
            if pucks.isEmpty {
                scheduleRackRespawn()
            }
        }
        collision.removeItem(ball)
        puckProperties.removeItem(ball)
        continuousPush?.removeItem(ball)
        Haptics.collision(intensity: 0.9)

        UIView.animate(
            withDuration: 0.25,
            animations: {
                ball.center = pocket
                ball.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                ball.alpha = 0
            },
            completion: { _ in
                ball.removeFromSuperview()
            }
        )
    }

    /// The table is cleared — roll out a fresh rack after a short pause.
    private func scheduleRackRespawn() {
        pendingRespawn?.cancel()
        pendingRespawn = scheduleRespawn { [weak self] in
            guard let self else { return }
            self.spawnRack()
            if self.mode == .continuous {
                self.startContinuousPush()
            }
        }
    }

    /// A potted (scratched) cue ball comes back to its spot.
    private func scheduleCueRespawn() {
        pendingCueRespawn?.cancel()
        pendingCueRespawn = scheduleRespawn { [weak self] in
            self?.spawnCueBall()
        }
    }

    private func scheduleRespawn(_ work: @escaping () -> Void) -> DispatchWorkItem {
        let respawn = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + viewModel.rackRespawnDelay,
            execute: respawn
        )
        return respawn
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item1: UIDynamicItem,
        with item2: UIDynamicItem,
        at p: CGPoint
    ) {
        reactToContact(item1, item2, intensity: 0.6)
        squashOnContact(item1)
        squashOnContact(item2)
        shatterIfSmashed(item1, by: item2)
        shatterIfSmashed(item2, by: item1)
    }

    /// A short jelly squash plus a border flash the instant a fake-screen
    /// element is hit. Layer animations override the model values the
    /// animator keeps writing, so they play cleanly mid-flight.
    private func squashOnContact(_ item: UIDynamicItem) {
        guard let target = item as? UIView, !(target is BallView) else { return }

        let squashX = CAKeyframeAnimation(keyPath: "transform.scale.x")
        squashX.values = [1.0, 1.06, 0.97, 1.0]
        let squashY = CAKeyframeAnimation(keyPath: "transform.scale.y")
        squashY.values = [1.0, 0.9, 1.04, 1.0]
        for squash in [squashX, squashY] {
            squash.keyTimes = [0, 0.35, 0.7, 1]
            squash.duration = 0.22
        }

        target.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        let border = CABasicAnimation(keyPath: "borderWidth")
        border.fromValue = 2
        border.toValue = 0
        border.duration = 0.3

        target.layer.add(squashX, forKey: "contactSquashX")
        target.layer.add(squashY, forKey: "contactSquashY")
        target.layer.add(border, forKey: "contactBorder")
    }

    // MARK: - Shattering

    /// A cell hit by a fast-enough cue ball doesn't just rock — it breaks.
    /// The threshold compares against the velocity sampled a frame ago:
    /// by the time beganContact fires the collision is already resolved
    /// and the ball has bounced and slowed down.
    private func shatterIfSmashed(_ item: UIDynamicItem, by other: UIDynamicItem) {
        guard let target = item as? UIView,
              targetSimulations[target] != nil,
              other is BallView
        else { return }

        let speed = hypot(lastCueVelocity.x, lastCueVelocity.y)
        guard speed > viewModel.shatterSpeedThreshold else { return }
        shatter(target, ballVelocity: lastCueVelocity)
    }

    /// The most screenshot-worthy moment: the cell splits into snapshot
    /// shards that spin away, rain down and get swept up afterwards.
    private func shatter(_ target: UIView, ballVelocity: CGPoint) {
        guard let shards = makeShards(of: target) else { return }

        // The original leaves the simulation entirely.
        if let simulation = targetSimulations.removeValue(forKey: target) {
            animator.removeBehavior(simulation.body)
            animator.removeBehavior(simulation.spring)
        }
        targetCollision?.removeItem(target)
        target.removeFromSuperview()
        Haptics.collision(intensity: 1)

        let debris = UIDynamicItemBehavior(items: shards)
        debris.resistance = viewModel.shardResistance
        // This screen has no global gravity — only the shards fall.
        let fall = UIGravityBehavior(items: shards)
        animator.addBehavior(debris)
        animator.addBehavior(fall)

        for shard in shards {
            let dx = shard.center.x - target.center.x
            let dy = shard.center.y - target.center.y
            let radial = max(1, hypot(dx, dy))
            let burst = CGFloat.random(in: viewModel.shardBurstSpeed)
            debris.addLinearVelocity(
                CGPoint(
                    x: dx / radial * burst + ballVelocity.x * 0.3,
                    y: dy / radial * burst + ballVelocity.y * 0.3
                ),
                for: shard
            )
            debris.addAngularVelocity(.random(in: viewModel.shardSpinRange), for: shard)
        }

        // Sweep the debris once it has fallen off the screen.
        let cleanup = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.animator.removeBehavior(debris)
            self.animator.removeBehavior(fall)
            shards.forEach { $0.removeFromSuperview() }
        }
        pendingCleanups.append(cleanup)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + viewModel.shardCleanupDelay,
            execute: cleanup
        )
    }

    /// Slices the cell's live snapshot into a grid of 4–6 pieces.
    private func makeShards(of target: UIView) -> [UIView]? {
        let size = target.bounds.size
        guard size.width > 1, size.height > 1 else { return nil }

        let columns = size.width > 200 ? 3 : 2
        let rows = 2
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
                guard let shard = target.resizableSnapshotView(
                    from: rect,
                    afterScreenUpdates: false,
                    withCapInsets: .zero
                ) else { continue }
                shard.center = target.convert(CGPoint(x: rect.midX, y: rect.midY), to: contentView)
                shard.transform = target.transform
                contentView.addSubview(shard)
                shards.append(shard)
            }
        }
        return shards.isEmpty ? nil : shards
    }

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item: UIDynamicItem,
        withBoundaryIdentifier identifier: NSCopying?,
        at p: CGPoint
    ) {
        reactToContact(item, intensity: 0.4)
    }
}

/// Burgundy felt: the billiards-table backdrop this screen uses in place
/// of the standard gradient.
private final class FeltBackgroundView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [
            UIColor(red: 0.38, green: 0.09, blue: 0.17, alpha: 1).cgColor,
            UIColor(red: 0.21, green: 0.04, blue: 0.10, alpha: 1).cgColor,
        ]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Screenshot snippet
//
// The physics core of this screen, stripped of layout and styling.
// This block goes on the code screenshot shown next to the recording.
/*

// Billiards-style slingshot: the cue ball flies opposite to the pull.
// UIPushBehavior treats the vector's length as the force magnitude.
let magnitude = min(pullDistance / 10, 24)
let push = UIPushBehavior(items: [cueBall], mode: .instantaneous)
push.pushDirection = CGVector(
    dx: (cueBall.center.x - finger.x) / pullDistance * magnitude,
    dy: (cueBall.center.y - finger.y) / pullDistance * magnitude
)

// Grabbing off-center spins the ball — a cue striking off-center.
push.setTargetOffsetFromCenter(grabOffset, for: cueBall)
animator.addBehavior(push)

// A potted ball simply leaves the simulation.
collision.removeItem(pottedBall)

// Mode 2, .continuous, applies the force every frame; slowly
// rotating its angle swirls all the balls around the table.
continuousPush.angle += 0.02

// Mode 3: every settings cell hangs on an invisible spring —
// a hit rocks it, jelly-like, and it snaps back home.
let spring = UIAttachmentBehavior(item: cell, attachedToAnchor: home)
spring.length = 0
spring.frequency = 2.2
spring.damping = 0.55

// Mass honesty sells the effect: density grows with the cell's
// area, so small cells fly and the big profile cell barely budges.
body.density = cellArea / 12_000
*/
