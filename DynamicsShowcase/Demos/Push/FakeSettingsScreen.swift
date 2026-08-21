import UIKit

/// Builds the fake settings screen for the "Real UI" mode of the push
/// demo: a vertical stack of ordinary UIKit views — labels, cards, a
/// working UISwitch, buttons of every kind. Pure view construction;
/// the controller turns the result into dynamic items.
enum FakeSettingsScreen {

    /// The stacked elements, positioned with plain frames — UIKit Dynamics
    /// moves items by center and transform, so the views are frame-based.
    static func makeElements(
        content: PushDemoViewModel,
        in bounds: CGRect,
        topY: CGFloat
    ) -> [UIView] {
        let margin: CGFloat = 24
        let width = bounds.width - margin * 2
        var elements: [UIView] = []
        var y = topY

        let title = makeLabel(
            content.uiScreenTitle,
            font: UIFont.systemFont(ofSize: 32, weight: .bold).rounded(),
            color: .white
        )
        title.sizeToFit()
        title.frame.origin = CGPoint(x: margin, y: y)
        elements.append(title)
        y = title.frame.maxY + 16

        let profile = makeProfileCard(
            content: content,
            frame: CGRect(x: margin, y: y, width: width, height: 76)
        )
        elements.append(profile)
        y = profile.frame.maxY + 12

        let toggleRow = makeToggleRow(
            content: content,
            frame: CGRect(x: margin, y: y, width: width, height: 52)
        )
        elements.append(toggleRow)
        y = toggleRow.frame.maxY + 12

        let linkRow = makeLinkRow(
            content: content,
            frame: CGRect(x: margin, y: y, width: width, height: 52)
        )
        elements.append(linkRow)
        y = linkRow.frame.maxY + 16

        let primary = makeButton(
            content.uiPrimaryTitle,
            titleColor: .black,
            background: Palette.amber
        )
        primary.frame = CGRect(x: margin, y: y, width: width, height: 52)
        elements.append(primary)
        y = primary.frame.maxY + 12

        let secondary = makeButton(
            content.uiSecondaryTitle,
            titleColor: .white,
            background: UIColor.white.withAlphaComponent(0.12)
        )
        secondary.frame = CGRect(x: margin, y: y, width: width, height: 48)
        elements.append(secondary)
        y = secondary.frame.maxY + 10

        let signOut = UIButton(type: .system)
        signOut.setTitle(content.uiDestructiveTitle, for: .normal)
        signOut.setTitleColor(Palette.coral, for: .normal)
        signOut.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold).rounded()
        signOut.sizeToFit()
        signOut.center = CGPoint(x: bounds.midX, y: y + signOut.bounds.height / 2)
        elements.append(signOut)

        return elements
    }

    // MARK: - Building blocks

    private static func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }

    private static func makeButton(
        _ title: String,
        titleColor: UIColor,
        background: UIColor
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold).rounded()
        button.backgroundColor = background
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        return button
    }

    private static func makeCard(frame: CGRect) -> UIView {
        let card = UIView(frame: frame)
        card.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        return card
    }

    private static func makeChevron(in card: UIView) -> UIImageView {
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.tintColor = UIColor.white.withAlphaComponent(0.4)
        chevron.sizeToFit()
        chevron.center = CGPoint(x: card.bounds.width - 20, y: card.bounds.height / 2)
        return chevron
    }

    private static func makeProfileCard(content: PushDemoViewModel, frame: CGRect) -> UIView {
        let card = makeCard(frame: frame)

        let avatar = makeLabel(
            content.uiProfileInitials,
            font: UIFont.systemFont(ofSize: 18, weight: .bold).rounded(),
            color: .white
        )
        avatar.textAlignment = .center
        avatar.backgroundColor = Palette.cyan.withAlphaComponent(0.6)
        avatar.frame = CGRect(x: 14, y: 14, width: 48, height: 48)
        avatar.layer.cornerRadius = 24
        avatar.layer.masksToBounds = true
        card.addSubview(avatar)

        let name = makeLabel(
            content.uiProfileName,
            font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            color: .white
        )
        name.frame = CGRect(x: 76, y: 17, width: frame.width - 110, height: 22)
        card.addSubview(name)

        let detail = makeLabel(
            content.uiProfileDetail,
            font: UIFont.systemFont(ofSize: 13, weight: .regular),
            color: UIColor.white.withAlphaComponent(0.55)
        )
        detail.frame = CGRect(x: 76, y: 41, width: frame.width - 110, height: 18)
        card.addSubview(detail)

        card.addSubview(makeChevron(in: card))
        return card
    }

    private static func makeToggleRow(content: PushDemoViewModel, frame: CGRect) -> UIView {
        let row = makeCard(frame: frame)

        let label = makeLabel(
            content.uiToggleTitle,
            font: UIFont.systemFont(ofSize: 16, weight: .medium).rounded(),
            color: .white
        )
        label.frame = CGRect(x: 16, y: 0, width: frame.width - 90, height: frame.height)
        row.addSubview(label)

        // A real, working UISwitch — flip it, then smash it.
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.onTintColor = Palette.mint.withAlphaComponent(0.7)
        toggle.center = CGPoint(x: frame.width - 16 - toggle.bounds.width / 2, y: frame.height / 2)
        row.addSubview(toggle)

        return row
    }

    private static func makeLinkRow(content: PushDemoViewModel, frame: CGRect) -> UIView {
        let row = makeCard(frame: frame)

        let label = makeLabel(
            content.uiLinkTitle,
            font: UIFont.systemFont(ofSize: 16, weight: .medium).rounded(),
            color: .white
        )
        label.frame = CGRect(x: 16, y: 0, width: frame.width / 2, height: frame.height)
        row.addSubview(label)

        let value = makeLabel(
            content.uiLinkValue,
            font: UIFont.systemFont(ofSize: 16, weight: .regular),
            color: UIColor.white.withAlphaComponent(0.55)
        )
        value.textAlignment = .right
        value.frame = CGRect(x: frame.width - 140, y: 0, width: 100, height: frame.height)
        row.addSubview(value)

        row.addSubview(makeChevron(in: row))
        return row
    }
}
