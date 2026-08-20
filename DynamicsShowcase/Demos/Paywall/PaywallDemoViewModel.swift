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
    let congratulations = "Congratulations"

    // The collapse: how the paywall elements behave once they become
    // dynamic items. There is no collision behavior on purpose — the
    // elements fall straight through the bottom edge and off the screen.
    /// Random spin handed to every falling element, rad/s.
    let spinRange: ClosedRange<CGFloat> = -6...6
    /// Sideways scatter so the elements tumble apart as they fall.
    let kickRangeX: ClosedRange<CGFloat> = -160...160
    /// A small upward pop before the fall — the layout bursts apart.
    let kickRangeY: ClosedRange<CGFloat> = -220...(-60)
    /// By this time everything has left the screen and the simulation
    /// of the fallen elements can be torn down.
    let cleanupDelay: TimeInterval = 4

    /// Pause between the collapse and the celebration.
    let celebrationDelay: TimeInterval = 1.1
    /// Damping of the snap that drops the congratulations in.
    let congratulationsSnapDamping: CGFloat = 0.65
    /// How long the confetti cannon fires.
    let confettiDuration: TimeInterval = 2.5
}
