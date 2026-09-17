import UIKit

/// The rope as it is drawn: a chain of points between two pinned ends,
/// integrated with Verlet and held together by distance constraints.
///
/// Purely visual — the force on the ball comes from `RopeBehavior`. Slack,
/// the chain sags, lags behind the ball and whips; taut, the constraints
/// pull it into a straight line, and stretched past its length the links
/// simply share the extra distance.
struct VerletRope {

    private(set) var points: [CGPoint]
    private var previous: [CGPoint]
    private let linkLength: CGFloat

    /// Acceleration of the rope's own weight, pt/s².
    var gravity: CGFloat
    /// Share of a point's velocity lost per step; keeps the whip from ringing on.
    var drag: CGFloat = 0.02
    var iterations = 24

    init(from start: CGPoint, to end: CGPoint, length: CGFloat, links: Int, gravity: CGFloat) {
        points = (0...links).map { index in
            let t = CGFloat(index) / CGFloat(links)
            return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        }
        previous = points
        linkLength = length / CGFloat(links)
        self.gravity = gravity
    }

    /// Advances the chain by `dt` with its ends pinned to `start` and `end`.
    mutating func step(from start: CGPoint, to end: CGPoint, dt: CGFloat) {
        let last = points.count - 1
        let fall = gravity * dt * dt

        for index in 1..<last {
            let point = points[index]
            points[index] = CGPoint(
                x: point.x + (point.x - previous[index].x) * (1 - drag),
                y: point.y + (point.y - previous[index].y) * (1 - drag) + fall
            )
            previous[index] = point
        }

        points[0] = start
        points[last] = end
        for _ in 0..<iterations {
            for index in 0..<last {
                let a = points[index]
                let b = points[index + 1]
                let dx = b.x - a.x
                let dy = b.y - a.y
                let distance = max(hypot(dx, dy), 0.001)
                let correction = (distance - linkLength) / distance / 2
                // A pinned end doesn't move; its neighbour takes the whole correction.
                let aShare: CGFloat = index == 0 ? 0 : (index + 1 == last ? 2 : 1)
                let bShare: CGFloat = index + 1 == last ? 0 : (index == 0 ? 2 : 1)
                points[index] = CGPoint(
                    x: a.x + dx * correction * aShare,
                    y: a.y + dy * correction * aShare
                )
                points[index + 1] = CGPoint(
                    x: b.x - dx * correction * bShare,
                    y: b.y - dy * correction * bShare
                )
            }
        }
    }

    /// A smooth curve through the points: quadratic segments between the
    /// midpoints of neighbouring links.
    var path: UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first, let end = points.last else { return path }
        path.move(to: first)
        for index in 1..<(points.count - 1) {
            let point = points[index]
            let next = points[index + 1]
            path.addQuadCurve(
                to: CGPoint(x: (point.x + next.x) / 2, y: (point.y + next.y) / 2),
                controlPoint: point
            )
        }
        path.addLine(to: end)
        return path
    }
}
