import UIKit

/// A committed search is independent of the sheet that edits it.
struct CardSearchCriteria {
    static let maximums = [10000, 10000, 12]
    static var empty: CardSearchCriteria {
        CardSearchCriteria(query: "", selections: [[], [], []], ranges: [(0, 10000), (0, 10000), (0, 12)])
    }

    var query: String
    var selections: [Set<String>]
    var ranges: [(Int, Int)]

    var isEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selections.allSatisfy { $0.isEmpty }
            && ranges.enumerated().allSatisfy { $0.element.0 == 0 && $0.element.1 == Self.maximums[$0.offset] }
    }

    func filter(_ cards: [CardEntity]) -> [CardEntity] {
        guard !isEmpty else { return cards }
        let words = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return cards.filter { card in
            let searchable = [card.id ?? "", card.enName ?? "", card.cnName ?? "", card.enDesc ?? "", card.cnDesc ?? ""]
                .joined(separator: " ").lowercased()
            guard words.allSatisfy({ searchable.contains($0) }) else { return false }
            if !selections[0].isEmpty && !selections[0].contains(where: { card.getType().contains($0) }) { return false }
            if !selections[1].isEmpty && !selections[1].contains(card.getAttribute() ?? "") { return false }
            if !selections[2].isEmpty && !selections[2].contains(card.getRace() ?? "") { return false }
            let values = [card.getAtk(), card.getDef(), card.getLevel()]
            for index in 0..<3 {
                let (lower, upper) = ranges[index]
                // An untouched range includes cards without that numeric stat.
                guard lower != 0 || upper != Self.maximums[index] else { continue }
                guard let value = Int(values[index]), value >= lower, value <= upper else { return false }
            }
            return true
        }
    }
}

/// Draft conditions are committed only when the user taps Search.
final class CardSearchViewController: UIViewController {
    var criteria: CardSearchCriteria = .empty
    var onSearch: ((CardSearchCriteria) -> Void)?

