import Foundation

// MARK: - Enums

enum BikeType: String, Codable, CaseIterable, Identifiable {
    case road = "Road"
    case mtb = "Mountain"
    case fixed = "Fixed"

    var id: String { rawValue }

    var crr: Double {
        switch self {
        case .road, .fixed: return 0.004
        case .mtb: return 0.010
        }
    }

    var drivetrainEfficiency: Double {
        self == .fixed ? 0.99 : 0.97
    }
}

enum RidingPosition: String, Codable, CaseIterable, Identifiable {
    case drops = "Drops"
    case hoods = "Hoods"
    case upright = "Upright"

    var id: String { rawValue }

    var cdA: Double {
        switch self {
        case .drops:  return 0.30
        case .hoods:  return 0.38
        case .upright: return 0.55
        }
    }
}

// MARK: - Wheel Size

struct WheelSize: Identifiable, Codable, Hashable {
    let name: String
    let diameterInches: Double

    var id: String { name }

    nonisolated static func == (lhs: WheelSize, rhs: WheelSize) -> Bool { lhs.name == rhs.name }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(name) }

    static let catalog: [WheelSize] = [
        WheelSize(name: "700c × 23mm",           diameterInches: 26.9),
        WheelSize(name: "700c × 25mm",           diameterInches: 27.0),
        WheelSize(name: "700c × 28mm",           diameterInches: 27.2),
        WheelSize(name: "700c × 32mm",           diameterInches: 27.4),
        WheelSize(name: "700c × 35mm",           diameterInches: 27.6),
        WheelSize(name: "650b × 40mm (Gravel)",  diameterInches: 27.1),
        WheelSize(name: "650b × 47mm",           diameterInches: 27.2),
        WheelSize(name: "29\" × 2.10\"",         diameterInches: 29.15),
        WheelSize(name: "29\" × 2.35\"",         diameterInches: 29.5),
        WheelSize(name: "29\" × 2.80\"",         diameterInches: 30.1),
        WheelSize(name: "29\" × 3.00\"",         diameterInches: 30.4),
        WheelSize(name: "27.5\" × 2.10\"",       diameterInches: 27.5),
        WheelSize(name: "27.5\" × 2.35\"",       diameterInches: 27.9),
        WheelSize(name: "27.5\" × 2.80\"",       diameterInches: 28.6),
        WheelSize(name: "27.5\" × 3.00\"",       diameterInches: 28.9),
        WheelSize(name: "26\" × 2.00\"",         diameterInches: 26.4),
        WheelSize(name: "26\" × 2.35\"",         diameterInches: 27.0),
        WheelSize(name: "24\" × 1.75\"",         diameterInches: 24.5),
        WheelSize(name: "20\" × 1.75\"",         diameterInches: 20.5),
    ]
}

// MARK: - Gear Combo

struct GearCombo: Identifiable {
    let id = UUID()
    let chainring: Int
    let cog: Int
    let wheelDiameter: Double
    var isDuplicate: Bool = false
    var duplicateGroup: Int? = nil

    var gearInches: Double {
        (Double(chainring) / Double(cog)) * wheelDiameter
    }

    var ratio: Double { Double(chainring) / Double(cog) }

    func speedMph(rpm: Double) -> Double {
        // inches/rev * revs/min * pi = inches/min / (12*5280/60) = mph
        rpm * gearInches * .pi / 1056.0
    }

    func speedKmh(rpm: Double) -> Double {
        speedMph(rpm: rpm) * 1.60934
    }

    func watts(massKg: Double, position: RidingPosition, bikeType: BikeType, rpm: Double) -> Double {
        let v = speedMph(rpm: rpm) * 0.44704  // m/s
        guard v > 0 else { return 0 }
        let fRolling = bikeType.crr * massKg * 9.81
        let fDrag    = 0.5 * position.cdA * 1.225 * v * v
        return (fRolling + fDrag) * v / bikeType.drivetrainEfficiency
    }

}

// MARK: - Rider Settings

struct RiderSettings: Codable, Equatable {
    var weightKg: Double = 75.0
    var useMetricWeight: Bool = true
    var useKmh: Bool = true
    var position: RidingPosition = .hoods

    var weightDisplay: Double {
        get { useMetricWeight ? weightKg : weightKg * 2.20462 }
        set { weightKg = useMetricWeight ? newValue : newValue / 2.20462 }
    }

