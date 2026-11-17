import KeeperCore
import SnapKit
import TKUIKit
import UIKit

@MainActor
final class MockNFTEditorViewController: UIViewController {
    var onSave: (() -> Void)?

    private let existingItem: MockNFTItem?
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let typeControl = UISegmentedControl(items: MockNFTType.allCases.map { $0.title })
    private let nameField = UITextField()
    private let collectionField = UITextField()
    private let imageURLField = UITextField()
    private let dnsField = UITextField()
    private let usernameField = UITextField()
    private let fragmentURLField = UITextField()
    private let descriptionField = UITextField()
    private let collectionDescField = UITextField()

    private var currentAttributes: [MockNFTAttribute] = []
    private var selectedType: MockNFTType = .telegramGift

    private lazy var typeContainer = labeledView(label: "Тип", view: typeControl)
    private lazy var fragmentURLContainer = labeledView(label: "Ссылка на подарок (t.me/nft/... или fragment.com) *", view: fragmentURLField)
    private lazy var dnsContainer = labeledView(label: "TON DNS домен (например wistykkeqqq.ton) *", view: dnsField)
    private lazy var usernameContainer = labeledView(label: "Telegram Username (например @username) *", view: usernameField)
    private lazy var nameContainer = labeledView(label: "Название *", view: nameField)
    private lazy var collectionContainer = labeledView(label: "Коллекция", view: collectionField)
    private lazy var imageURLContainer = labeledView(label: "URL изображения", view: imageURLField)
    private lazy var descriptionContainer = labeledView(label: "Описание NFT", view: descriptionField)
    private lazy var collectionDescContainer = labeledView(label: "Описание коллекции (Подробнее о коллекции)", view: collectionDescField)

    init(item: MockNFTItem? = nil) {
        self.existingItem = item
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        if let item = existingItem {
            populate(with: item)
        } else {
            selectedType = .telegramGift
            typeControl.selectedSegmentIndex = MockNFTType.allCases.firstIndex(of: .telegramGift) ?? 0
            updateFormLayout()
        }
    }

