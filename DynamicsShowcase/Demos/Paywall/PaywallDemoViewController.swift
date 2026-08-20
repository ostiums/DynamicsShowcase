import UIKit

/// The trick shot of the showcase: a perfectly ordinary paywall screen
/// where every element is a plain UIView — until "Continue" hands them
/// all over to UIKit Dynamics. The whole interface tumbles off the
/// bottom of the screen, confetti rains from a CAEmitterLayer, and the
/// congratulations drops in on a UISnapBehavior.
final class PaywallDemoViewController: DemoViewController {

    private let viewModel = PaywallDemoViewModel()

    /// Everything that will fall, in the order it appears on screen.
    private var elements: [UIView] = []
    private var collapsed = false
    /// Kept as work items so a reset can cancel a celebration still pending.
    private var pendingWork: [DispatchWorkItem] = []

    override func buildScene() {
        elements.removeAll()
        collapsed = false
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()

        layoutPaywall()
    }

    // MARK: - Static paywall layout

    /// Lays the paywall out with plain frames — UIKit Dynamics moves items
    /// by center and transform, so the views must be frame-based.
    private func layoutPaywall() {
        let margin: CGFloat = 24
        let width = view.bounds.width - margin * 2
        var y = view.safeAreaInsets.top + 20

        let title = makeLabel(
            viewModel.title,
            font: UIFont.systemFont(ofSize: 26, weight: .bold).rounded(),
            color: .white
        )
        title.numberOfLines = 2
        title.textAlignment = .center
        title.frame = CGRect(x: margin, y: y, width: width, height: 68)
        addElement(title)
        y = title.frame.maxY + 24

        y = layoutTimeline(startY: y, margin: margin, width: width) + 16
        y = layoutPlanCards(startY: y, margin: margin, width: width) + 14

        // Fitted to its text: a tight frame tumbles much better than a
        // screen-wide slab of empty label.
        let note = makeLabel(
            viewModel.note,
            font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            color: .white
        )
        note.sizeToFit()
        note.center = CGPoint(x: view.bounds.midX, y: y + 10)
        addElement(note)
        y = note.frame.maxY + 14

        let button = UIButton(type: .system)
        button.setTitle(viewModel.buttonTitle, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold).rounded()
        button.backgroundColor = .white
        button.layer.cornerRadius = 16
        button.layer.cornerCurve = .continuous
        button.frame = CGRect(x: margin, y: y, width: width, height: 56)
        button.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        addElement(button)
        y = button.frame.maxY + 12

        let footnote = makeLabel(
            viewModel.footnote,
            font: UIFont.systemFont(ofSize: 12, weight: .regular),
            color: UIColor.white.withAlphaComponent(0.5)
        )
        footnote.sizeToFit()
        footnote.center = CGPoint(x: view.bounds.midX, y: y + 8)
        addElement(footnote)
    }

    /// Three timeline entries plus the vertical line connecting their icons.
    /// Icon and text block are separate elements on purpose: many small
    /// pieces burst apart far livelier than full-width row containers.
    /// Returns the bottom edge of the timeline.
    private func layoutTimeline(startY: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        let rowHeight: CGFloat = 74
        let rowSpacing: CGFloat = 10
        let step = rowHeight + rowSpacing

        let line = UIView(frame: CGRect(
            x: margin + 16,
            y: startY + 18,
            width: 4,
            height: step * CGFloat(viewModel.steps.count - 1)
        ))
        line.backgroundColor = Palette.amber.withAlphaComponent(0.3)
        line.layer.cornerRadius = 2
        addElement(line)

        for (index, timelineStep) in viewModel.steps.enumerated() {
            let rowY = startY + CGFloat(index) * step

            let icon = UIImageView(image: UIImage(systemName: timelineStep.iconName))
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            icon.tintColor = .black
            icon.contentMode = .center
            icon.backgroundColor = timelineStep.iconBackground
            icon.frame = CGRect(x: margin, y: rowY, width: 36, height: 36)
            icon.layer.cornerRadius = 18
            addElement(icon)

            addElement(makeTimelineText(
                timelineStep,
                frame: CGRect(
                    x: margin + 52,
                    y: rowY,
                    width: width - 52,
                    height: rowHeight
                )
            ))
        }
        return startY + step * CGFloat(viewModel.steps.count) - rowSpacing
    }

