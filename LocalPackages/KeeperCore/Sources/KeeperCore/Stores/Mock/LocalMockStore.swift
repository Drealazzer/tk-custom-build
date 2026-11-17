import BigInt
import Foundation
import TonSwift
import UIKit
import UserNotifications

public final class LocalMockStore: @unchecked Sendable {
    public static let shared = LocalMockStore()
    public static let didChangeNotification = Notification.Name("LocalMockStoreDidChangeNotification")

    private struct State: Codable {
        var isEnabled: Bool
        var tonBalance: Decimal?
        var tokens: [MockTokenBalance]
        var events: [MockHistoryEvent]
        var nfts: [MockNFTItem]

        init(isEnabled: Bool, tonBalance: Decimal?, tokens: [MockTokenBalance], events: [MockHistoryEvent], nfts: [MockNFTItem] = []) {
            self.isEnabled = isEnabled
            self.tonBalance = tonBalance
            self.tokens = tokens
            self.events = events
            self.nfts = nfts
        }

        enum CodingKeys: String, CodingKey {
            case isEnabled, tonBalance, tokens, events, nfts
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
            tonBalance = try c.decodeIfPresent(Decimal.self, forKey: .tonBalance)
            tokens = try c.decode([MockTokenBalance].self, forKey: .tokens)
            events = try c.decode([MockHistoryEvent].self, forKey: .events)
            nfts = (try? c.decodeIfPresent([MockNFTItem].self, forKey: .nfts)) ?? []
        }
    }

