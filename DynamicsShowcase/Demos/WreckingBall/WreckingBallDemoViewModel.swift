import UIKit

/// Pure geometry of the wrecking-ball scene: chain layout and tower placement.
/// All the tricky math lives here, fully testable and free of any
/// UIKit Dynamics code.
struct WreckingBallDemoViewModel {

    /// One link of the chain.
    struct ChainBall {
        let diameter: CGFloat
        let color: UIColor
    }

    /// The chain from the anchor down; the last, heaviest ball is the wrecking ball.
    let chainBalls: [ChainBall] = [
        ChainBall(diameter: 32, color: Palette.violet),
        ChainBall(diameter: 30, color: Palette.cyan),
        ChainBall(diameter: 28, color: Palette.magenta),
        ChainBall(diameter: 26, color: Palette.mint),
        ChainBall(diameter: 64, color: Palette.amber),
    ]

    /// Diameter of the wrecking ball at the end of the chain.
    private var wreckingBallDiameter: CGFloat { chainBalls.last?.diameter ?? 0 }

    let firstLinkLength: CGFloat = 70
    let linkGap: CGFloat = 14
    /// Radius within which a pan grabs a ball of the chain.
    let grabRadius: CGFloat = 80

    // Physical tuning.
    let chainElasticity: CGFloat = 0.3
    let chainResistance: CGFloat = 0.1
    let chainAngularResistance: CGFloat = 0.2
    /// The wrecking ball is much denser than the chain — that's what carries the momentum.
    let wreckingBallDensity: CGFloat = 2.5

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
            CGPoint(
                x: anchor.x + direction.dx * distances[index],
                y: anchor.y + direction.dy * distances[index]
            )
        }
    }

    /// Lays the chain out hanging straight down from the anchor, at rest.
    /// The player swings it into the tower by dragging the wrecking ball.
    func chainLayout(anchor: CGPoint) -> ChainLayout {
        var distances: [CGFloat] = []
        var reach = firstLinkLength
        for (index, ball) in chainBalls.enumerated() {
            if index > 0 {
                reach += chainBalls[index - 1].diameter / 2 + ball.diameter / 2 + linkGap
            }
            distances.append(reach)
        }
        return ChainLayout(distances: distances, direction: CGVector(dx: 0, dy: 1))
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
    /// which is why it ends shortly before the tower on the center side.
    func towerLayout(anchor: CGPoint, chainLength: CGFloat, in bounds: CGRect) -> TowerLayout {
        let towerX = bounds.width - 90
        let clearance = wreckingBallDiameter / 2 + 16

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
            platformStart: CGPoint(x: towerX - 40, y: platformY),
            platformEnd: CGPoint(x: towerX + 70, y: platformY),
            blockCenters: centers
        )
    }
}
