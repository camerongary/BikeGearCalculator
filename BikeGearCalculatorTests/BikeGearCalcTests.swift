import XCTest
@testable import BikeGearCalculator

final class GearInchesTests: XCTestCase {

    // 53/11 on 700c×25mm (27.0") = (53÷11)×27 = 130.09"
    func testGearInchesRoad() {
        let combo = GearCombo(chainring: 53, cog: 11, wheelDiameter: 27.0)
        XCTAssertEqual(combo.gearInches, (53.0 / 11.0) * 27.0, accuracy: 0.01)
    }

    // 48/16 fixed classic = 81.0"
    func testGearInchesFixed() {
        let combo = GearCombo(chainring: 48, cog: 16, wheelDiameter: 27.0)
        XCTAssertEqual(combo.gearInches, 81.0, accuracy: 0.01)
    }

    // 32/42 MTB granny = (32÷42)×29.15 ≈ 22.21"
    func testGearInchesMTBLow() {
        let combo = GearCombo(chainring: 32, cog: 42, wheelDiameter: 29.15)
        XCTAssertEqual(combo.gearInches, (32.0 / 42.0) * 29.15, accuracy: 0.01)
    }

    func testRatioMatchesGearInchesOverDiameter() {
        let combo = GearCombo(chainring: 50, cog: 17, wheelDiameter: 27.0)
        XCTAssertEqual(combo.ratio, combo.gearInches / 27.0, accuracy: 0.0001)
    }
}

final class SpeedTests: XCTestCase {

    // speed_mph = rpm × GI × π / 1056
    func testSpeedMph() {
        let combo = GearCombo(chainring: 48, cog: 16, wheelDiameter: 27.0) // GI = 81"
        let expected = 90.0 * 81.0 * Double.pi / 1056.0
        XCTAssertEqual(combo.speedMph(rpm: 90), expected, accuracy: 0.001)
    }

    func testSpeedKmhConversion() {
        let combo = GearCombo(chainring: 48, cog: 16, wheelDiameter: 27.0)
        XCTAssertEqual(combo.speedKmh(rpm: 90), combo.speedMph(rpm: 90) * 1.60934, accuracy: 0.001)
    }

    func testSpeedScalesWithRPM() {
        let combo = GearCombo(chainring: 39, cog: 19, wheelDiameter: 27.0)
        // Doubling RPM should double speed
        XCTAssertEqual(combo.speedMph(rpm: 100), combo.speedMph(rpm: 50) * 2.0, accuracy: 0.0001)
    }

    func testHighGearFasterThanLowGear() {
        let big   = GearCombo(chainring: 53, cog: 11, wheelDiameter: 27.0)
        let small = GearCombo(chainring: 39, cog: 25, wheelDiameter: 27.0)
        XCTAssertGreaterThan(big.speedMph(rpm: 90), small.speedMph(rpm: 90))
    }

    // Sanity check: 48/16 at 90 rpm ≈ 21.7 mph
    func testKnownSpeedValue() {
        let combo = GearCombo(chainring: 48, cog: 16, wheelDiameter: 27.0)
        XCTAssertEqual(combo.speedMph(rpm: 90), 21.7, accuracy: 0.1)
    }
}

final class WattsTests: XCTestCase {

    func testWattsPositive() {
        let combo = GearCombo(chainring: 39, cog: 19, wheelDiameter: 27.0)
        let w = combo.watts(massKg: 75, position: .hoods, bikeType: .road, rpm: 90)
        XCTAssertGreaterThan(w, 0)
    }

    func testWattsZeroAtZeroSpeed() {
        let combo = GearCombo(chainring: 39, cog: 19, wheelDiameter: 27.0)
        XCTAssertEqual(combo.watts(massKg: 75, position: .hoods, bikeType: .road, rpm: 0), 0)
    }

    func testHigherSpeedRequiresMoreWatts() {
        let combo = GearCombo(chainring: 53, cog: 11, wheelDiameter: 27.0)
        let w80  = combo.watts(massKg: 75, position: .hoods, bikeType: .road, rpm: 80)
        let w100 = combo.watts(massKg: 75, position: .hoods, bikeType: .road, rpm: 100)
        XCTAssertGreaterThan(w100, w80)
    }