    var weightUnit: String { useMetricWeight ? "kg" : "lbs" }
    var speedUnit: String  { useKmh ? "km/h" : "mph" }
}

// MARK: - Saved Config

struct SavedConfig: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var bikeType: BikeType
    var wheelSize: WheelSize
    var chainrings: [Int]
    var cogs: [Int]
    var riderSettings: RiderSettings
    var createdAt: Date = Date()
}

// MARK: - Presets

struct GearPreset: Identifiable {
    let id = UUID()
    let name: String
    let bikeType: BikeType
    let wheelSize: WheelSize
    let chainrings: [Int]
    let cogs: [Int]

    func toConfig(riderSettings: RiderSettings) -> SavedConfig {
        SavedConfig(name: name, bikeType: bikeType, wheelSize: wheelSize,
                    chainrings: chainrings, cogs: cogs, riderSettings: riderSettings)
    }

    // MARK: Road
    static let road: [GearPreset] = [
        GearPreset(
            name: "Standard — 53/39, 11-28",
            bikeType: .road,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [53, 39],
            cogs: [11, 12, 13, 14, 15, 17, 19, 21, 23, 25, 28]
        ),
        GearPreset(
            name: "Compact — 50/34, 11-32",
            bikeType: .road,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [50, 34],
            cogs: [11, 12, 13, 15, 17, 19, 22, 25, 28, 32]
        ),
        GearPreset(
            name: "Semi-Compact — 52/36, 11-30",
            bikeType: .road,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [52, 36],
            cogs: [11, 12, 13, 14, 16, 18, 20, 22, 25, 28, 30]
        ),
        GearPreset(
            name: "Gravel — 46/30, 11-34",
            bikeType: .road,
            wheelSize: WheelSize(name: "700c × 35mm", diameterInches: 27.6),
            chainrings: [46, 30],
            cogs: [11, 13, 15, 17, 19, 22, 25, 28, 32, 34]
        ),
        GearPreset(
            name: "Endurance — 48/32, 11-34",
            bikeType: .road,
            wheelSize: WheelSize(name: "700c × 28mm", diameterInches: 27.2),
            chainrings: [48, 32],
            cogs: [11, 13, 15, 17, 19, 22, 25, 28, 32, 34]
        ),
    ]

    // MARK: Mountain
    static let mtb: [GearPreset] = [
        GearPreset(
            name: "1× XC — 32t, 10-42",
            bikeType: .mtb,
            wheelSize: WheelSize(name: "29\" × 2.10\"", diameterInches: 29.15),
            chainrings: [32],
            cogs: [10, 12, 14, 16, 18, 21, 24, 28, 33, 38, 42]
        ),
        GearPreset(
            name: "1× Trail — 30t, 10-51",
            bikeType: .mtb,
            wheelSize: WheelSize(name: "29\" × 2.35\"", diameterInches: 29.5),
            chainrings: [30],
            cogs: [10, 12, 14, 17, 21, 26, 32, 39, 46, 51]
        ),
        GearPreset(
            name: "1× Enduro — 28t, 10-52",
            bikeType: .mtb,
            wheelSize: WheelSize(name: "27.5\" × 2.35\"", diameterInches: 27.9),
            chainrings: [28],
            cogs: [10, 12, 14, 17, 21, 26, 32, 39, 46, 52]
        ),
        GearPreset(
            name: "2× — 36/26, 11-36",
            bikeType: .mtb,
            wheelSize: WheelSize(name: "27.5\" × 2.35\"", diameterInches: 27.9),
            chainrings: [36, 26],
            cogs: [11, 13, 15, 17, 19, 22, 25, 28, 32, 36]
        ),
        GearPreset(
            name: "3× Classic — 44/32/22, 11-34",
            bikeType: .mtb,
            wheelSize: WheelSize(name: "26\" × 2.00\"", diameterInches: 26.4),
            chainrings: [44, 32, 22],
            cogs: [11, 13, 15, 18, 21, 24, 28, 32, 34]
        ),
    ]

