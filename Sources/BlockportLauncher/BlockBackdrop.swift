import SwiftUI

/// A landscape of blocks drawn in code: sky, rolling grass, dirt and stone.
struct BlockBackdrop: View {
    private static let block: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: Theme.sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.6)
            ))
            let columns = Int(size.width / Self.block) + 1
            let rows = Int(size.height / Self.block) + 1
            for column in 0..<columns {
                let surface = rows * 3 / 5 + Int((sin(Double(column) * 0.45) + sin(Double(column) * 0.17)) * 1.6)
                for row in surface..<rows {
                    let depth = row - surface
                    let palette = depth == 0 ? Theme.grass : depth < 4 ? Theme.dirt : Theme.stone
                    let shade = palette[Self.noise(column, row) % palette.count]
                    let rect = CGRect(x: CGFloat(column) * Self.block, y: CGFloat(row) * Self.block, width: Self.block, height: Self.block)
                    context.fill(Path(rect), with: .color(shade))
                }
            }
        }
        .overlay(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom))
        .accessibilityHidden(true)
    }

    /// Deterministic per-block variation, so the landscape never flickers.
    private static func noise(_ x: Int, _ y: Int) -> Int {
        let hash = (x &* 73_856_093) ^ (y &* 19_349_663)
        return abs(hash) % 7
    }
}