    /// The two plan cards side by side. Returns their bottom edge.
    private func layoutPlanCards(startY: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        let cardWidth = (width - 12) / 2
        let cardHeight: CGFloat = 82
        for (index, plan) in viewModel.plans.enumerated() {
            let card = makePlanCard(
                plan,
                frame: CGRect(
                    x: margin + CGFloat(index) * (cardWidth + 12),
                    y: startY,
                    width: cardWidth,
                    height: cardHeight
                )
            )
            addElement(card)
        }
        return startY + cardHeight
    }

    private func makeTimelineText(
        _ timelineStep: PaywallDemoViewModel.TimelineStep,
        frame: CGRect
    ) -> UIView {
        let block = UIView(frame: frame)

        let title = makeLabel(
            timelineStep.title,
            font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            color: .white
        )
        title.frame = CGRect(x: 0, y: 0, width: frame.width, height: 22)
        block.addSubview(title)

        let subtitle = makeLabel(
            timelineStep.subtitle,
            font: UIFont.systemFont(ofSize: 13, weight: .regular),
            color: UIColor.white.withAlphaComponent(0.55)
        )
        subtitle.numberOfLines = 2
        subtitle.frame = CGRect(x: 0, y: 26, width: frame.width, height: 36)
        block.addSubview(subtitle)

        return block
    }

    private func makePlanCard(_ plan: PaywallDemoViewModel.Plan, frame: CGRect) -> UIView {
        let card = UIView(frame: frame)

        // The card body leaves headroom for the badge overlapping its top edge.
        let bodyTop: CGFloat = 10
        let body = UIView(frame: CGRect(
            x: 0,
            y: bodyTop,
            width: frame.width,
            height: frame.height - bodyTop
        ))
        body.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        body.layer.cornerRadius = 14
        body.layer.cornerCurve = .continuous
        body.layer.borderWidth = plan.isSelected ? 2 : 1
        body.layer.borderColor = plan.isSelected
            ? UIColor.white.cgColor
            : UIColor.white.withAlphaComponent(0.3).cgColor
        card.addSubview(body)

        let title = makeLabel(
            plan.title,
            font: UIFont.systemFont(ofSize: 16, weight: .semibold).rounded(),
            color: .white
        )
        title.frame = CGRect(x: 14, y: bodyTop + 14, width: frame.width - 58, height: 20)
        card.addSubview(title)

        let price = makeLabel(
            plan.price,
            font: UIFont.systemFont(ofSize: 14, weight: .regular),
            color: UIColor.white.withAlphaComponent(0.7)
        )
        price.frame = CGRect(x: 14, y: bodyTop + 38, width: frame.width - 58, height: 18)
        card.addSubview(price)

        let marker = UIImageView(frame: CGRect(
            x: frame.width - 40,
            y: bodyTop + 24,
            width: 26,
            height: 26
        ))
        if plan.isSelected {
            marker.image = UIImage(systemName: "checkmark.circle.fill")
            marker.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
            marker.tintColor = .white
        } else {
            marker.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            marker.layer.borderWidth = 1.5
            marker.layer.cornerRadius = 13
        }
        card.addSubview(marker)

        if let badge = plan.badge {
            let label = makeLabel(
                badge,
                font: UIFont.systemFont(ofSize: 11, weight: .heavy).rounded(),
                color: .black
            )
            label.backgroundColor = Palette.amber
            label.textAlignment = .center
            label.frame = CGRect(x: (frame.width - 104) / 2, y: 0, width: 104, height: 20)
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            card.addSubview(label)
        }
        return card
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }

    private func addElement(_ element: UIView) {
        contentView.addSubview(element)
        elements.append(element)
    }

