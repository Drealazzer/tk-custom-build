import BigInt
import Foundation
import TonSwift

@frozen public enum MockHistoryEventType: String, Codable, Sendable, CaseIterable {
    case incoming
    case outgoing
    case swap

    public var title: String {
        switch self {
        case .incoming: return "Получено"
        case .outgoing: return "Отправлено"
        case .swap: return "Обмен"
        }
    }
}

@frozen public enum MockHistoryEventStatus: String, Codable, Sendable, CaseIterable {
    case success
    case pending
    case failed

    public var title: String {
        switch self {
        case .success: return "Успешно"
        case .pending: return "В обработке"
        case .failed: return "Ошибка"
        }
    }
}

public struct MockHistoryEvent: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var type: MockHistoryEventType
    public var tokenSymbol: String
    public var tokenAddress: String?
    public var fractionDigits: Int
    public var amount: Decimal
    public var counterpartyAddress: String
    public var comment: String?
    public var timestamp: Date
    public var status: MockHistoryEventStatus

    public init(
        id: UUID = UUID(),
        type: MockHistoryEventType,
        tokenSymbol: String,
        tokenAddress: String? = nil,
        fractionDigits: Int = 9,
        amount: Decimal,
        counterpartyAddress: String,
        comment: String? = nil,
        timestamp: Date = Date(),
        status: MockHistoryEventStatus = .success
    ) {
        self.id = id
        self.type = type
        self.tokenSymbol = tokenSymbol
        self.tokenAddress = tokenAddress
        self.fractionDigits = fractionDigits
        self.amount = amount
        self.counterpartyAddress = counterpartyAddress
        self.comment = comment
        self.timestamp = timestamp
        self.status = status
    }
}

public struct MockTokenBalance: Codable, Sendable, Identifiable, Equatable {
    public var id: String { symbol }
    public var name: String
    public var symbol: String
    public var address: String?
    public var fractionDigits: Int
    public var amount: Decimal
    public var customPriceUSD: Decimal?

    public init(
        name: String,
        symbol: String,
        address: String? = nil,
        fractionDigits: Int = 9,
        amount: Decimal = 0,
        customPriceUSD: Decimal? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.address = address
        self.fractionDigits = fractionDigits
        self.amount = amount
        self.customPriceUSD = customPriceUSD
    }

    public static let popularPresets: [MockTokenBalance] = [
        MockTokenBalance(
            name: "Toncoin",
            symbol: "TON",
            address: nil,
            fractionDigits: 9,
            amount: 150,
            customPriceUSD: 5.5
        ),
        MockTokenBalance(
            name: "Tether USD",
            symbol: "USDT",
            address: JettonMasterAddress.tonUSDT.toRaw(),
            fractionDigits: 6,
            amount: 1500,
            customPriceUSD: 1.0
        ),
        MockTokenBalance(
            name: "Gram",
            symbol: "GRAM",
            address: "0:47093a17e57e5b85bd31ba4da0a6f4a86704407460959828456a0664670be8e5",
            fractionDigits: 9,
            amount: 50000,
            customPriceUSD: 0.015
        ),
        MockTokenBalance(
            name: "Notcoin",
            symbol: "NOT",
            address: JettonMasterAddress.NOT.toRaw(),
            fractionDigits: 9,
            amount: 250000,
            customPriceUSD: 0.007
        ),
        MockTokenBalance(
            name: "Dogs",
            symbol: "DOGS",
            address: "0:af84e1b54cfdb39cf4d306b9b1e9592dd7fe0a623910c22fa45e3ea1e0b3d884",
            fractionDigits: 9,
            amount: 100000,
            customPriceUSD: 0.0006
        ),
    ]
}
