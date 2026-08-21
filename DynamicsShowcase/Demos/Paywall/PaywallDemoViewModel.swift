import UIKit

/// Content and physics tuning for the paywall-collapse demo.
struct PaywallDemoViewModel {

    struct TimelineStep {
        let iconName: String
        let iconBackground: UIColor
        let title: String
        let subtitle: String
    }

    struct Plan {
        let title: String
        let price: String
        let badge: String?
        let isSelected: Bool
    }

    let title = "Start your 3-day FREE\ntrial to continue."

    // All texts (dates included) are static recording props — the paywall
    // is a fake built for the physics demo, nothing here is computed.

    let steps: [TimelineStep] = [
        TimelineStep(
            iconName: "lock.open.fill",
            iconBackground: Palette.amber,
            title: "Today",
            subtitle: "Unlock all the app's features like AI calorie scanning and more."
        ),
        TimelineStep(
            iconName: "bell.fill",
            iconBackground: Palette.amber,
            title: "In 2 Days – Reminder",
            subtitle: "We'll send you a reminder that your trial is ending soon."
        ),
        TimelineStep(
            iconName: "crown.fill",
            iconBackground: Palette.violet,
            title: "In 3 Days – Billing Starts",
            subtitle: "You'll be charged on Aug 23, 2026 unless you cancel anytime before."
        ),
    ]

    let plans: [Plan] = [
        Plan(title: "Monthly", price: "$9.99 /mo", badge: nil, isSelected: false),
        Plan(title: "Yearly", price: "$2.49 /mo", badge: "3 DAYS FREE", isSelected: true),
    ]

    let note = "✓ No Payment Due Now"
    let buttonTitle = "Start My 3-Day Free Trial"
    let footnote = "3 days free, then $29.99 per year ($2.49/mo)"
    let greeting = "You're all set"

    // Stacking metrics of the static layout; the drawing details (inner
    // paddings, fonts) stay with the view code.
    let contentMargin: CGFloat = 24
    let titleHeight: CGFloat = 68
    let timelineRowHeight: CGFloat = 74
    let timelineRowSpacing: CGFloat = 10
    let planCardHeight: CGFloat = 82
    let ctaButtonHeight: CGFloat = 56

    // The collapse: how the paywall elements behave once they become
    // dynamic items. There is no collision behavior on purpose — the
    // elements fall straight through the bottom edge and off the screen.
    /// Sideways scatter so the elements drift apart as they fall.
    let kickRangeX: ClosedRange<CGFloat> = -160...160
    /// A small upward pop before the fall — the layout bursts apart.
    let kickRangeY: ClosedRange<CGFloat> = -220...(-60)
    /// By this time everything has left the screen and the simulation
    /// of the fallen elements can be torn down.
    let cleanupDelay: TimeInterval = 4

    /// Pause between the collapse and the celebration.
    let celebrationDelay: TimeInterval = 1.1
    /// Damping of the snap that drops the greeting in. Near 1 the arrival
    /// is critically damped — a smooth settle with no jitter.
    let greetingSnapDamping: CGFloat = 0.85
    /// Resistance on the greeting: a snap has no speed setting, so this
    /// is what makes the flight a slow drift instead of a slam.
    let greetingResistance: CGFloat = 3
    /// The greeting fades in while it drifts, instead of popping into view.
    let greetingFadeInDuration: TimeInterval = 0.4
    /// How long the confetti cannon fires.
    let confettiDuration: TimeInterval = 2.5
}