    // MARK: - The collapse

    /// The moment of the trick: the same views that made up the paywall
    /// become dynamic items. With no collision boundary in their way they
    /// tumble straight off the bottom of the screen.
    @objc private func continueTapped() {
        guard !collapsed else { return }
        collapsed = true
        Haptics.action()

        let gravity = UIGravityBehavior(items: elements)
        let bodies = UIDynamicItemBehavior(items: elements)
        animator.addBehavior(gravity)
        animator.addBehavior(bodies)

        // Scatter: a small upward pop with sideways drift and spin, so the
        // layout bursts apart as it falls out of view.
        for element in elements {
            bodies.addAngularVelocity(.random(in: viewModel.spinRange), for: element)
            bodies.addLinearVelocity(
                CGPoint(
                    x: .random(in: viewModel.kickRangeX),
                    y: .random(in: viewModel.kickRangeY)
                ),
                for: element
            )
        }

        schedule(after: viewModel.celebrationDelay) { $0.celebrate() }

        // Once everything has left the screen, stop simulating it.
        schedule(after: viewModel.cleanupDelay) {
            $0.animator.removeBehavior(gravity)
            $0.animator.removeBehavior(bodies)
            $0.elements.forEach { $0.removeFromSuperview() }
            $0.elements.removeAll()
        }
    }

    // MARK: - Celebration

    private func celebrate() {
        startConfetti()
        Haptics.action()

        let label = makeLabel(
            viewModel.congratulations,
            font: UIFont.systemFont(ofSize: 34, weight: .heavy).rounded(),
            color: .white
        )
        label.sizeToFit()
        label.layer.shadowColor = Palette.amber.cgColor
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 12
        label.layer.shadowOffset = .zero
        label.center = CGPoint(x: view.bounds.midX, y: -60)
        contentView.addSubview(label)

        // The greeting starts above the screen and drops onto a damped
        // spring — no gravity on it, the snap alone does the work.
        let snap = UISnapBehavior(
            item: label,
            snapTo: CGPoint(x: view.bounds.midX, y: view.bounds.midY - 140)
        )
        snap.damping = viewModel.congratulationsSnapDamping
        animator.addBehavior(snap)
    }

    private func startConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        emitter.emitterShape = .line
        emitter.emitterCells = Palette.neon.map { makeConfettiCell(color: $0) }
        contentView.layer.addSublayer(emitter)

        schedule(after: viewModel.confettiDuration) { _ in
            // Stop the cannon; pieces already in the air finish their fall.
            emitter.birthRate = 0
        }
    }

    private func makeConfettiCell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = makeConfettiImage(color: color).cgImage
        cell.birthRate = 7
        cell.lifetime = 8
        cell.velocity = 140
        cell.velocityRange = 60
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 5
        cell.yAcceleration = 160
        cell.spin = 3
        cell.spinRange = 4
        cell.scale = 0.7
        cell.scaleRange = 0.3
        return cell
    }

    private func makeConfettiImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 12)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping (PaywallDemoViewController) -> Void) {
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            work(self)
        }
        pendingWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

// MARK: - Screenshot snippet
//
// The physics core of this screen, stripped of layout and styling.
// This block goes on the code screenshot shown next to the recording.
/*

// Any UIView already is a UIDynamicItem — even a live paywall.
// One tap hands the whole layout over to the physics engine,
// and gravity carries it right off the screen.
let gravity = UIGravityBehavior(items: paywallElements)
let bodies = UIDynamicItemBehavior(items: paywallElements)
animator.addBehavior(gravity)
animator.addBehavior(bodies)

// A pop of spin and scatter, so the layout bursts apart as it falls.
for element in paywallElements {
    bodies.addAngularVelocity(.random(in: -6...6), for: element)
    bodies.addLinearVelocity(scatterKick(), for: element)
}

// The greeting drops in on a damped spring while confetti falls.
let snap = UISnapBehavior(item: congratulations, snapTo: center)
snap.damping = 0.65
animator.addBehavior(snap)
*/
