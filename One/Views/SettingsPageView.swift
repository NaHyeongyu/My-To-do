import SwiftData
import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppSettingsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(AppSettingsKey.themeMode) private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage(AppSettingsKey.customRoutineLabels) private var customRoutineLabelsRaw = CustomRoutineLabelStore.emptyStorage

    @Query(sort: \ScheduleItem.createdAt, order: .reverse) private var items: [ScheduleItem]

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false
    @State private var customLabelTitle = ""
    @State private var customLabelSymbolName = CustomRoutineLabel.defaultSymbolName

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

            customLabelsSection
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

    private var customLabelsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                SettingsLabel(title: "Custom Labels", systemImage: "tag")

                HStack(spacing: 10) {
                    TextField("New label", text: $customLabelTitle)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(addCustomLabel)

                    Button(action: addCustomLabel) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .disabled(!canAddCustomLabel)
                    .accessibilityLabel("Add custom label")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CustomRoutineLabelStore.availableSymbolNames, id: \.self) { symbolName in
                            Button {
                                customLabelSymbolName = symbolName
                            } label: {
                                Image(systemName: symbolName)
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 32, height: 32)
                            }
                            .foregroundStyle(customLabelSymbolName == symbolName ? MissionTheme.selectedText : MissionTheme.graphite)
                            .background(
                                customLabelSymbolName == symbolName ? MissionTheme.selection : MissionTheme.controlFill,
                                in: Circle()
                            )
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(customLabelSymbolName == symbolName ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }

                if !customRoutineLabels.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(customRoutineLabels) { label in
                            CustomRoutineLabelRow(label: label) {
                                deleteCustomLabel(label)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var customRoutineLabels: [CustomRoutineLabel] {
        CustomRoutineLabelStore.labels(from: customRoutineLabelsRaw)
    }

    private var routineLabelOptions: [RoutineLabelOption] {
        RoutineLabelOption.options(customLabels: customRoutineLabels)
    }

    private var trimmedCustomLabelTitle: String {
        customLabelTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAddCustomLabel: Bool {
        guard !trimmedCustomLabelTitle.isEmpty else {
            return false
        }

        return !routineLabelOptions.contains {
            $0.title.compare(trimmedCustomLabelTitle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
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

    private func addCustomLabel() {
        guard canAddCustomLabel else {
            return
        }

        var labels = customRoutineLabels
        labels.append(CustomRoutineLabel(title: trimmedCustomLabelTitle, symbolName: customLabelSymbolName))
        customRoutineLabelsRaw = CustomRoutineLabelStore.encoded(labels)
        customLabelTitle = ""
        customLabelSymbolName = CustomRoutineLabel.defaultSymbolName
    }

    private func deleteCustomLabel(_ label: CustomRoutineLabel) {
        let labels = customRoutineLabels.filter { $0.id != label.id }
        customRoutineLabelsRaw = CustomRoutineLabelStore.encoded(labels)

        for item in items where item.routineLabelRawValue == label.id {
            item.routineLabelRawValue = nil
        }

        try? modelContext.save()
    }
}

private struct CustomRoutineLabelRow: View {
    let label: CustomRoutineLabel
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoutineLabelBadge(
                label: label.option,
                fillsWidth: false,
                fixedWidth: 140,
                font: .caption.weight(.semibold),
                iconSize: 12,
                height: 30,
                horizontalPadding: 9
            )

            Spacer(minLength: 8)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(label.title)")
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
