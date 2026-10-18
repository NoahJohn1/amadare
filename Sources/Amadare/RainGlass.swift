import SwiftUI
import AmadareCore

/// Water on the window: beads, drops sliding down with trails, and faint rain falling behind.
/// Drawn every frame from `RainField`; with Reduce Motion on, the beads hold still.
struct RainGlass: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rain = RainModel()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let field = rain.advance(to: timeline.date, size: size, animate: !reduceMotion)
                Self.draw(field, in: &context)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func draw(_ field: RainField, in context: inout GraphicsContext) {
        var behind = context
        behind.addFilter(.blur(radius: 1.5))
        for streak in field.streaks {
            var path = Path()
            path.move(to: CGPoint(x: streak.x, y: streak.y))
            path.addLine(to: CGPoint(x: streak.x - streak.length * 0.08, y: streak.y + streak.length))
            behind.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 1.2)
        }
        for drop in field.trail { drawDrop(drop, opacity: drop.opacity * 0.8, in: &context) }
        for drop in field.beads { drawDrop(drop, in: &context) }
        for runner in field.runners { drawDrop(runner.drop, stretch: 1.3, in: &context) }
    }

    /// A drop is a tiny lens: dark crescent of shadow below, body brightening toward the bottom
    /// where light from above is focused, a thin rim, and a highlight up top.
    private static func drawDrop(_ drop: Drop, stretch: Double = 1, opacity: Double = 1, in context: inout GraphicsContext) {
        let r = drop.radius
        let rect = CGRect(x: drop.x - r, y: drop.y - r * stretch, width: 2 * r, height: 2 * r * stretch)
        let shape = Path(ellipseIn: rect)
        context.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: r * 0.25)), with: .color(.black.opacity(0.22 * opacity)))
        context.fill(shape, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.04 * opacity), .white.opacity(0.26 * opacity)]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        context.stroke(shape, with: .color(.white.opacity(0.16 * opacity)), lineWidth: max(0.5, r * 0.12))
        if r > 1.4 {
            let highlight = CGRect(x: drop.x - r * 0.45, y: drop.y - r * 0.6 * stretch, width: r * 0.4, height: r * 0.3)
            context.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.7 * opacity)))
        }
    }
}

/// Holds the simulation between frames. A new window size starts fresh glass.
final class RainModel {
    private var field: RainField?
    private var lastDate: Date?

    func advance(to date: Date, size: CGSize, animate: Bool) -> RainField {
        if field == nil || field?.width != Double(size.width) || field?.height != Double(size.height) {
            field = RainField(width: size.width, height: size.height, seed: 7)
            lastDate = date
        }
        if animate, let lastDate {
            // Cap the step so a stalled frame doesn't teleport the drops.
            field?.step(min(1.0 / 15, date.timeIntervalSince(lastDate)))
        }
        lastDate = date
        return field!
    }
}
