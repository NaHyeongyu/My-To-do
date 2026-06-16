import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettingsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(AppSettingsKey.themeMode) private var themeModeRaw = AppThemeMode.system.rawValue

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false
    @State private var routineLabelTargetMinutes: [RoutineLabel: Int] = [:]

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
                        SettingsLabel(title: "Open Settings", systemImage: "gear")
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

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsLabel(title: "Weekly Label Targets", systemImage: "scope")

                    VStack(spacing: 12) {
                        ForEach(RoutineLabel.allCases) { label in
                            RoutineLabelTargetRow(
                                label: label,
                                minutes: targetMinutesBinding(for: label)
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Targets are used by Streak to show remaining time and risk by label.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MissionTheme.appBackground)
        .onAppear {
            loadRoutineLabelTargets()
        }
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

    private func loadRoutineLabelTargets() {
        routineLabelTargetMinutes = Dictionary(
            uniqueKeysWithValues: RoutineLabel.allCases.map {
                ($0, RoutineLabelTargetStore.weeklyTargetMinutes(for: $0))
            }
        )
    }

    private func targetMinutesBinding(for label: RoutineLabel) -> Binding<Int> {
        Binding {
            routineLabelTargetMinutes[label] ?? RoutineLabelTargetStore.weeklyTargetMinutes(for: label)
        } set: { newValue in
            RoutineLabelTargetStore.setWeeklyTargetMinutes(newValue, for: label)
            routineLabelTargetMinutes[label] = RoutineLabelTargetStore.weeklyTargetMinutes(for: label)
        }
    }
}

private struct RoutineLabelTargetRow: View {
    let label: RoutineLabel
    @Binding var minutes: Int

    private var targetText: String {
        minutes == 0 ? "Off" : minutes.readableDuration
    }

    var body: some View {
        HStack(spacing: 12) {
            RoutineLabelBadge(
                label: label,
                fillsWidth: false,
                fixedWidth: 120,
                font: .caption.weight(.semibold),
                iconSize: 12,
                height: 30,
                horizontalPadding: 9
            )

            Spacer(minLength: 8)

            Stepper(
                value: $minutes,
                in: 0...RoutineLabelTargetStore.maximumWeeklyTargetMinutes,
                step: RoutineLabelTargetStore.targetStepMinutes
            ) {
                Text(targetText)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(MissionTheme.graphite)
                    .lineLimit(1)
                    .frame(minWidth: 58, alignment: .trailing)
            }
            .accessibilityLabel("\(label.title) weekly target")
            .accessibilityValue(targetText)
        }
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
