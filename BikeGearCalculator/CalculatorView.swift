import SwiftUI
import Charts

extension GearCombo {
    private static let duplicateColors: [Color] = [.orange, .purple, .cyan, .pink, .mint, .yellow]

    var duplicateColor: Color? {
        guard let g = duplicateGroup else { return nil }
        return GearCombo.duplicateColors[(g - 1) % GearCombo.duplicateColors.count]
    }
}

// Carries all data needed by ResultsView through the navigation path,
// avoiding @State capture timing issues in navigationDestination closures.
private struct ResultsPayload: Hashable {
    let id = UUID()
    let combos: [GearCombo]
    let riderSettings: RiderSettings
    let bikeType: BikeType
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// Same pattern for the gear finder (Find Gear mode).
private struct FinderPayload: Hashable {
    let id = UUID()
    let suggestions: [GearSuggestion]
    let targetSpeed: Double        // in the unit the user entered
    let cadence: Double
    let useKmh: Bool
    let requiredInches: Double
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

enum CalcMode: String, CaseIterable, Identifiable {
    case findSpeed = "Find Speed"
    case findGear = "Find Gear"
    var id: String { rawValue }
}

// MARK: - Calculator (inputs)

struct CalculatorView: View {
    @EnvironmentObject var store: GearStore

    @State private var bikeType: BikeType = .road
    @State private var wheelSize: WheelSize = WheelSize.catalog[1]

    // Road/MTB chainrings
    @State private var chainringValues: [Int] = [53, 39]

    // Cassette
    @State private var selectedSpeeds: Int = 11
    @State private var selectedCassetteID: String = "shi_r_11_11_28"
    @State private var customCogsText: String = "11, 12, 13, 14, 15, 17, 19, 21, 23, 25, 28"

    // Fixed gear dials
    @State private var fixedChainring: Int = 48
    @State private var fixedCog: Int = 16
    @State private var fixedCompareEnabled: Bool = false
    @State private var fixedChainring2: Int = 46
    @State private var fixedCog2: Int = 16

    @State private var riderSettings = RiderSettings()
    @State private var navigationPath = NavigationPath()
    @State private var currentConfigID: UUID? = nil
    @State private var showMethodsSheet = false

    // Gear finder (Find Gear mode)
    @State private var calcMode: CalcMode = .findSpeed
    @State private var targetSpeed: Double = 30.0   // in the user's speed unit
    @State private var targetCadence: Double = 90

    // MARK: Derived

    private var chainrings: [Int] {
        bikeType == .fixed ? [fixedChainring] : chainringValues.filter { $0 > 0 }
    }

    private var cogs: [Int] {
        if bikeType == .fixed { return [fixedCog] }
        if selectedCassetteID == "custom" { return parseInts(customCogsText) }
        return CassettePreset.all.first { $0.id == selectedCassetteID }?.cogs ?? []
    }

    private var filteredCassettes: [CassettePreset] {
        CassettePreset.all.filter {
            $0.speeds == selectedSpeeds && (bikeType == .road ? $0.forRoad : $0.forMTB)
        }
    }

    private var speedOptions: [Int] {
        bikeType == .mtb ? [10, 11, 12] : [8, 9, 10, 11, 12, 13]
    }

