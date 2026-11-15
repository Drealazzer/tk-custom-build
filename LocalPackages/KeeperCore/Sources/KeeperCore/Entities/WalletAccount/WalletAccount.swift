import Foundation
import TonAPI
@preconcurrency import TonSwift

public struct WalletAccount: Equatable, Codable, Sendable {
    public let address: Address
    public let name: String?
    public let isScam: Bool
    public let isWallet: Bool

    public init(
        address: Address,
        name: String? = nil,
        isScam: Bool = false,
        isWallet: Bool = true
    ) {
        self.address = address
        self.name = name
        self.isScam = isScam
        self.isWallet = isWallet
    }
}
