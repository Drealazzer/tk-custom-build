import KeeperCore
import SnapKit
import TKUIKit
import UIKit

@MainActor
final class LocalMockSettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
    }

    private func setupUI() {
        title = "Локальный мок-режим"
        view.backgroundColor = .Background.page

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Готово",
            style: .done,
            target: self,
            action: #selector(didTapDone)
        )

        tableView.backgroundColor = .Background.page
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SubtitleCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didGetMockStoreChange),
            name: LocalMockStore.didChangeNotification,
            object: nil
        )
    }

    @objc private func didGetMockStoreChange() {
        tableView.reloadData()
    }

    @objc private func didTapDone() {
        dismiss(animated: true)
    }

    @objc private func didToggleSwitch(_ sender: UISwitch) {
        LocalMockStore.shared.setIsEnabled(sender.isOn)
    }

    private func showEditBalanceAlert(token: MockTokenBalance) {
        let alert = UIAlertController(
            title: "Баланс \(token.symbol)",
            message: "Задайте количество монет для \(token.name)",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            textField.text = "\(token.amount)"
            textField.placeholder = "0.0"
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                  let newAmount = Decimal(string: text)
            else { return }

            var updated = token
            updated.amount = newAmount
            LocalMockStore.shared.addOrUpdateToken(updated)
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func showWhaleConfirmation() {
        let alert = UIAlertController(
            title: "Применить пресет «Крипто-Кит»? 🐋",
            message: "Баланс будет установлен на ~$1,207,500 (850,000 USD₮ и 65,000 TON) с реалистичной историей переводов от Bybit, Fragment, OKX и STON.fi.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Применить", style: .default) { [weak self] _ in
            LocalMockStore.shared.applyWhalePreset()
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func openPushScheduler() {
        let vc = MockPushSchedulerViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Сбросить все данные?",
            message: "Все кастомные балансы и добавленные транзакции будут возвращены к исходным значениям.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive) { [weak self] _ in
            LocalMockStore.shared.resetToDefaults()
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension LocalMockSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        4
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4 // Switch + Whale + Push + Reset
        case 1:
            return LocalMockStore.shared.mockTokens.count // Only active TON & USDT
        case 2:
            return LocalMockStore.shared.mockEvents.count + 1 // Add Event button + Events
        case 3:
            return LocalMockStore.shared.mockNFTs.count + 1 // Add NFT button + NFTs
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Управление симуляцией"
        case 1: return "Активные токены (TON и USDT)"
        case 2: return "История транзакций"
        case 3: return "NFT и Коллеции"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "SwitchCell")
                cell.textLabel?.text = "Включить симуляцию"
                cell.textLabel?.textColor = .Text.primary
                cell.backgroundColor = .Background.content
                cell.selectionStyle = .none

                let toggle = UISwitch()
                toggle.isOn = LocalMockStore.shared.isEnabled
                toggle.onTintColor = .Accent.blue
                toggle.addTarget(self, action: #selector(didToggleSwitch(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                return cell
            } else if indexPath.row == 1 {
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "WhaleCell")
                cell.textLabel?.text = "🐋 Применить пресет «Крипто-Кит» ($1.2M)"
                cell.textLabel?.textColor = .Accent.blue
                cell.textLabel?.font = TKTextStyle.label1.font
                cell.detailTextLabel?.text = "850,000 USD₮ + 65,000 TON и богатая история"
                cell.detailTextLabel?.textColor = .Text.secondary
                cell.backgroundColor = .Background.content
                cell.accessoryType = .disclosureIndicator
                return cell
            } else if indexPath.row == 2 {
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PushCell")
                cell.textLabel?.text = "🔔 Запланировать входящий Push-перевод"
                cell.textLabel?.textColor = .Accent.green
                cell.textLabel?.font = TKTextStyle.label1.font
                cell.detailTextLabel?.text = "Реальный пуш на заблокированный экран по таймеру"
                cell.detailTextLabel?.textColor = .Text.secondary
                cell.backgroundColor = .Background.content
                cell.accessoryType = .disclosureIndicator
                return cell
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "ResetCell")
                cell.textLabel?.text = "Сбросить данные к дефолтным"
                cell.textLabel?.textColor = .Accent.red
                cell.backgroundColor = .Background.content
                cell.selectionStyle = .default
                return cell
            }

        case 1:
            let tokens = LocalMockStore.shared.mockTokens
            let token = tokens[indexPath.row]
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "TokenCell")
            cell.textLabel?.text = "\(token.symbol) (\(token.name))"
            cell.textLabel?.textColor = .Text.primary
            cell.detailTextLabel?.text = "\(token.amount) \(token.symbol)"
            cell.detailTextLabel?.textColor = .Accent.blue
            cell.detailTextLabel?.font = TKTextStyle.label1.font
            cell.backgroundColor = .Background.content
            cell.accessoryType = .disclosureIndicator
            return cell

        case 2:
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "AddTxCell")
                cell.textLabel?.text = "+ Добавить операцию в историю"
                cell.textLabel?.textColor = .Accent.blue
                cell.backgroundColor = .Background.content
                return cell
            } else {
                let events = LocalMockStore.shared.mockEvents
                let event = events[indexPath.row - 1]
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "TxCell")
                cell.backgroundColor = .Background.content
                cell.accessoryType = .disclosureIndicator

                let prefix: String
                let amountColor: UIColor
                switch event.type {
                case .incoming:
                    prefix = "+"
                    amountColor = .Accent.green
                case .outgoing:
                    prefix = "-"
                    amountColor = .Text.primary
                case .swap:
                    prefix = "⇄ "
                    amountColor = .Accent.blue
                }

                cell.textLabel?.text = "\(prefix)\(event.amount) \(event.tokenSymbol)  •  \(event.status.title)"
                cell.textLabel?.textColor = amountColor
                cell.textLabel?.font = TKTextStyle.label1.font

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                let dateStr = dateFormatter.string(from: event.timestamp)
                let commentStr = event.comment.map { " • \($0)" } ?? ""
                cell.detailTextLabel?.text = "\(dateStr)\(commentStr) (\(event.counterpartyAddress.prefix(12))...)"
                cell.detailTextLabel?.textColor = .Text.secondary
                return cell
            }

        case 3:
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "AddNFTCell")
                cell.textLabel?.text = "+ Добавить NFT / Домен / Подарок"
                cell.textLabel?.textColor = .Accent.blue
                cell.backgroundColor = .Background.content
                return cell
            } else {
                let nfts = LocalMockStore.shared.mockNFTs
                let nft = nfts[indexPath.row - 1]
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "NFTCell")
                cell.backgroundColor = .Background.content
                cell.accessoryType = .disclosureIndicator

                cell.textLabel?.text = "\(nft.name)  •  \(nft.type.title)"
                cell.textLabel?.textColor = .Text.primary
                cell.textLabel?.font = TKTextStyle.label1.font

                let detail: String
                switch nft.type {
                case .tonDNS:
                    detail = nft.dns ?? ""
                case .telegramUsername:
                    detail = nft.username ?? ""
                case .telegramGift:
                    detail = nft.collectionName ?? "Telegram Gift"
                }
                cell.detailTextLabel?.text = detail
                cell.detailTextLabel?.textColor = .Text.secondary
                return cell
            }

        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                showWhaleConfirmation()
            } else if indexPath.row == 2 {
                openPushScheduler()
            } else if indexPath.row == 3 {
                showResetConfirmation()
            }

        case 1:
            let tokens = LocalMockStore.shared.mockTokens
            guard indexPath.row < tokens.count else { break }
            let token = tokens[indexPath.row]
            let editor = MockTokenEditorViewController(token: token)
            editor.onSave = { [weak self] in
                self?.tableView.reloadData()
            }
            let nav = UINavigationController(rootViewController: editor)
            present(nav, animated: true)

        case 2:
            if indexPath.row == 0 {
                let editor = MockTransactionEditorViewController()
                editor.onSave = { [weak self] in
                    self?.tableView.reloadData()
                }
                let nav = UINavigationController(rootViewController: editor)
                present(nav, animated: true)
            } else {
                let events = LocalMockStore.shared.mockEvents
                let event = events[indexPath.row - 1]
                let editor = MockTransactionEditorViewController(event: event)
                editor.onSave = { [weak self] in
                    self?.tableView.reloadData()
                }
                let nav = UINavigationController(rootViewController: editor)
                present(nav, animated: true)
            }

        case 3:
            if indexPath.row == 0 {
                let editor = MockNFTEditorViewController()
                editor.onSave = { [weak self] in
                    self?.tableView.reloadData()
                }
                let nav = UINavigationController(rootViewController: editor)
                present(nav, animated: true)
            } else {
                let nfts = LocalMockStore.shared.mockNFTs
                let nft = nfts[indexPath.row - 1]
                let editor = MockNFTEditorViewController(item: nft)
                editor.onSave = { [weak self] in
                    self?.tableView.reloadData()
                }
                let nav = UINavigationController(rootViewController: editor)
                present(nav, animated: true)
            }

        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 2 || indexPath.section == 3) && indexPath.row > 0 {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.section == 2 && indexPath.row > 0 {
                let event = LocalMockStore.shared.mockEvents[indexPath.row - 1]
                LocalMockStore.shared.removeEvent(id: event.id)
                tableView.reloadData()
            } else if indexPath.section == 3 && indexPath.row > 0 {
                let nft = LocalMockStore.shared.mockNFTs[indexPath.row - 1]
                LocalMockStore.shared.removeMockNFT(id: nft.id)
                tableView.reloadData()
            }
        }
    }
}
