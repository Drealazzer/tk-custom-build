import KeeperCore
import SnapKit
import TKUIKit
import UIKit

@MainActor
final class MockTransactionEditorViewController: UIViewController {
    var onSave: (() -> Void)?

    private let existingEvent: MockHistoryEvent?
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let typeSegmentedControl = UISegmentedControl(items: ["Получено", "Отправлено", "Обмен"])
    private let statusSegmentedControl = UISegmentedControl(items: ["Успешно", "В обработке", "Ошибка"])

    private let tokenPickerButton = UIButton(type: .system)
    private var selectedTokenSymbol: String = "TON"
    private var selectedTokenAddress: String?
    private var selectedFractionDigits: Int = 9

    private let amountField = UITextField()
    private let counterpartyField = UITextField()
    private let commentField = UITextField()
    private let datePicker = UIDatePicker()

    private let saveButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    init(event: MockHistoryEvent? = nil) {
        self.existingEvent = event
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
        title = existingEvent == nil ? "Новая транзакция" : "Редактировать"
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

        typeSegmentedControl.selectedSegmentIndex = 0
        typeSegmentedControl.addTarget(self, action: #selector(didChangeType), for: .valueChanged)

        statusSegmentedControl.selectedSegmentIndex = 0

        tokenPickerButton.setTitle("Токен: TON", for: .normal)
        tokenPickerButton.setTitleColor(.Text.primary, for: .normal)
        tokenPickerButton.backgroundColor = .Background.content
        tokenPickerButton.layer.cornerRadius = 12
        tokenPickerButton.contentHorizontalAlignment = .left
        tokenPickerButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tokenPickerButton.addTarget(self, action: #selector(didTapTokenPicker), for: .touchUpInside)

        configureTextField(amountField, placeholder: "Сумма (например, 25.5)")
        amountField.keyboardType = .decimalPad

        configureTextField(counterpartyField, placeholder: "Адрес контрагента (UQ...)")
        configureTextField(commentField, placeholder: "Комментарий (memo)")

        datePicker.datePickerMode = .dateAndTime
        if #available(iOS 14.0, *) {
            datePicker.preferredDatePickerStyle = .compact
        }

        saveButton.setTitle("Сохранить операцию", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = TKTextStyle.label1.font
        saveButton.backgroundColor = .Accent.blue
        saveButton.layer.cornerRadius = 14
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)

        deleteButton.setTitle("Удалить операцию", for: .normal)
        deleteButton.setTitleColor(.Accent.red, for: .normal)
        deleteButton.titleLabel?.font = TKTextStyle.label1.font
        deleteButton.backgroundColor = .Background.content
        deleteButton.layer.cornerRadius = 14
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        deleteButton.isHidden = existingEvent == nil

        let dateContainer = UIStackView()
        dateContainer.axis = .horizontal
        dateContainer.distribution = .spaceBetween
        dateContainer.alignment = .center
        let dateLabel = UILabel()
        dateLabel.text = "Дата и время"
        dateLabel.textColor = .Text.secondary
        dateLabel.font = TKTextStyle.label2.font
        dateContainer.addArrangedSubview(dateLabel)
        dateContainer.addArrangedSubview(datePicker)

        let stack = UIStackView(arrangedSubviews: [
            createLabeledField(label: "Тип операции", field: typeSegmentedControl),
            createLabeledField(label: "Статус", field: statusSegmentedControl),
            createLabeledField(label: "Токен", field: tokenPickerButton),
            createLabeledField(label: "Сумма", field: amountField),
            createLabeledField(label: "Контрагент", field: counterpartyField),
            createLabeledField(label: "Комментарий", field: commentField),
            dateContainer,
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
        tokenPickerButton.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
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
        if let event = existingEvent {
            switch event.type {
            case .incoming: typeSegmentedControl.selectedSegmentIndex = 0
            case .outgoing: typeSegmentedControl.selectedSegmentIndex = 1
            case .swap: typeSegmentedControl.selectedSegmentIndex = 2
            }

            switch event.status {
            case .success: statusSegmentedControl.selectedSegmentIndex = 0
            case .pending: statusSegmentedControl.selectedSegmentIndex = 1
            case .failed: statusSegmentedControl.selectedSegmentIndex = 2
            }

            selectedTokenSymbol = event.tokenSymbol
            selectedTokenAddress = event.tokenAddress
            selectedFractionDigits = event.fractionDigits
            tokenPickerButton.setTitle("Токен: \(event.tokenSymbol)", for: .normal)

            amountField.text = "\(event.amount)"
            counterpartyField.text = event.counterpartyAddress
            commentField.text = event.comment
            datePicker.date = event.timestamp
        } else {
            typeSegmentedControl.selectedSegmentIndex = 0
            statusSegmentedControl.selectedSegmentIndex = 0
            selectedTokenSymbol = "TON"
            selectedTokenAddress = nil
            selectedFractionDigits = 9
            tokenPickerButton.setTitle("Токен: TON", for: .normal)
            counterpartyField.text = "UQDFf1234567890abcdefAliceTonkeeperTest"
        }
    }

    @objc private func didChangeType() {
        if typeSegmentedControl.selectedSegmentIndex == 2 {
            counterpartyField.text = "STON.fi DEX"
        }
    }

    @objc private func didTapTokenPicker() {
        let alert = UIAlertController(title: "Выберите токен", message: nil, preferredStyle: .actionSheet)
        let activeTokens = LocalMockStore.shared.mockTokens
        for token in activeTokens {
            alert.addAction(UIAlertAction(title: "\(token.symbol) (\(token.name))", style: .default) { [weak self] _ in
                guard let self else { return }
                self.selectedTokenSymbol = token.symbol
                self.selectedTokenAddress = token.address
                self.selectedFractionDigits = token.fractionDigits
                self.tokenPickerButton.setTitle("Токен: \(token.symbol)", for: .normal)
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func didTapSave() {
        let amountText = (amountField.text ?? "0").replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: amountText), amount > 0 else {
            shakeField(amountField)
            return
        }

        let type: MockHistoryEventType = {
            switch typeSegmentedControl.selectedSegmentIndex {
            case 1: return .outgoing
            case 2: return .swap
            default: return .incoming
            }
        }()

        let status: MockHistoryEventStatus = {
            switch statusSegmentedControl.selectedSegmentIndex {
            case 1: return .pending
            case 2: return .failed
            default: return .success
            }
        }()

        let counterparty = counterpartyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let comment = commentField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        let event = MockHistoryEvent(
            id: existingEvent?.id ?? UUID(),
            type: type,
            tokenSymbol: selectedTokenSymbol,
            tokenAddress: selectedTokenAddress,
            fractionDigits: selectedFractionDigits,
            amount: amount,
            counterpartyAddress: counterparty.isEmpty ? "UQWalletDefaultMockCounterpartyAddress" : counterparty,
            comment: comment?.isEmpty == true ? nil : comment,
            timestamp: datePicker.date,
            status: status
        )

        if existingEvent != nil {
            LocalMockStore.shared.updateEvent(event)
        } else {
            LocalMockStore.shared.addEvent(event)
        }

        onSave?()
        dismiss(animated: true)
    }

    @objc private func didTapDelete() {
        guard let event = existingEvent else { return }
        LocalMockStore.shared.removeEvent(id: event.id)
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
