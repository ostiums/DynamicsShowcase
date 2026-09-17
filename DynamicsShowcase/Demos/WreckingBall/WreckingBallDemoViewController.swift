import UIKit

/// Demonstrates UIAttachmentBehavior — and where it ends.
///
/// - The ball hangs on a rope. An attachment can't be one: rigid or
///   springy, it pushes as readily as it pulls. `RopeBehavior` is a custom
///   `UIDynamicBehavior` that only pulls: slack, it leaves the ball in free
///   flight; stretched, it is a damped spring, so the ball caught at the
///   end of a fall bounces on it. The drawn rope is a Verlet chain that
///   sags and whips on its own.
/// - Dragging is a springy `UIAttachmentBehavior(item:attachedToAnchor:)`
///   whose `anchorPoint` follows the finger. The rope stays on: pull the
///   ball past its reach and the rope stretches against the finger, let go
///   and it slings the ball back. A flick throws the ball with the
///   finger's velocity.
/// - The dense wrecking ball smashes a wall of bricks standing on a
///   pedestal (a line boundary of the collision behavior). Every brick
///   carries a word, the ball carries the answer.
/// - A hard enough hit doesn't just topple a brick: it shatters it into
///   snapshot shards, sends a shockwave out of the contact point and
///   shakes the screen. Once the pedestal is cleared the payoff line drops
///   in on a `UISnapBehavior` and the wall stands back up for another go.
final class WreckingBallDemoViewController: DemoViewController, UICollisionBehaviorDelegate {

    private let viewModel = WreckingBallDemoViewModel()

    private var wreckingBall: BallView?
    private var bricks: [BrickView] = []
    /// Where each brick was laid — the reference for "still standing".
    private var brickHomes: [BrickView: CGPoint] = [:]
    private var gravity = UIGravityBehavior()
    private var collision = UICollisionBehavior()
    /// The pedestal line, for the bricks only: the ball swings through it.
    private var pedestal = UICollisionBehavior()
    private var ballProperties = UIDynamicItemBehavior()
    private var brickProperties = UIDynamicItemBehavior()
    private var dragAttachment: UIAttachmentBehavior?
    private var rope: RopeBehavior?
    /// The rope as it is drawn; the force comes from `rope`.
    private var ropeChain: VerletRope?
    private var wallLayout: WreckingBallDemoViewModel.WallLayout?

    /// The wrecking ball's velocity sampled one frame before a contact —
    /// beganContact fires after the collision is resolved, when the ball
    /// has already bounced and slowed down.
    private var lastBallVelocity: CGPoint = .zero
    private var wallCleared = false
    private var counterLabel: UILabel?
    /// Bricks knocked out of the wall this round; never goes back down.
    private var destroyedCount = 0

    /// Velocities taken away from the items for the length of a hit-stop.
    private struct FrozenMotion {
        let behavior: UIDynamicItemBehavior
        let item: UIDynamicItem
        let linear: CGPoint
        let angular: CGFloat
    }
    private var frozenMotion: [FrozenMotion] = []
    private var isFrozen = false
    private var lastHitStop: CFTimeInterval = 0
    /// One behavior per shattered brick, holding its shards.
    private var debrisBehaviors: [UIDynamicItemBehavior] = []
    /// Set once the payoff has had its moment; the rebuild itself waits for
    /// the ball to swing clear of the pedestal.
    private var rebuildPending = false
    private var payoffLabel: UILabel?
    private var payoffBehaviors: [UIDynamicBehavior] = []

    /// Hard shadows. A layer's own shadow is cast in the layer's coordinates
    /// and would swing around a rotating brick. These are sublayers that
    /// slide the opposite way as their view turns, so every shadow falls
    /// down and to the right. Being part of the view, they can't lag behind
    /// it the way a separate layer synced once per frame does.
    private var shadows: [UIView: CALayer] = [:]
    private var shadowObservations: [UIView: NSKeyValueObservation] = [:]

