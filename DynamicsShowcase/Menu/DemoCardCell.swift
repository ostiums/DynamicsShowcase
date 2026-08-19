import UIKit

/// A menu card: emoji bubble, title, API subtitle and a chevron.
final class DemoCardCell: UITableViewCell {

    static let reuseIdentifier = "DemoCardCell"

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

    func configure(with demo: DemoDescriptor) {
        emojiBubble.text = demo.emoji
        emojiBubble.backgroundColor = demo.accentColor.withAlphaComponent(0.16)
        titleLabel.text = demo.title
        subtitleLabel.text = demo.apiSummary
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