    // MARK: Fixed
    static let fixed: [GearPreset] = [
        GearPreset(
            name: "Classic — 48/16 (81.0\")",
            bikeType: .fixed,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [48], cogs: [16]
        ),
        GearPreset(
            name: "Street — 46/16 (77.6\")",
            bikeType: .fixed,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [46], cogs: [16]
        ),
        GearPreset(
            name: "Easy Street — 44/16 (74.3\")",
            bikeType: .fixed,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [44], cogs: [16]
        ),
        GearPreset(
            name: "Hilly — 42/18 (63.0\")",
            bikeType: .fixed,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [42], cogs: [18]
        ),
        GearPreset(
            name: "Steep Hills — 36/18 (54.0\")",
            bikeType: .fixed,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [36], cogs: [18]
        ),
        GearPreset(
            name: "Crit — 50/16 (84.4\")",
            bikeType: .fixed,
            wheelSize: WheelSize(name: "700c × 25mm", diameterInches: 27.0),
            chainrings: [50], cogs: [16]
        ),
    ]
}

// MARK: - Cassette Presets

struct CassettePreset: Identifiable {
    let id: String
    let brand: String
    let range: String
    let speeds: Int
    let forRoad: Bool
    let forMTB: Bool
    let cogs: [Int]

    var displayName: String { "\(brand)  \(range)" }
}

extension CassettePreset {
    static let all: [CassettePreset] = road + mtb

