import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.tintColor = Palette.tint

        let nav = UINavigationController(rootViewController: MenuViewController())
        nav.navigationBar.prefersLargeTitles = true

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .heavy).rounded()
        ]
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance

        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()
    }
}
