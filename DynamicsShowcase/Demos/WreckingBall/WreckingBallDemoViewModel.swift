import CoreGraphics

/// Pure geometry of the wrecking-ball scene: chain layout, tower placement
/// and the launch kick. All the tricky math lives here, fully testable and
/// free of any UIKit Dynamics code.
struct WreckingBallDemoViewModel {

    let hint = "Drag the ball and smash the tower.  Anchor + item-to-item rigid links"

    /// Ball diameters from the anchor down; the last one is the wrecking ball.
    let ballDiameters: [CGFloat] = [32, 30, 28, 26, 64]
    let firstLinkLength: CGFloat = 70
    let linkGap: CGFloat = 14

    // Physical tuning.
    let chainElasticity: CGFloat = 0.3
    let chainResistance: CGFloat = 0.1
    let chainAngularResistance: CGFloat = 0.2
    /// The wrecking ball is much denser than the chain — that's what carries the momentum.
    let wreckingBallDensity: CGFloat = 2.5
    let launchSpeed: CGFloat = 260

    // Tower tuning.
    let blockSize: CGFloat = 30
    let blockRows = 3
    let blockColumns = 2
    let blockDensity: CGFloat = 0.5
    let blockFriction: CGFloat = 0.5
    let blockElasticity: CGFloat = 0.25

    // MARK: - Chain

    struct ChainLayout {
        /// Distance of each ball from the anchor, measured along the chain.
        let distances: [CGFloat]
        /// Unit direction in which the chain is initially laid out.
        let direction: CGVector

        var length: CGFloat { distances.last ?? 0 }

        func ballCenter(at index: Int, anchor: CGPoint) -> CGPoint {
            CGPoint(x: anchor.x + direction.dx * distances[index],
                    y: anchor.y + direction.dy * distances[index])
        }
    }

    /// Lays the chain out along a straight line tilted from vertical.
    /// The tilt makes the pendulum start swinging by itself; the angle is
    /// capped so the last ball always stays inside the screen.
    func chainLayout(anchor: CGPoint, in bounds: CGRect) -> ChainLayout {
        var distances: [CGFloat] = []
        var reach = firstLinkLength
        for (index, diameter) in ballDiameters.enumerated() {
            if index > 0 {
                reach += ballDiameters[index - 1] / 2 + diameter / 2 + linkGap
            }
            distances.append(reach)
        }

        let length = distances.last ?? 1
        let maxDx = bounds.width - anchor.x - (ballDiameters.last ?? 0) / 2 - 12
        let sine = min(0.85, maxDx / length)
        let direction = CGVector(dx: sine, dy: sqrt(1 - sine * sine))

        return ChainLayout(distances: distances, direction: direction)
    }

    /// Initial velocity of the wrecking ball, tangential to the swing arc
    /// (perpendicular to the chain, pointing "downhill"). Guarantees a
    /// spectacular first hit even with air resistance.
    func launchVelocity(chainDirection: CGVector) -> CGPoint {
        CGPoint(x: -chainDirection.dy * launchSpeed,
                y: chainDirection.dx * launchSpeed)
    }

    // MARK: - Tower

    struct TowerLayout {
        let platformStart: CGPoint
        let platformEnd: CGPoint
        let blockCenters: [CGPoint]
    }

    /// Places a pedestal with a tower of blocks inside the chain's swing arc.
    ///
    /// The platform height is derived from the arc: at the tower's x-position
    /// the swinging ball's center passes at `sweepY`, so the platform sits
    /// `clearance` below it — close enough for the ball to plow through the
    /// blocks, far enough that the platform itself never blocks the swing.
    /// The platform also must not extend toward the arc's lowest point,
    /// which is why it ends shortly after the tower.
    func towerLayout(anchor: CGPoint, chainLength: CGFloat, in bounds: CGRect) -> TowerLayout {
        let towerX: CGFloat = 90
        let ballRadius = (ballDiameters.last ?? 0) / 2
        let clearance = ballRadius + 16

        let dx = towerX - anchor.x
        let sweepY = anchor.y + sqrt(max(0, chainLength * chainLength - dx * dx))
        let platformY = min(sweepY + clearance, bounds.height - 140)

        var centers: [CGPoint] = []
        let columnOffset = blockSize / 2 + 2
        for row in 0..<blockRows {
            for column in 0..<blockColumns {
                centers.append(CGPoint(
                    x: towerX + (column == 0 ? -columnOffset : columnOffset),
                    y: platformY - blockSize / 2 - CGFloat(row) * (blockSize + 2)
                ))
            }
        }

        return TowerLayout(
            platformStart: CGPoint(x: towerX - 70, y: platformY),
            platformEnd: CGPoint(x: towerX + 40, y: platformY),
            blockCenters: centers
        )
    }
}
