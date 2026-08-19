import UIKit

/// Demonstrates UISnapBehavior.
///
/// A snap pulls an item to a point with a damped spring; `damping` controls
/// how much it wobbles on arrival. An item can have only one active snap,
/// so each tap replaces the previous set of snaps.
final class SnapDemoViewController: DemoViewController {

    private let viewModel = SnapDemoViewModel()

    private var tiles: [BoxView] = []
    private var snaps: [UISnapBehavior] = []

    private let dampingControl = UISegmentedControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint(viewModel.hint)

        for (index, option) in viewModel.dampingOptions.enumerated() {
            dampingControl.insertSegment(withTitle: option.title, at: index, animated: false)
        }
        dampingControl.selectedSegmentIndex = 0
        dampingControl.selectedSegmentTintColor = Palette.magenta.withAlphaComponent(0.6)
        dampingControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        dampingControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dampingControl)
        NSLayoutConstraint.activate([
            dampingControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dampingControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    override func buildScene() {
        tiles.removeAll()
        snaps.removeAll()

        let colors = [Palette.magenta, Palette.cyan, Palette.amber, Palette.mint]
        let centers = viewModel.initialTileCenters(in: view.bounds)

        for (index, letter) in viewModel.tileLetters.enumerated() {
            let tile = BoxView(size: viewModel.tileSize, color: colors[index], letter: letter)
            tile.center = centers[index]
            contentView.addSubview(tile)
            tiles.append(tile)
        }
    }

    // MARK: - Gestures

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        Haptics.action()

        // Remove the previous snaps — an item can have only one active snap.
        snaps.forEach { animator.removeBehavior($0) }
        snaps.removeAll()

        let targets = viewModel.snapTargets(around: tap.location(in: contentView),
                                            in: view.bounds)
        let damping = viewModel.dampingOptions[dampingControl.selectedSegmentIndex].value

        for (tile, target) in zip(tiles, targets) {
            let snap = UISnapBehavior(item: tile, snapTo: target)
            snap.damping = damping
            animator.addBehavior(snap)
            snaps.append(snap)
        }
    }
}
