import Testing
@testable import AmadareCore

private func run(_ field: inout RainField, seconds: Double) {
    for _ in 0..<Int(seconds * 30) { field.step(1.0 / 30) }
}

@Test func glassStartsBeadedWithinBounds() {
    let field = RainField(width: 800, height: 600, seed: 1)
    #expect(field.beads.count == field.targetBeads)
    #expect(field.targetBeads > 50)
    #expect(field.beads.allSatisfy { (0...800).contains($0.x) && (0...600).contains($0.y) && $0.radius > 0 })
}

@Test func runnerSlidesDownAndLeavesATrail() {
    var field = RainField(width: 800, height: 600, seed: 2, autoRunners: false)
    field.addRunner(x: 400, y: 50, radius: 5)
    run(&field, seconds: 1)
    #expect(field.runners.count == 1)
    #expect(field.runners[0].drop.y > 80)
    #expect(!field.trail.isEmpty)
    #expect(field.trail.allSatisfy { $0.radius < 5 })
}

@Test func runnerSwallowsBeadsInItsPath() {
    func slide(withBead: Bool) -> RainField {
        var field = RainField(width: 800, height: 600, seed: 3, autoRunners: false)
        field.removeAllBeads()
        if withBead { field.addBead(x: 400, y: 200, radius: 3) }
        field.addRunner(x: 400, y: 100, radius: 4)
        run(&field, seconds: 1.5)
        return field
    }
    let swallowed = slide(withBead: true)
    let dry = slide(withBead: false)
    #expect(swallowed.beads.isEmpty)
    #expect(swallowed.runners[0].drop.radius > dry.runners[0].drop.radius)
}

@Test func runnerLeavesThroughTheBottomAndTrailFades() {
    var field = RainField(width: 800, height: 600, seed: 4, autoRunners: false)
    field.addRunner(x: 400, y: 500, radius: 5)
    run(&field, seconds: 3)
    #expect(field.runners.isEmpty)
    run(&field, seconds: 8)
    #expect(field.trail.isEmpty)
}

@Test func condensationKeepsTheGlassBeaded() {
    var field = RainField(width: 800, height: 600, seed: 5)
    run(&field, seconds: 60)
    let ratio = Double(field.beads.count) / Double(field.targetBeads)
    #expect(ratio > 0.7 && ratio < 1.1)
    #expect(!field.streaks.isEmpty)
    #expect(field.streaks.allSatisfy { $0.y >= -$0.length && $0.y <= 600 })
}

@Test func sameSeedSameRain() {
    var a = RainField(width: 500, height: 400, seed: 9)
    var b = RainField(width: 500, height: 400, seed: 9)
    run(&a, seconds: 5)
    run(&b, seconds: 5)
    #expect(a == b)
}