    // MARK: Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                calculateButton
                modeSection
                if calcMode == .findSpeed {
                    bikeTypeSection
                    wheelSection
                    gearingSection
                    riderSection
                } else {
                    wheelSection
                    finderSection
                }
                methodsButton
            }
            .navigationTitle("🚲 Cameron's Gear Calculator 🧮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("🚲 Cameron's Gear Calculator 🧮")
                        .font(.title3.weight(.semibold))
                }
            }
            .onAppear {
                riderSettings = store.loadRiderSettings()
            }
            .onChange(of: riderSettings) { _, settings in
                store.saveRiderSettings(settings)
            }
            .onChange(of: store.pendingLoad) { _, load in
                guard let load else { return }
                applyLoad(load)
                store.pendingLoad = nil
            }
            .navigationDestination(for: ResultsPayload.self) { payload in
                ResultsView(
                    combos: payload.combos,
                    riderSettings: payload.riderSettings,
                    bikeType: payload.bikeType,
                    onSave: { name in persistConfig(name: name) }
                )
            }
            .navigationDestination(for: FinderPayload.self) { payload in
                GearFinderResultsView(
                    suggestions: payload.suggestions,
                    targetSpeed: payload.targetSpeed,
                    cadence: payload.cadence,
                    useKmh: payload.useKmh,
                    requiredInches: payload.requiredInches
                )
            }
            .sheet(isPresented: $showMethodsSheet) {
                MethodsView()
            }
        }
    }

    // MARK: - Sections

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: $calcMode) {
                ForEach(CalcMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var finderSection: some View {
        Section("Target") {
            HStack {
                Text("Speed")
                Spacer()
                Stepper(
                    String(format: "%.1f %@", targetSpeed, riderSettings.speedUnit),
                    value: $targetSpeed, in: 5...80, step: 0.5
                )
            }

            HStack {
                Text("Cadence")
                Spacer()
                Stepper("\(Int(targetCadence)) rpm", value: $targetCadence, in: 40...140, step: 5)
            }

            Toggle(isOn: $riderSettings.useKmh) {
                Text("Speed in km/h")
            }

            Text(String(format: "Requires %.1f\" gear inches", requiredInchesForTarget))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var targetSpeedMph: Double {
        riderSettings.useKmh ? targetSpeed / 1.60934 : targetSpeed
    }

    private var requiredInchesForTarget: Double {
        GearCalculator.requiredGearInches(targetMph: targetSpeedMph, rpm: targetCadence)
    }

    private var bikeTypeSection: some View {
        Section("Bike Type") {
            Picker("Type", selection: $bikeType) {
                ForEach(BikeType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: bikeType) { applyBikeTypeDefaults() }
        }
    }

    private var wheelSection: some View {
        Section("Wheel Size") {
            Picker("Wheel", selection: $wheelSize) {
                ForEach(WheelSize.catalog) { ws in Text(ws.name).tag(ws) }
            }
        }
    }

    @ViewBuilder
    private var gearingSection: some View {
        if bikeType == .fixed {
            Section("Fixed Gearing") {
                Toggle("Compare two setups", isOn: $fixedCompareEnabled)

                fixedGearDialRow(
                    label: fixedCompareEnabled ? "Setup 1" : nil,
                    chainring: $fixedChainring,
                    cog: $fixedCog
                )

                if fixedCompareEnabled {
                    Divider()
                    fixedGearDialRow(
                        label: "Setup 2",
                        chainring: $fixedChainring2,
                        cog: $fixedCog2
                    )
                }
            }
        } else {
            Section("Chainrings") {
                ForEach(chainringValues.indices, id: \.self) { i in
                    LabeledContent("Ring \(i + 1)") {
                        Stepper("\(chainringValues[i])t", value: $chainringValues[i], in: 20...60)
                    }
                }
                HStack {
                    if chainringValues.count > 1 {
                        Button(role: .destructive) {
                            chainringValues.removeLast()
                        } label: {
                            Label("Remove last", systemImage: "minus.circle").font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                    if chainringValues.count < 3 {
                        Button {
                            chainringValues.append(max(20, (chainringValues.min() ?? 30) - 14))
                        } label: {
                            Label("Add chainring", systemImage: "plus.circle").font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Cassette") {
                // Speed selector
                HStack {
                    Text("Speeds")
                    Spacer()
                    Picker("Speeds", selection: $selectedSpeeds) {
                        ForEach(speedOptions, id: \.self) { Text("\($0)-speed").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedSpeeds) {
                        resetCassetteToFirst()
                    }
                }

                // Cassette picker
                Picker("Cassette", selection: $selectedCassetteID) {
                    ForEach(filteredCassettes) { c in
                        Text(c.displayName).tag(c.id)
                    }
                    Text("Custom…").tag("custom")
                }
                .pickerStyle(.navigationLink)

                // Custom cog entry
                if selectedCassetteID == "custom" {
                    LabeledContent("Cogs") {
                        TextField("11, 12, 13…", text: $customCogsText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Preview selected cogs
                if selectedCassetteID != "custom", let preset = filteredCassettes.first(where: { $0.id == selectedCassetteID }) {
                    Text(preset.cogs.map(String.init).joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func fixedGearDialRow(label: String?, chainring: Binding<Int>, cog: Binding<Int>) -> some View {
        if let label {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }

        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Chainring")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Chainring", selection: chainring) {
                    ForEach(26...62, id: \.self) { t in Text("\(t)t").tag(t) }
                }
                .pickerStyle(.wheel)
                .frame(height: 130)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 130)

            VStack(spacing: 4) {
                Text("Cog")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Cog", selection: cog) {
                    ForEach(12...24, id: \.self) { t in Text("\(t)t").tag(t) }
                }
                .pickerStyle(.wheel)
                .frame(height: 130)
            }
            .frame(maxWidth: .infinity)
        }

        let gi = (Double(chainring.wrappedValue) / Double(cog.wrappedValue)) * wheelSize.diameterInches
        Text(String(format: "%.1f\" gear inches  ·  ratio %.2f",
                    gi, Double(chainring.wrappedValue) / Double(cog.wrappedValue)))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var riderSection: some View {
        Section("Rider") {
            HStack {
                Text("Weight")
                Spacer()
                Stepper(weightLabel, onIncrement: incrementWeight, onDecrement: decrementWeight)
            }

            HStack {
                Spacer()
                Button(riderSettings.useMetricWeight ? "Switch to lbs" : "Switch to kg") {
                    let kg = riderSettings.weightKg
                    riderSettings.useMetricWeight.toggle()
                    riderSettings.weightKg = kg
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.tint)
            }

            if bikeType == .road {
                Picker("Position", selection: $riderSettings.position) {
                    ForEach(RidingPosition.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $riderSettings.useKmh) {
                Text("Speed in km/h")
            }
        }
    }

    private var weightLabel: String {
        if riderSettings.useMetricWeight {
            return String(format: "%.1f kg", riderSettings.weightKg)
        } else {
            return String(format: "%.0f lbs", (riderSettings.weightKg * 2.20462).rounded())
        }
    }

    private func incrementWeight() {
        if riderSettings.useMetricWeight {
            riderSettings.weightKg += 0.5
        } else {
            let lbs = (riderSettings.weightKg * 2.20462).rounded() + 1
            riderSettings.weightKg = lbs / 2.20462
        }
    }

    private func decrementWeight() {
        if riderSettings.useMetricWeight {
            riderSettings.weightKg = max(30, riderSettings.weightKg - 0.5)
        } else {
            let lbs = max(66, (riderSettings.weightKg * 2.20462).rounded() - 1)
            riderSettings.weightKg = lbs / 2.20462
        }
    }

    private var calculateButton: some View {
        Section {
            Button {
                if calcMode == .findGear {
                    let suggestions = GearCalculator.findGears(
                        targetMph: targetSpeedMph,
                        rpm: targetCadence,
                        wheelDiameter: wheelSize.diameterInches
                    )
                    if !suggestions.isEmpty {
                        navigationPath.append(FinderPayload(
                            suggestions: suggestions,
                            targetSpeed: targetSpeed,
                            cadence: targetCadence,
                            useKmh: riderSettings.useKmh,
                            requiredInches: requiredInchesForTarget
                        ))
                    }
                } else {
                    let result = buildCombos()
                    if !result.isEmpty {
                        navigationPath.append(ResultsPayload(
                            combos: result,
                            riderSettings: riderSettings,
                            bikeType: bikeType
                        ))
                    }
                }
            } label: {
                Label("Calculate", systemImage: "function")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(calcMode == .findSpeed && (chainrings.isEmpty || cogs.isEmpty))
        }
    }

    private var methodsButton: some View {
        Section {
            Button {
                showMethodsSheet = true
            } label: {
                Label("How calculations work", systemImage: "function")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
    }

    // MARK: - Logic

    private func buildCombos() -> [GearCombo] {
        if bikeType == .fixed && fixedCompareEnabled {
            return GearCalculator.compareFixed(
                chainring1: fixedChainring, cog1: fixedCog,
                chainring2: fixedChainring2, cog2: fixedCog2,
                wheelDiameter: wheelSize.diameterInches
            )
        }
        return GearCalculator.computeCombos(
            chainrings: chainrings,
            cogs: cogs,
            wheelDiameter: wheelSize.diameterInches
        )
    }

    private func persistConfig(name: String) {
        let config = SavedConfig(
            id: currentConfigID ?? UUID(),
            name: name,
            bikeType: bikeType,
            wheelSize: wheelSize,
            chainrings: chainrings,
            cogs: cogs,
            riderSettings: riderSettings
        )
        store.save(config)
        currentConfigID = config.id
    }

    private func resetCassetteToFirst() {
        let first = CassettePreset.all.first {
            $0.speeds == selectedSpeeds && (bikeType == .road ? $0.forRoad : $0.forMTB)
        }
        selectedCassetteID = first?.id ?? "custom"
    }

    private func applyLoad(_ load: GearStore.PendingLoad) {
        let c = load.config
        bikeType = c.bikeType
        wheelSize = c.wheelSize
        if bikeType == .fixed {
            fixedChainring = c.chainrings.first ?? 48
            fixedCog = c.cogs.first ?? 16
        } else {
            chainringValues = c.chainrings.isEmpty ? [39] : c.chainrings
            customCogsText = c.cogs.map(String.init).joined(separator: ", ")
            selectedCassetteID = "custom"
        }
        if load.restoreRiderSettings { riderSettings = c.riderSettings }
        currentConfigID = load.restoreRiderSettings ? c.id : nil
        calcMode = .findSpeed
        let result = buildCombos()
        if !result.isEmpty {
            navigationPath = NavigationPath()
            navigationPath.append(ResultsPayload(combos: result, riderSettings: riderSettings, bikeType: bikeType))
        }
    }

    private func applyBikeTypeDefaults() {
        switch bikeType {
        case .road:
            chainringValues = [53, 39]
            selectedSpeeds = 11
            selectedCassetteID = "shi_r_11_11_28"
            wheelSize = WheelSize.catalog.first { $0.name == "700c × 25mm" } ?? WheelSize.catalog[1]
        case .mtb:
            chainringValues = [32]
            selectedSpeeds = 12
            selectedCassetteID = "sram_eagle_10_52"
            wheelSize = WheelSize.catalog.first { $0.name.contains("29\" × 2.10") } ?? WheelSize.catalog[7]
        case .fixed:
            fixedChainring = 48
            fixedCog = 16
            fixedChainring2 = 46
            fixedCog2 = 16
            fixedCompareEnabled = false
            wheelSize = WheelSize.catalog.first { $0.name == "700c × 25mm" } ?? WheelSize.catalog[1]
        }
        currentConfigID = nil
        navigationPath = NavigationPath()
    }

    private func parseInts(_ text: String) -> [Int] {
        text.components(separatedBy: CharacterSet(charactersIn: ",; "))
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
}

// MARK: - Results Screen

struct ResultsView: View {
    let combos: [GearCombo]
    let riderSettings: RiderSettings
    let bikeType: BikeType
    let onSave: (String) -> Void

    @State private var showDupsOnly = false
    @State private var showSaveSheet = false
    @State private var saveName = ""
    @State private var useKmh: Bool

    init(combos: [GearCombo], riderSettings: RiderSettings, bikeType: BikeType, onSave: @escaping (String) -> Void) {
        self.combos = combos
        self.riderSettings = riderSettings
        self.bikeType = bikeType
        self.onSave = onSave
        self._useKmh = State(initialValue: riderSettings.useKmh)
    }

    // Merges the original settings with the in-screen unit toggle.
    private var displaySettings: RiderSettings {
        var s = riderSettings
        s.useKmh = useKmh
        return s
    }

    private var displayedCombos: [GearCombo] {
        showDupsOnly ? combos.filter(\.isDuplicate) : combos
    }

    private var hasDuplicates: Bool { combos.contains(where: \.isDuplicate) }

    var body: some View {
        List {
            Section {
                Picker("Units", selection: $useKmh) {
                    Text("km/h").tag(true)
                    Text("mph").tag(false)
                }
                .pickerStyle(.segmented)
            }

            if bikeType == .fixed && combos.count == 2 {
                FixedCompareChartSection(combos: combos, useKmh: useKmh)
            } else if bikeType != .fixed {
                GearChartSection(combos: combos, riderSettings: displaySettings)
            }

            if hasDuplicates {
                Section {
                    Toggle(isOn: $showDupsOnly) {
                        Label("Near-duplicates only", systemImage: "equal.circle")
                    }
                    .tint(.orange)
                    Label("Colored rows share gear inches within ±1\"",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(displayedCombos) { combo in
                    GearComboRow(combo: combo, settings: displaySettings, bikeType: bikeType)
                }
            } header: {
                HStack {
                    Text("\(combos.count) combos")
                    Spacer()
                    Text("80 / 90 / 100 rpm")
                        .font(.caption2)
                }
            }
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { saveName = ""; showSaveSheet = true } label: {
                    Image(systemName: "bookmark")
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            NavigationStack {
                Form {
                    Section("Name this configuration") {
                        TextField("e.g. My Road Bike", text: $saveName)
                    }
                }
                .navigationTitle("Save Configuration")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSaveSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(saveName.isEmpty ? "Unnamed" : saveName)
                            showSaveSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Gear Finder Results

struct GearFinderResultsView: View {
    let suggestions: [GearSuggestion]
    let targetSpeed: Double
    let cadence: Double
    let useKmh: Bool
    let requiredInches: Double

    @State private var displayKmh: Bool

    init(suggestions: [GearSuggestion], targetSpeed: Double, cadence: Double,
         useKmh: Bool, requiredInches: Double) {
        self.suggestions = suggestions
        self.targetSpeed = targetSpeed
        self.cadence = cadence
        self.useKmh = useKmh
        self.requiredInches = requiredInches
        self._displayKmh = State(initialValue: useKmh)
    }

    private var displayUnit: String { displayKmh ? "km/h" : "mph" }

    private var targetSpeedInDisplayUnit: Double {
        // targetSpeed was entered in the unit indicated by useKmh
        let mph = useKmh ? targetSpeed / 1.60934 : targetSpeed
        return displayKmh ? mph * 1.60934 : mph
    }

    private func achievedSpeed(_ s: GearSuggestion) -> Double {
        displayKmh ? s.achievedSpeedMph * 1.60934 : s.achievedSpeedMph
    }

    var body: some View {
        List {
            Section {
                Picker("Units", selection: $displayKmh) {
                    Text("km/h").tag(true)
                    Text("mph").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section {
                VStack(spacing: 6) {
                    Text(String(format: "%.1f\"", requiredInches))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text(String(format: "gear inches needed for %.1f %@ at %.0f rpm",
                                targetSpeedInDisplayUnit, displayUnit, cadence))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                ForEach(suggestions) { s in
                    GearSuggestionRow(
                        suggestion: s,
                        achievedSpeed: achievedSpeed(s),
                        targetSpeed: targetSpeedInDisplayUnit,
                        speedUnit: displayUnit
                    )
                }
            } header: {
                Text("Closest gears")
            }
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
        .navigationTitle("Gear Finder")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GearSuggestionRow: View {
    let suggestion: GearSuggestion
    let achievedSpeed: Double
    let targetSpeed: Double
    let speedUnit: String

    private var speedError: Double { achievedSpeed - targetSpeed }
    private var isClose: Bool { abs(speedError) <= 0.5 }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(suggestion.chainring)×\(suggestion.cog)")
                    .font(.headline)
                    .monospacedDigit()
                Text(String(format: "%.1f\"  ·  ratio %.2f",
                            suggestion.gearInches,
                            Double(suggestion.chainring) / Double(suggestion.cog)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f %@", achievedSpeed, speedUnit))
                    .font(.footnote)
                    .monospacedDigit()
                Text(String(format: "%@%.1f %@",
                            speedError >= 0 ? "+" : "−", abs(speedError), speedUnit))
                    .font(.caption)
                    .foregroundStyle(isClose ? .green : .secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Gear Combo Row

struct GearComboRow: View {
    let combo: GearCombo
    let settings: RiderSettings
    let bikeType: BikeType

    private let cadences: [Double] = [80, 90, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(combo.chainring)×\(combo.cog)")
                    .font(.headline)
                    .monospacedDigit()
                Text(String(format: "%.2f\"  ·  ratio %.2f", combo.gearInches, combo.ratio))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                if combo.isDuplicate {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(combo.duplicateColor ?? .orange)
                }
            }

            HStack(spacing: 0) {
                ForEach(cadences, id: \.self) { rpm in
                    CadenceCell(
                        rpm: rpm,
                        speed: settings.useKmh ? combo.speedKmh(rpm: rpm) : combo.speedMph(rpm: rpm),
                        speedUnit: settings.speedUnit,
                        watts: combo.watts(massKg: settings.weightKg,
                                           position: settings.position,
                                           bikeType: bikeType,
                                           rpm: rpm)
                    )
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            combo.isDuplicate
                ? (combo.duplicateColor ?? .orange).opacity(0.12)
                : Color.clear
        )
    }
}

// MARK: - Gear Chart (road)

struct GearChartSection: View {
    let combos: [GearCombo]
    let riderSettings: RiderSettings

    // Pre-computed flat data keeps Chart closures trivially simple for the type-checker.

    struct GearBar: Identifiable {
        let id: Int
        let gearIndex: Int
        let gearInches: Double
        let ring: String
    }

    struct SpeedPoint: Identifiable {
        let id: UUID
        let gearIndex: Int
        let speed: Double
        let cadence: String
    }

    private var bars: [GearBar] {
        combos
            .sorted { $0.gearInches < $1.gearInches }
            .enumerated()
            .map { i, c in GearBar(id: i, gearIndex: i + 1, gearInches: c.gearInches, ring: "\(c.chainring)t") }
    }

    private var speedPoints: [SpeedPoint] {
        let sorted = combos.sorted { $0.gearInches < $1.gearInches }
        return [80.0, 90.0, 100.0].flatMap { rpm -> [SpeedPoint] in
            let label = "\(Int(rpm)) rpm"
            return sorted.enumerated().map { i, c in
                let spd = riderSettings.useKmh ? c.speedKmh(rpm: rpm) : c.speedMph(rpm: rpm)
                return SpeedPoint(id: UUID(), gearIndex: i + 1, speed: spd, cadence: label)
            }
        }
    }

    var body: some View {
        Section("Overview") {
            VStack(alignment: .leading, spacing: 16) {
                gearInchesChart
                Divider()
                speedChart
            }
            .padding(.vertical, 6)
        }
    }

    private var gearInchesChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gear inches — low to high")
                .font(.caption).foregroundStyle(.secondary)

            Chart(bars) { bar in
                BarMark(
                    x: .value("Gear", bar.gearIndex),
                    y: .value("Gear Inches", bar.gearInches)
                )
                .foregroundStyle(by: .value("Ring", bar.ring))
                .cornerRadius(2)
            }
            .chartYAxisLabel("Gear inches")
            .chartLegend(position: .topTrailing)
            .frame(height: 150)
        }
    }

    private var speedChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speed at 80 / 90 / 100 rpm")
                .font(.caption).foregroundStyle(.secondary)

            Chart(speedPoints) { pt in
                LineMark(
                    x: .value("Gear", pt.gearIndex),
                    y: .value("Speed", pt.speed),
                    series: .value("Cadence", pt.cadence)
                )
                .foregroundStyle(by: .value("Cadence", pt.cadence))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Gear", pt.gearIndex),
                    y: .value("Speed", pt.speed)
                )
                .foregroundStyle(by: .value("Cadence", pt.cadence))
                .symbolSize(25)
            }
            .chartYAxisLabel(riderSettings.speedUnit)
            .chartLegend(position: .topLeading)
            .frame(height: 180)
        }
    }
}

// MARK: - Fixed Gear Comparison Chart

struct FixedCompareChartSection: View {
    let combos: [GearCombo]   // exactly 2
    let useKmh: Bool

    private var speedUnit: String { useKmh ? "km/h" : "mph" }

    struct SpeedPoint: Identifiable {
        let id = UUID()
        let rpm: Double
        let speed: Double
        let setup: String
    }

    private var points: [SpeedPoint] {
        let rpms = stride(from: 50.0, through: 130.0, by: 5.0)
        return combos.enumerated().flatMap { idx, combo -> [SpeedPoint] in
            let label = "Setup \(idx + 1): \(combo.chainring)×\(combo.cog)"
            return rpms.map { rpm in
                let spd = useKmh ? combo.speedKmh(rpm: rpm) : combo.speedMph(rpm: rpm)
                return SpeedPoint(rpm: rpm, speed: spd, setup: label)
            }
        }
    }

    var body: some View {
        Section("Speed Comparison") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Speed vs cadence (50–130 rpm)")
                    .font(.caption).foregroundStyle(.secondary)

                Chart(points) { pt in
                    LineMark(
                        x: .value("RPM", pt.rpm),
                        y: .value("Speed", pt.speed),
                        series: .value("Setup", pt.setup)
                    )
                    .foregroundStyle(by: .value("Setup", pt.setup))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                }
                .chartXAxisLabel("Cadence (rpm)")
                .chartYAxisLabel(speedUnit)
                .chartLegend(position: .topLeading)
                .frame(height: 220)
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Methods Sheet

struct MethodsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Gear Inches") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("gear_inches = (chainring ÷ cog) × wheel_diameter")
                            .font(.system(.footnote, design: .monospaced))
                        Text("Wheel diameter is the outside diameter of the inflated tyre in inches. Gear inches express how far the bike travels per pedal revolution, equivalent to the wheel diameter of a penny-farthing with the same mechanical advantage.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Speed") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("mph  =  rpm × gear_inches × π ÷ 1056")
                            .font(.system(.footnote, design: .monospaced))
                        Text("km/h  =  mph × 1.60934")
                            .font(.system(.footnote, design: .monospaced))
                        Text("Derived from: (gear inches × π) gives inches of travel per revolution. Multiply by RPM for inches per minute. Divide by (12 × 5280 ÷ 60) to convert to mph.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Development") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("m/rev  =  gear_inches × π ÷ 39.37")
                            .font(.system(.footnote, design: .monospaced))
                        Text("Distance travelled per pedal revolution in metres. Converts gear inches to metres using π (circumference factor) and the conversion 39.37 inches per metre.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Power (Watts)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("P  =  (F_roll + F_drag) × v ÷ η")
                            .font(.system(.footnote, design: .monospaced))
                        Text("F_roll  =  Crr × m × g")
                            .font(.system(.footnote, design: .monospaced))
                        Text("F_drag  =  0.5 × CdA × ρ × v²")
                            .font(.system(.footnote, design: .monospaced))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Crr — rolling resistance (road: 0.004, MTB: 0.010)")
                            Text("m — rider mass (kg)")
                            Text("g — 9.81 m/s²")
                            Text("CdA — drag area in m² (drops: 0.30, hoods: 0.38, upright: 0.55)")
                            Text("ρ — air density 1.225 kg/m³ (sea level, 15 °C)")
                            Text("v — speed in m/s")
                            Text("η — drivetrain efficiency (fixed: 0.99, geared: 0.97)")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Notes") {
                    Text("Power estimates assume flat ground with no wind and standard air density at sea level. They are useful for comparing gears relative to each other, not as absolute power targets.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("How It's Calculated")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CadenceCell: View {
    let rpm: Double
    let speed: Double
    let speedUnit: String
    let watts: Double

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("\(Int(rpm))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(String(format: "%.1f %@", speed, speedUnit))
                .font(.footnote)
                .monospacedDigit()
            Text(String(format: "%.0fW", watts))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
