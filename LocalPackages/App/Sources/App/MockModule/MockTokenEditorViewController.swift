import KeeperCore
import SnapKit
import TKUIKit
import UIKit

@MainActor
final class MockTokenEditorViewController: UIViewController {
    var onSave: (() -> Void)?

    private let existingToken: MockTokenBalance?
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let presetSegmentedControl = UISegmentedControl(items: ["Популярные", "Свой жетон"])
    private let popularPickerButton = UIButton(type: .system)
    private var selectedPreset: MockTokenBalance?

    private let symbolField = UITextField()
    private let nameField = UITextField()
    private let addressField = UITextField()
    private let decimalsField = UITextField()
    private let amountField = UITextField()
    private let priceField = UITextField()

    private let saveButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    init(token: MockTokenBalance? = nil) {
        self.existingToken = token
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        title = existingToken == nil ? "Добавить токен" : "Редактировать токен"
        view.backgroundColor = .Background.page

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(didTapCancel)
        )

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        presetSegmentedControl.selectedSegmentIndex = existingToken == nil ? 0 : 1
        presetSegmentedControl.addTarget(self, action: #selector(didChangePresetSegment), for: .valueChanged)

        popularPickerButton.setTitle("Выбрать: USDT (Tether)", for: .normal)
        popularPickerButton.setTitleColor(.Text.primary, for: .normal)
        popularPickerButton.backgroundColor = .Background.content
        popularPickerButton.layer.cornerRadius = 12
        popularPickerButton.contentHorizontalAlignment = .left
        popularPickerButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        popularPickerButton.addTarget(self, action: #selector(didTapPopularPicker), for: .touchUpInside)

        configureTextField(symbolField, placeholder: "Символ (например, TON, USDT)")
        configureTextField(nameField, placeholder: "Название (например, Tether USD)")
        configureTextField(addressField, placeholder: "Адрес мастер-контракта (0:...)")
        configureTextField(decimalsField, placeholder: "Десятичные знаки (обычно 6 или 9)")
        decimalsField.keyboardType = .numberPad
        configureTextField(amountField, placeholder: "Количество монет (например, 1000)")
        amountField.keyboardType = .decimalPad
        configureTextField(priceField, placeholder: "Цена в USD (например, 1.00)")
        priceField.keyboardType = .decimalPad

        saveButton.setTitle("Сохранить", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = TKTextStyle.label1.font
        saveButton.backgroundColor = .Accent.blue
        saveButton.layer.cornerRadius = 14
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)

        deleteButton.setTitle("Удалить токен", for: .normal)
        deleteButton.setTitleColor(.Accent.red, for: .normal)
        deleteButton.titleLabel?.font = TKTextStyle.label1.font
        deleteButton.backgroundColor = .Background.content
        deleteButton.layer.cornerRadius = 14
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        deleteButton.isHidden = existingToken == nil

        let stack = UIStackView(arrangedSubviews: [
            presetSegmentedControl,
            popularPickerButton,
            createLabeledField(label: "Символ", field: symbolField),
            createLabeledField(label: "Название", field: nameField),
            createLabeledField(label: "Адрес контракта", field: addressField),
            createLabeledField(label: "Десятичные знаки", field: decimalsField),
            createLabeledField(label: "Баланс", field: amountField),
            createLabeledField(label: "Цена USD", field: priceField),
            saveButton,
            deleteButton,
        ])
        stack.axis = .vertical
        stack.spacing = 16

        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-32)
        }

        saveButton.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        deleteButton.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        popularPickerButton.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        updateFieldsVisibility()
    }

    private func configureTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.backgroundColor = .Background.content
        field.textColor = .Text.primary
        field.font = TKTextStyle.body1.font
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 48))
        field.leftViewMode = .always
        field.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }

    private func createLabeledField(label: String, field: UIView) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.textColor = .Text.secondary
        titleLabel.font = TKTextStyle.label2.font
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(field)
        return container
    }

    private func loadData() {
        if let token = existingToken {
            symbolField.text = token.symbol
            nameField.text = token.name
            addressField.text = token.address
            decimalsField.text = "\(token.fractionDigits)"
            amountField.text = "\(token.amount)"
            priceField.text = token.customPriceUSD.map { "\($0)" } ?? ""
        } else {
            selectPreset(MockTokenBalance.popularPresets[1]) // USDT default
        }
    }

    private func selectPreset(_ preset: MockTokenBalance) {
        selectedPreset = preset
        popularPickerButton.setTitle("Выбран: \(preset.symbol) (\(preset.name))", for: .normal)
        symbolField.text = preset.symbol
        nameField.text = preset.name
        addressField.text = preset.address
        decimalsField.text = "\(preset.fractionDigits)"
        amountField.text = "\(preset.amount)"
        priceField.text = preset.customPriceUSD.map { "\($0)" } ?? ""
    }

    @objc private func didChangePresetSegment() {
        updateFieldsVisibility()
    }

    private func updateFieldsVisibility() {
        let isPopular = presetSegmentedControl.selectedSegmentIndex == 0 && existingToken == nil
        popularPickerButton.isHidden = !isPopular
        symbolField.superview?.isHidden = isPopular
        nameField.superview?.isHidden = isPopular
        addressField.superview?.isHidden = isPopular
        decimalsField.superview?.isHidden = isPopular
    }

    @objc private func didTapPopularPicker() {
        let alert = UIAlertController(title: "Выберите токен", message: nil, preferredStyle: .actionSheet)
        for preset in MockTokenBalance.popularPresets {
            alert.addAction(UIAlertAction(title: "\(preset.symbol) — \(preset.name)", style: .default) { [weak self] _ in
                self?.selectPreset(preset)
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func didTapSave() {
        let symbol = symbolField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !symbol.isEmpty else {
            shakeField(symbolField)
            return
        }

        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? symbol
        let address = addressField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let decimals = Int(decimalsField.text ?? "") ?? 9
        let amount = Decimal(string: (amountField.text ?? "0").replacingOccurrences(of: ",", with: ".")) ?? 0
        let price = Decimal(string: (priceField.text ?? "").replacingOccurrences(of: ",", with: "."))

        let token = MockTokenBalance(
            name: name,
            symbol: symbol,
            address: address?.isEmpty == true ? nil : address,
            fractionDigits: decimals,
            amount: amount,
            customPriceUSD: price
        )

        LocalMockStore.shared.addOrUpdateToken(token)
        onSave?()
        dismiss(animated: true)
    }

    @objc private func didTapDelete() {
        guard let token = existingToken else { return }
        LocalMockStore.shared.removeToken(symbol: token.symbol)
        onSave?()
        dismiss(animated: true)
    }

    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    private func shakeField(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-10.0, 10.0, -8.0, 8.0, -5.0, 5.0, 0.0]
        view.layer.add(animation, forKey: "shake")
    }
}
