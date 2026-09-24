import SwiftUI

/// Ordinary SwiftUI content used as the input of layer and distortion demos:
/// a test card with a gradient, a grid, color swatches and type, so
/// distortions, color changes and blur are easy to read.
struct SampleContent: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.32),
                                      Color(red: 0.55, green: 0.20, blue: 0.45),
                                      Color(red: 0.95, green: 0.60, blue: 0.30)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            // Grid
            let step = max(size.width, size.height) / 16
            var grid = Path()
            var x: CGFloat = 0
            while x <= size.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(grid, with: .color(.white.opacity(0.35)), lineWidth: 1)

            // Swatches
            let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .white]
            let swatch = size.width / CGFloat(colors.count + 2)
            for (i, color) in colors.enumerated() {
                let r = CGRect(x: swatch * CGFloat(i + 1), y: size.height * 0.72, width: swatch * 0.8, height: swatch * 0.8)
                context.fill(Path(ellipseIn: r), with: .color(color))
            }

            // Center target
            let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
            let radius = min(size.width, size.height) * 0.22
            for i in 0..<4 {
                let r = radius * (1 - CGFloat(i) * 0.24)
                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(.white), lineWidth: 2)
            }

            let title = Text("LYGIA")
                .font(.system(size: min(size.width, size.height) * 0.16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            context.draw(title, at: c)

            let caption = Text("Metal · SwiftUI shaders")
                .font(.system(size: min(size.width, size.height) * 0.045, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
            context.draw(caption, at: CGPoint(x: size.width / 2, y: size.height * 0.12))
        }
    }
}

#Preview {
    SampleContent().frame(width: 400, height: 400)
}
