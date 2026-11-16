import BigInt
import Foundation
import TonSwift

public final class LocalMockStore: @unchecked Sendable {
    public static let shared = LocalMockStore()
    public static let didChangeNotification = Notification.Name("LocalMockStoreDidChangeNotification")

    private struct State: Codable {
        var isEnabled: Bool
        var tonBalance: Decimal?
        var tokens: [MockTokenBalance]
        var events: [MockHistoryEvent]
    }

    private let userDefaultsKey = "tonkeeper_custom_mock_store_v1"
    private let lock = NSLock()
    private var storedState: State

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let state = try? JSONDecoder().decode(State.self, from: data) {
            self.storedState = state
        } else {
            self.storedState = Self.makeDefaultState()
        }
    }

    private static func makeDefaultState() -> State {
        State(
            isEnabled: false,
            tonBalance: Decimal(150),
            tokens: MockTokenBalance.popularPresets,
            events: Self.makeDefaultEvents()
        )
    }

    private static func makeDefaultEvents() -> [MockHistoryEvent] {
        let now = Date()
        return [
            MockHistoryEvent(
                type: .incoming,
                tokenSymbol: "TON",
                tokenAddress: nil,
                fractionDigits: 9,
                amount: Decimal(50),
                counterpartyAddress: "UQDFf1234567890abcdefAliceTonkeeperTest",
                comment: "Reward for design",
                timestamp: now.addingTimeInterval(-3600),
                status: .success
            ),
            MockHistoryEvent(
                type: .outgoing,
                tokenSymbol: "USDT",
                tokenAddress: JettonMasterAddress.tonUSDT.toRaw(),
                fractionDigits: 6,
                amount: Decimal(150),
                counterpartyAddress: "UQBob9876543210fedcbaSubscriptionTon",
                comment: "Services renewal",
                timestamp: now.addingTimeInterval(-86400),
                status: .success
            ),
            MockHistoryEvent(
                type: .swap,
                tokenSymbol: "TON",
                tokenAddress: nil,
                fractionDigits: 9,
                amount: Decimal(10),
                counterpartyAddress: "STON.fi DEX",
                comment: nil,
                timestamp: now.addingTimeInterval(-172800),
                status: .success
            ),
        ]
    }

    // MARK: - Public State Access

    public var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedState.isEnabled
    }

    public var tonBalance: Decimal? {
        lock.lock()
        defer { lock.unlock() }
        return storedState.tonBalance
    }

    public var mockTokens: [MockTokenBalance] {
        lock.lock()
        defer { lock.unlock() }
        return storedState.tokens
    }

    public var mockEvents: [MockHistoryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedState.events
    }

    // MARK: - Mutating Methods

    public func setIsEnabled(_ isEnabled: Bool) {
        lock.lock()
        storedState.isEnabled = isEnabled
        lock.unlock()
        persistAndNotify()
    }

    public func setTonBalance(_ balance: Decimal?) {
        lock.lock()
        storedState.tonBalance = balance
        if let idx = storedState.tokens.firstIndex(where: { $0.symbol.uppercased() == "TON" }) {
            storedState.tokens[idx].amount = balance ?? 0
        }
        lock.unlock()
        persistAndNotify()
    }

    public func setTokens(_ tokens: [MockTokenBalance]) {
        lock.lock()
        storedState.tokens = tokens
        lock.unlock()
        persistAndNotify()
    }

    public func addOrUpdateToken(_ token: MockTokenBalance) {
        lock.lock()
        if let idx = storedState.tokens.firstIndex(where: { $0.symbol.caseInsensitiveCompare(token.symbol) == .orderedSame }) {
            storedState.tokens[idx] = token
        } else {
            storedState.tokens.append(token)
        }
        if token.symbol.uppercased() == "TON" {
            storedState.tonBalance = token.amount
        }
        lock.unlock()
        persistAndNotify()
    }

    public func removeToken(symbol: String) {
        lock.lock()
        storedState.tokens.removeAll { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
        lock.unlock()
        persistAndNotify()
    }

    public func addEvent(_ event: MockHistoryEvent) {
        lock.lock()
        storedState.events.insert(event, at: 0)
        lock.unlock()
        persistAndNotify()
    }

    public func updateEvent(_ event: MockHistoryEvent) {
        lock.lock()
        if let idx = storedState.events.firstIndex(where: { $0.id == event.id }) {
            storedState.events[idx] = event
        }
        lock.unlock()
        persistAndNotify()
    }

    public func removeEvent(id: UUID) {
        lock.lock()
        storedState.events.removeAll { $0.id == id }
        lock.unlock()
        persistAndNotify()
    }

    public func resetToDefaults() {
        lock.lock()
        storedState = Self.makeDefaultState()
        lock.unlock()
        persistAndNotify()
    }

    private func persistAndNotify() {
        lock.lock()
        let stateToSave = storedState
        lock.unlock()

        if let encoded = try? JSONEncoder().encode(stateToSave) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    // MARK: - Conversions

    public static func decimalToBigUInt(_ decimal: Decimal, fractionDigits: Int) -> BigUInt {
        let multiplier = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
        let scaled = decimal * multiplier
        let nsDecimal = NSDecimalNumber(decimal: scaled)
        let integerPart = nsDecimal.stringValue.components(separatedBy: ".").first ?? "0"
        return BigUInt(integerPart) ?? BigUInt(0)
    }

    public func makeProcessedTonItem(tonRates: Rates.Rate?, currency: Currency) -> ProcessedBalanceTonItem {
        lock.lock()
        let amount = storedState.tonBalance ?? Decimal(150)
        lock.unlock()

        let price = tonRates?.rate ?? Decimal(5.0)
        let converted = amount * price
        let nanoTons = UInt64(max(0, NSDecimalNumber(decimal: amount * 1_000_000_000).int64Value))

        return ProcessedBalanceTonItem(
            id: TonInfo.symbol,
            title: TonInfo.name,
            amount: nanoTons,
            fractionalDigits: TonInfo.fractionDigits,
            currency: currency,
            converted: converted,
            price: price,
            diff: tonRates?.diff24h,
            shouldCalculateInTotal: true
        )
    }

    public func makeProcessedJettonItems(jettonRates: [String: [Rates.Rate]], currency: Currency) -> [ProcessedBalanceJettonItem] {
        lock.lock()
        let tokens = storedState.tokens.filter { $0.symbol.uppercased() != "TON" }
        lock.unlock()

        return tokens.map { token in
            let addressStr = token.address ?? ""
            let jettonAddress = (try? Address.parse(addressStr)) ?? JettonMasterAddress.tonUSDT
            let jettonInfo = JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: jettonAddress,
                fractionDigits: token.fractionDigits,
                name: token.name,
                symbol: token.symbol,
                verification: .whitelist,
                imageURL: nil
            )
            let jettonItem = JettonItem(jettonInfo: jettonInfo, walletAddress: nil)

            let rate: Rates.Rate? = {
                if let ratesList = jettonRates[addressStr] ?? jettonRates[token.symbol],
                   let found = ratesList.first(where: { $0.currency == currency }) {
                    return found
                }
                if token.symbol.uppercased() == "USDT" {
                    return Rates.Rate(currency: currency, rate: 1.0, diff24h: "0.0%")
                }
                if let customPrice = token.customPriceUSD {
                    return Rates.Rate(currency: currency, rate: customPrice, diff24h: nil)
                }
                return nil
            }()

            let price = rate?.rate ?? token.customPriceUSD ?? 0
            let converted = token.amount * price
            let rawQuantity = Self.decimalToBigUInt(token.amount, fractionDigits: token.fractionDigits)

            return ProcessedBalanceJettonItem(
                id: token.id,
                jetton: jettonItem,
                amount: rawQuantity,
                fractionalDigits: token.fractionDigits,
                tag: nil,
                currency: currency,
                converted: converted,
                price: price,
                diff: rate?.diff24h,
                shouldCalculateInTotal: true
            )
        }
    }

    public func makeHistoryEvents(wallet: Wallet) -> [HistoryEvent] {
        lock.lock()
        let currentEvents = storedState.events
        lock.unlock()

        let walletAddress: Address = (try? wallet.address) ?? (try! Address.parse("0:0000000000000000000000000000000000000000000000000000000000000000"))
        let walletAccount = WalletAccount(address: walletAddress, name: wallet.label, isScam: false, isWallet: true)

        return currentEvents.map { mockEvent in
            let eventId = "mock_\(mockEvent.id.uuidString)"
            let status: AccountEventStatus = {
                switch mockEvent.status {
                case .success, .pending: return .ok
                case .failed: return .failed
                }
            }()

            let counterpartyAddr: Address = (try? Address.parse(mockEvent.counterpartyAddress)) ?? walletAddress
            let counterpartyAccount = WalletAccount(
                address: counterpartyAddr,
                name: mockEvent.counterpartyAddress.isEmpty ? nil : mockEvent.counterpartyAddress,
                isScam: false,
                isWallet: true
            )

            let isTon = mockEvent.tokenSymbol.uppercased() == "TON"
            let action: AccountEventAction

            if isTon {
                let nanoTons = Int64(NSDecimalNumber(decimal: mockEvent.amount * 1_000_000_000).int64Value)
                switch mockEvent.type {
                case .incoming:
                    let transfer = AccountEventAction.TonTransfer(
                        sender: counterpartyAccount,
                        recipient: walletAccount,
                        amount: nanoTons,
                        comment: mockEvent.comment
                    )
                    let preview = AccountEventAction.SimplePreview(
                        name: "Toncoin",
                        description: "Received",
                        value: "+\(mockEvent.amount) TON",
                        accounts: [counterpartyAccount, walletAccount]
                    )
                    action = AccountEventAction(type: .tonTransfer(transfer), status: status, preview: preview)
                case .outgoing:
                    let transfer = AccountEventAction.TonTransfer(
                        sender: walletAccount,
                        recipient: counterpartyAccount,
                        amount: nanoTons,
                        comment: mockEvent.comment
                    )
                    let preview = AccountEventAction.SimplePreview(
                        name: "Toncoin",
                        description: "Sent",
                        value: "-\(mockEvent.amount) TON",
                        accounts: [walletAccount, counterpartyAccount]
                    )
                    action = AccountEventAction(type: .tonTransfer(transfer), status: status, preview: preview)
                case .swap:
                    let swap = AccountEventAction.JettonSwap(
                        dex: "STON.fi",
                        amountIn: BigUInt(integerLiteral: UInt64(abs(nanoTons))),
                        amountOut: BigUInt(integerLiteral: UInt64(abs(nanoTons * 5))),
                        tonIn: nanoTons,
                        tonOut: nil,
                        user: walletAccount,
                        router: walletAccount
                    )
                    let preview = AccountEventAction.SimplePreview(
                        name: "Swap",
                        description: "Swap",
                        value: "\(mockEvent.amount) TON",
                        accounts: [walletAccount]
                    )
                    action = AccountEventAction(type: .jettonSwap(swap), status: status, preview: preview)
                }
            } else {
                let rawAmount = Self.decimalToBigUInt(mockEvent.amount, fractionDigits: mockEvent.fractionDigits)
                let jettonAddress: Address = {
                    if let raw = mockEvent.tokenAddress, let addr = try? Address.parse(raw) {
                        return addr
                    }
                    if mockEvent.tokenSymbol.uppercased() == "USDT" {
                        return JettonMasterAddress.tonUSDT
                    }
                    return walletAddress
                }()
                let jettonInfo = JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: jettonAddress,
                    fractionDigits: mockEvent.fractionDigits,
                    name: mockEvent.tokenSymbol,
                    symbol: mockEvent.tokenSymbol,
                    verification: .whitelist,
                    imageURL: nil
                )

                switch mockEvent.type {
                case .incoming:
                    let transfer = AccountEventAction.JettonTransfer(
                        sender: counterpartyAccount,
                        recipient: walletAccount,
                        senderAddress: counterpartyAddr,
                        recipientAddress: walletAddress,
                        amount: rawAmount,
                        jettonInfo: jettonInfo,
                        comment: mockEvent.comment
                    )
                    let preview = AccountEventAction.SimplePreview(
                        name: mockEvent.tokenSymbol,
                        description: "Received",
                        value: "+\(mockEvent.amount) \(mockEvent.tokenSymbol)",
                        accounts: [counterpartyAccount, walletAccount]
                    )
                    action = AccountEventAction(type: .jettonTransfer(transfer), status: status, preview: preview)
                case .outgoing:
                    let transfer = AccountEventAction.JettonTransfer(
                        sender: walletAccount,
                        recipient: counterpartyAccount,
                        senderAddress: walletAddress,
                        recipientAddress: counterpartyAddr,
                        amount: rawAmount,
                        jettonInfo: jettonInfo,
                        comment: mockEvent.comment
                    )
                    let preview = AccountEventAction.SimplePreview(
                        name: mockEvent.tokenSymbol,
                        description: "Sent",
                        value: "-\(mockEvent.amount) \(mockEvent.tokenSymbol)",
                        accounts: [walletAccount, counterpartyAccount]
                    )
                    action = AccountEventAction(type: .jettonTransfer(transfer), status: status, preview: preview)
                case .swap:
                    let swap = AccountEventAction.JettonSwap(
                        dex: "DeDust.io",
                        amountIn: rawAmount,
                        amountOut: rawAmount,
                        tonIn: nil,
                        tonOut: nil,
                        user: walletAccount,
                        router: walletAccount,
                        jettonInfoIn: jettonInfo,
                        jettonInfoOut: nil
                    )
                    let preview = AccountEventAction.SimplePreview(
                        name: "Swap",
                        description: "Swap",
                        value: "\(mockEvent.amount) \(mockEvent.tokenSymbol)",
                        accounts: [walletAccount]
                    )
                    action = AccountEventAction(type: .jettonSwap(swap), status: status, preview: preview)
                }
            }

            let accountEvent = AccountEvent(
                eventId: eventId,
                date: mockEvent.timestamp,
                account: walletAccount,
                isScam: false,
                isInProgress: mockEvent.status == .pending,
                extra: .Fee(0),
                excess: nil,
                progress: mockEvent.status == .pending ? 0.5 : nil,
                actions: [action]
            )
            return HistoryEvent.tonAccountEvent(accountEvent)
        }
    }
}
