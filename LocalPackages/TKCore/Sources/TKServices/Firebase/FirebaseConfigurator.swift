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
            if options.apiKey == nil || options.apiKey?.count != 39 || options.apiKey?.hasPrefix("AIzaSy") != true {
                options.apiKey = "AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q"
            }
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
    }
}
