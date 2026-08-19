import UIKit

extension CGFloat {
    /// The value pulled back into `range`. Used to cap offsets and target points.
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Collection where Element: UIView {
    /// The view whose center is closest to `point`, or nil when the closest one
    /// is farther away than `maxDistance`. Every demo that grabs, drags or flicks
    /// an item picks its target this way.
    func nearest(to point: CGPoint,
                 within maxDistance: CGFloat = .greatestFiniteMagnitude) -> Element? {
        func distance(to view: Element) -> CGFloat {
            hypot(view.center.x - point.x, view.center.y - point.y)
        }
        guard let closest = self.min(by: { distance(to: $0) < distance(to: $1) }),
              distance(to: closest) < maxDistance
        else { return nil }
        return closest
    }
}