    private let searchBar = UISearchBar()
    private let filtersScrollView = UIScrollView()
    private let filterContent = UIStackView()
    private var selections: [Set<String>] = [[], [], []]
    private var chipGroups: [SearchFilterChipsView] = []
    private var rangeSliders: [RangeSlider] = []
    private var rangeLabels: [UILabel] = []
    private let rangeMaximums = CardSearchCriteria.maximums
    private let accent = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.42, green: 0.78, blue: 0.65, alpha: 1)
        : UIColor(red: 0.12, green: 0.36, blue: 0.29, alpha: 1) }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = "cardSearchSheet"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = accent
        selections = criteria.selections
        setupLayout()
        setupFilters()
        searchBar.text = criteria.query
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { updateSliderColors() }
    }

    private func setupLayout() {
        let heading = UILabel()
        heading.text = L10n.text("搜索卡牌", "Search Cards")
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        let cancel = UIButton(type: .system)
        cancel.setTitle(L10n.text("取消", "Cancel"), for: .normal)
        cancel.accessibilityIdentifier = "cardSearchCancel"
        cancel.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)
        let reset = UIButton(type: .system)
        reset.setTitle(L10n.text("清除条件", "Clear"), for: .normal)
        reset.accessibilityIdentifier = "cardSearchReset"
        reset.addTarget(self, action: #selector(resetFilters), for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [cancel, UIView(), heading, UIView(), reset])
        header.alignment = .center
        header.distribution = .equalSpacing
        header.isLayoutMarginsRelativeArrangement = true
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 16, bottom: 4, trailing: 16)
        cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        reset.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = L10n.text("搜索名称、效果或编号", "Search name, effect or ID")
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.searchTextField.font = .preferredFont(forTextStyle: .body)
        searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        searchBar.searchTextField.accessibilityIdentifier = "cardSearchField"
        searchBar.searchTextField.backgroundColor = .secondarySystemGroupedBackground

        filterContent.axis = .vertical
        filterContent.spacing = 16
        filterContent.isLayoutMarginsRelativeArrangement = true
        filterContent.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 18, trailing: 14)
        filterContent.backgroundColor = .secondarySystemGroupedBackground
        filterContent.layer.cornerRadius = 14
        filterContent.layer.cornerCurve = .continuous
        filtersScrollView.addSubview(filterContent)
        filterContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            filterContent.topAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.topAnchor),
            filterContent.leadingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            filterContent.trailingAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            filterContent.bottomAnchor.constraint(equalTo: filtersScrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            filterContent.widthAnchor.constraint(equalTo: filtersScrollView.frameLayoutGuide.widthAnchor, constant: -24)
        ])
        filtersScrollView.alwaysBounceVertical = true
        filtersScrollView.keyboardDismissMode = .onDrag
        filtersScrollView.accessibilityIdentifier = "cardSearchConditions"

        let submit = UIButton(type: .system)
        var style = UIButton.Configuration.filled()
        style.title = L10n.text("搜索", "Search")
        style.baseBackgroundColor = accent
        style.cornerStyle = .large
        submit.configuration = style
        submit.accessibilityIdentifier = "cardSearchSubmit"
        submit.addTarget(self, action: #selector(submitSearch), for: .touchUpInside)
        submit.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        let footer = UIView()
        footer.addSubview(submit)
        submit.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            submit.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            submit.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            submit.topAnchor.constraint(equalTo: footer.topAnchor, constant: 8),
            submit.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -8)
        ])
        let stack = UIStackView(arrangedSubviews: [header, searchBar, filtersScrollView, footer])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
    }

    private func setupFilters() {
        let rangeNames = [L10n.text("攻击力", "ATK"), L10n.text("守备力", "DEF"), L10n.text("等级 / 阶级", "Level / Rank")]
        for index in 0..<3 {
            let label = makeHeading(rangeNames[index])
            let slider = RangeSlider(frame: CGRect(x: 0, y: 0, width: 280, height: 32))
            slider.maximumValue = Double(rangeMaximums[index])
            slider.lowerValue = Double(criteria.ranges[index].0)
            slider.upperValue = Double(criteria.ranges[index].1)
            slider.tag = index
            slider.heightAnchor.constraint(equalToConstant: 32).isActive = true
            slider.addTarget(self, action: #selector(rangeChanged(_:)), for: .valueChanged)
            slider.accessibilityLabel = rangeNames[index]
            let row = UIStackView(arrangedSubviews: [label, slider])
            row.axis = .vertical
            row.spacing = 5
            rangeSliders.append(slider)
            rangeLabels.append(label)
            filterContent.addArrangedSubview(row)
        }
        let titles = [L10n.text("类型", "Card Type"), L10n.text("属性", "Attribute"), L10n.text("种族", "Race")]
        for (index, key) in ["type", "attribute", "race"].enumerated() {
            let group = SearchFilterChipsView(values: getValues(inputKey: key), accent: accent)
            group.setSelection(selections[index])
            group.onToggle = { [weak self] value in
                guard let self = self else { return }
                if self.selections[index].contains(value) { self.selections[index].remove(value) }
                else { self.selections[index].insert(value) }
            }
            chipGroups.append(group)
            let section = UIStackView(arrangedSubviews: [makeHeading(titles[index]), group])
            section.axis = .vertical
            section.spacing = 8
            filterContent.addArrangedSubview(section)
        }
        updateRangeLabels()
        updateSliderColors()
    }

    private func makeHeading(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }

    private func updateSliderColors() {
        for slider in rangeSliders {
            slider.trackTintColor = .tertiarySystemFill
            slider.trackHighlightTintColor = accent.resolvedColor(with: traitCollection)
            slider.thumbTintColor = .systemBackground
            slider.thumbBorderColor = accent.resolvedColor(with: traitCollection)
            slider.thumbBorderWidth = 1.5
        }
    }

    private func bounds(for index: Int) -> (Int, Int) {
        let step = index == 2 ? 1 : 500
        return (Int(rangeSliders[index].lowerValue) / step * step,
                Int(rangeSliders[index].upperValue) / step * step)
    }

    private func updateRangeLabels() {
        let names = [L10n.text("攻击力", "ATK"), L10n.text("守备力", "DEF"), L10n.text("等级 / 阶级", "Level / Rank")]
        for index in 0..<3 {
            let (lower, upper) = bounds(for: index)
            rangeLabels[index].text = "\(names[index])  \(lower) – \(upper)"
            rangeSliders[index].accessibilityValue = "\(lower) – \(upper)"
        }
    }

    @objc private func cancelSearch() { dismiss(animated: true) }

    @objc private func submitSearch() {
        let selected = CardSearchCriteria(query: searchBar.text ?? "", selections: selections,
                                          ranges: (0..<3).map { bounds(for: $0) })
        view.endEditing(true)
        dismiss(animated: true) { [onSearch] in onSearch?(selected) }
    }

    @objc private func resetFilters() {
        searchBar.text = ""
        selections = [[], [], []]
        chipGroups.forEach { $0.clearSelection() }
        for index in 0..<3 {
            rangeSliders[index].lowerValue = 0
            rangeSliders[index].upperValue = Double(rangeMaximums[index])
        }
        updateRangeLabels()
    }

    @objc private func rangeChanged(_ slider: RangeSlider) { updateRangeLabels() }
}

