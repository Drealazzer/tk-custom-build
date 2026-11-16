import KeeperCore
import TKCore
import TKUIKit
import UIKit

extension TKListItemIconView.Configuration {
    static func configuration(
        jettonInfo: JettonInfo,
        isNetworkBadgeVisible: Bool
    ) -> TKListItemIconView.Configuration {
        var badge: TKListItemIconView.Configuration.Badge?
        if isNetworkBadgeVisible {
            badge = Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.image(.TKUIKit.Icons.Size20.tonChain)),
                    size: .small
                ),
                position: .bottomRight
            )
        }

        let imageSource: TKImage = {
            if jettonInfo.isTonUSDT || jettonInfo.symbol?.uppercased() == "USDT" {
                return .image(.TKUIKit.Icons.Size44.currencyUsdt)
            }
            if jettonInfo.symbol?.uppercased() == "GRAM" {
                return .image(.TKUIKit.Icons.Size44.currencyGram)
            }
            return .urlImage(jettonInfo.imageURL)
        }()

        return TKListItemIconView.Configuration(
            content: .image(TKImageView.Model(image: imageSource, size: .size(CGSize(width: 44, height: 44)), corners: .circle)),
            alignment: .center,
            cornerRadius: 22,
            backgroundColor: .Background.contentTint,
            size: CGSize(width: 44, height: 44),
            badge: badge
        )
    }
}