    private let userDefaultsKey = "tonkeeper_custom_mock_store_v1"
    private let lock = NSLock()
    private var storedState: State

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           var state = try? JSONDecoder().decode(State.self, from: data) {
            state.tokens = state.tokens.filter {
                $0.symbol.uppercased() == "TON" || $0.symbol.uppercased() == "USDT" || $0.symbol == "USD₮"
            }
            if !state.tokens.contains(where: { $0.symbol.uppercased() == "USDT" || $0.symbol == "USD₮" }) {
                state.tokens.append(MockTokenBalance.popularPresets[1])
            }
            if !state.tokens.contains(where: { $0.symbol.uppercased() == "TON" }) {
                state.tokens.insert(MockTokenBalance.popularPresets[0], at: 0)
            }
            if let idx = state.tokens.firstIndex(where: { $0.symbol.uppercased() == "USDT" || $0.symbol == "USD₮" }) {
                state.tokens[idx].symbol = "USD₮"
                if state.tokens[idx].customPriceUSD == nil || state.tokens[idx].customPriceUSD == 1.0 {
                    state.tokens[idx].customPriceUSD = 0.99
                }
            }
            for i in 0..<state.nfts.count {
                if state.nfts[i].type == .tonDNS,
                   let img = state.nfts[i].imageURL,
                   img.contains("cache.tonapi.io/img/dns") {
                    state.nfts[i].imageURL = nil
                }
            }
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
            events: Self.makeDefaultEvents(),
            nfts: []
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

    public var mockNFTs: [MockNFTItem] {
        lock.lock()
        defer { lock.unlock() }
        return storedState.nfts
    }

    public func addMockNFT(_ item: MockNFTItem) {
        lock.lock()
        storedState.nfts.removeAll { $0.id == item.id }
        storedState.nfts.append(item)
        lock.unlock()
        persistAndNotify()
    }

    public func removeMockNFT(id: String) {
        lock.lock()
        storedState.nfts.removeAll { $0.id == id }
        lock.unlock()
        persistAndNotify()
    }

    public func makeNFTs(wallet: Wallet) -> [NFT] {
        lock.lock()
        let items = storedState.nfts
        lock.unlock()

        let walletAddress: Address = (try? wallet.address) ?? (try! Address.parse("0:0000000000000000000000000000000000000000000000000000000000000000"))

        return items.compactMap { item -> NFT? in
            let hexId = Data(item.id.utf8).map { String(format: "%02x", $0) }.joined()
            let padded = String((hexId + String(repeating: "0", count: 64)).prefix(64))
            guard let nftAddress = try? Address.parse(raw: "0:\(padded)") else { return nil }

            let cleanUsername = (item.username ?? item.name).trimmingCharacters(in: CharacterSet(charactersIn: "@ "))

            let collectionName: String = {
                if let name = item.collectionName, !name.isEmpty { return name }
                switch item.type {
                case .tonDNS: return "TON DNS Domains"
                case .telegramUsername: return "Telegram Usernames"
                case .telegramGift: return "Telegram Gifts"
                }
            }()

            let collectionDesc: String? = {
                if let desc = item.collectionDescription, !desc.isEmpty { return desc }
                switch item.type {
                case .tonDNS:
                    return "*.ton domains"
                case .telegramUsername:
                    return "Unique addresses in Telegram's ecosystem of more than 700 million active users."
                case .telegramGift:
                    return "\(collectionName) is an exclusive NFT collection by Telegram. Owners can showcase these unique gifts on Telegram."
                }
            }()

            let collection: NFTCollection?
            let collectionHex = Data(collectionName.utf8).map { String(format: "%02x", $0) }.joined()
            let collectionPadded = String((collectionHex + String(repeating: "0", count: 64)).prefix(64))
            if let collectionAddr = try? Address.parse(raw: "0:\(collectionPadded)") {
                collection = NFTCollection(address: collectionAddr, name: collectionName, description: collectionDesc)
            } else {
                collection = nil
            }

            let previewURL: URL? = {
                if item.type == .tonDNS {
                    if let raw = item.imageURL, !raw.contains("cache.tonapi.io/img/dns"), let url = URL(string: raw), !raw.isEmpty {
                        return url
                    }
                    return Self.generateTONDNSImageURL(domain: item.dns ?? item.name)
                }
                if let raw = item.imageURL, let url = URL(string: raw) {
                    return url
                }
                if item.type == .telegramUsername {
                    return URL(string: "https://nft.fragment.com/username/\(cleanUsername).webp")
                }
                return nil
            }()

            let preview = NFT.Preview(size5: previewURL, size100: previewURL, size500: previewURL, size1500: previewURL)

            let lottieURL: URL? = {
                if item.type == .telegramGift, let fragment = item.fragmentURL {
                    return URL(string: fragment)
                }
                return nil
            }()

            let programmaticButtons: [NFT.Button]? = {
                switch item.type {
                case .tonDNS:
                    return [NFT.Button(label: "Manage", style: "primary", url: URL(string: "https://dns.ton.org"))]
                case .telegramUsername:
                    return [NFT.Button(label: "Manage", style: "primary", url: URL(string: "https://fragment.com/username/\(cleanUsername)"))]
                case .telegramGift:
                    return nil
                }
            }()

            let attributes: [NFT.Attribute] = []

            let nftDescription: String? = {
                if let desc = item.description, !desc.isEmpty { return desc }
                switch item.type {
                case .tonDNS:
                    return nil
                case .telegramUsername:
                    return "The @\(cleanUsername) username on Telegram.\nAliases: \(cleanUsername).t.me, t.me/\(cleanUsername)"
                case .telegramGift:
                    return "\(item.name) collectible gift by Telegram."
                }
            }()

            let resolvedDNS: String? = {
                switch item.type {
                case .tonDNS:
                    return item.dns ?? item.name
                case .telegramUsername:
                    return "\(cleanUsername).t.me"
                case .telegramGift:
                    return nil
                }
            }()

            return NFT(
                address: nftAddress,
                owner: WalletAccount(address: walletAddress, name: nil, isScam: false, isWallet: true),
                name: item.name,
                imageURL: previewURL,
                preview: preview,
                description: nftDescription,
                attributes: attributes,
                collection: collection,
                programmaticButtons: programmaticButtons,
                dns: resolvedDNS,
                sale: nil,
                trust: .whitelist,
                renderType: nil,
                lottieURL: lottieURL
            )
        }
    }

    public static func generateTONDNSImageURL(domain: String) -> URL? {
        let clean = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }

        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        let safeName = clean.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let fileURL = cachesDir.appendingPathComponent("ton_dns_\(safeName).png")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let size = CGSize(width: 800, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 215 / 255.0, green: 236 / 255.0, blue: 252 / 255.0, alpha: 1.0).cgColor,
                UIColor(red: 238 / 255.0, green: 247 / 255.0, blue: 255 / 255.0, alpha: 1.0).cgColor,
                UIColor(white: 1.0, alpha: 1.0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.55, 1.0]
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            }

