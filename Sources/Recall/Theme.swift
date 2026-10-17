import SwiftUI
import RecallCore

/// WaniKani-style colors and small shared views.
enum Theme {
    static let promptBand = Color(red: 0.63, green: 0.0, blue: 0.94)
    static let correct = Color(red: 0.53, green: 0.8, blue: 0.0)
    static let wrong = Color(red: 1.0, green: 0.0, blue: 0.2)
    static let meaningStrip = Color(white: 0.9)
    static let readingStrip = Color(white: 0.2)
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

struct StageBar: View {
    let counts: [Stage: Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Stage.allCases, id: \.self) { stage in
                VStack(spacing: 2) {
                    Text("\(counts[stage, default: 0])").font(.title2.bold())
                    Text(stage.name).font(.caption)
                }
                .foregroundStyle(.white)
                .frame(width: 104, height: 64)
                .background(stage.color, in: RoundedRectangle(cornerRadius: 8))
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