    func testAeroDragReducedInDrops() {
        let combo = GearCombo(chainring: 53, cog: 11, wheelDiameter: 27.0)
        let wDrops   = combo.watts(massKg: 75, position: .drops,  bikeType: .road, rpm: 90)
        let wUpright = combo.watts(massKg: 75, position: .upright, bikeType: .road, rpm: 90)
        XCTAssertLessThan(wDrops, wUpright)
    }

    func testHeavierRiderRequiresMoreWatts() {
        let combo = GearCombo(chainring: 39, cog: 19, wheelDiameter: 27.0)
        let wLight = combo.watts(massKg: 60,  position: .hoods, bikeType: .road, rpm: 90)
        let wHeavy = combo.watts(massKg: 100, position: .hoods, bikeType: .road, rpm: 90)
        XCTAssertGreaterThan(wHeavy, wLight)
    }

    func testMTBHigherRollingResistance() {
        let combo = GearCombo(chainring: 32, cog: 18, wheelDiameter: 29.15)
        let wRoad = combo.watts(massKg: 75, position: .upright, bikeType: .road, rpm: 90)
        let wMTB  = combo.watts(massKg: 75, position: .upright, bikeType: .mtb,  rpm: 90)
        XCTAssertGreaterThan(wMTB, wRoad)
    }

    func testFixedBetterEfficiencyThanRoad() {
        let combo = GearCombo(chainring: 48, cog: 16, wheelDiameter: 27.0)
        let wFixed = combo.watts(massKg: 75, position: .hoods, bikeType: .fixed, rpm: 90)
        let wRoad  = combo.watts(massKg: 75, position: .hoods, bikeType: .road,  rpm: 90)
        XCTAssertLessThan(wFixed, wRoad)
    }
}

final class GearCalculatorTests: XCTestCase {

    func testComboCountIsChainringsTimesCogs() {
        let combos = GearCalculator.computeCombos(chainrings: [53, 39], cogs: [11, 13, 15], wheelDiameter: 27.0)
        XCTAssertEqual(combos.count, 6)
    }

    func testSingleFixedComboCount() {
        let combos = GearCalculator.computeCombos(chainrings: [48], cogs: [16], wheelDiameter: 27.0)
        XCTAssertEqual(combos.count, 1)
    }

    func testCombosOrderedLargeChainringFirst() {
        let combos = GearCalculator.computeCombos(chainrings: [39, 53], cogs: [11], wheelDiameter: 27.0)
        XCTAssertEqual(combos[0].chainring, 53)
        XCTAssertEqual(combos[1].chainring, 39)
    }

    func testCogsOrderedSmallFirst() {
        let combos = GearCalculator.computeCombos(chainrings: [53], cogs: [25, 11, 17], wheelDiameter: 27.0)
        XCTAssertEqual(combos[0].cog, 11)
        XCTAssertEqual(combos[1].cog, 17)
        XCTAssertEqual(combos[2].cog, 25)
    }
}

final class DuplicateDetectionTests: XCTestCase {

    // 53/19 × 27.0 = 75.32"   39/14 × 27.0 = 75.21"  → diff 0.11" → duplicate
    func testKnownCrossChainDuplicateFlagged() {
        let combos = GearCalculator.computeCombos(
            chainrings: [53, 39],
            cogs: [14, 19],
            wheelDiameter: 27.0
        )
        let c5319 = combos.first { $0.chainring == 53 && $0.cog == 19 }!
        let c3914 = combos.first { $0.chainring == 39 && $0.cog == 14 }!
        XCTAssertTrue(c5319.isDuplicate)
        XCTAssertTrue(c3914.isDuplicate)
        XCTAssertEqual(c5319.duplicateGroup, c3914.duplicateGroup)
    }

    // 53/11 = 130.09"   39/25 = 42.12"  → diff 87.97" → not a duplicate
    func testWidelySpacedGearsNotFlagged() {
        let combos = GearCalculator.computeCombos(
            chainrings: [53, 39],
            cogs: [11, 25],
            wheelDiameter: 27.0
        )
        let c5311 = combos.first { $0.chainring == 53 && $0.cog == 11 }!
        let c3925 = combos.first { $0.chainring == 39 && $0.cog == 25 }!
        XCTAssertFalse(c5311.isDuplicate)
        XCTAssertFalse(c3925.isDuplicate)
    }

