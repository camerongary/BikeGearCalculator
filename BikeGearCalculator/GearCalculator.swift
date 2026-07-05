import Foundation

struct GearSuggestion: Identifiable, Hashable {
    let id = UUID()
    let chainring: Int
    let cog: Int
    let gearInches: Double
    let achievedSpeedMph: Double   // at the target cadence
    let errorInches: Double        // signed: positive = taller than target
}

enum GearCalculator {

    static func computeCombos(
        chainrings: [Int],
        cogs: [Int],
        wheelDiameter: Double
    ) -> [GearCombo] {
        var combos: [GearCombo] = []
        for cr in chainrings.sorted(by: >) {
            for cog in cogs.sorted() {
                combos.append(GearCombo(chainring: cr, cog: cog, wheelDiameter: wheelDiameter))
            }
        }
        return markDuplicates(in: combos, multipleChainrings: chainrings.count > 1)
    }

    // Compare exactly two fixed-gear setups, marking them as duplicates if within 1 gear inch.
    static func compareFixed(
        chainring1: Int, cog1: Int,
        chainring2: Int, cog2: Int,
        wheelDiameter: Double
    ) -> [GearCombo] {
        var c1 = GearCombo(chainring: chainring1, cog: cog1, wheelDiameter: wheelDiameter)
        var c2 = GearCombo(chainring: chainring2, cog: cog2, wheelDiameter: wheelDiameter)
        if abs(c1.gearInches - c2.gearInches) <= 1.0 {
            c1.isDuplicate = true; c1.duplicateGroup = 1
            c2.isDuplicate = true; c2.duplicateGroup = 1
        }
        return [c1, c2]
    }

    // Inverse of GearCombo.speedMph: the gear inches needed to hit a speed at a cadence.
    static func requiredGearInches(targetMph: Double, rpm: Double) -> Double {
        guard rpm > 0 else { return 0 }
        return targetMph * 1056.0 / (rpm * .pi)
    }

    // Suggest chainring/cog combos that best hit a target speed at a cadence.
    // Equivalent ratios (48×16 vs 51×17) are deduped, keeping the fewest total teeth.
    static func findGears(
        targetMph: Double,
        rpm: Double,
        wheelDiameter: Double,
        chainringRange: ClosedRange<Int> = 24...62,
        cogRange: ClosedRange<Int> = 9...36,
        maxResults: Int = 10
    ) -> [GearSuggestion] {
        let target = requiredGearInches(targetMph: targetMph, rpm: rpm)
        guard target > 0 else { return [] }

        // reduced ratio → best combo for that ratio
        var best: [String: GearSuggestion] = [:]
        for ring in chainringRange {
            for cog in cogRange {
                let d = gcd(ring, cog)
                let key = "\(ring / d)/\(cog / d)"
                if let existing = best[key], existing.chainring + existing.cog <= ring + cog {
                    continue
                }
                let gi = (Double(ring) / Double(cog)) * wheelDiameter
                best[key] = GearSuggestion(
                    chainring: ring,
                    cog: cog,
                    gearInches: gi,
                    achievedSpeedMph: rpm * gi * .pi / 1056.0,
                    errorInches: gi - target
                )
            }
        }
        return best.values
            .sorted { abs($0.errorInches) < abs($1.errorInches) }
            .prefix(maxResults)
            .map { $0 }
    }

    // Best combos buildable from the rider's owned parts, closest to target first.
    static func bestOwnedCombos(
        targetMph: Double,
        rpm: Double,
        wheelDiameter: Double,
        owned: OwnedGears,
        maxResults: Int = 3
    ) -> [GearSuggestion] {
        let target = requiredGearInches(targetMph: targetMph, rpm: rpm)
        guard target > 0, !owned.chainrings.isEmpty, !owned.cogs.isEmpty else { return [] }

        var suggestions: [GearSuggestion] = []
        for ring in owned.chainrings {
            for cog in owned.cogs {
                let gi = (Double(ring) / Double(cog)) * wheelDiameter
                suggestions.append(GearSuggestion(
                    chainring: ring,
                    cog: cog,
                    gearInches: gi,
                    achievedSpeedMph: rpm * gi * .pi / 1056.0,
                    errorInches: gi - target
                ))
            }
        }
        return suggestions
            .sorted { abs($0.errorInches) < abs($1.errorInches) }
            .prefix(maxResults)
            .map { $0 }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (a, b)
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    // Within 1 gear inch of each other — only flag cross-chainring pairs so single-ring
    // drivetrains don't get spurious highlights.
    private static func markDuplicates(in combos: [GearCombo], multipleChainrings: Bool) -> [GearCombo] {
        var result = combos
        guard multipleChainrings else { return result }

        var groupCounter = 0
        // id → group number
        var groupMap: [UUID: Int] = [:]

        for i in 0..<result.count {
            for j in (i + 1)..<result.count {
                guard result[i].chainring != result[j].chainring else { continue }
                guard abs(result[i].gearInches - result[j].gearInches) <= 1.0 else { continue }

                let gi = groupMap[result[i].id]
                let gj = groupMap[result[j].id]

                switch (gi, gj) {
                case (nil, nil):
                    groupCounter += 1
                    groupMap[result[i].id] = groupCounter
                    groupMap[result[j].id] = groupCounter
                case let (g?, nil):
                    groupMap[result[j].id] = g
                case let (nil, g?):
                    groupMap[result[i].id] = g
                default:
                    break
                }
            }
        }

        for i in 0..<result.count {
            if let g = groupMap[result[i].id] {
                result[i].isDuplicate = true
                result[i].duplicateGroup = g
            }
        }
        return result
    }
}
