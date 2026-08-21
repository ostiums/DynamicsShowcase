import Foundation

/// View model of the menu screen: the list of demos and the launch options.
struct MenuViewModel {
    let title = "UIKit Dynamics"
    let demos = DemoCatalog.all

    var demoCount: Int { demos.count }

    func demo(at index: Int) -> DemoDescriptor {
        demos[index]
    }

    /// Index of the demo to open immediately, taken from the AUTO_OPEN_DEMO
    /// environment variable (handy for screen recording and UI tests).
    var autoOpenIndex: Int? {
        guard let value = ProcessInfo.processInfo.environment["AUTO_OPEN_DEMO"],
              let index = Int(value), demos.indices.contains(index) else { return nil }
        return index
    }
}
