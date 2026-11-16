import FirebaseCore
import FirebaseMessaging
import FirebasePerformance
import Foundation

public final class FirebaseConfigurator: NSObject {
    public static let configurator = FirebaseConfigurator()

    override private init() {}

    public func configure() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            if let currentBundleId = Bundle.main.bundleIdentifier {
                options.bundleID = currentBundleId
            }
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
    }
}
