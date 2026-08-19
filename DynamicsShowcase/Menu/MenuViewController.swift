import UIKit

/// The root screen: a card per demo, driven by MenuViewModel.
final class MenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel = MenuViewModel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var didAutoOpen = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title

        let background = GradientBackgroundView(frame: view.bounds)
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(background)

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DemoCardCell.self, forCellReuseIdentifier: DemoCardCell.reuseIdentifier)
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)

        let header = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        header.text = viewModel.headerText
        header.numberOfLines = 2
        header.textAlignment = .center
        header.font = UIFont.systemFont(ofSize: 14, weight: .medium).rounded()
        header.textColor = UIColor.white.withAlphaComponent(0.55)
        tableView.tableHeaderView = header

        view.addSubview(tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didAutoOpen, let index = viewModel.autoOpenIndex {
            didAutoOpen = true
            open(viewModel.demo(at: index))
        }
    }

    private func open(_ demo: DemoDescriptor) {
        let controller = demo.makeViewController()
        controller.title = demo.title
        navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.demoCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: DemoCardCell.reuseIdentifier,
            for: indexPath
        ) as! DemoCardCell
        cell.configure(with: viewModel.demo(at: indexPath.row))
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        open(viewModel.demo(at: indexPath.row))
    }
}
