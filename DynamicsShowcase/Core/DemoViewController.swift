import UIKit

/// Base class for every demo: gradient background, a contentView hosting the physics
/// items, a UIDynamicAnimator and a reset button.
class DemoViewController: UIViewController {

    /// Layer that hosts the dynamic items. Also the animator's reference view.
    let contentView = UIView()

    lazy var animator = UIDynamicAnimator(referenceView: contentView)

    private var didBuildScene = false
    private var pendingWork: [DispatchWorkItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        let background = GradientBackgroundView(frame: view.bounds)
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(background)

        contentView.frame = view.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(contentView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.counterclockwise"),
            style: .plain,
            target: self,
            action: #selector(resetTapped)
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Build the scene once the real screen size is known.
        if !didBuildScene, view.bounds.width > 0 {
            didBuildScene = true
            buildScene()
        }
    }

    @objc private func resetTapped() {
        Haptics.action()
        resetScene()
    }

    /// Tears the scene down and builds it again. Bound to the reset button;
    /// demos that rebuild on their own (a mode switch, a replay tap) call it too.
    func resetScene() {
        cancelPendingWork()
        animator.removeAllBehaviors()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        buildScene()
    }

    /// Cancellable delayed work for scene events (spawn rains, celebrations,
    /// debris sweeps). Every pending item is cancelled by the next reset,
    /// so a stale closure never fires into a rebuilt scene.
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        let item = DispatchWorkItem(block: work)
        pendingWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelPendingWork() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
    }

    /// Demo entry point. Called after layout and on every reset.
    /// Behaviors must be created fresh here: reused behavior instances would still
    /// reference items removed by a previous reset.
    func buildScene() { }

    /// The reaction every UICollisionBehaviorDelegate in this project shares:
    /// a glow pulse on each ball involved plus a haptic tick. Only the tick
    /// intensity differs from demo to demo.
    func reactToContact(_ items: UIDynamicItem..., intensity: CGFloat) {
        for item in items {
            (item as? BallView)?.flash()
        }
        Haptics.collision(intensity: intensity)
    }
}
