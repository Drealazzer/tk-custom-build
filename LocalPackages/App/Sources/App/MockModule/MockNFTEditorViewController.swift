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

    private var selectedType: MockNFTType = .genericNFT

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
            updateFieldVisibility()
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
        contentStack.spacing = 12
        contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 40, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        typeControl.selectedSegmentIndex = MockNFTType.allCases.firstIndex(of: .genericNFT) ?? 0
        typeControl.addTarget(self, action: #selector(didChangeType), for: .valueChanged)
        contentStack.addArrangedSubview(labeledView(label: "Тип", view: typeControl))

        nameField.placeholder = "Название NFT"
        nameField.borderStyle = .roundedRect
        nameField.returnKeyType = .next
        nameField.delegate = self
        contentStack.addArrangedSubview(labeledView(label: "Название *", view: nameField))

        collectionField.placeholder = "Название коллекции (необязательно)"
        collectionField.borderStyle = .roundedRect
        collectionField.returnKeyType = .next
        collectionField.delegate = self
        contentStack.addArrangedSubview(labeledView(label: "Коллекция", view: collectionField))

        imageURLField.placeholder = "https://example.com/image.png"
        imageURLField.borderStyle = .roundedRect
        imageURLField.keyboardType = .URL
        imageURLField.autocapitalizationType = .none
        imageURLField.returnKeyType = .next
        imageURLField.delegate = self
        contentStack.addArrangedSubview(labeledView(label: "URL изображения", view: imageURLField))

        dnsField.placeholder = "example.ton"
        dnsField.borderStyle = .roundedRect
        dnsField.autocapitalizationType = .none
        dnsField.returnKeyType = .done
        dnsField.delegate = self
        dnsField.addTarget(self, action: #selector(didEndEditingDNS), for: .editingDidEnd)
        contentStack.addArrangedSubview(labeledView(label: "TON DNS домен", view: dnsField))

        usernameField.placeholder = "@username"
        usernameField.borderStyle = .roundedRect
        usernameField.autocapitalizationType = .none
        usernameField.returnKeyType = .done
        usernameField.delegate = self
        usernameField.addTarget(self, action: #selector(didEndEditingUsername), for: .editingDidEnd)
        contentStack.addArrangedSubview(labeledView(label: "Telegram Username", view: usernameField))

        fragmentURLField.placeholder = "https://nft.fragment.com/gift/..."
        fragmentURLField.borderStyle = .roundedRect
        fragmentURLField.keyboardType = .URL
        fragmentURLField.autocapitalizationType = .none
        fragmentURLField.returnKeyType = .done
        fragmentURLField.delegate = self
        fragmentURLField.addTarget(self, action: #selector(didEndEditingFragmentURL), for: .editingDidEnd)
        fragmentURLField.addTarget(self, action: #selector(didEndEditingFragmentURL), for: .editingChanged)
        contentStack.addArrangedSubview(labeledView(label: "Fragment URL (авто-заполнение)", view: fragmentURLField))

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        updateFieldVisibility()
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
        updateFieldVisibility()
    }

    private func updateFieldVisibility() {
        dnsField.superview?.isHidden = selectedType != .tonDNS
        usernameField.superview?.isHidden = selectedType != .telegramUsername
        fragmentURLField.superview?.isHidden = selectedType != .telegramGift
    }

    @objc private func didChangeType() {
        let idx = typeControl.selectedSegmentIndex
        guard idx >= 0, idx < MockNFTType.allCases.count else { return }
        selectedType = MockNFTType.allCases[idx]
        updateFieldVisibility()

        if collectionField.text?.isEmpty ?? true {
            switch selectedType {
            case .tonDNS:
                collectionField.text = "TON DNS Domains"
            case .telegramUsername:
                collectionField.text = "Telegram Usernames"
            case .telegramGift:
                collectionField.text = "Telegram Gifts"
            case .genericNFT:
                break
            }
        }
    }

    @objc private func didEndEditingDNS() {
        guard var text = dnsField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        if !text.contains(".") {
            text += ".ton"
            dnsField.text = text
        }
        if nameField.text?.isEmpty ?? true {
            nameField.text = text
        }
        if collectionField.text?.isEmpty ?? true {
            collectionField.text = "TON DNS Domains"
        }
        if imageURLField.text?.isEmpty ?? true {
            imageURLField.text = "https://cache.tonapi.io/img/dns/\(text).png"
        }
    }

    @objc private func didEndEditingUsername() {
        guard var text = usernameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        if !text.hasPrefix("@") {
            text = "@\(text)"
            usernameField.text = text
        }
        let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        if nameField.text?.isEmpty ?? true {
            nameField.text = text
        }
        if collectionField.text?.isEmpty ?? true {
            collectionField.text = "Telegram Usernames"
        }
        if imageURLField.text?.isEmpty ?? true {
            imageURLField.text = "https://nft.fragment.com/username/\(clean).webp"
        }
    }

    @objc private func didEndEditingFragmentURL() {
        guard let text = fragmentURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        let (parsedName, parsedImageURL, parsedCollection) = parseFragmentGiftURL(text)
        if (nameField.text?.isEmpty ?? true) && !parsedName.isEmpty {
            nameField.text = parsedName
        }
        if (imageURLField.text?.isEmpty ?? true) && !parsedImageURL.isEmpty {
            imageURLField.text = parsedImageURL
        }
        if collectionField.text?.isEmpty ?? true {
            collectionField.text = parsedCollection
        }
    }

    private func parseFragmentGiftURL(_ urlString: String) -> (name: String, imageURL: String, collection: String) {
        guard let url = URL(string: urlString) else { return ("", "", "Telegram Gifts") }
        let lastComponent = url.lastPathComponent
        let slug = (lastComponent as NSString).deletingPathExtension
        guard !slug.isEmpty else { return ("", "", "Telegram Gifts") }

        let parts = slug.components(separatedBy: "-")
        let giftName: String
        if parts.count >= 2, let number = parts.last {
            let baseName = parts.dropLast().joined(separator: "-")
            var formattedBase = ""
            for char in baseName {
                if char.isUppercase && !formattedBase.isEmpty {
                    formattedBase.append(" ")
                }
                formattedBase.append(char)
            }
            giftName = "\(formattedBase) #\(number)"
        } else {
            giftName = slug
        }

        let webpURL = "https://nft.fragment.com/gift/\(slug).webp"
        return (giftName, webpURL, "Telegram Gifts")
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
            let raw = dnsField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                showError("Введите TON DNS домен (например: example.ton)")
                return
            }
            dns = raw
        case .telegramUsername:
            let raw = usernameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                showError("Введите Telegram username")
                return
            }
            username = raw.hasPrefix("@") ? raw : "@\(raw)"
        case .telegramGift:
            let raw = fragmentURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty || URL(string: raw) == nil {
                showError("Вставьте корректный Fragment URL\n(https://nft.fragment.com/gift/...)")
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
            fragmentURL: fragmentURL
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
        let fields: [UITextField] = [nameField, collectionField, imageURLField, dnsField, usernameField, fragmentURLField]
        if let idx = fields.firstIndex(of: textField), idx + 1 < fields.count {
            fields[idx + 1].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
