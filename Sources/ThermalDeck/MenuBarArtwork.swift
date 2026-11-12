import AppKit

@MainActor
enum MenuBarArtwork {
    static func image(values: [String]) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let runs = values.prefix(2).map {
            NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.black])
        }
        let markSize: CGFloat = 16
        let spacing: CGFloat = 5
        let width = markSize + runs.reduce(CGFloat.zero) { $0 + ceil($1.size().width) + spacing }
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            var x = bounds.minX
            if runs.count == 2 {
                let left = runs[0]
                left.draw(at: NSPoint(x: x, y: bounds.midY - left.size().height / 2))
                x += ceil(left.size().width) + spacing
            }

            drawMark(in: context, center: CGPoint(x: x + markSize / 2, y: bounds.midY), size: markSize)

            if let right = runs.last {
                right.draw(at: NSPoint(x: x + markSize + spacing, y: bounds.midY - right.size().height / 2))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawMark(in context: CGContext, center: CGPoint, size: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: size / 680, y: size / 680)
        let ink = CGColor(gray: 0, alpha: 1)
        context.setStrokeColor(ink)
        context.setFillColor(ink)
        context.setLineWidth(42)
        context.strokeEllipse(in: CGRect(x: -303, y: -303, width: 606, height: 606))

        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 25, y: 31))
        blade.addCurve(to: CGPoint(x: -40, y: 237), control1: CGPoint(x: 118, y: 114), control2: CGPoint(x: 116, y: 242))
        blade.addCurve(to: CGPoint(x: -53, y: 175), control1: CGPoint(x: -72, y: 235), control2: CGPoint(x: -74, y: 204))
        blade.addCurve(to: CGPoint(x: -23, y: 42), control1: CGPoint(x: -17, y: 126), control2: CGPoint(x: 1, y: 80))
        blade.closeSubpath()

        for _ in 0..<3 {
            context.addPath(blade)
            context.fillPath()
            context.rotate(by: .pi * 2 / 3)
        }
        context.fillEllipse(in: CGRect(x: -31, y: -31, width: 62, height: 62))
    }
}
