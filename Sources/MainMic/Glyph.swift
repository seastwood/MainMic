import AppKit

/// MainMic's "input level" glyph: five rounded bars, the centre one drawn as a
/// "1" with a flag and a base (the main mic). The geometry matches
/// scripts/make_icon.py so the menu bar icon and the app icon are the same shape.
enum Glyph {
    static let barHeights: [CGFloat] = [0.30, 0.52, 1.0, 0.62, 0.42]
    static let gapRatio: CGFloat = 0.6
    /// The "1" flag runs from the top of the centre bar down to the left, this far in
    /// bar widths (between the rounded ends' centres), at this fraction of a bar's width.
    static let oneFlagOffset = CGPoint(x: 0.9, y: 0.5)
    static let oneFlagWidth: CGFloat = 0.75
    /// ...and it stands on a base this far either side of the bar's centre (in bar
    /// widths, to the rounded ends' centres), as thick as the flag.
    static let oneBaseHalf: CGFloat = 0.8

    /// Template image for the menu bar; macOS tints it for light and dark menu bars.
    /// While paused the bars collapse to dots.
    static func menuBarImage(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.set()
            draw(in: rect.insetBy(dx: 1.5, dy: 1.5), heights: paused ? barHeights.map { _ in 0 } : barHeights,
                 one: !paused)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "MainMic (paused)" : "MainMic"
        return image
    }

    private static func draw(in rect: NSRect, heights: [CGFloat], one: Bool) {
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
            if one && i == heights.count / 2 {
                let flagRadius = barWidth * oneFlagWidth / 2
                let start = NSPoint(x: bar.midX, y: bar.maxY - flagRadius)
                let marks = NSBezierPath()  // the flag and the base
                marks.move(to: start)
                marks.line(to: NSPoint(x: start.x - oneFlagOffset.x * barWidth,
                                      y: start.y - oneFlagOffset.y * barWidth))
                let baseY = bar.minY + flagRadius
                marks.move(to: NSPoint(x: bar.midX - oneBaseHalf * barWidth, y: baseY))
                marks.line(to: NSPoint(x: bar.midX + oneBaseHalf * barWidth, y: baseY))
                marks.lineWidth = flagRadius * 2
                marks.lineCapStyle = .round
                marks.stroke()
            }
        }
    }
}
