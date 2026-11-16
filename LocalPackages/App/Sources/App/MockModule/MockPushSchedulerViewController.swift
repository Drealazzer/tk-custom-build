import KeeperCore
import SnapKit
import TKUIKit
import UIKit
import UserNotifications

@MainActor
final class MockPushSchedulerViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let tokenSegmentedControl = UISegmentedControl(items: ["USD₮ (Tether)", "TON (Toncoin)"])
    private let amountField = UITextField()
    private let quickAmountsStack = UIStackView()
    private let delaySegmentedControl = UISegmentedControl(items: ["5 сек", "10 сек", "30 сек", "1 мин"])
    private let commentField = UITextField()
    private let senderField = UITextField()
    private let scheduleButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardObservers()
    }

    private func setupUI() {
        title = "Фейковый перевод (Push)"
        view.backgroundColor = .Background.page

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(didTapCancel)
        )

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapBackground))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        tokenSegmentedControl.selectedSegmentIndex = 0

        let toolbar = makeKeyboardToolbar()
        configureTextField(amountField, placeholder: "Сумма (например, 500)", keyboardType: .decimalPad, returnKeyType: .next, toolbar: toolbar)
        amountField.text = "500"

        setupQuickAmounts()

        delaySegmentedControl.selectedSegmentIndex = 0 // 5 sec default

        configureTextField(commentField, placeholder: "Комментарий (например: Оплата за проект)", returnKeyType: .next, toolbar: toolbar)
        configureTextField(senderField, placeholder: "Отправитель (по умолчанию: Tonkeeper)", returnKeyType: .done, toolbar: toolbar)

        scheduleButton.setTitle("Запустить таймер (сверните приложение)", for: .normal)
        scheduleButton.setTitleColor(.white, for: .normal)
        scheduleButton.titleLabel?.font = TKTextStyle.label1.font
        scheduleButton.backgroundColor = .Accent.blue
        scheduleButton.layer.cornerRadius = 14
        scheduleButton.addTarget(self, action: #selector(didTapSchedule), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            createLabeledField(label: "Токен для получения", field: tokenSegmentedControl),
            createLabeledField(label: "Сумма перевода", field: amountField),
            quickAmountsStack,
            createLabeledField(label: "Через сколько прислать Push", field: delaySegmentedControl),
            createLabeledField(label: "Комментарий (необязательно)", field: commentField),
            createLabeledField(label: "Имя отправителя в пуше", field: senderField),
            scheduleButton,
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

        scheduleButton.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
    }

    private func setupQuickAmounts() {
        quickAmountsStack.axis = .horizontal
        quickAmountsStack.spacing = 8
        quickAmountsStack.distribution = .fillEqually

        let amounts: [Int] = [50, 100, 500, 1000, 5000]
        for val in amounts {
            let btn = UIButton(type: .system)
            btn.setTitle("+\(val)", for: .normal)
            btn.setTitleColor(.Text.primary, for: .normal)
            btn.titleLabel?.font = TKTextStyle.label2.font
            btn.backgroundColor = .Background.content
            btn.layer.cornerRadius = 10
            btn.snp.makeConstraints { make in
                make.height.equalTo(36)
            }
            btn.addAction(UIAction { [weak self] _ in
                self?.amountField.text = "\(val)"
            }, for: .touchUpInside)
            quickAmountsStack.addArrangedSubview(btn)
        }
    }

    private func configureTextField(
        _ field: UITextField,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        returnKeyType: UIReturnKeyType = .default,
        toolbar: UIToolbar? = nil
    ) {
        field.placeholder = placeholder
        field.backgroundColor = .Background.content
        field.textColor = .Text.primary
        field.font = TKTextStyle.body1.font
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 48))
        field.leftViewMode = .always
        field.keyboardType = keyboardType
        field.returnKeyType = returnKeyType
        field.inputAccessoryView = toolbar
        field.delegate = self
        field.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(didTapDoneKeyboard))
        toolbar.items = [flex, done]
        return toolbar
    }

    @objc private func didTapBackground() {
        view.endEditing(true)
    }

    @objc private func didTapDoneKeyboard() {
        view.endEditing(true)
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let bottomInset = keyboardFrame.height - view.safeAreaInsets.bottom
        scrollView.contentInset.bottom = max(0, bottomInset)
        scrollView.verticalScrollIndicatorInsets.bottom = max(0, bottomInset)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
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

    @objc private func didTapSchedule() {
        let rawAmount = amountField.text?.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let amount = Decimal(string: rawAmount), amount > 0 else {
            shakeField(amountField)
            return
        }

        let symbol = tokenSegmentedControl.selectedSegmentIndex == 0 ? "USDT" : "TON"
        let delays: [TimeInterval] = [5, 10, 30, 60]
        let delay = delays[min(max(0, delaySegmentedControl.selectedSegmentIndex), delays.count - 1)]
        let comment = commentField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sender = senderField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                LocalMockStore.shared.schedulePushTransfer(
                    tokenSymbol: symbol,
                    amount: amount,
                    delaySeconds: delay,
                    comment: comment,
                    senderName: sender
                )

                let alert = UIAlertController(
                    title: "Таймер запущен на \(Int(delay)) сек! ⏳",
                    message: "Сверните Tonkeeper или заблокируйте экран. Через \(Int(delay)) секунд придет системный Push, а баланс сразу обновится.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Понятно", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                self.present(alert, animated: true)
            }
        }
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

extension MockPushSchedulerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == amountField {
            commentField.becomeFirstResponder()
        } else if textField == commentField {
            senderField.becomeFirstResponder()
        } else {
            view.endEditing(true)
        }
        return true
    }
}
