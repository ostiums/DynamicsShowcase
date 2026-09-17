import UIKit

/// Configuration and pure geometry of the wrecking-ball scene: the cable,
/// the brick wall, the label sets. All the math lives here, fully testable
/// and free of any UIKit Dynamics code.
struct WreckingBallDemoViewModel {

    // What the wall says: a joke the ball is the punchline to. Swapping the
    // strings below is all it takes to shoot another take.
    /// Written on the wrecking ball.
    let ballLabel = "UIKit"
    /// One word per brick, bottom row first, left to right. The key pair
    /// sits in the middle rows, level with the ball.
    let bricks = [
        "Legacy", "Deprecated",
        "Rewrite it", "It's 2026",
        "Obsolete", "Old school",
        "UIKit is dead", "Use SwiftUI",
        "Nobody uses it", "Just migrate",
        "Storyboards", "Boilerplate",
    ]
    /// Drops in once the wall is gone.
    let payoff = "STILL ALIVE"

    // The ball and its cable.
    let wreckingBallDiameter: CGFloat = 120
    let wreckingBallColor = Palette.amber
    /// Cable length: the ball hangs level with the middle rows of the wall.
    let cableLength: CGFloat = 425
    /// Radius within which a pan grabs the ball.
    let grabRadius: CGFloat = 110
    /// Cap on the speed a flick can give the ball.
    let maxThrowSpeed: CGFloat = 1400

    /// The anchor hangs left of center so the ball rests clear of the wall
    /// and swings into it from the side.
    let anchorXFraction: CGFloat = 0.19
    let anchorTopInset: CGFloat = 70

    // Ball physics. It barely loses energy: the pendulum keeps going
    // through the wall several times on one throw.
    let ballElasticity: CGFloat = 0.3
    let ballResistance: CGFloat = 0.04
    let ballAngularResistance: CGFloat = 0.1
    /// Much denser than the bricks — that's what carries the momentum.
    let wreckingBallDensity: CGFloat = 4

    // Wall tuning: a brick bond, rows staggered by a sixth of a brick.
    let brickSize = CGSize(width: 84, height: 30)
    let brickGap: CGFloat = 3
    let wallRows = 6
    let wallColumns = 2
    /// Light bricks: the ball shoves them aside instead of plowing into a
    /// stiff pile, and the collision solver moves them rather than the ball.
    let brickDensity: CGFloat = 0.3
    /// High friction keeps a nudged wall from sliding along the pedestal in one piece.
    let brickFriction: CGFloat = 0.7
    let brickElasticity: CGFloat = 0.15
    /// Wall center, measured from the right edge of the screen. The pedestal
    /// stops well short of the edge, so a brick shoved off its far end falls
    /// instead of leaning on the screen boundary.
    let wallRightInset: CGFloat = 150
    /// The pedestal stands this far above the bottom of the screen.
    let platformBottomInset: CGFloat = 110
    /// A brick still counts as part of the wall while it sits this close to
    /// its home spot and this level. Anything else is rubble.
    let standingMaxOffset: CGFloat = 30
    let standingMaxTilt: CGFloat = .pi / 7

    /// Ball speed (pt/s) at contact that breaks a brick into shards and
    /// shakes the screen instead of just knocking the brick over.
    let shatterSpeedThreshold: CGFloat = 450
    let shardBurstSpeed: ClosedRange<CGFloat> = 80...260
    let shardSpinRange: ClosedRange<CGFloat> = -8...8
    let shardResistance: CGFloat = 0.8
    /// By this time the shards have rained off the screen.
    let shardCleanupDelay: TimeInterval = 3.5

    /// Number of ghost dots trailing the wrecking ball.
    let trailLength = 14

    /// Pause between the payoff dropping in and the wall standing back up.
    let rebuildDelay: TimeInterval = 2.4
    let brickDropDuration: TimeInterval = 0.45
    /// Rows land one after another, bottom first.
    let brickDropRowStagger: TimeInterval = 0.08
    let payoffSnapDamping: CGFloat = 0.6
    let payoffResistance: CGFloat = 6

    // MARK: - Cable

    func anchorPoint(in bounds: CGRect, safeTop: CGFloat) -> CGPoint {
        CGPoint(x: bounds.width * anchorXFraction, y: safeTop + anchorTopInset)
    }

    /// Where the ball hangs at rest: straight down from the anchor.
    func restPoint(anchor: CGPoint) -> CGPoint {
        CGPoint(x: anchor.x, y: anchor.y + cableLength)
    }

    /// The velocity a released ball gets from the gesture: the finger's own,
    /// capped so a wild flick can't launch the ball into orbit.
    func throwVelocity(fromGesture velocity: CGPoint) -> CGPoint {
        let speed = hypot(velocity.x, velocity.y)
        guard speed > maxThrowSpeed else { return velocity }
        return CGPoint(
            x: velocity.x / speed * maxThrowSpeed,
            y: velocity.y / speed * maxThrowSpeed
        )
    }

    /// `UIGravityBehavior`'s unit magnitude, in points per second squared.
    let gravityAcceleration: CGFloat = 1000

