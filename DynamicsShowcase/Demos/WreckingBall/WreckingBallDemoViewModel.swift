import UIKit

/// Configuration and pure geometry of the wrecking-ball scene: the rope,
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

    // The look: a construction site drawn on a drafting sheet. Unlike the
    // rest of the app this screen is light — flat saturated color, dark
    // ink and hard shadows read better than neon in a small muted video.
    let sheetTop = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
    let sheetBottom = UIColor(red: 0.87, green: 0.90, blue: 0.92, alpha: 1)
    let gridColor = UIColor(red: 0.79, green: 0.82, blue: 0.85, alpha: 1)
    let inkColor = UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)
    /// One per course of the wall, bottom row first.
    let brickColors = [
        UIColor(red: 0.12, green: 0.44, blue: 0.92, alpha: 1),
        UIColor(red: 0.90, green: 0.28, blue: 0.30, alpha: 1),
        UIColor(red: 0.49, green: 0.30, blue: 1.00, alpha: 1),
        UIColor(red: 0.07, green: 0.64, blue: 0.43, alpha: 1),
        UIColor(red: 0.97, green: 0.41, blue: 0.03, alpha: 1),
        UIColor(red: 0.05, green: 0.56, blue: 0.64, alpha: 1),
    ]
    /// Everything casts the same hard shadow, down and to the right.
    let shadowOffset = CGSize(width: 4, height: 5)
    let shadowOpacity: CGFloat = 0.26

    /// `UIGravityBehavior.magnitude` for everything in the scene. At the
    /// default 1 (1000 pt/s²) a 120 pt ball on a 425 pt rope swings and
    /// falls in slow motion; the scene is big, so gravity has to be too.
    let gravityMagnitude: CGFloat = 2.5
    /// `UIGravityBehavior`'s unit magnitude, in points per second squared.
    let gravityUnit: CGFloat = 1000

    // The ball and its rope.
    let wreckingBallDiameter: CGFloat = 120
    /// Hazard yellow.
    let wreckingBallColor = UIColor(red: 1.00, green: 0.77, blue: 0.00, alpha: 1)
    /// Unstretched rope length: the ball hangs level with the middle rows of the wall.
    let ropeLength: CGFloat = 425
    /// The stretched rope is a damped spring: soft enough to see it give
    /// when the ball is caught at the end of a fall or pulled by hand,
    /// damped enough to settle after a couple of bounces.
    let ropeFrequency: CGFloat = 3.5
    let ropeDampingRatio: CGFloat = 0.35
    /// Points of the drawn rope's chain.
    let ropeLinks = 14
    let ropeLineWidth: CGFloat = 2.5
    /// Radius within which a pan grabs the ball.
    let grabRadius: CGFloat = 110
    /// The finger holds the ball on a spring of its own, soft enough to
    /// give in a tug-of-war against the rope.
    let dragFrequency: CGFloat = 6
    let dragDamping: CGFloat = 8
    /// The ball's `resistance` while it is held: a hand steadies what it
    /// holds, and the rope's pull against the drag spring would otherwise
    /// leave the ball buzzing in place.
    let heldBallResistance: CGFloat = 5
    /// Cap on the speed a flick can give the ball.
    let maxThrowSpeed: CGFloat = 2200

    /// The anchor hangs left of center so the ball rests clear of the wall
    /// and swings into it from the side.
    let anchorXFraction: CGFloat = 0.19
    let anchorTopInset: CGFloat = 70

    // Ball physics. Next to no air drag: the pendulum keeps going through
    // the wall several times on one throw and loses its energy to the hits.
    let ballElasticity: CGFloat = 0.3
    let ballResistance: CGFloat = 0.08
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
    /// The pedestal stands this far above the lowest point of the hanging
    /// ball, so the swing sweeps the bottom row too instead of passing
    /// over it. The ball itself doesn't collide with the pedestal.
    let platformRise: CGFloat = 10
    /// A brick still counts as part of the wall while it sits this close to
    /// its home spot and this level. Anything else is rubble.
    let standingMaxOffset: CGFloat = 30
    let standingMaxTilt: CGFloat = .pi / 7

    /// Ball speed (pt/s) at contact that breaks a brick into shards and
    /// shakes the screen instead of just knocking the brick over.
    let shatterSpeedThreshold: CGFloat = 700
    let shardBurstSpeed: ClosedRange<CGFloat> = 130...420
    let shardSpinRange: ClosedRange<CGFloat> = -8...8
    /// Shards tumble, but nothing slows their flight: they fall like the bricks do.
    let shardAngularResistance: CGFloat = 0.4
    /// By this time the shards have rained off the screen.
    let shardCleanupDelay: TimeInterval = 2.5

    /// Hit-stop: on a shattering hit the whole simulation stands still for
    /// a moment while the shockwave and the shake play on — the pause is
    /// what makes the hit read as heavy. One per swing, not one per brick.
    let hitStopDuration: TimeInterval = 0.11
    let hitStopCooldown: TimeInterval = 1.0

    /// The score line under the title.
    func counterText(destroyed: Int) -> String {
        "Arguments destroyed: \(destroyed)/\(wallRows * wallColumns)"
    }

    /// Number of ghost dots trailing the wrecking ball.
    let trailLength = 14

    /// Pause between the payoff dropping in and the wall standing back up.
    let rebuildDelay: TimeInterval = 2.4
    let brickDropDuration: TimeInterval = 0.45
    /// Rows land one after another, bottom first.
    let brickDropRowStagger: TimeInterval = 0.08
    let payoffSnapDamping: CGFloat = 0.6
    let payoffResistance: CGFloat = 6

    // MARK: - Rope

    func anchorPoint(in bounds: CGRect, safeTop: CGFloat) -> CGPoint {
        CGPoint(x: bounds.width * anchorXFraction, y: safeTop + anchorTopInset)
    }

    /// How far the ball's weight stretches the rope at rest: `g / ω²`.
    var restStretch: CGFloat {
        let omega = 2 * .pi * ropeFrequency
        return gravityMagnitude * gravityUnit / (omega * omega)
    }

    /// Where the ball hangs at rest: straight down from the anchor, the
    /// rope already stretched by its weight — so a fresh scene doesn't bob.
    func restPoint(anchor: CGPoint) -> CGPoint {
        CGPoint(x: anchor.x, y: anchor.y + ropeLength + restStretch)
    }

    /// The drawn rope thins out as it stretches, like anything elastic.
    func ropeLineWidth(stretch: CGFloat) -> CGFloat {
        let elongation = 1 + max(0, stretch) / ropeLength
        return max(1, ropeLineWidth / (elongation * elongation))
    }

    /// The velocity a released ball leaves with: the hand's own — what a
    /// firm grip gives anything it lets go of — capped so a wild flick
    /// can't launch the ball into orbit.
    func throwVelocity(fromGesture velocity: CGPoint) -> CGPoint {
        let speed = hypot(velocity.x, velocity.y)
        guard speed > maxThrowSpeed else { return velocity }
        return CGPoint(
            x: velocity.x / speed * maxThrowSpeed,
            y: velocity.y / speed * maxThrowSpeed
        )
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
    func wallLayout(in bounds: CGRect, ballRest: CGPoint) -> WallLayout {
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
        let platformY = ballRest.y + wreckingBallDiameter / 2 - platformRise

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

    /// Wall bricks take their color from the row, a stripe per course.
    func brickColor(forRow row: Int) -> UIColor {
        brickColors[row % brickColors.count]
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
