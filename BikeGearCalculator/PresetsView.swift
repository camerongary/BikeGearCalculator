import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var store: GearStore

    // Borrow rider settings from a transient state so presets feel connected
    @State private var riderSettings = RiderSettings()

    var body: some View {
        NavigationStack {
            List {
                presetSection("Road Bike", presets: GearPreset.road, icon: "bicycle")
                presetSection("Mountain Bike", presets: GearPreset.mtb, icon: "mountain.2")
                presetSection("Fixed Gear", presets: GearPreset.fixed, icon: "infinity")
            }
            .contentMargins(.bottom, 90, for: .scrollContent)
            .navigationTitle("Presets")
        }
    }

    private func presetSection(_ title: String, presets: [GearPreset], icon: String) -> some View {
        Section {
            ForEach(presets) { preset in
                Button {
                    store.loadPreset(preset, riderSettings: riderSettings)
                } label: {
                    PresetRow(preset: preset)
                }
                .tint(.primary)
            }
        } header: {
            Label(title, systemImage: icon)
        }
    }
}

struct PresetRow: View {
    let preset: GearPreset

    private var gearInchRange: String {
        let combos = GearCalculator.computeCombos(
            chainrings: preset.chainrings,
            cogs: preset.cogs,
            wheelDiameter: preset.wheelSize.diameterInches
        )
        guard let lo = combos.map(\.gearInches).min(),
              let hi = combos.map(\.gearInches).max() else { return "" }
        return String(format: "%.0f\"–%.0f\" gear inches", lo, hi)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preset.name)
                .font(.body)
            HStack(spacing: 8) {
                Text(preset.wheelSize.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(gearInchRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
