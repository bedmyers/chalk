//
//  SettingsView.swift
//  Chalk
//

import ChalkCore
import Foundation
import SwiftUI

/// Links the app shows. Set before the first TestFlight build.
enum AppLinks {
    /// TODO: Set to the hosted privacy policy (see docs/privacy-policy.md) before TestFlight.
    static let privacyPolicy: URL? = nil
}

/// App-wide preferences and information.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    /// The unit new programs start with. Existing programs keep their own.
    @AppStorage("defaultUnit") private var defaultUnitRaw = WeightUnit.pounds.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Default unit", selection: $defaultUnitRaw) {
                        Text("Pounds").tag(WeightUnit.pounds.rawValue)
                        Text("Kilograms").tag(WeightUnit.kilograms.rawValue)
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Used for new programs. Existing programs keep their unit.")
                }
                .chalkRow()

                Section {
                    Text("Your programs and workouts are stored on this device and synced through your own iCloud account. Chalk has no accounts and doesn't collect or share your data.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if let privacyPolicy = AppLinks.privacyPolicy {
                        Link("Privacy Policy", destination: privacyPolicy)
                    }
                } header: {
                    Text("Your data")
                }
                .chalkRow()

                Section("About") {
                    LabeledContent("Version", value: AppVersion.display)
                }
                .chalkRow()
            }
            .chalkListStyle()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

nonisolated enum AppVersion {
    /// "1.0 (1)", from the bundle's version and build number.
    static var display: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
#endif
