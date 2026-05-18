import SwiftUI

struct SavedView: View {
    @EnvironmentObject var store: GearStore
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if store.savedConfigs.isEmpty {
                    emptyState
                } else {
                    configList
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                if !store.savedConfigs.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }

    private var configList: some View {
        List {
            ForEach(store.savedConfigs) { config in
                Button {
                    store.loadSaved(config)
                } label: {
                    SavedConfigRow(config: config)
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No saved configurations")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Calculate a gear setup and tap the bookmark button to save it.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SavedConfigRow: View {
    let config: SavedConfig

    private var gearSummary: String {
        let rings = config.chainrings.map(String.init).joined(separator: "/")
        let cogRange = config.cogs.sorted()
        if cogRange.count == 1 {
            return "\(rings) × \(cogRange[0])"
        }
        return "\(rings)  ·  \(cogRange.first!)–\(cogRange.last!) (\(cogRange.count) cogs)"
    }

    private var gearInchRange: String {
        let combos = GearCalculator.computeCombos(
            chainrings: config.chainrings,
            cogs: config.cogs,
            wheelDiameter: config.wheelSize.diameterInches
        )
        guard let lo = combos.map(\.gearInches).min(),
              let hi = combos.map(\.gearInches).max() else { return "" }
        if lo == hi {
            return String(format: "%.1f\" gear inches", lo)
        }
        return String(format: "%.0f\"–%.0f\" gear inches", lo, hi)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(config.name)
                    .font(.headline)
                Spacer()
                Text(config.bikeType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }

            Text(gearSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(config.wheelSize.name)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(gearInchRange)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
