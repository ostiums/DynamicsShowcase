import UIKit

/// Model of one demo screen: everything the menu needs to render a card,
/// plus a factory that creates the screen itself.
struct DemoDescriptor {
    let emoji: String
    let accentColor: UIColor
    let title: String
    /// The UIKit Dynamics API the screen demonstrates; shown as the card subtitle.
    let apiSummary: String
    let makeViewController: () -> UIViewController
}

/// The single source of truth for the list of demos.
enum DemoCatalog {
    static let all: [DemoDescriptor] = [
        DemoDescriptor(
            emoji: "🌍",
            accentColor: Palette.cyan,
            title: "Gravity",
            apiSummary: "UIGravityBehavior · UICollisionBehavior",
            makeViewController: { GravityDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "🧲",
            accentColor: Palette.magenta,
            title: "Snap",
            apiSummary: "UISnapBehavior",
            makeViewController: { SnapDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "⛓️",
            accentColor: Palette.violet,
            title: "Wrecking Ball",
            apiSummary: "UIAttachmentBehavior",
            makeViewController: { WreckingBallDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "🚀",
            accentColor: Palette.mint,
            title: "Push Impulses",
            apiSummary: "UIPushBehavior",
            makeViewController: { PushDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "🌀",
            accentColor: Palette.amber,
            title: "Force Fields",
            apiSummary: "UIFieldBehavior — 10 field types",
            makeViewController: { FieldsDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "🪐",
            accentColor: Palette.violet,
            title: "Solar System",
            apiSummary: ".radialGravityField(falloff: 2)",
            makeViewController: { SolarSystemDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "⚖️",
            accentColor: Palette.coral,
            title: "Body Properties",
            apiSummary: "UIDynamicItemBehavior",
            makeViewController: { PropertiesDemoViewController() }
        ),
        DemoDescriptor(
            emoji: "🎪",
            accentColor: Palette.cyan,
            title: "Playground",
            apiSummary: "Everything + UIDynamicItemGroup",
            makeViewController: { PlaygroundDemoViewController() }
        ),
    ]
}
