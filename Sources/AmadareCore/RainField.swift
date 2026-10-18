import Foundation

/// A drop of water on the glass, in points. `opacity` is used by fading trail drops.
public struct Drop: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var radius: Double
    public var opacity: Double = 1
}

/// A drop sliding down the glass.
public struct Runner: Sendable, Equatable {
    public var drop: Drop
    var speed: Double
    var wobble: Double
    var lastTrailY: Double
}

/// An out-of-focus raindrop falling behind the glass.
public struct Streak: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var length: Double
    var speed: Double
}

/// Water on a window: beads condense, some grow heavy and slide down, swallowing beads in
/// their path and leaving a trail of tiny drops that evaporate. Light rain falls behind.
/// Deterministic for a given seed.
public struct RainField: Sendable, Equatable {
    public let width: Double
    public let height: Double
    public let targetBeads: Int
    public private(set) var beads: [Drop] = []
    public private(set) var runners: [Runner] = []
    public private(set) var trail: [Drop] = []
    public private(set) var streaks: [Streak] = []

    private var rng: SplitMix64
    private let autoRunners: Bool
    private var condensation = 0.0
    private var condenses = true
    private var nextRunnerIn: Double

    static let trailLifetime = 6.0

    public init(width: Double, height: Double, seed: UInt64, density: Double = 1, autoRunners: Bool = true) {
        self.width = width
        self.height = height
        self.targetBeads = max(1, Int(width * height / 2600 * density))
        self.autoRunners = autoRunners
        self.rng = SplitMix64(seed: seed)
        self.nextRunnerIn = 1
        for _ in 0..<targetBeads { beads.append(randomBead()) }
        for _ in 0..<max(1, Int(width / 28)) {
            streaks.append(Streak(x: rng.next(in: 0...width), y: rng.next(in: 0...height),
                                  length: rng.next(in: 30...70), speed: rng.next(in: 300...450)))
        }
        nextRunnerIn = rng.next(in: 0.5...2.5)
    }

    public mutating func step(_ dt: Double) {
        condense(dt)
        if autoRunners { spawnRunners(dt) }
        moveRunners(dt)
        for i in trail.indices { trail[i].opacity -= dt / Self.trailLifetime }
        trail.removeAll { $0.opacity <= 0 }
        for i in streaks.indices {
            streaks[i].y += streaks[i].speed * dt
            if streaks[i].y > height {
                streaks[i].y = -streaks[i].length
                streaks[i].x = rng.next(in: 0...width)
            }
        }
    }

    // MARK: Test hooks

    mutating func addRunner(x: Double, y: Double, radius: Double) {
        runners.append(Runner(drop: Drop(x: x, y: y, radius: radius), speed: 20, wobble: 0, lastTrailY: y))
    }

    mutating func addBead(x: Double, y: Double, radius: Double) {
        beads.append(Drop(x: x, y: y, radius: radius))
    }

    /// Dries the glass and stops new beads forming.
    mutating func removeAllBeads() {
        beads.removeAll()
        condenses = false
    }

    // MARK: Simulation

    private mutating func randomBead() -> Drop {
        // Mostly small beads, a few larger ones.
        let size = rng.next(in: 0...1)
        return Drop(x: rng.next(in: 0...width), y: rng.next(in: 0...height), radius: 0.8 + 3.2 * size * size)
    }

    private mutating func condense(_ dt: Double) {
        guard condenses else { return }
        condensation += Double(max(0, targetBeads - beads.count)) * 0.4 * dt + 0.5 * dt
        while condensation >= 1 {
            condensation -= 1
            if beads.count < targetBeads + targetBeads / 10 { beads.append(randomBead()) }
        }
    }

    private mutating func spawnRunners(_ dt: Double) {
        nextRunnerIn -= dt
        guard nextRunnerIn <= 0 else { return }
        nextRunnerIn = rng.next(in: 3...7)
        // A heavy bead starts to slide; otherwise a drop arrives at the top.
        if let index = beads.indices.filter({ beads[$0].radius > 2.6 }).randomElement(using: &rng) {
            let bead = beads.remove(at: index)
            runners.append(Runner(drop: Drop(x: bead.x, y: bead.y, radius: bead.radius + 1.2), speed: 10,
                                  wobble: rng.next(in: 0...(2 * .pi)), lastTrailY: bead.y))
        } else {
            let y = -4.0
            runners.append(Runner(drop: Drop(x: rng.next(in: 0...width), y: y, radius: rng.next(in: 3...5)), speed: 30,
                                  wobble: rng.next(in: 0...(2 * .pi)), lastTrailY: y))
        }
    }

    private mutating func moveRunners(_ dt: Double) {
        for i in runners.indices {
            var runner = runners[i]
            let maxSpeed = 30 + runner.drop.radius * 7
            runner.speed = min(maxSpeed, runner.speed + 35 * dt)
            runner.drop.y += runner.speed * dt
            runner.wobble += dt * 1.5
            runner.drop.x += sin(runner.wobble) * 3 * dt   // a slight meander, a few points at most

            // Swallow beads in the path.
            let reach = runner.drop.radius
            let before = beads.count
            beads.removeAll { bead in
                let hit = hypot(bead.x - runner.drop.x, bead.y - runner.drop.y) < reach + bead.radius
                if hit { runner.drop.radius = min(7, (runner.drop.radius * runner.drop.radius + bead.radius * bead.radius * 0.5).squareRoot()) }
                return hit
            }
            if beads.count != before { runner.speed *= 0.85 }

            // Leave a trail, losing a little water each time.
            if runner.drop.y - runner.lastTrailY > runner.drop.radius * 2.2 {
                trail.append(Drop(x: runner.drop.x, y: runner.drop.y - runner.drop.radius,
                                  radius: max(0.6, runner.drop.radius * 0.35)))
                runner.lastTrailY = runner.drop.y
                runner.drop.radius = max(2.5, runner.drop.radius * 0.985)
            }
            runners[i] = runner
        }
        runners.removeAll { $0.drop.y - $0.drop.radius > height }
    }
}

/// Small, fast, seedable generator so the rain is reproducible in tests.
struct SplitMix64: RandomNumberGenerator, Sendable, Equatable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }
}
