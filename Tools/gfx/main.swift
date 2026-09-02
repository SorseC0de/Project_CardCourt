import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Flattens an animated GIF into a vertical sprite strip.
///
/// Vertical on purpose: wide strips are what hang `actool`, and a tall narrow one costs
/// the asset catalog nothing. Frame height is the source height, so the view slices it by
/// offsetting in whole frames.
func makeStrip(gif: String, into destination: String) -> (frames: Int, width: Int, height: Int)? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: gif) as CFURL, nil),
          CGImageSourceGetCount(src) > 0,
          let first = CGImageSourceCreateImageAtIndex(src, 0, nil)
    else { return nil }

    let count = CGImageSourceGetCount(src)
    let width = first.width, height = first.height

    guard let context = CGContext(data: nil, width: width, height: height * count,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .none

    for index in 0..<count {
        guard let frame = CGImageSourceCreateImageAtIndex(src, index, nil) else { continue }
        // CoreGraphics is bottom-up, so frame 0 has to land at the top of the strip.
        let y = (count - 1 - index) * height
        context.draw(frame, in: CGRect(x: 0, y: y, width: width, height: height))
    }

    guard let strip = context.makeImage(),
          let out = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: destination) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(out, strip, nil)
    guard CGImageDestinationFinalize(out) else { return nil }
    return (count, width, height)
}

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: gfx <in.gif> <out.png>"); exit(1) }
if let made = makeStrip(gif: args[1], into: args[2]) {
    print("\((args[1] as NSString).lastPathComponent) -> \(made.frames) frames, \(made.width)x\(made.height) each")
} else {
    print("failed: \(args[1])"); exit(1)
}
