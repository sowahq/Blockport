import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders the Blockport app icon, a 1024 × 1024 PNG, to the path given as
/// the first argument: a block rising through a golden ring, on the macOS
/// icon grid.

let canvas: CGFloat = 1024
let tileInset: CGFloat = 100
let tileRadius: CGFloat = 185

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func polygon(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    return path
}

func fill(_ context: CGContext, _ path: CGPath, gradient colors: [CGColor], from start: CGPoint, to end: CGPoint) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

guard let output = CommandLine.arguments.dropFirst().first else {
    FileHandle.standardError.write(Data("usage: render-icon.swift <output.png>\n".utf8))
    exit(EXIT_FAILURE)
}

let context = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
context.translateBy(x: 0, y: canvas)
context.scaleBy(x: 1, y: -1)

let tile = CGRect(x: tileInset, y: tileInset, width: canvas - 2 * tileInset, height: canvas - 2 * tileInset)
let tilePath = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 18), blur: 36, color: color(0, 0, 0, 0.35))
context.addPath(tilePath)
context.setFillColor(color(16, 26, 46))
context.fillPath()
context.restoreGState()
fill(context, tilePath, gradient: [color(18, 30, 54), color(14, 52, 38)], from: CGPoint(x: 0, y: tile.minY), to: CGPoint(x: 0, y: tile.maxY))

let center = CGPoint(x: canvas / 2, y: canvas / 2 + 20)
context.saveGState()
context.addPath(tilePath)
context.clip()
context.setShadow(offset: .zero, blur: 40, color: color(242, 178, 61, 0.55))
context.setLineWidth(30)
context.setStrokeColor(color(242, 178, 61))
context.strokeEllipse(in: CGRect(x: center.x - 290, y: center.y - 290, width: 580, height: 580))
context.restoreGState()

let side: CGFloat = 230
let horizontal = side * cos(.pi / 6)
let half = side / 2
let cubeCenter = CGPoint(x: canvas / 2, y: center.y + 10)
let top = CGPoint(x: cubeCenter.x, y: cubeCenter.y - side)
let left = CGPoint(x: cubeCenter.x - horizontal, y: cubeCenter.y - half)
let right = CGPoint(x: cubeCenter.x + horizontal, y: cubeCenter.y - half)
let middle = cubeCenter
let bottom = CGPoint(x: cubeCenter.x, y: cubeCenter.y + side)
let bottomLeft = CGPoint(x: left.x, y: left.y + side)
let bottomRight = CGPoint(x: right.x, y: right.y + side)
let grassDepth: CGFloat = 0.24

func lerp(_ from: CGPoint, _ to: CGPoint, _ amount: CGFloat) -> CGPoint {
    CGPoint(x: from.x + (to.x - from.x) * amount, y: from.y + (to.y - from.y) * amount)
}

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: 24), blur: 30, color: color(0, 0, 0, 0.45))
context.addPath(polygon([top, right, bottomRight, bottom, bottomLeft, left]))
context.setFillColor(color(60, 40, 26))
context.fillPath()
context.restoreGState()

fill(context, polygon([left, middle, bottom, bottomLeft]), gradient: [color(150, 101, 63), color(117, 77, 47)], from: left, to: bottom)
fill(context, polygon([middle, right, bottomRight, bottom]), gradient: [color(110, 72, 44), color(84, 55, 34)], from: middle, to: bottomRight)
fill(context, polygon([left, middle, lerp(middle, bottom, grassDepth), lerp(left, bottomLeft, grassDepth)]), gradient: [color(92, 186, 82), color(70, 156, 64)], from: left, to: middle)
fill(context, polygon([middle, right, lerp(right, bottomRight, grassDepth), lerp(middle, bottom, grassDepth)]), gradient: [color(66, 146, 60), color(54, 124, 50)], from: middle, to: right)
fill(context, polygon([top, right, middle, left]), gradient: [color(128, 214, 104), color(88, 182, 78)], from: top, to: middle)

context.setStrokeColor(color(255, 255, 255, 0.18))
context.setLineWidth(4)
context.setLineJoin(.round)
context.addLines(between: [left, top, right])
context.strokePath()
context.setStrokeColor(color(0, 0, 0, 0.25))
context.addLines(between: [middle, bottom])
context.strokePath()

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(EXIT_FAILURE) }
