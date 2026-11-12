import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift Scripts/draw-icon.swift OUTPUT.png")
}
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

let tile = CGRect(x: 82, y: 82, width: 860, height: 860)
let silhouette = CGPath(roundedRect: tile, cornerWidth: 182, cornerHeight: 182, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -13), blur: 36, color: CGColor(gray: 0, alpha: 0.36))
context.setFillColor(rgb(0x15282D))
context.addPath(silhouette)
context.fillPath()
context.restoreGState()
context.setStrokeColor(rgb(0x334A4F))
context.setLineWidth(4)
context.addPath(silhouette)
context.strokePath()

context.translateBy(x: 512, y: 512)
let dial = CGRect(x: -309, y: -309, width: 618, height: 618)
context.setFillColor(rgb(0x101F24))
context.fillEllipse(in: dial)
context.setStrokeColor(rgb(0x40575B))
context.setLineWidth(10)
context.strokeEllipse(in: dial)

context.setLineCap(.round)
context.setStrokeColor(rgb(0xF0AF6E))
context.setLineWidth(25)
context.addArc(center: .zero, radius: 307, startAngle: .pi * 0.12, endAngle: .pi * 0.39, clockwise: false)
context.strokePath()

let blade = CGMutablePath()
blade.move(to: CGPoint(x: 25, y: 31))
blade.addCurve(to: CGPoint(x: -40, y: 237), control1: CGPoint(x: 118, y: 114), control2: CGPoint(x: 116, y: 242))
blade.addCurve(to: CGPoint(x: -53, y: 175), control1: CGPoint(x: -72, y: 235), control2: CGPoint(x: -74, y: 204))
blade.addCurve(to: CGPoint(x: -23, y: 42), control1: CGPoint(x: -17, y: 126), control2: CGPoint(x: 1, y: 80))
blade.closeSubpath()
for (index, color) in [0xA4EBDD, 0x70D9C7, 0x58BEAF].enumerated() {
    context.saveGState()
    context.rotate(by: CGFloat(index) * .pi * 2 / 3)
    context.setFillColor(rgb(UInt32(color)))
    context.addPath(blade)
    context.fillPath()
    context.restoreGState()
}
context.setFillColor(rgb(0xC1F2E9))
context.fillEllipse(in: CGRect(x: -29, y: -29, width: 58, height: 58))

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Icon PNG could not be written.") }