    // Single chainring — no cross-chainring pairs, nothing should be flagged
    func testSingleChainringNoDuplicates() {
        let combos = GearCalculator.computeCombos(
            chainrings: [32],
            cogs: [10, 12, 14, 16, 18, 21, 24, 28, 33, 38, 42],
            wheelDiameter: 29.15
        )
        XCTAssertFalse(combos.contains { $0.isDuplicate })
    }

    // Same chainring combos should not be flagged as duplicates of each other
    func testSameChainringNotFlagged() {
        let combos = GearCalculator.computeCombos(
            chainrings: [53, 39],
            cogs: [17, 18],          // 53/17=84.2" vs 53/18=79.5" — different chainring same teeth won't match
            wheelDiameter: 27.0
        )
        let sameRing = combos.filter { $0.chainring == 53 }
        // These are same-chainring pairs — must not be grouped together because of each other
        for combo in sameRing {
            if combo.isDuplicate {
                // If flagged, the partner must be on a different chainring
                let partner = combos.first {
                    $0.id != combo.id && $0.duplicateGroup == combo.duplicateGroup
                }
                XCTAssertNotNil(partner)
                XCTAssertNotEqual(partner?.chainring, combo.chainring)
            }
        }
    }

    func testDuplicatesShareGroup() {
        let combos = GearCalculator.computeCombos(
            chainrings: [53, 39],
            cogs: [14, 19],
            wheelDiameter: 27.0
        )
        let dupes = combos.filter { $0.isDuplicate }
        XCTAssertEqual(dupes.count, 2)
        XCTAssertEqual(dupes[0].duplicateGroup, dupes[1].duplicateGroup)
    }

    func testExactlyOneGearInchDiffIsFlagged() {
        // Construct a wheel diameter so two combos land exactly 1.0" apart
        // chainring1/cog1 × d = chainring2/cog2 × d + 1.0 → solve for d
        // (2/1 - 1/1) × d = 1.0 → d = 1.0
        let combos = GearCalculator.computeCombos(
            chainrings: [2, 1],
            cogs: [1],
            wheelDiameter: 1.0   // GI: 2.0" vs 1.0" → diff 1.0" → on the boundary
        )
        let big   = combos.first { $0.chainring == 2 }!
        let small = combos.first { $0.chainring == 1 }!
        XCTAssertEqual(abs(big.gearInches - small.gearInches), 1.0, accuracy: 0.0001)
        XCTAssertTrue(big.isDuplicate)
        XCTAssertTrue(small.isDuplicate)
    }

    func testJustOverOneGearInchNotFlagged() {
        // diff slightly over 1.0 → should NOT be flagged
        // (2/1 - 1/1) × 1.01 = 1.01"
        let combos = GearCalculator.computeCombos(
            chainrings: [2, 1],
            cogs: [1],
            wheelDiameter: 1.01
        )
        XCTAssertFalse(combos.contains { $0.isDuplicate })
    }
}

final class RiderSettingsTests: XCTestCase {

    func testDefaultWeightIsMetric() {
        let s = RiderSettings()
        XCTAssertTrue(s.useMetricWeight)
        XCTAssertEqual(s.weightDisplay, 75.0, accuracy: 0.01)
    }

    func testWeightConversionToLbs() {
        var s = RiderSettings()
        s.useMetricWeight = false
        XCTAssertEqual(s.weightDisplay, 75.0 * 2.20462, accuracy: 0.01)
    }

    func testSettingWeightInLbsRoundTrips() {
        var s = RiderSettings()
        s.useMetricWeight = false
        s.weightDisplay = 165.0                          // lbs
        s.useMetricWeight = true
        XCTAssertEqual(s.weightDisplay, 165.0 / 2.20462, accuracy: 0.01)
    }

    func testWeightUnitLabel() {
        var s = RiderSettings()
        XCTAssertEqual(s.weightUnit, "kg")
        s.useMetricWeight = false
        XCTAssertEqual(s.weightUnit, "lbs")
    }
}

final class WheelSizeCatalogTests: XCTestCase {

    func testAllDiametersPositive() {
        for ws in WheelSize.catalog {
            XCTAssertGreaterThan(ws.diameterInches, 0, "\(ws.name) has non-positive diameter")
        }
    }

    func testAllNamesUnique() {
        let names = WheelSize.catalog.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "Duplicate wheel size names found")
    }

    func testEqualityByName() {
        let a = WheelSize(name: "700c × 25mm", diameterInches: 27.0)
        let b = WheelSize(name: "700c × 25mm", diameterInches: 27.0)
        XCTAssertEqual(a, b)
    }

    func testInequalityByName() {
        let a = WheelSize(name: "700c × 25mm", diameterInches: 27.0)
        let b = WheelSize(name: "700c × 28mm", diameterInches: 27.2)
        XCTAssertNotEqual(a, b)
    }
}

