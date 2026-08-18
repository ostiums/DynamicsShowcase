import UIKit

/// База всех демо: градиентный фон, contentView для физических объектов,
/// UIDynamicAnimator, подсказка внизу и кнопка перезапуска.
class DemoViewController: UIViewController {

    /// Слой, в котором живут физические объекты. Он же — referenceView аниматора.
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
        // Без preferredMaxLayoutWidth многострочная подсказка может сжаться в точку.
        hintLabel.preferredMaxLayoutWidth = view.bounds.width - 96
        // Сцену строим, когда известны реальные размеры экрана.
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

    /// Точка входа демо. Вызывается после layout и при каждом сбросе.
    func buildScene() { }
}