    /// Whether the cable should catch the ball: it has reached its full
    /// reach from the anchor and is still heading outward (or resting there).
    func shouldAttachCable(ballCenter: CGPoint, velocity: CGPoint, anchor: CGPoint) -> Bool {
        let dx = ballCenter.x - anchor.x
        let dy = ballCenter.y - anchor.y
        let distance = hypot(dx, dy)
        guard distance >= cableLength - 1 else { return false }
        let radialSpeed = (velocity.x * dx + velocity.y * dy) / max(distance, 1)
        return radialSpeed >= 0
    }

    /// Whether a taut cable is actually pulling. A rope on a swinging ball
    /// is under tension while `v²/L + g·cosθ > 0` (θ measured from straight
    /// down): always below the anchor, above it only when the ball is moving
    /// fast enough to be flung outward. Otherwise the rope goes slack and
    /// the ball falls freely — an attachment, being a rod, would hold it up.
    func isCableUnderTension(ballCenter: CGPoint, velocity: CGPoint, anchor: CGPoint) -> Bool {
        let cosTheta = (ballCenter.y - anchor.y) / cableLength
        let speedSquared = velocity.x * velocity.x + velocity.y * velocity.y
        return speedSquared / cableLength + gravityAcceleration * cosTheta > 0
    }

    // MARK: - Wall

    struct WallLayout {
        let platformStart: CGPoint
        let platformEnd: CGPoint
        /// Brick centers, bottom row first, left to right — the order of `bricks`.
        let brickCenters: [CGPoint]
        var platformY: CGFloat { platformStart.y }
    }

    /// Places a pedestal with a brick wall on the ground, right of the ball.
    func wallLayout(in bounds: CGRect) -> WallLayout {
        let wallX = bounds.width - wallRightInset
        // Rows shift by a sixth of a brick: enough to read as a bond, small
        // enough that every edge brick's center still sits on the brick below.
        let stagger = brickSize.width / 6
        let rowWidth = CGFloat(wallColumns) * brickSize.width + CGFloat(wallColumns - 1) * brickGap
        let platformStartX = wallX - rowWidth / 2 - stagger - 8
        // The far end stops short of the wall: the staggered edge bricks
        // overhang with their centers still supported, and a brick shoved
        // outward tips off instead of coming to rest on the pedestal.
        let platformEndX = wallX + rowWidth / 2 - stagger
        let platformY = bounds.height - platformBottomInset

        var centers: [CGPoint] = []
        let rowPitch = brickSize.height + brickGap
        for row in 0..<wallRows {
            let rowOffset = row.isMultiple(of: 2) ? -stagger : stagger
            for column in 0..<wallColumns {
                let x = wallX - rowWidth / 2 + brickSize.width / 2
                    + CGFloat(column) * (brickSize.width + brickGap) + rowOffset
                let y = platformY - brickSize.height / 2 - CGFloat(row) * rowPitch
                centers.append(CGPoint(x: x, y: y))
            }
        }

        return WallLayout(
            platformStart: CGPoint(x: platformStartX, y: platformY),
            platformEnd: CGPoint(x: platformEndX, y: platformY),
            brickCenters: centers
        )
    }

    /// Wall bricks take their color from the row, a neon stripe per course.
    func brickColor(forRow row: Int) -> UIColor {
        Palette.neon[row % Palette.neon.count]
    }

    /// Whether a brick is still standing in the wall: at its home spot and
    /// level. A brick knocked aside, toppled or lying on the pedestal is rubble.
    func isStanding(brickCenter: CGPoint, rotation: CGFloat, home: CGPoint) -> Bool {
        hypot(brickCenter.x - home.x, brickCenter.y - home.y) < standingMaxOffset
            && abs(rotation) < standingMaxTilt
    }

    /// A brick this far outside the screen is gone for good. Nothing stops
    /// a brick at the screen edges: knocked off the pedestal, it flies out
    /// of the picture. A brick thrown above the top is not counted out —
    /// gravity brings it back.
    func isOffScreen(brickCenter: CGPoint, in bounds: CGRect) -> Bool {
        let margin = brickSize.width
        return brickCenter.x < -margin
            || brickCenter.x > bounds.width + margin
            || brickCenter.y > bounds.height + margin
    }

    /// Whether the wall can be rebuilt without dropping bricks onto the
    /// ball: it is left of the pedestal and heading away, or hanging still.
    /// Half a swing period is plenty for the rows to land and settle.
    func isBallClear(ballCenter: CGPoint, velocity: CGPoint, layout: WallLayout) -> Bool {
        let clearOfPedestal = ballCenter.x + wreckingBallDiameter / 2 < layout.platformStart.x
        let heading = velocity.x < 0 || hypot(velocity.x, velocity.y) < 60
        return clearOfPedestal && heading
    }

    /// Where the payoff line settles: above the wall, out of the swing.
    func payoffPoint(in bounds: CGRect, layout: WallLayout) -> CGPoint {
        CGPoint(x: bounds.width - wallRightInset, y: layout.platformY - 300)
    }
}
