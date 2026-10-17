import SwiftUI
import RecallCore

/// Colors and type. Glass needs something behind it to refract, so every screen sits on
/// `KanjiBackdrop`: deep ink with a huge blurred copy of the word being studied.
enum Theme {
    static let ink = Color(red: 0.10, green: 0.06, blue: 0.20)        // #1A1033
    static let violet = Color(red: 0.63, green: 0.0, blue: 0.94)      // #A100F0, WaniKani vocabulary
    static let correct = Color(red: 0.53, green: 0.8, blue: 0.0)      // #88CC00
    static let wrong = Color(red: 1.0, green: 0.0, blue: 0.2)         // #FF0033
}

extension Stage {
    var color: Color {
        switch self {
        case .apprentice: Color(red: 0.87, green: 0.0, blue: 0.58)
        case .guru: Color(red: 0.53, green: 0.18, blue: 0.62)
        case .master: Color(red: 0.16, green: 0.35, blue: 0.85)
        case .enlightened: Color(red: 0.0, green: 0.58, blue: 0.87)
        case .burned: Color(white: 0.26)
        }
    }
}

struct KanjiBackdrop: View {
    let glyph: String

    var body: some View {
        Theme.ink
            .overlay {
                Text(glyph)
                    .font(.system(size: 560, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .foregroundStyle(Theme.violet.opacity(0.75))
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
