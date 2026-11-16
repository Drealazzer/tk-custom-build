import KeeperCore
import TKCore
import TKUIKit
import UIKit

enum WalletBalanceMoreAssetsPreviewMapper {
    static func previewAvatarSource(for balanceItem: ProcessedBalanceItem) -> AssetAvatarViewImageSource {
        switch balanceItem {
        case .ton:
            return .image(.TKUIKit.Icons.Size44.tonLogo)
        case let .jetton(item):
            if item.jetton.jettonInfo.isTonUSDT || item.jetton.jettonInfo.symbol?.uppercased() == "USDT" {
                return .image(.TKUIKit.Icons.Size44.currencyUsdt)
            }
            if item.jetton.jettonInfo.symbol?.uppercased() == "GRAM" {
                return .image(.TKUIKit.Icons.Size44.currencyGram)
            }
            if let url = item.jetton.jettonInfo.imageURL {
                return .url(url)
            }
            return .image(nil)
        case let .staking(item):
            return .image(item.poolInfo?.icon)
        case .tronUSDT:
            return .image(.TKUIKit.Icons.Size44.currencyUsdt)
        case .tronTRX:
            return .image(.TKUIKit.Icons.Size44.trxChain)
        case .ethena:
            return .image(.TKUIKit.Icons.Size44.currencyUsde)
        }
    }
}
