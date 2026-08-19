import CoreGraphics

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

    // Elasticity scene: four identical balls dropped at once.
    let elasticityValues: [CGFloat] = [0.1, 0.4, 0.7, 0.95]
    /// Height of the visible floor above the bottom edge.
    let floorInset: CGFloat = 180

    // Density scene: four lanes, one identical impulse each.
    let densityValues: [CGFloat] = [0.3, 0.8, 1.5, 2.4]
    let densityResistance: CGFloat = 1.6
    let densityElasticity: CGFloat = 0.4
    /// The impulse shared by every ball in the density scene.
    let sharedImpulse = CGVector(dx: 1.6, dy: 0)
    let laneHeight: CGFloat = 110
}
