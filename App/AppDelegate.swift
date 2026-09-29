import CarPlay
import UIKit

/// Routes scene connections. With the SwiftUI lifecycle the phone scene is created by SwiftUI; the CarPlay scene
/// needs an explicit delegate class.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .carTemplateApplication {
            configuration.delegateClass = CarPlaySceneDelegate.self
        }
        return configuration
    }
}
