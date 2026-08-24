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

        let centers = viewModel.initialTileCenters(in: view.bounds)

        for (index, tile) in viewModel.tiles.enumerated() {
            let box = BoxView(size: viewModel.tileSize, color: tile.color, letter: tile.letter)
            box.center = centers[index]
            contentView.addSubview(box)
            tiles.append(box)
        }
    }

    // MARK: - Gestures

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        Haptics.action()

        // Remove the previous snaps — an item can have only one active snap.
        snaps.forEach { animator.removeBehavior($0) }
        snaps.removeAll()

        let targets = viewModel.snapTargets(
            around: tap.location(in: contentView),
            in: view.bounds
        )
        let damping = viewModel.dampingOptions[dampingControl.selectedSegmentIndex].value

        for (tile, target) in zip(tiles, targets) {
            let snap = UISnapBehavior(item: tile, snapTo: target)
            snap.damping = damping
            animator.addBehavior(snap)
            snaps.append(snap)
        }
    }
}

// MARK: - The gist
//
// The physics core of this screen, stripped of layout and styling.
/*

// An item can have only one active snap,
// so each tap starts by removing the previous ones.
snaps.forEach { animator.removeBehavior($0) }

// A snap pulls an item to a point with a damped spring.
for (tile, target) in zip(tiles, targetsAroundFinger) {
    let snap = UISnapBehavior(item: tile, snapTo: target)
    snap.damping = 0.5  // 0 — maximum wobble … 1 — dead stop
    animator.addBehavior(snap)
}
*/