extension CardSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { submitSearch() }
}

/// Self-sizing flow layout keeps translated filter chips readable at any width.
private final class SearchFilterChipsView: UIView {
    var onToggle: ((String) -> Void)?
    private let values: [String]
    private let accent: UIColor
    private var buttons: [UIButton] = []
    private var measuredHeight: CGFloat = 44

    init(values: [String], accent: UIColor) {
        self.values = values
        self.accent = accent
        super.init(frame: .zero)
        for (index, title) in values.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.accessibilityLabel = title
            button.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
            addSubview(button)
            buttons.append(button)
            updateStyle(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight) }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for button in buttons {
            let fitting = button.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
            let width = min(bounds.width, ceil(fitting.width))
            let height = max(44, ceil(fitting.height))
            if x > 0 && x + width > bounds.width { x = 0; y += rowHeight + 6; rowHeight = 0 }
            button.frame = CGRect(x: x, y: y, width: width, height: height)
            x += width + 6
            rowHeight = max(rowHeight, height)
        }
        let height = y + rowHeight
        if measuredHeight != height { measuredHeight = height; invalidateIntrinsicContentSize() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            buttons.forEach { updateStyle($0) }
            setNeedsLayout()
        }
    }

    func setSelection(_ selection: Set<String>) {
        for (index, button) in buttons.enumerated() {
            button.isSelected = selection.contains(values[index])
            updateStyle(button)
        }
        setNeedsLayout()
    }

    func clearSelection() { setSelection([]) }

    @objc private func toggle(_ button: UIButton) {
        button.isSelected.toggle()
        updateStyle(button)
        setNeedsLayout()
        onToggle?(values[button.tag])
    }

    private func updateStyle(_ button: UIButton) {
        var configuration = button.isSelected ? UIButton.Configuration.filled() : .tinted()
        configuration.title = values[button.tag]
        let foreground: UIColor = button.isSelected ? .systemBackground : .secondaryLabel
        configuration.baseForegroundColor = foreground
        configuration.baseBackgroundColor = button.isSelected ? accent : .tertiarySystemFill
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = .preferredFont(forTextStyle: .caption1)
            updated.foregroundColor = foreground
            return updated
        }
        button.configuration = configuration
        button.accessibilityTraits = button.isSelected ? [.button, .selected] : [.button]
    }
}