final class PresetsTests: XCTestCase {

    func testAllRoadPresetsHaveChainrings() {
        for p in GearPreset.road {
            XCTAssertFalse(p.chainrings.isEmpty, "\(p.name) has no chainrings")
        }
    }

    func testAllPresetsHaveCogs() {
        let all = GearPreset.road + GearPreset.mtb + GearPreset.fixed
        for p in all {
            XCTAssertFalse(p.cogs.isEmpty, "\(p.name) has no cogs")
        }
    }

    func testFixedPresetsHaveExactlyOneChainringAndCog() {
        for p in GearPreset.fixed {
            XCTAssertEqual(p.chainrings.count, 1, "\(p.name) should have 1 chainring")
            XCTAssertEqual(p.cogs.count, 1,       "\(p.name) should have 1 cog")
        }
    }

    func testToConfigPreservesGearing() {
        let preset = GearPreset.road[0]
        let config = preset.toConfig(riderSettings: RiderSettings())
        XCTAssertEqual(config.chainrings, preset.chainrings)
        XCTAssertEqual(config.cogs, preset.cogs)
        XCTAssertEqual(config.bikeType, preset.bikeType)
    }
}

final class GearFinderTests: XCTestCase {

    // requiredGearInches is the exact inverse of speedMph
    func testRequiredGearInchesRoundTrip() {
        let combo = GearCombo(chainring: 48, cog: 16, wheelDiameter: 27.0) // 81.0"
        let speed = combo.speedMph(rpm: 90)
        let required = GearCalculator.requiredGearInches(targetMph: speed, rpm: 90)
        XCTAssertEqual(required, combo.gearInches, accuracy: 0.0001)
    }

    func testRequiredGearInchesZeroRPM() {
        XCTAssertEqual(GearCalculator.requiredGearInches(targetMph: 20, rpm: 0), 0)
    }

    func testFindGearsSortedByError() {
        let results = GearCalculator.findGears(targetMph: 20, rpm: 90, wheelDiameter: 27.0)
        XCTAssertFalse(results.isEmpty)
        for i in 1..<results.count {
            XCTAssertLessThanOrEqual(abs(results[i-1].errorInches), abs(results[i].errorInches))
        }
    }

    func testFindGearsRespectsRanges() {
        let results = GearCalculator.findGears(targetMph: 20, rpm: 90, wheelDiameter: 27.0)
        for s in results {
            XCTAssertTrue((24...62).contains(s.chainring))
            XCTAssertTrue((9...36).contains(s.cog))
        }
    }

    func testFindGearsDedupesEquivalentRatios() {
        let results = GearCalculator.findGears(targetMph: 20, rpm: 90, wheelDiameter: 27.0,
                                               maxResults: 100)
        var seen = Set<String>()
        for s in results {
            func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
            let d = gcd(s.chainring, s.cog)
            let key = "\(s.chainring / d)/\(s.cog / d)"
            XCTAssertFalse(seen.contains(key), "duplicate ratio \(key)")
            seen.insert(key)
        }
    }

    func testFindGearsTopResultMatchesHandMath() {
        // 30 km/h = 18.641 mph @ 90 rpm on 27.0" wheel
        // required GI = 18.641 × 1056 / (90 × π) ≈ 69.6"
        let mph = 30.0 / 1.60934
        let results = GearCalculator.findGears(targetMph: mph, rpm: 90, wheelDiameter: 27.0)
        let required = GearCalculator.requiredGearInches(targetMph: mph, rpm: 90)
        XCTAssertEqual(required, 69.6, accuracy: 0.1)
        // Top result should be within half a gear inch of the target
        XCTAssertLessThanOrEqual(abs(results[0].errorInches), 0.5)
        // And its achieved speed should round-trip to ~30 km/h
        XCTAssertEqual(results[0].achievedSpeedMph * 1.60934, 30.0, accuracy: 0.5)
    }

    func testFindGearsMaxResults() {
        let results = GearCalculator.findGears(targetMph: 20, rpm: 90, wheelDiameter: 27.0,
                                               maxResults: 5)
        XCTAssertEqual(results.count, 5)
    }
}