            let circleRect = CGRect(x: 48, y: 48, width: 92, height: 92)
            cg.setFillColor(UIColor.black.cgColor)
            cg.fillEllipse(in: circleRect)

            drawTONSymbol(in: circleRect, context: cg)

            let text = clean.hasSuffix(".ton") ? clean : "\(clean).ton"
            let badgeWidth = min(size.width - 64, max(380, CGFloat(text.count) * 36 + 120))
            let badgeHeight: CGFloat = 144
            let badgeRect = CGRect(
                x: (size.width - badgeWidth) / 2,
                y: (size.height - badgeHeight) / 2,
                width: badgeWidth,
                height: badgeHeight
            )
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 36)
            cg.setShadow(offset: CGSize(width: 0, height: 6), blur: 18, color: UIColor.black.withAlphaComponent(0.08).cgColor)
            cg.setFillColor(UIColor.white.cgColor)
            badgePath.fill()
            cg.setShadow(offset: .zero, blur: 0, color: nil)

            let fontSize: CGFloat = min(54, max(28, (badgeWidth - 48) / CGFloat(max(6, text.count)) * 1.5))
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(
                x: badgeRect.minX + 16,
                y: badgeRect.midY - font.lineHeight / 2,
                width: badgeRect.width - 32,
                height: font.lineHeight
            )
            (text as NSString).draw(in: textRect, withAttributes: attrs)
        }

        if let data = image.pngData() {
            try? data.write(to: fileURL)
        }
        return fileURL
    }

    private static func drawTONSymbol(in circleRect: CGRect, context cg: CGContext) {
        let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
        let s: CGFloat = 22

        let path = UIBezierPath()
        path.move(to: CGPoint(x: center.x, y: center.y - s))
        path.addLine(to: CGPoint(x: center.x - s * 0.9, y: center.y + s * 0.1))
        path.addLine(to: CGPoint(x: center.x, y: center.y + s * 1.05))
        path.addLine(to: CGPoint(x: center.x + s * 0.9, y: center.y + s * 0.1))
        path.close()

        cg.setFillColor(UIColor.white.cgColor)
        path.fill()

        cg.setStrokeColor(UIColor.black.cgColor)
        cg.setLineWidth(1.5)
        let inner = UIBezierPath()
        inner.move(to: CGPoint(x: center.x, y: center.y - s))
        inner.addLine(to: CGPoint(x: center.x, y: center.y + s * 1.05))
        inner.move(to: CGPoint(x: center.x - s * 0.9, y: center.y + s * 0.1))
        inner.addLine(to: CGPoint(x: center.x + s * 0.9, y: center.y + s * 0.1))
        cg.addPath(inner.cgPath)
        cg.strokePath()
    }

    public func applyWhalePreset() {
        lock.lock()
        let now = Date()
        let whaleTon = Decimal(65_000)
        let whaleUsdt = Decimal(850_000)

        storedState.isEnabled = true
        storedState.tonBalance = whaleTon
        storedState.tokens = [
            MockTokenBalance(
                name: "Toncoin",
                symbol: "TON",
                address: nil,
                fractionDigits: 9,
                amount: whaleTon,
                customPriceUSD: 5.5,
                imageURL: nil
            ),
            MockTokenBalance(
                name: "Tether USD",
                symbol: "USD₮",
                address: JettonMasterAddress.tonUSDT.toRaw(),
                fractionDigits: 6,
                amount: whaleUsdt,
                customPriceUSD: 0.99,
                imageURL: "https://cache.tonapi.io/img/token/usdt.png"
            ),
        ]

        storedState.events = [
            MockHistoryEvent(
                type: .incoming,
                tokenSymbol: "USDT",
                tokenAddress: JettonMasterAddress.tonUSDT.toRaw(),
                fractionDigits: 6,
                amount: Decimal(350_000),
                counterpartyAddress: "UQBybitHotWallet6WithdrawalsTONNetwork",
                comment: "Withdrawal #89218",
                timestamp: now.addingTimeInterval(-1800),
                status: .success
            ),
            MockHistoryEvent(
                type: .incoming,
                tokenSymbol: "TON",
                tokenAddress: nil,
                fractionDigits: 9,
                amount: Decimal(25_000),
                counterpartyAddress: "UQFragmentAuctionPayoutSystemTonkeeper",
                comment: "Auction payout: @investor",
                timestamp: now.addingTimeInterval(-14400),
                status: .success
            ),
            MockHistoryEvent(
                type: .incoming,
                tokenSymbol: "USDT",
                tokenAddress: JettonMasterAddress.tonUSDT.toRaw(),
                fractionDigits: 6,
                amount: Decimal(500_000),
                counterpartyAddress: "UQOKXOfficialExchangeColdWalletSettlement",
                comment: "Internal transfer",
                timestamp: now.addingTimeInterval(-43200),
                status: .success
            ),
            MockHistoryEvent(
                type: .incoming,
                tokenSymbol: "TON",
                tokenAddress: nil,
                fractionDigits: 9,
                amount: Decimal(1_250),
                counterpartyAddress: "UQTonstakersPoolStakingRewardsValidator",
                comment: "Staking APY Reward",
                timestamp: now.addingTimeInterval(-86400),
                status: .success
            ),
            MockHistoryEvent(
                type: .swap,
                tokenSymbol: "TON",
                tokenAddress: nil,
                fractionDigits: 9,
                amount: Decimal(38_750),
                counterpartyAddress: "STON.fi DEX Router",
                comment: nil,
                timestamp: now.addingTimeInterval(-172800),
                status: .success
            ),
            MockHistoryEvent(
                type: .outgoing,
                tokenSymbol: "USDT",
                tokenAddress: JettonMasterAddress.tonUSDT.toRaw(),
                fractionDigits: 6,
                amount: Decimal(10_000),
                counterpartyAddress: "UQDFf1234567890abcdefAlicePartnerPayment",
                comment: "Services renewal",
                timestamp: now.addingTimeInterval(-259200),
                status: .success
            ),
            MockHistoryEvent(
                type: .incoming,
                tokenSymbol: "USDT",
                tokenAddress: JettonMasterAddress.tonUSDT.toRaw(),
                fractionDigits: 6,
                amount: Decimal(150_000),
                counterpartyAddress: "UQBinanceInstitutionalSettlementDeposit",
                comment: "OTC Settlement",
                timestamp: now.addingTimeInterval(-345600),
                status: .success
            ),
        ]

        storedState.nfts = [
            MockNFTItem(
                type: .telegramUsername,
                name: "@investor",
                collectionName: "Telegram Usernames",
                imageURL: "https://nft.fragment.com/username/investor.webp",
                dns: "investor.t.me",
                username: "@investor",
                fragmentURL: nil,
                description: "The @investor username on Telegram.\nAliases: investor.t.me, t.me/investor",
                collectionDescription: "Unique addresses in Telegram's ecosystem of more than 700 million active users.",
                attributes: []
            ),
            MockNFTItem(
                type: .tonDNS,
                name: "whale.ton",
                collectionName: "TON DNS Domains",
                imageURL: nil,
                dns: "whale.ton",
                username: nil,
                fragmentURL: nil,
                description: nil,
                collectionDescription: "*.ton domains",
                attributes: []
            ),
            MockNFTItem(
                type: .telegramGift,
                name: "Resistance Dog #16789",
                collectionName: "Resistance Dogs",
                imageURL: "https://nft.fragment.com/gift/ResistanceDog-16789.webp",
                dns: nil,
                username: nil,
                fragmentURL: "https://nft.fragment.com/gift/ResistanceDog-16789.tgs",
                description: "An exclusive Resistance Dog with unique appearance and charm.",
                collectionDescription: "Resistance Dogs is an exclusive NFT collection by Telegram. Owners can showcase these unique gifts on Telegram.",
                attributes: []
            )
        ]
        lock.unlock()
        persistAndNotify()
    }

    public func schedulePushTransfer(
        tokenSymbol: String,
        amount: Decimal,
        delaySeconds: TimeInterval,
        comment: String? = nil,
        senderName: String? = nil,
        senderAddress: String? = nil
    ) {
        let isTon = tokenSymbol.uppercased() == "TON" || tokenSymbol.uppercased() == "GRAM"
        let displaySymbol = isTon ? "Gram" : "USD₮"
        let tokenAddress = isTon ? nil : JettonMasterAddress.tonUSDT.toRaw()
        let fractionDigits = isTon ? 9 : 6
        let commentText = (comment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? "\n«\(comment!)»" : ""
        let title = senderName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? senderName! : "Tonkeeper"
        let body = "Получено \(amount) \(displaySymbol)\(commentText)"
        let rawSender = senderAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSender = (rawSender?.isEmpty == false) ? rawSender! : "UQCNohVHSvqtavYW5IyRg0_666TY7pwL4SorNQRDGmv8NhKF"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { _ in }

        DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            if isTon {
                let current = self.storedState.tonBalance ?? 0
                self.storedState.tonBalance = current + amount
                if let idx = self.storedState.tokens.firstIndex(where: { $0.symbol.uppercased() == "TON" }) {
                    self.storedState.tokens[idx].amount = current + amount
                }
            } else {
                if let idx = self.storedState.tokens.firstIndex(where: { $0.symbol.uppercased() == "USDT" || $0.symbol == "USD₮" }) {
                    self.storedState.tokens[idx].amount += amount
                } else {
                    self.storedState.tokens.append(
                        MockTokenBalance(
                            name: "Tether USD",
                            symbol: "USD₮",
                            address: JettonMasterAddress.tonUSDT.toRaw(),
                            fractionDigits: 6,
                            amount: amount,
                            customPriceUSD: 0.99,
                            imageURL: "https://cache.tonapi.io/img/token/usdt.png"
                        )
                    )
                }
            }

            let newEvent = MockHistoryEvent(
                type: .incoming,
                tokenSymbol: isTon ? "TON" : "USD₮",
                tokenAddress: tokenAddress,
                fractionDigits: fractionDigits,
                amount: amount,
                counterpartyAddress: resolvedSender,
                comment: comment,
                timestamp: Date(),
                status: .success
            )
            self.storedState.events.insert(newEvent, at: 0)
            self.lock.unlock()

            DispatchQueue.main.async {
                self.persistAndNotify()
            }
        }
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

        var seenAddresses = Set<Address>()
        var result = [ProcessedBalanceJettonItem]()

        for token in tokens {
            let addressStr = token.address ?? ""
            let jettonAddress: Address = {
                if let raw = try? Address.parse(raw: addressStr) {
                    return raw
                }
                if let parsed = try? Address.parse(addressStr) {
                    return parsed
                }
                let hexSymbol = Data(token.symbol.utf8).map { String(format: "%02x", $0) }.joined()
                let padded = String((hexSymbol + String(repeating: "0", count: 64)).prefix(64))
                return (try? Address.parse(raw: "0:\(padded)")) ?? JettonMasterAddress.tonUSDT
            }()

            guard !seenAddresses.contains(jettonAddress) else { continue }
            seenAddresses.insert(jettonAddress)

            let isUSDT = token.symbol.uppercased() == "USDT" || token.symbol == "USD₮"
            let tokenImageURL: URL? = {
                if let raw = token.imageURL, let url = URL(string: raw) {
                    return url
                }
                if isUSDT {
                    return URL(string: "https://cache.tonapi.io/img/token/usdt.png")
                }
                switch token.symbol.uppercased() {
                case "NOT":
                    return URL(string: "https://cache.tonapi.io/img/token/notcoin.png")
                case "DOGS":
                    return URL(string: "https://cache.tonapi.io/img/token/dogs.png")
                case "GRAM":
                    return URL(string: "https://cache.tonapi.io/img/token/gram.png")
                default:
                    return nil
                }
            }()

            let jettonInfo = JettonInfo(
                isTransferable: true,
                hasCustomPayload: false,
                address: jettonAddress,
                fractionDigits: token.fractionDigits,
                name: token.name,
                symbol: isUSDT ? "USD₮" : token.symbol,
                verification: .whitelist,
                imageURL: tokenImageURL
            )
            let jettonItem = JettonItem(jettonInfo: jettonInfo, walletAddress: nil)

            let rate: Rates.Rate? = {
                if let ratesList = jettonRates[addressStr] ?? jettonRates[token.symbol],
                   let found = ratesList.first(where: { $0.currency == currency }) {
                    return found
                }
                if isUSDT {
                    let custom = token.customPriceUSD ?? 0.99
                    return Rates.Rate(currency: currency, rate: custom, diff24h: "0.0%")
                }
                if let customPrice = token.customPriceUSD {
                    return Rates.Rate(currency: currency, rate: customPrice, diff24h: nil)
                }
                return nil
            }()

            let price = rate?.rate ?? token.customPriceUSD ?? (isUSDT ? 0.99 : 0)
            let converted = token.amount * price
            let rawQuantity = Self.decimalToBigUInt(token.amount, fractionDigits: token.fractionDigits)

            result.append(
                ProcessedBalanceJettonItem(
                    id: jettonAddress.toRaw(),
                    jetton: jettonItem,
                    amount: rawQuantity,
                    fractionalDigits: token.fractionDigits,
                    tag: isUSDT ? "TON" : nil,
                    currency: currency,
                    converted: converted,
                    price: price,
                    diff: rate?.diff24h,
                    shouldCalculateInTotal: true
                )
            )
        }
        return result
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
                let isEventUSDT = mockEvent.tokenSymbol.uppercased() == "USDT" || mockEvent.tokenSymbol == "USD₮"
                let jettonAddress: Address = {
                    if let raw = mockEvent.tokenAddress, let addr = try? Address.parse(raw) {
                        return addr
                    }
                    if isEventUSDT {
                        return JettonMasterAddress.tonUSDT
                    }
                    return walletAddress
                }()
                let eventImageURL: URL? = {
                    if isEventUSDT {
                        return URL(string: "https://cache.tonapi.io/img/token/usdt.png")
                    }
                    switch mockEvent.tokenSymbol.uppercased() {
                    case "NOT":
                        return URL(string: "https://cache.tonapi.io/img/token/notcoin.png")
                    case "DOGS":
                        return URL(string: "https://cache.tonapi.io/img/token/dogs.png")
                    case "GRAM":
                        return URL(string: "https://cache.tonapi.io/img/token/gram.png")
                    default:
                        return nil
                    }
                }()

                let jettonInfo = JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: jettonAddress,
                    fractionDigits: mockEvent.fractionDigits,
                    name: isEventUSDT ? "Tether USD" : mockEvent.tokenSymbol,
                    symbol: isEventUSDT ? "USD₮" : mockEvent.tokenSymbol,
                    verification: .whitelist,
                    imageURL: eventImageURL
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