    // MARK: Road
    static let road: [CassettePreset] = [
        // Shimano 8-speed
        CassettePreset(id: "shi_r_8_11_28", brand: "Shimano", range: "11-28", speeds: 8, forRoad: true, forMTB: false,
                       cogs: [11,12,14,16,18,21,24,28]),
        CassettePreset(id: "shi_r_8_11_32", brand: "Shimano", range: "11-32", speeds: 8, forRoad: true, forMTB: false,
                       cogs: [11,13,15,17,19,22,25,32]),
        // Shimano 9-speed
        CassettePreset(id: "shi_r_9_11_25", brand: "Shimano", range: "11-25", speeds: 9, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,22,25]),
        CassettePreset(id: "shi_r_9_11_28", brand: "Shimano", range: "11-28", speeds: 9, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,16,18,21,24,28]),
        CassettePreset(id: "shi_r_9_11_32", brand: "Shimano", range: "11-32", speeds: 9, forRoad: true, forMTB: false,
                       cogs: [11,12,14,16,18,21,24,28,32]),
        // Shimano 10-speed
        CassettePreset(id: "shi_r_10_11_25", brand: "Shimano", range: "11-25", speeds: 10, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,23,25]),
        CassettePreset(id: "shi_r_10_11_28", brand: "Shimano", range: "11-28", speeds: 10, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,24,28]),
        CassettePreset(id: "shi_r_10_11_32", brand: "Shimano", range: "11-32", speeds: 10, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,16,18,20,23,26,32]),
        // Shimano 11-speed
        CassettePreset(id: "shi_r_11_11_28", brand: "Shimano", range: "11-28", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,23,25,28]),
        CassettePreset(id: "shi_r_11_11_30", brand: "Shimano", range: "11-30", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,16,18,20,22,25,28,30]),
        CassettePreset(id: "shi_r_11_11_32", brand: "Shimano", range: "11-32", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,16,18,20,22,25,28,32]),
        CassettePreset(id: "shi_r_11_11_34", brand: "Shimano", range: "11-34", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,16,18,20,22,25,30,34]),
        // Shimano 12-speed (R9200/R8100)
        CassettePreset(id: "shi_r_12_11_30", brand: "Shimano", range: "11-30", speeds: 12, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,16,17,19,21,24,27,30]),
        CassettePreset(id: "shi_r_12_11_34", brand: "Shimano", range: "11-34", speeds: 12, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,24,27,31,34]),
        // SRAM 10-speed
        CassettePreset(id: "sram_r_10_11_28", brand: "SRAM", range: "11-28", speeds: 10, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,24,28]),
        CassettePreset(id: "sram_r_10_11_32", brand: "SRAM", range: "11-32", speeds: 10, forRoad: true, forMTB: false,
                       cogs: [11,12,13,15,17,19,21,24,28,32]),
        // SRAM 11-speed
        CassettePreset(id: "sram_r_11_11_26", brand: "SRAM", range: "11-26", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,16,17,19,21,23,26]),
        CassettePreset(id: "sram_r_11_11_28", brand: "SRAM", range: "11-28", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,23,25,28]),
        CassettePreset(id: "sram_r_11_11_32", brand: "SRAM", range: "11-32", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,16,18,20,22,25,28,32]),
        // SRAM 12-speed (Force/Red AXS)
        CassettePreset(id: "sram_r_12_10_33", brand: "SRAM", range: "10-33", speeds: 12, forRoad: true, forMTB: false,
                       cogs: [10,11,12,13,15,17,19,21,24,28,30,33]),
        CassettePreset(id: "sram_r_12_10_36", brand: "SRAM", range: "10-36", speeds: 12, forRoad: true, forMTB: false,
                       cogs: [10,11,12,14,16,18,20,22,25,28,32,36]),
        // Campagnolo 11-speed
        CassettePreset(id: "campy_11_11_25", brand: "Campagnolo", range: "11-25", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,16,17,19,21,23,25]),
        CassettePreset(id: "campy_11_11_27", brand: "Campagnolo", range: "11-27", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,16,17,19,21,23,27]),
        CassettePreset(id: "campy_11_11_29", brand: "Campagnolo", range: "11-29", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,24,27,29]),
        CassettePreset(id: "campy_11_11_32", brand: "Campagnolo", range: "11-32", speeds: 11, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,22,25,29,32]),
        // Campagnolo 12-speed
        CassettePreset(id: "campy_12_11_29", brand: "Campagnolo", range: "11-29", speeds: 12, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,16,17,19,21,24,27,29]),
        CassettePreset(id: "campy_12_11_32", brand: "Campagnolo", range: "11-32", speeds: 12, forRoad: true, forMTB: false,
                       cogs: [11,12,13,14,15,17,19,21,24,27,30,32]),
    ]

    // MARK: MTB
    static let mtb: [CassettePreset] = [
        // Shimano 10-speed MTB
        CassettePreset(id: "shi_m_10_11_36", brand: "Shimano", range: "11-36", speeds: 10, forRoad: false, forMTB: true,
                       cogs: [11,13,15,17,19,21,24,28,32,36]),
        CassettePreset(id: "shi_m_10_11_42", brand: "Shimano", range: "11-42", speeds: 10, forRoad: false, forMTB: true,
                       cogs: [11,13,15,17,19,22,25,28,34,42]),
        // Shimano 11-speed MTB
        CassettePreset(id: "shi_m_11_11_42", brand: "Shimano", range: "11-42", speeds: 11, forRoad: false, forMTB: true,
                       cogs: [11,13,15,17,19,21,24,28,32,37,42]),
        CassettePreset(id: "shi_m_11_11_46", brand: "Shimano", range: "11-46", speeds: 11, forRoad: false, forMTB: true,
                       cogs: [11,13,15,18,21,24,28,32,37,42,46]),
        // Shimano 12-speed MTB (M9100/M8100)
        CassettePreset(id: "shi_m_12_10_45", brand: "Shimano", range: "10-45", speeds: 12, forRoad: false, forMTB: true,
                       cogs: [10,12,14,16,18,21,24,28,33,39,42,45]),
        CassettePreset(id: "shi_m_12_10_51", brand: "Shimano", range: "10-51", speeds: 12, forRoad: false, forMTB: true,
                       cogs: [10,12,14,16,18,21,24,28,33,39,45,51]),
        // SRAM Eagle 12-speed
        CassettePreset(id: "sram_eagle_10_44", brand: "SRAM Eagle", range: "10-44", speeds: 12, forRoad: false, forMTB: true,
                       cogs: [10,12,14,16,18,21,24,28,32,36,40,44]),
        CassettePreset(id: "sram_eagle_10_50", brand: "SRAM Eagle", range: "10-50", speeds: 12, forRoad: false, forMTB: true,
                       cogs: [10,12,14,16,18,21,24,28,32,36,42,50]),
        CassettePreset(id: "sram_eagle_10_52", brand: "SRAM Eagle", range: "10-52", speeds: 12, forRoad: false, forMTB: true,
                       cogs: [10,12,14,16,18,21,24,28,32,36,42,52]),
        // SRAM MTB 11-speed (NX/GX)
        CassettePreset(id: "sram_m_11_10_42", brand: "SRAM", range: "10-42", speeds: 11, forRoad: false, forMTB: true,
                       cogs: [10,12,14,16,18,21,24,28,32,36,42]),
        CassettePreset(id: "sram_m_11_11_42", brand: "SRAM", range: "11-42", speeds: 11, forRoad: false, forMTB: true,
                       cogs: [11,13,15,17,19,22,25,28,32,37,42]),
    ]
}