    /// Draws the rope between the anchor and the ball, beneath it.
    private let ropeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.fillColor = nil
        return layer
    }()

    /// Ghost dots trailing the wrecking ball, oldest first.
    private var trailDots: [CALayer] = []
    private var trailPoints: [CGPoint] = []

    private var displayLink: CADisplayLink?

    private var anchorPoint: CGPoint {
        viewModel.anchorPoint(in: view.bounds, safeTop: view.safeAreaLayoutGuide.layoutFrame.minY)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // This screen is light, unlike the rest of the app: the drafting
        // sheet covers the shared dark gradient, and the navigation bar
        // switches to dark ink for as long as the screen is up.
        let sheet = BlueprintBackgroundView(
            frame: view.bounds,
            top: viewModel.sheetTop,
            bottom: viewModel.sheetBottom,
            line: viewModel.gridColor
        )
        sheet.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(sheet, belowSubview: contentView)
        ropeLayer.strokeColor = viewModel.inkColor.withAlphaComponent(0.85).cgColor

        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
    }

    // The per-frame tick (rope, trail, velocity sampling) runs only while the
    // screen is visible. A CADisplayLink retains its target, so one that lived
    // as long as the controller would keep the controller alive forever.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDisplayLink()
        styleNavigationBar(light: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        styleNavigationBar(light: false)
    }

    private func styleNavigationBar(light: Bool) {
        guard let bar = navigationController?.navigationBar else { return }
        bar.overrideUserInterfaceStyle = light ? .light : .unspecified
        bar.tintColor = light ? viewModel.inkColor : nil

        guard light, navigationItem.standardAppearance == nil else { return }
        let appearance = bar.standardAppearance.copy()
        appearance.titleTextAttributes[.foregroundColor] = viewModel.inkColor
        appearance.largeTitleTextAttributes[.foregroundColor] = viewModel.inkColor
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
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
        wreckingBall = nil
        bricks.removeAll()
        brickHomes.removeAll()
        trailPoints.removeAll()
        lastBallVelocity = .zero
        wallCleared = false
        destroyedCount = 0
        frozenMotion.removeAll()
        isFrozen = false
        debrisBehaviors.removeAll()
        rebuildPending = false
        payoffLabel = nil
        payoffBehaviors.removeAll()
        dragAttachment = nil
        shadows.removeAll()
        shadowObservations.removeAll()
        rope = nil
        ropeChain = nil

        gravity = UIGravityBehavior()
        gravity.magnitude = viewModel.gravityMagnitude
        collision = UICollisionBehavior()
        // No screen edges, deliberately: the pedestal is the only boundary.
        // Bricks knocked off it fly out of the picture instead of piling up
        // against an immovable wall with a heavy ball wedged into the pile.
        // The ball itself is kept on screen by its rope.
        collision.collisionDelegate = self
        pedestal = UICollisionBehavior()
        pedestal.collisionMode = .boundaries
        pedestal.collisionDelegate = self
        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(pedestal)

        ballProperties = UIDynamicItemBehavior()
        ballProperties.elasticity = viewModel.ballElasticity
        ballProperties.resistance = viewModel.ballResistance
        ballProperties.angularResistance = viewModel.ballAngularResistance
        ballProperties.density = viewModel.wreckingBallDensity
        // A slick ball: bricks that land on it slide off instead of riding
        // along on top of it through the next swing.
        ballProperties.friction = 0
        animator.addBehavior(ballProperties)

        brickProperties = UIDynamicItemBehavior()
        brickProperties.density = viewModel.brickDensity
        brickProperties.friction = viewModel.brickFriction
        brickProperties.elasticity = viewModel.brickElasticity
        animator.addBehavior(brickProperties)

        // Added first so the views drawn afterwards cover the rope and the trail.
        addTrail()
        contentView.layer.addSublayer(ropeLayer)

        addAnchorDot()

        let wallLayout = viewModel.wallLayout(
            in: view.bounds,
            ballRest: viewModel.restPoint(anchor: anchorPoint)
        )
        self.wallLayout = wallLayout
        addPlatform(wallLayout)
        spawnWall(animated: false)
        addBall()
        addCounter()
        drawRope(dt: 0)
    }

    // MARK: - Scene

    private func addAnchorDot() {
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
        dot.backgroundColor = viewModel.inkColor
        dot.layer.cornerRadius = 7
        dot.center = anchorPoint
        contentView.addSubview(dot)
    }

    private func addCounter() {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold).rounded()
        label.textColor = viewModel.inkColor.withAlphaComponent(0.7)
        label.text = viewModel.counterText(destroyed: 0)
        label.sizeToFit()
        // Left-aligned under the large title; the anchor keeps the pop
        // animation growing away from the screen edge.
        label.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
        label.layer.position = CGPoint(
            x: 20,
            y: view.safeAreaLayoutGuide.layoutFrame.minY + 14
        )
        contentView.addSubview(label)
        counterLabel = label
    }

    private func updateCounter(destroyed: Int) {
        guard destroyed > destroyedCount, let counterLabel else { return }
        destroyedCount = destroyed
        counterLabel.text = viewModel.counterText(destroyed: destroyed)
        counterLabel.sizeToFit()

        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1, 1.18, 1]
        pop.duration = 0.2
        counterLabel.layer.add(pop, forKey: "pop")
    }

    private func addTrail() {
        trailDots = (0..<viewModel.trailLength).map { index in
            let progress = CGFloat(index) / CGFloat(max(1, viewModel.trailLength - 1))
            let diameter = viewModel.wreckingBallDiameter * (0.15 + 0.7 * progress)
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            dot.cornerRadius = diameter / 2
            dot.backgroundColor = viewModel.wreckingBallColor
                .withAlphaComponent(0.06 + 0.34 * progress).cgColor
            dot.isHidden = true
            contentView.layer.addSublayer(dot)
            return dot
        }
    }

    private func addBall() {
        let ball = BallView(
            diameter: viewModel.wreckingBallDiameter,
            color: viewModel.wreckingBallColor,
            label: viewModel.ballLabel
        )
        ball.center = viewModel.restPoint(anchor: anchorPoint)
        // No glow at rest on a light sheet; `flash()` still pulses it on a hit.
        ball.layer.shadowOpacity = 0
        contentView.addSubview(ball)
        wreckingBall = ball
        addShadow(for: ball, cornerRadius: viewModel.wreckingBallDiameter / 2)

        gravity.addItem(ball)
        collision.addItem(ball)
        ballProperties.addItem(ball)

        let rope = RopeBehavior(
            item: ball,
            body: ballProperties,
            anchor: anchorPoint,
            length: viewModel.ropeLength,
            frequency: viewModel.ropeFrequency,
            dampingRatio: viewModel.ropeDampingRatio
        )
        animator.addBehavior(rope)
        self.rope = rope
        ropeChain = VerletRope(
            from: anchorPoint,
            to: ball.center,
            length: viewModel.ropeLength,
            links: viewModel.ropeLinks,
            gravity: viewModel.gravityMagnitude * viewModel.gravityUnit
        )
    }

    private func addPlatform(_ layout: WreckingBallDemoViewModel.WallLayout) {
        // The pedestal is a line boundary; bricks rest on it until hit.
        pedestal.addBoundary(
            withIdentifier: "platform" as NSString,
            from: layout.platformStart,
            to: layout.platformEnd
        )
        contentView.layer.addSublayer(CAShapeLayer.boundaryLine(
            from: layout.platformStart,
            to: layout.platformEnd,
            color: viewModel.inkColor,
            glow: nil
        ))
    }

    private func addShadow(for view: UIView, cornerRadius: CGFloat) {
        let shadow = CALayer()
        shadow.bounds = view.bounds
        shadow.cornerRadius = cornerRadius
        shadow.cornerCurve = view.layer.cornerCurve
        shadow.backgroundColor = viewModel.inkColor
            .withAlphaComponent(viewModel.shadowOpacity).cgColor
        // Beneath the view's own content.
        shadow.zPosition = -1
        view.layer.addSublayer(shadow)
        shadows[view] = shadow
        updateShadow(of: view)

        shadowObservations[view] = view.layer.observe(\.transform) { [weak self, weak view] _, _ in
            if let view { self?.updateShadow(of: view) }
        }
    }

    private func removeShadow(for view: UIView) {
        shadowObservations[view] = nil
        shadows.removeValue(forKey: view)?.removeFromSuperlayer()
    }

    /// Places the shadow at the scene's offset, expressed in the view's
    /// own — rotated — coordinates.
    private func updateShadow(of view: UIView) {
        guard let shadow = shadows[view] else { return }
        let angle = atan2(view.transform.b, view.transform.a)
        let offset = viewModel.shadowOffset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadow.position = CGPoint(
            x: view.bounds.midX + offset.width * cos(angle) + offset.height * sin(angle),
            y: view.bounds.midY - offset.width * sin(angle) + offset.height * cos(angle)
        )
        CATransaction.commit()
    }

    /// Lays the bricks. Animated, they drop in from above the screen row by
    /// row and join the simulation only once they have landed — the rebuild
    /// after a cleared wall.
    private func spawnWall(animated: Bool) {
        guard let wallLayout else { return }
        let words = viewModel.bricks

        for (index, center) in wallLayout.brickCenters.enumerated() {
            let row = index / viewModel.wallColumns
            let brick = BrickView(
                size: viewModel.brickSize,
                color: viewModel.brickColor(forRow: row),
                text: words[index % words.count]
            )
            brick.center = center
            if let wreckingBall {
                contentView.insertSubview(brick, belowSubview: wreckingBall)
            } else {
                contentView.addSubview(brick)
            }
            bricks.append(brick)
            brickHomes[brick] = center
            addShadow(for: brick, cornerRadius: brick.layer.cornerRadius)

            guard animated else {
                addToSimulation(brick)
                continue
            }

            let delay = viewModel.brickDropRowStagger * Double(row)
            brick.center.y = -viewModel.brickSize.height
            brick.alpha = 0
            UIView.animate(
                withDuration: viewModel.brickDropDuration,
                delay: delay,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.4
            ) {
                brick.center = center
                brick.alpha = 1
            }
            schedule(after: delay + viewModel.brickDropDuration) { [weak self] in
                self?.addToSimulation(brick)
            }
        }
    }

    private func addToSimulation(_ brick: BrickView) {
        gravity.addItem(brick)
        collision.addItem(brick)
        pedestal.addItem(brick)
        brickProperties.addItem(brick)
    }

    private func removeFromSimulation(_ brick: BrickView) {
        gravity.removeItem(brick)
        collision.removeItem(brick)
        pedestal.removeItem(brick)
        brickProperties.removeItem(brick)
    }

    /// Takes a brick out of the scene entirely.
    private func discard(_ brick: BrickView) {
        removeFromSimulation(brick)
        bricks.removeAll { $0 === brick }
        brickHomes[brick] = nil
        removeShadow(for: brick)
        brick.removeFromSuperview()
    }

    // MARK: - Gestures

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: contentView)

        switch pan.state {
        case .began:
            guard let wreckingBall,
                  hypot(wreckingBall.center.x - location.x, wreckingBall.center.y - location.y)
                    < viewModel.grabRadius
            else { return }
            beginDrag(of: wreckingBall, at: location)
            Haptics.action()

        case .changed:
            dragAttachment?.anchorPoint = location

        default:
            endDrag(throwVelocity: pan.velocity(in: contentView))
        }
    }

    /// A spring, not a rigid joint: the ball keeps a velocity of its own
    /// while it follows the finger, and the rope can pull against the hand.
    private func beginDrag(of ball: BallView, at location: CGPoint) {
        let attachment = UIAttachmentBehavior(item: ball, attachedToAnchor: location)
        attachment.length = 0
        attachment.frequency = viewModel.dragFrequency
        attachment.damping = viewModel.dragDamping
        animator.addBehavior(attachment)
        dragAttachment = attachment
        ballProperties.resistance = viewModel.heldBallResistance
    }

    /// Letting go hands the ball the finger's velocity. The drag spring
    /// can't be trusted to leave it behind: the ball trails the finger, and
    /// a short flick is over before the spring has passed its speed on.
    /// A rope stretched by the pull needs no help — it is still there after
    /// the release and slings the ball back on its own.
    private func endDrag(throwVelocity: CGPoint) {
        guard let dragAttachment, let wreckingBall else { return }
        animator.removeBehavior(dragAttachment)
        self.dragAttachment = nil
        ballProperties.resistance = viewModel.ballResistance

        let throwing = viewModel.throwVelocity(fromGesture: throwVelocity)
        let current = ballProperties.linearVelocity(for: wreckingBall)
        ballProperties.addLinearVelocity(
            CGPoint(x: throwing.x - current.x, y: throwing.y - current.y),
            for: wreckingBall
        )
    }

    // MARK: - Every frame

    @objc private func tick(_ link: CADisplayLink) {
        drawRope(dt: link.targetTimestamp - link.timestamp)
        guard let wreckingBall else { return }

        // A frozen scene has no velocities to sample and no trail to extend.
        if !isFrozen {
            lastBallVelocity = ballProperties.linearVelocity(for: wreckingBall)
            updateTrail(with: wreckingBall.center)
        }

        // Bricks that flew off the screen are gone; keep the simulation lean.
        for brick in bricks where viewModel.isOffScreen(brickCenter: brick.center, in: view.bounds) {
            discard(brick)
        }

        // The wall is down once nothing is left standing — rubble on the
        // pedestal doesn't count, the rebuild sweeps it away.
        let standing = bricks.filter { brick in
            guard let home = brickHomes[brick] else { return false }
            return viewModel.isStanding(
                brickCenter: brick.center,
                rotation: atan2(brick.transform.b, brick.transform.a),
                home: home
            )
        }.count
        updateCounter(destroyed: viewModel.wallRows * viewModel.wallColumns - standing)
        if !wallCleared, standing == 0 {
            wallCleared = true
            celebrate()
        }

        if rebuildPending, let wallLayout, viewModel.isBallClear(
            ballCenter: wreckingBall.center,
            velocity: lastBallVelocity,
            layout: wallLayout
        ) {
            rebuildPending = false
            rebuildWall()
        }
    }

    private func drawRope(dt: TimeInterval) {
        guard let wreckingBall, let rope else {
            ropeLayer.path = nil
            return
        }
        if dt > 0 {
            ropeChain?.step(from: anchorPoint, to: wreckingBall.center, dt: min(dt, 1.0 / 30))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ropeLayer.path = ropeChain?.path.cgPath
        ropeLayer.lineWidth = viewModel.ropeLineWidth(stretch: rope.stretch)
        CATransaction.commit()
    }

    private func updateTrail(with point: CGPoint) {
        trailPoints.append(point)
        if trailPoints.count > trailDots.count {
            trailPoints.removeFirst(trailPoints.count - trailDots.count)
        }
        // Positions are set every frame; implicit animations would only lag behind.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let offset = trailDots.count - trailPoints.count
        for (index, dot) in trailDots.enumerated() {
            let pointIndex = index - offset
            dot.isHidden = pointIndex < 0
            if pointIndex >= 0 {
                dot.position = trailPoints[pointIndex]
            }
        }
        CATransaction.commit()
    }

    // MARK: - UICollisionBehaviorDelegate

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item1: UIDynamicItem,
        with item2: UIDynamicItem,
        at p: CGPoint
    ) {
        reactToContact(item1, item2, intensity: 0.5)
        if let brick = item1 as? BrickView, item2 === wreckingBall {
            brickHit(brick, at: p)
        } else if let brick = item2 as? BrickView, item1 === wreckingBall {
            brickHit(brick, at: p)
        }
    }

    func collisionBehavior(
        _ behavior: UICollisionBehavior,
        beganContactFor item: UIDynamicItem,
        withBoundaryIdentifier identifier: NSCopying?,
        at p: CGPoint
    ) {
        reactToContact(item, intensity: 0.3)
    }

    /// The wrecking ball has hit a brick: a light touch rocks it, a hard
    /// one breaks it — with the whole screen feeling the impact.
    private func brickHit(_ brick: BrickView, at point: CGPoint) {
        let speed = hypot(lastBallVelocity.x, lastBallVelocity.y)
        guard speed > viewModel.shatterSpeedThreshold else {
            brick.squash()
            return
        }
        // No squash on a brick about to shatter: the shards are snapshots
        // and would be taken mid-blink, white.

        shatter(brick)
        shockwave(at: point)
        shakeScreen()
        hitStop()
        Haptics.collision(intensity: 1)
    }

    // MARK: - Impact effects

    /// The brick splits into snapshot shards that burst away from its
    /// center, keep some of the ball's momentum and rain out of the screen.
    /// They collide with nothing, so the wall isn't disturbed by its own debris.
    private func shatter(_ brick: BrickView) {
        guard let snapshots = brick.makeShards(in: contentView, columns: 4, rows: 2) else { return }
        let shards = snapshots.map { wrapShard($0, color: brick.color) }
        let origin = brick.center
        discard(brick)

        let debris = UIDynamicItemBehavior(items: shards)
        debris.angularResistance = viewModel.shardAngularResistance
        animator.addBehavior(debris)
        shards.forEach {
            // Debris flies behind the ball, not across its face.
            if let wreckingBall {
                contentView.insertSubview($0, belowSubview: wreckingBall)
            }
            gravity.addItem($0)
            addShadow(for: $0, cornerRadius: 0)
        }

        for shard in shards {
            let dx = shard.center.x - origin.x
            let dy = shard.center.y - origin.y
            let radial = max(1, hypot(dx, dy))
            let burst = CGFloat.random(in: viewModel.shardBurstSpeed)
            debris.addLinearVelocity(
                CGPoint(
                    x: dx / radial * burst + lastBallVelocity.x * 0.4,
                    y: dy / radial * burst + lastBallVelocity.y * 0.4
                ),
                for: shard
            )
            debris.addAngularVelocity(.random(in: viewModel.shardSpinRange), for: shard)
        }
        debrisBehaviors.append(debris)
        // A brick shattered while the scene stands still waits with the rest.
        if isFrozen {
            freeze(debris)
        }

        // Sweep the debris once it has fallen off the screen.
        schedule(after: viewModel.shardCleanupDelay) { [weak self] in
            guard let self else { return }
            self.animator.removeBehavior(debris)
            self.debrisBehaviors.removeAll { $0 === debris }
            shards.forEach {
                self.gravity.removeItem($0)
                self.removeShadow(for: $0)
                $0.removeFromSuperview()
            }
        }
    }

    // MARK: - Hit-stop

    /// The animator has no clock to slow down, so the scene is frozen by
    /// hand: every item's velocity is taken away and remembered, gravity
    /// and the rope let go, and a moment later everything gets its motion
    /// back. `beganContact` fires after the collision is resolved, so what
    /// is remembered is the motion the hit produced. Layer animations —
    /// the shockwave, the shake — aren't the animator's and play on.
    private func hitStop() {
        let now = CACurrentMediaTime()
        guard !isFrozen, dragAttachment == nil, now - lastHitStop > viewModel.hitStopCooldown else { return }
        lastHitStop = now
        isFrozen = true

        gravity.gravityDirection = .zero
        rope?.isPaused = true
        ([ballProperties, brickProperties] + debrisBehaviors).forEach(freeze)

        schedule(after: viewModel.hitStopDuration) { [weak self] in
            self?.unfreeze()
        }
    }

    private func freeze(_ behavior: UIDynamicItemBehavior) {
        for item in behavior.items {
            let linear = behavior.linearVelocity(for: item)
            let angular = behavior.angularVelocity(for: item)
            frozenMotion.append(FrozenMotion(
                behavior: behavior,
                item: item,
                linear: linear,
                angular: angular
            ))
            behavior.addLinearVelocity(CGPoint(x: -linear.x, y: -linear.y), for: item)
            behavior.addAngularVelocity(-angular, for: item)
        }
    }

    private func unfreeze() {
        // The direction, not `magnitude`: a zeroed gravity vector has lost
        // its angle, and setting the magnitude alone would point it sideways.
        gravity.gravityDirection = CGVector(dx: 0, dy: viewModel.gravityMagnitude)
        rope?.isPaused = false
        for motion in frozenMotion {
            motion.behavior.addLinearVelocity(motion.linear, for: motion.item)
            motion.behavior.addAngularVelocity(motion.angular, for: motion.item)
        }
        frozenMotion.removeAll()
        isFrozen = false
    }

    /// A shard is a clear view holding the snapshot piece, which leaves
    /// room underneath for its shadow. A snapshot of a brick in mid-flight
    /// can come back empty; the brick's color behind it keeps such a shard
    /// visible.
    private func wrapShard(_ snapshot: UIView, color: UIColor) -> UIView {
        let shard = UIView(frame: snapshot.bounds)
        shard.center = snapshot.center
        shard.transform = snapshot.transform
        let backing = CALayer()
        backing.frame = shard.bounds
        backing.backgroundColor = color.cgColor
        shard.layer.addSublayer(backing)

        snapshot.transform = .identity
        snapshot.frame = shard.bounds
        shard.addSubview(snapshot)
        contentView.addSubview(shard)
        return shard
    }

    /// An ink ring expanding out of the contact point.
    private func shockwave(at point: CGPoint) {
        let radius: CGFloat = 70
        let ring = CAShapeLayer()
        ring.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        ring.position = point
        ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
        ring.strokeColor = viewModel.inkColor.cgColor
        ring.fillColor = nil
        ring.lineWidth = 2
        ring.opacity = 0
        contentView.layer.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.15
        scale.toValue = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.5
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.45
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(group, forKey: "shockwave")
        CATransaction.commit()
    }

    /// The whole screen jolts on a hard hit. Additive translation on the
    /// presentation layer only: nothing the animator tracks is touched.
    private func shakeScreen() {
        let shakeX = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shakeX.values = [0, 7, -6, 4, -2, 0]
        let shakeY = CAKeyframeAnimation(keyPath: "transform.translation.y")
        shakeY.values = [0, -4, 3, -2, 1, 0]
        for shake in [shakeX, shakeY] {
            shake.duration = 0.28
            shake.isAdditive = true
        }
        view.layer.add(shakeX, forKey: "shakeX")
        view.layer.add(shakeY, forKey: "shakeY")
    }

    // MARK: - Payoff and rebuild

    /// The pedestal is clear: the payoff line drops in, then the wall stands
    /// back up so the swing can go on without touching the reset button.
    private func celebrate() {
        guard let wallLayout else { return }
        Haptics.action()

        let label = UILabel()
        label.text = viewModel.payoff
        label.font = UIFont.systemFont(ofSize: 40, weight: .black).rounded()
        label.textColor = viewModel.inkColor
        label.textAlignment = .center
        label.sizeToFit()
        label.layer.shadowColor = viewModel.wreckingBallColor.cgColor
        label.layer.shadowOpacity = 1
        label.layer.shadowRadius = 0
        label.layer.shadowOffset = CGSize(width: 3, height: 4)
        let target = viewModel.payoffPoint(in: view.bounds, layout: wallLayout)
        label.center = CGPoint(x: target.x, y: -60)
        contentView.addSubview(label)
        payoffLabel = label

        // No gravity on the label — the snap alone pulls it in, and the
        // resistance turns the arrival from a slam into a drift.
        let snap = UISnapBehavior(item: label, snapTo: target)
        snap.damping = viewModel.payoffSnapDamping
        let drift = UIDynamicItemBehavior(items: [label])
        drift.resistance = viewModel.payoffResistance
        animator.addBehavior(snap)
        animator.addBehavior(drift)
        payoffBehaviors = [snap, drift]

        schedule(after: viewModel.rebuildDelay) { [weak self] in
            self?.rebuildPending = true
        }
    }

    private func rebuildWall() {
        payoffBehaviors.forEach { animator.removeBehavior($0) }
        payoffBehaviors.removeAll()
        if let payoffLabel {
            UIView.animate(withDuration: 0.3, animations: {
                payoffLabel.alpha = 0
            }, completion: { _ in
                payoffLabel.removeFromSuperview()
            })
            self.payoffLabel = nil
        }

        // Whatever is left of the old wall is swept away.
        bricks.forEach(discard)

        spawnWall(animated: true)
        wallCleared = false
        destroyedCount = 0
        counterLabel?.text = viewModel.counterText(destroyed: 0)
        counterLabel?.sizeToFit()
    }
}
