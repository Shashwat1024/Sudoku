import SwiftUI

extension View {
    /// Draws the view on a Liquid Glass surface of the given shape.
    func glassSurface<S: Shape>(
        _ shape: S, tint: Color? = nil, interactive: Bool = true
    ) -> some View {
        // contentShape makes the whole surface tappable, including transparent gaps
        // (e.g. the Spacer between a label and its chevron).
        contentShape(shape)
            .glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
    }
}

/// Soft colour behind the screen so glass has something to refract.
struct AmbientBackground: View {
    let theme: Theme
    /// Zen mode: add a slow time-of-day sky gradient.
    var zen = false

    /// Two sky colours for the hour: dawn, day, dusk, night.
    private static func sky(hour: Int) -> (Color, Color) {
        switch hour {
        case 5..<8: return (Color(red: 1.00, green: 0.74, blue: 0.70), Color(red: 1.00, green: 0.90, blue: 0.75))
        case 8..<17: return (Color(red: 0.55, green: 0.80, blue: 1.00), Color(red: 0.85, green: 0.95, blue: 1.00))
        case 17..<20: return (Color(red: 1.00, green: 0.60, blue: 0.40), Color(red: 0.50, green: 0.40, blue: 0.80))
        default: return (Color(red: 0.10, green: 0.12, blue: 0.30), Color(red: 0.25, green: 0.20, blue: 0.45))
        }
    }

    var body: some View {
        ZStack {
            if let bg = theme.background {
                bg
            } else {
                Rectangle().fill(.background)
            }
            if zen {
                TimelineView(.everyMinute) { context in
                    let hour = Calendar.current.component(.hour, from: context.date)
                    let (top, bottom) = Self.sky(hour: hour)
                    LinearGradient(
                        colors: [top.opacity(0.45), bottom.opacity(0.45)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
            Circle()
                .fill(theme.accent.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -140, y: -260)
            Circle()
                .fill(theme.accent.opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 160, y: 300)
        }
        .clipped()
        .ignoresSafeArea()
    }
}
