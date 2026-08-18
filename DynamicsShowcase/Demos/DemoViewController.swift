import UIKit

/// Base class for every demo: gradient background, a contentView hosting the physics
/// items, a UIDynamicAnimator, a bottom hint and a reset button.
class DemoViewController: UIViewController {

    /// Layer that hosts the dynamic items. Also the animator's reference view.
    let contentView = UIView()

    lazy var animator = UIDynamicAnimator(referenceView: contentView)

    let hintLabel = HintLabel()

    private var didBuildScene = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let background = GradientBackgroundView(frame: view.bounds)
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(background)

        contentView.frame = view.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(contentView)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        hintLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        view.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.counterclockwise"),
            style: .plain,
            target: self,
            action: #selector(resetTapped)
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Without preferredMaxLayoutWidth a multiline hint can collapse to a dot.
        hintLabel.preferredMaxLayoutWidth = view.bounds.width - 96
        // Build the scene once the real screen size is known.
        if !didBuildScene, view.bounds.width > 0 {
            didBuildScene = true
            buildScene()
        }
    }

    @objc private func resetTapped() {
        Haptics.action()
        animator.removeAllBehaviors()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        buildScene()
    }

    func showHint(_ text: String) {
        hintLabel.text = text
        view.setNeedsLayout()
    }

    /// Demo entry point. Called after layout and on every reset.
    /// Behaviors must be created fresh here: reused behavior instances would still
    /// reference items removed by a previous reset.
    func buildScene() { }
}
