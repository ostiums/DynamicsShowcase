import UIKit

/// UISnapBehavior: tiles "snap" to the touch point with a spring animation.
/// Damping controls how much the snap oscillates.
final class SnapDemoViewController: DemoViewController {

    private var tiles: [BoxView] = []
    private var snaps: [UISnapBehavior] = []

    private let dampingControl = UISegmentedControl(items: ["Bouncy 0.2", "Medium 0.5", "Stiff 0.9"])
    private var damping: CGFloat {
        [0.2, 0.5, 0.9][dampingControl.selectedSegmentIndex]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        showHint("Tap anywhere — the tiles fly there.  UISnapBehavior(damping:)")

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

        let letters = ["S", "N", "A", "P"]
        let colors = [Palette.magenta, Palette.cyan, Palette.amber, Palette.mint]
        let size: CGFloat = 66
        let spacing: CGFloat = 14
        let totalWidth = CGFloat(letters.count) * size + CGFloat(letters.count - 1) * spacing
        let startX = (view.bounds.width - totalWidth) / 2 + size / 2

        for (i, letter) in letters.enumerated() {
            let tile = BoxView(size: size, color: colors[i], letter: letter)
            tile.center = CGPoint(x: startX + CGFloat(i) * (size + spacing),
                                  y: view.bounds.midY)
            contentView.addSubview(tile)
            tiles.append(tile)
        }
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: contentView)
        Haptics.action()

        // Remove previous snaps — an item can have only one active snap.
        snaps.forEach { animator.removeBehavior($0) }
        snaps.removeAll()

        // Tiles spread on a circle around the finger; every tap picks a new rotation.
        let radius: CGFloat = 74
        let baseAngle = CGFloat.random(in: 0 ..< .pi * 2)
        for (i, tile) in tiles.enumerated() {
            let angle = baseAngle + CGFloat(i) * (.pi * 2 / CGFloat(tiles.count))
            let target = CGPoint(x: point.x + cos(angle) * radius,
                                 y: point.y + sin(angle) * radius)
            let snap = UISnapBehavior(item: tile, snapTo: clampToBounds(target))
            snap.damping = damping
            animator.addBehavior(snap)
            snaps.append(snap)
        }
    }

    private func clampToBounds(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 50), view.bounds.width - 50),
                y: min(max(p.y, 140), view.bounds.height - 120))
    }
}
