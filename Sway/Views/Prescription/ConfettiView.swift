import SwiftUI

/// One-shot confetti shower drawn with Canvas. Pieces fall from above the screen, sway and spin,
/// and the view stops redrawing once they've all landed.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var pieces = (0..<140).map { _ in Piece() }

    private static let lifetime: TimeInterval = 4.5

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(paused: Date.now.timeIntervalSince(start) > Self.lifetime)) { context in
                Canvas { canvas, size in
                    let t = context.date.timeIntervalSince(start)
                    for piece in pieces {
                        draw(piece, at: t, in: &canvas, size: size)
                    }
                }
            }
        }
    }

    private func draw(_ piece: Piece, at time: TimeInterval, in canvas: inout GraphicsContext, size: CGSize) {
        let t = time - piece.delay
        guard t > 0 else { return }
        let y = -20 + piece.speed * t + 120 * t * t
        guard y < size.height + 20 else { return }
        let x = piece.x * size.width + sin(t * piece.swayRate + piece.phase) * piece.sway
        // Fade out over the last second of the shower.
        let opacity = min(1, max(0, Self.lifetime - time))

        var context = canvas
        context.opacity = opacity
        context.translateBy(x: x, y: y)
        context.rotate(by: .radians(t * piece.spin))
        // Squash on one axis to fake the paper flipping in 3D.
        context.scaleBy(x: 1, y: abs(cos(t * piece.flip)) * 0.8 + 0.2)
        let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                          width: piece.size.width, height: piece.size.height)
        let shape = piece.round ? Path(ellipseIn: rect) : Path(rect)
        context.fill(shape, with: .color(piece.color))
    }

    private struct Piece {
        private static let colors: [Color] = [.pink, .orange, .yellow, .green, .mint, .blue, .purple]

        var x = Double.random(in: 0...1)
        var delay = Double.random(in: 0...0.8)
        var speed = Double.random(in: 80...220)
        var sway = Double.random(in: 10...40)
        var swayRate = Double.random(in: 2...5)
        var phase = Double.random(in: 0...(2 * .pi))
        var spin = Double.random(in: -6...6)
        var flip = Double.random(in: 3...9)
        var size = CGSize(width: Double.random(in: 6...11), height: Double.random(in: 9...15))
        var round = Bool.random() && Bool.random()
        var color = colors.randomElement()!
    }
}

#Preview {
    ConfettiView()
}
