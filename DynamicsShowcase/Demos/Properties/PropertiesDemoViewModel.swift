import UIKit

/// Configuration for the body-properties demo: two comparison scenes
/// driven by the same UIDynamicItemBehavior API.
struct PropertiesDemoViewModel {

    enum Mode: Int, CaseIterable {
        case elasticity
        case density

        var title: String {
            switch self {
            case .elasticity: return "Elasticity"
            case .density: return "Density"
            }
        }

        var hint: String {
            switch self {
            case .elasticity:
                return "elasticity 0.1 → 0.95 — same balls, different bounciness.  Tap to replay"
            case .density:
                return "density 0.3 → 2.4 — same impulse, different mass.  Tap to replay"
            }
        }
    }

    var mode: Mode = .elasticity

    var hint: String { mode.hint }

    let ballDiameter: CGFloat = 52

    /// One comparison lane: the property value under test and the color
    /// that marks its ball and its caption.
    struct Lane {
        let value: CGFloat
        let color: UIColor
    }

    // Elasticity scene: four identical balls dropped at once.
    let elasticityLanes: [Lane] = [
        Lane(value: 0.1, color: Palette.coral),
        Lane(value: 0.4, color: Palette.amber),
        Lane(value: 0.7, color: Palette.mint),
        Lane(value: 0.95, color: Palette.cyan),
    ]
    /// Height of the visible floor above the bottom edge.
    let floorInset: CGFloat = 180

    // Density scene: four lanes, one identical impulse each.
    let densityLanes: [Lane] = [
        Lane(value: 0.3, color: Palette.cyan),
        Lane(value: 0.8, color: Palette.mint),
        Lane(value: 1.5, color: Palette.amber),
        Lane(value: 2.4, color: Palette.coral),
    ]
    let densityResistance: CGFloat = 1.6
    let densityElasticity: CGFloat = 0.4
    /// The impulse shared by every ball in the density scene.
    let sharedImpulse = CGVector(dx: 1.6, dy: 0)
    let laneHeight: CGFloat = 110
}
