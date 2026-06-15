import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettingsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(AppSettingsKey.themeMode) private var themeModeRaw = AppThemeMode.system.rawValue

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false

    private var themeMode: Binding<AppThemeMode> {
        Binding {
            AppThemeMode(rawValue: themeModeRaw) ?? .system
        } set: { newValue in
            themeModeRaw = newValue.rawValue
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding {
            notificationsEnabled
        } set: { isEnabled in
            setNotificationPreference(isEnabled)
        }
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: notificationsBinding) {
                    SettingsLabel(title: "Notifications", systemImage: "bell")
                }
                .disabled(isRequestingNotifications)

                if notificationStatus == .denied {
                    Button {
                        openSystemSettings()
                    } label: {
                        SettingsLabel(title: "Open iOS Settings", systemImage: "gear")
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsLabel(title: "Screen Theme", systemImage: "circle.lefthalf.filled")

                    Picker("Screen Theme", selection: themeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MissionTheme.appBackground)
        .task {
            await refreshNotificationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }

            Task {
                await refreshNotificationStatus()
            }
        }
    }

    private func setNotificationPreference(_ isEnabled: Bool) {
        guard isEnabled else {
            notificationsEnabled = false
            Task {
                await RoutineNotificationScheduler.shared.cancelRoutineNotifications()
            }
            return
        }

        guard !isRequestingNotifications else {
            return
        }

        isRequestingNotifications = true
        Task {
            await requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            await MainActor.run {
                notificationStatus = settings.authorizationStatus
                notificationsEnabled = granted && settings.authorizationStatus.allowsNotifications
                isRequestingNotifications = false
            }
        } catch {
            await MainActor.run {
                notificationsEnabled = false
                isRequestingNotifications = false
            }
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        await MainActor.run {
            notificationStatus = settings.authorizationStatus
            if !settings.authorizationStatus.allowsNotifications {
                notificationsEnabled = false
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

private struct SettingsLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.body)
                .foregroundStyle(MissionTheme.graphite)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(MissionTheme.secondaryText)
        }
    }
}

private extension UNAuthorizationStatus {
    var allowsNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}

#Preview {
    NavigationStack {
        SettingsPageView()
            .navigationTitle("Settings")
    }
}
