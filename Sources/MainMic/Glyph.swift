import AppKit

/// MainMic's "input level" glyph: five rounded bars. The geometry matches
/// scripts/make_icon.py so the menu bar icon and the app icon are the same shape.
enum Glyph {
    static let barHeights: [CGFloat] = [0.42, 0.78, 1.0, 0.62, 0.30]
    static let gapRatio: CGFloat = 0.6

    /// Template image for the menu bar; macOS tints it for light and dark menu bars.
    /// While paused the bars collapse to dots.
    static func menuBarImage(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setFill()
            draw(in: rect.insetBy(dx: 1.5, dy: 1.5), heights: paused ? barHeights.map { _ in 0 } : barHeights)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "MainMic (paused)" : "MainMic"
        return image
    }

    private static func draw(in rect: NSRect, heights: [CGFloat]) {
        let count = CGFloat(heights.count)
        let barWidth = rect.width / (count + gapRatio * (count - 1))
        let gap = barWidth * gapRatio
        for (i, h) in heights.enumerated() {
            let barHeight = max(barWidth, rect.height * h)
            let bar = NSRect(
                x: rect.minX + CGFloat(i) * (barWidth + gap),
                y: rect.midY - barHeight / 2,
                width: barWidth,
                height: barHeight)
            NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        }
    }
}
