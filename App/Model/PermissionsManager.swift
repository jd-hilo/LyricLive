import ActivityKit
import AVFoundation
import Foundation
import MediaPlayer
import UserNotifications

enum PermissionStatus: Equatable {
    case notDetermined
    case granted
    case denied
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var appleMusic: PermissionStatus = .notDetermined
    @Published private(set) var microphone: PermissionStatus = .notDetermined
    @Published private(set) var notifications: PermissionStatus = .notDetermined
    @Published private(set) var liveActivitiesEnabled = true

    init() {
        refreshSynchronous()
    }

    func refresh() async {
        refreshSynchronous()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = Self.map(settings.authorizationStatus)
    }

    private func refreshSynchronous() {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized: appleMusic = .granted
        case .notDetermined: appleMusic = .notDetermined
        default: appleMusic = .denied
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted: microphone = .granted
        case .undetermined: microphone = .notDetermined
        default: microphone = .denied
        }
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func requestMicrophone() async {
        _ = await AVAudioApplication.requestRecordPermission()
        await refresh()
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }

    private static func map(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
