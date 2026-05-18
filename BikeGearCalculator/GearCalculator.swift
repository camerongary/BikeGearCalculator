import Foundation

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