    private func setupUI() {
        title = existingItem == nil ? "Добавить NFT" : "Редактировать NFT"
        view.backgroundColor = .Background.page

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(didTapCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(didTapSave))

        scrollView.keyboardDismissMode = .interactiveWithAccessory
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 40, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        typeControl.addTarget(self, action: #selector(didChangeType), for: .valueChanged)

        configureTextField(nameField, placeholder: "Название NFT", returnKey: .next)
        configureTextField(collectionField, placeholder: "Название коллекции", returnKey: .next)
        configureTextField(imageURLField, placeholder: "https://example.com/image.png", keyboard: .URL, returnKey: .next)
        configureTextField(dnsField, placeholder: "wistykkeqqq.ton", returnKey: .next)
        configureTextField(usernameField, placeholder: "@username", returnKey: .next)
        configureTextField(fragmentURLField, placeholder: "https://t.me/nft/VictoryMedal-83302", keyboard: .URL, returnKey: .next)
        configureTextField(descriptionField, placeholder: "Описание конкретного предмета", returnKey: .next)
        configureTextField(collectionDescField, placeholder: "Описание всей коллекции", returnKey: .done)

        dnsField.addTarget(self, action: #selector(dnsChanged), for: .editingChanged)
        dnsField.addTarget(self, action: #selector(dnsChanged), for: .editingDidEnd)

        usernameField.addTarget(self, action: #selector(usernameChanged), for: .editingChanged)
        usernameField.addTarget(self, action: #selector(usernameChanged), for: .editingDidEnd)

        fragmentURLField.addTarget(self, action: #selector(giftURLChanged), for: .editingChanged)
        fragmentURLField.addTarget(self, action: #selector(giftURLChanged), for: .editingDidEnd)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func configureTextField(
        _ field: UITextField,
        placeholder: String,
        keyboard: UIKeyboardType = .default,
        returnKey: UIReturnKeyType = .done
    ) {
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.keyboardType = keyboard
        field.autocapitalizationType = .none
        field.returnKeyType = returnKey
        field.delegate = self
    }

    private func labeledView(label: String, view: UIView) -> UIView {
        let container = UIView()
        let lbl = UILabel()
        lbl.text = label
        lbl.font = TKTextStyle.label2.font
        lbl.textColor = .Text.secondary
        container.addSubview(lbl)
        container.addSubview(view)
        lbl.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        view.snp.makeConstraints { make in
            make.top.equalTo(lbl.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        return container
    }

    private func populate(with item: MockNFTItem) {
        selectedType = item.type
        typeControl.selectedSegmentIndex = MockNFTType.allCases.firstIndex(of: item.type) ?? 0
        nameField.text = item.name
        collectionField.text = item.collectionName
        imageURLField.text = item.imageURL
        dnsField.text = item.dns
        usernameField.text = item.username
        fragmentURLField.text = item.fragmentURL
        descriptionField.text = item.description
        collectionDescField.text = item.collectionDescription
        currentAttributes = item.attributes ?? []
        updateFormLayout()
    }

    private func updateFormLayout() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        contentStack.addArrangedSubview(typeContainer)

        switch selectedType {
        case .telegramGift:
            contentStack.addArrangedSubview(fragmentURLContainer)
            contentStack.addArrangedSubview(nameContainer)
            contentStack.addArrangedSubview(collectionContainer)
            contentStack.addArrangedSubview(descriptionContainer)
            contentStack.addArrangedSubview(collectionDescContainer)
            contentStack.addArrangedSubview(imageURLContainer)

        case .tonDNS:
            contentStack.addArrangedSubview(dnsContainer)
            contentStack.addArrangedSubview(nameContainer)
            contentStack.addArrangedSubview(collectionContainer)
            contentStack.addArrangedSubview(collectionDescContainer)

        case .telegramUsername:
            contentStack.addArrangedSubview(usernameContainer)
            contentStack.addArrangedSubview(nameContainer)
            contentStack.addArrangedSubview(collectionContainer)
            contentStack.addArrangedSubview(descriptionContainer)
            contentStack.addArrangedSubview(collectionDescContainer)
            contentStack.addArrangedSubview(imageURLContainer)

        case .genericNFT:
            contentStack.addArrangedSubview(nameContainer)
            contentStack.addArrangedSubview(collectionContainer)
            contentStack.addArrangedSubview(imageURLContainer)
            contentStack.addArrangedSubview(descriptionContainer)
            contentStack.addArrangedSubview(collectionDescContainer)
        }
    }

    @objc private func didChangeType() {
        let idx = typeControl.selectedSegmentIndex
        guard idx >= 0, idx < MockNFTType.allCases.count else { return }
        selectedType = MockNFTType.allCases[idx]
        updateFormLayout()

        if existingItem == nil {
            switch selectedType {
            case .telegramGift:
                if let text = fragmentURLField.text, !text.isEmpty {
                    parseGiftInput(text)
                }
            case .tonDNS:
                if let text = dnsField.text, !text.isEmpty {
                    parseDNSInput(text)
                }
            case .telegramUsername:
                if let text = usernameField.text, !text.isEmpty {
                    parseUsernameInput(text)
                }
            case .genericNFT:
                break
            }
        }
    }

    @objc private func giftURLChanged() {
        guard let text = fragmentURLField.text else { return }
        parseGiftInput(text)
    }

    @objc private func dnsChanged() {
        guard let text = dnsField.text else { return }
        parseDNSInput(text)
    }

    @objc private func usernameChanged() {
        guard let text = usernameField.text else { return }
        parseUsernameInput(text)
    }

    private func parseGiftInput(_ rawInput: String) {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let slug: String
        if let url = URL(string: text), let host = url.host {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if host.contains("t.me") {
                slug = pathComponents.last ?? ""
            } else if host.contains("fragment.com") {
                let last = pathComponents.last ?? ""
                slug = (last as NSString).deletingPathExtension
            } else {
                slug = (pathComponents.last as NSString?)?.deletingPathExtension ?? text
            }
        } else if text.contains("/") {
            let last = text.components(separatedBy: "/").last ?? ""
            slug = (last as NSString).deletingPathExtension
        } else {
            slug = (text as NSString).deletingPathExtension
        }

        guard !slug.isEmpty else { return }

        let canonicalURL = "https://nft.fragment.com/gift/\(slug).tgs"
        if fragmentURLField.text != canonicalURL && (text.contains("t.me") || text.contains("fragment.com")) {
            fragmentURLField.text = canonicalURL
        }

        let parts = slug.components(separatedBy: "-")
        let giftName: String
        let baseName: String
        let numberStr: String
        if parts.count >= 2, let number = parts.last {
            numberStr = "#\(number)"
            var formattedBase = ""
            for char in parts.dropLast().joined(separator: "-") {
                if char.isUppercase && !formattedBase.isEmpty && !formattedBase.hasSuffix(" ") {
                    formattedBase.append(" ")
                }
                formattedBase.append(char)
            }
            baseName = formattedBase
            giftName = "\(formattedBase) #\(number)"
        } else {
            baseName = slug
            numberStr = "#1"
            giftName = slug
        }

        let formattedCollection: String = {
            if !baseName.hasSuffix("s") {
                return "\(baseName)s"
            }
            return baseName
        }()

        let webpURL = "https://nft.fragment.com/gift/\(slug).webp"

        nameField.text = giftName
        collectionField.text = formattedCollection
        imageURLField.text = webpURL
        descriptionField.text = "An exclusive \(giftName) with unique appearance and charm."
        collectionDescField.text = "\(formattedCollection) is an exclusive NFT collection by Telegram. Owners can showcase these unique gifts on Telegram."

        currentAttributes = [
            MockNFTAttribute(key: "Model", value: baseName),
            MockNFTAttribute(key: "Number", value: numberStr),
            MockNFTAttribute(key: "Availability", value: "1 of 100,000")
        ]
    }

    private func parseDNSInput(_ rawInput: String) {
        var text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return }
        if !text.contains(".") {
            text += ".ton"
        }

        nameField.text = text
        collectionField.text = "TON DNS Domains"
        collectionDescField.text = "*.ton domains"
        descriptionField.text = "TON DNS domain name."

        currentAttributes = [
            MockNFTAttribute(key: "Domain", value: text),
            MockNFTAttribute(key: "Length", value: "\(text.count) characters"),
            MockNFTAttribute(key: "Status", value: "Active")
        ]
    }

    private func parseUsernameInput(_ rawInput: String) {
        var text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.hasPrefix("@") {
            text = "@\(text)"
        }
        let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: "@"))

        nameField.text = text
        collectionField.text = "Telegram Usernames"
        imageURLField.text = "https://nft.fragment.com/username/\(clean).webp"
        descriptionField.text = "An exclusive Telegram username."
        collectionDescField.text = "Telegram Usernames is an exclusive collection by Telegram. Owners can showcase these unique usernames on Telegram accounts, channels or groups, or trade them on Fragment."

        currentAttributes = [
            MockNFTAttribute(key: "Type", value: "Username"),
            MockNFTAttribute(key: "Handle", value: text),
            MockNFTAttribute(key: "Length", value: "\(clean.count) characters")
        ]
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapSave() {
        guard let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            showError("Введите название NFT")
            return
        }

        var dns: String? = nil
        var username: String? = nil
        var fragmentURL: String? = nil

        switch selectedType {
        case .tonDNS:
            var raw = dnsField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                raw = name
            }
            if !raw.contains(".") {
                raw += ".ton"
            }
            dns = raw
        case .telegramUsername:
            var raw = usernameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                raw = name
            }
            if !raw.hasPrefix("@") {
                raw = "@\(raw)"
            }
            username = raw
        case .telegramGift:
            let raw = fragmentURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                showError("Вставьте ссылку на подарок (t.me/nft/... или fragment.com)")
                return
            }
            fragmentURL = raw
        case .genericNFT:
            break
        }

        let item = MockNFTItem(
            id: existingItem?.id ?? UUID().uuidString,
            type: selectedType,
            name: name,
            collectionName: collectionField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            imageURL: imageURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            dns: dns,
            username: username,
            fragmentURL: fragmentURL,
            description: descriptionField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            collectionDescription: collectionDescField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            attributes: currentAttributes.isEmpty ? nil : currentAttributes,
            expiresDays: 347
        )

        LocalMockStore.shared.addMockNFT(item)
        onSave?()
        dismiss(animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension MockNFTEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
