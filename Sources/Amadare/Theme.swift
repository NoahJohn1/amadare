import SwiftUI
import AmadareCore

/// Colors for a rainy night. Glass needs something behind it to refract, so every screen sits on
/// `KanjiBackdrop` (the frosted window, tinted with ink, under a huge blurred copy of the word being
/// studied) with `RainGlass` (water beading on the window) in front of it.
enum Theme {
    static let ink = Color(red: 0.04, green: 0.09, blue: 0.13)        // #0B1622, night-rain navy
    static let ai = Color(red: 0.18, green: 0.44, blue: 0.65)         // #2E70A6, 藍 indigo: prompt and mark
    static let mizu = Color(red: 0.37, green: 0.66, blue: 0.88)       // #5FA8E0, 水 water: main buttons
    static let correct = Color(red: 0.53, green: 0.8, blue: 0.0)      // #88CC00
    static let wrong = Color(red: 1.0, green: 0.0, blue: 0.2)         // #FF0033

    /// Amadare (雨垂れ) is rain dripping from the eaves; its mark is 雫, a single drop.
    static let brandGlyph = "雫"
    static let motto = "Consistency trumps intensity."
}

extension Stage {
    var color: Color {
        switch self {
        // Light rain deepening to still water; Burned is wet slate.
        case .apprentice: Color(red: 0.42, green: 0.72, blue: 0.90)
        case .guru: Color(red: 0.24, green: 0.56, blue: 0.82)
        case .master: Color(red: 0.16, green: 0.40, blue: 0.68)
        case .enlightened: Color(red: 0.13, green: 0.25, blue: 0.52)
        case .burned: Color(red: 0.24, green: 0.27, blue: 0.32)
        }
    }
}

struct KanjiBackdrop: View {
    let glyph: String

    var body: some View {
        Theme.ink.opacity(0.45)
            .overlay {
                // Brush-like Mincho, kept dim so it sets a mood without competing with the UI.
                Text(glyph)
                    .font(.custom("HiraMinProN-W6", size: 560))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .foregroundStyle(Theme.ai.opacity(0.3))
                    .blur(radius: 6)
                    .padding(-40)
                    .id(glyph)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.5), value: glyph)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// The 雫 mark in an indigo glass disc beside the name, with the motto underneath.
struct Wordmark: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text(Theme.brandGlyph)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular.tint(Theme.ai.opacity(0.75)), in: .circle)
                Text("Amadare")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(Theme.motto)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Amadare. \(Theme.motto)")
    }
}

/// The five stages as glass tiles that merge into one strip.
struct StageBar: View {
    let counts: [Stage: Int]

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Stage.allCases, id: \.self) { stage in
                    VStack(spacing: 2) {
                        Text("\(counts[stage, default: 0])")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(stage.name).font(.callout)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 112, height: 72)
                    .glassEffect(.regular.tint(stage.color.opacity(0.7)), in: .rect(cornerRadius: 18))
                }
            }
        }
    }
}

/// Horizontal shake; animate by incrementing `animatableData`.
struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}
