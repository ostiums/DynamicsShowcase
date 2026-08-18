import UIKit

final class MenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private struct Item {
        let emoji: String
        let color: UIColor
        let title: String
        let subtitle: String
        let make: () -> UIViewController
    }

    private let items: [Item] = [
        Item(emoji: "🌍", color: Palette.cyan,
             title: "Gravity",
             subtitle: "UIGravityBehavior · UICollisionBehavior",
             make: { GravityDemoViewController() }),
        Item(emoji: "🧲", color: Palette.magenta,
             title: "Snap",
             subtitle: "UISnapBehavior",
             make: { SnapDemoViewController() }),
        Item(emoji: "⛓️", color: Palette.violet,
             title: "Wrecking Ball",
             subtitle: "UIAttachmentBehavior",
             make: { AttachmentDemoViewController() }),
        Item(emoji: "🚀", color: Palette.mint,
             title: "Push Impulses",
             subtitle: "UIPushBehavior",
             make: { PushDemoViewController() }),
        Item(emoji: "🌀", color: Palette.amber,
             title: "Force Fields",
             subtitle: "UIFieldBehavior — 10 field types",
             make: { FieldsDemoViewController() }),
        Item(emoji: "⚖️", color: Palette.coral,
             title: "Body Properties",
             subtitle: "UIDynamicItemBehavior",
             make: { PropertiesDemoViewController() }),
        Item(emoji: "🎪", color: Palette.cyan,
             title: "Playground",
             subtitle: "Everything + UIDynamicItemGroup",
             make: { PlaygroundDemoViewController() }),
    ]

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Dynamics"

        let background = GradientBackgroundView(frame: view.bounds)
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(background)

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CardCell.self, forCellReuseIdentifier: "card")
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)

        let header = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        header.text = "A physics engine built right into UIKit.\nReal physics — no SpriteKit needed."
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

    private var didAutoOpen = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // AUTO_OPEN_DEMO=<0...6> jumps straight to a demo (handy for recording and tests).
        if !didAutoOpen,
           let value = ProcessInfo.processInfo.environment["AUTO_OPEN_DEMO"],
           let index = Int(value), items.indices.contains(index) {
            didAutoOpen = true
            tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "card", for: indexPath) as! CardCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        let vc = item.make()
        vc.title = item.title
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Cell

    private final class CardCell: UITableViewCell {
        private let card = UIView()
        private let emojiBubble = UILabel()
        private let titleLabel = UILabel()
        private let subtitleLabel = UILabel()
        private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            backgroundColor = .clear
            selectionStyle = .none

            card.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            card.layer.cornerRadius = 20
            card.layer.cornerCurve = .continuous
            card.layer.borderWidth = 1
            card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)

            emojiBubble.font = .systemFont(ofSize: 30)
            emojiBubble.textAlignment = .center
            emojiBubble.layer.cornerRadius = 28
            emojiBubble.layer.cornerCurve = .continuous
            emojiBubble.layer.masksToBounds = true
            emojiBubble.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(emojiBubble)

            titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold).rounded()
            titleLabel.textColor = .white
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(titleLabel)

            subtitleLabel.font = UIFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
            subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.5)
            subtitleLabel.adjustsFontSizeToFitWidth = true
            subtitleLabel.minimumScaleFactor = 0.8
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(subtitleLabel)

            chevron.tintColor = UIColor.white.withAlphaComponent(0.3)
            chevron.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(chevron)

            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                card.heightAnchor.constraint(equalToConstant: 84),

                emojiBubble.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                emojiBubble.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                emojiBubble.widthAnchor.constraint(equalToConstant: 56),
                emojiBubble.heightAnchor.constraint(equalToConstant: 56),

                titleLabel.leadingAnchor.constraint(equalTo: emojiBubble.trailingAnchor, constant: 14),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
                titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),

                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
                subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

                chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func configure(with item: Item) {
            emojiBubble.text = item.emoji
            emojiBubble.backgroundColor = item.color.withAlphaComponent(0.16)
            titleLabel.text = item.title
            subtitleLabel.text = item.subtitle
        }

        override func setHighlighted(_ highlighted: Bool, animated: Bool) {
            super.setHighlighted(highlighted, animated: animated)
            UIView.animate(withDuration: 0.18) {
                self.card.transform = highlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
            }
        }
    }
}
