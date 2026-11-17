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
    public var imageURL: String?

    public init(
        name: String,
        symbol: String,
        address: String? = nil,
        fractionDigits: Int = 9,
        amount: Decimal = 0,
        customPriceUSD: Decimal? = nil,
        imageURL: String? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.address = address
        self.fractionDigits = fractionDigits
        self.amount = amount
        self.customPriceUSD = customPriceUSD
        self.imageURL = imageURL
    }

    public static let popularPresets: [MockTokenBalance] = [
        MockTokenBalance(
            name: "Toncoin",
            symbol: "TON",
            address: nil,
            fractionDigits: 9,
            amount: 150,
            customPriceUSD: 5.5,
            imageURL: nil
        ),
        MockTokenBalance(
            name: "Tether USD",
            symbol: "USD₮",
            address: JettonMasterAddress.tonUSDT.toRaw(),
            fractionDigits: 6,
            amount: 1500,
            customPriceUSD: 0.99,
            imageURL: "https://cache.tonapi.io/img/token/usdt.png"
        ),
    ]
}

@frozen public enum MockNFTType: String, Codable, Sendable, CaseIterable {
    case tonDNS
    case telegramUsername
    case telegramGift
    case genericNFT

    public var title: String {
        switch self {
        case .tonDNS: return "TON DNS"
        case .telegramUsername: return "Telegram Username"
        case .telegramGift: return "TG Gift"
        case .genericNFT: return "NFT"
        }
    }
}

public struct MockNFTItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var type: MockNFTType
    public var name: String
    public var collectionName: String?
    public var imageURL: String?
    public var dns: String?
    public var username: String?
    public var fragmentURL: String?

    public init(
        id: String = UUID().uuidString,
        type: MockNFTType,
        name: String,
        collectionName: String? = nil,
        imageURL: String? = nil,
        dns: String? = nil,
        username: String? = nil,
        fragmentURL: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.collectionName = collectionName
        self.imageURL = imageURL
        self.dns = dns
        self.username = username
        self.fragmentURL = fragmentURL
    }
}
