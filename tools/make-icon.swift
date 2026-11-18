// Genera l'icona dell'app da un'immagine sorgente: ritaglia la scheda dallo sfondo, toglie gli angoli
// dello sfondo, la mette nella griglia delle icone macOS (tela 1024, riquadro 824 con angoli 185) e
// scrive tutte le dimensioni dell'iconset.
// Uso: swiftc tools/make-icon.swift -o build/make-icon && build/make-icon <sorgente> <cartella-uscita>
//      iconutil -c icns <cartella-uscita>/AppIcon.iconset -o Resources/AppIcon.icns
import AppKit
import CoreImage

let args = CommandLine.arguments
guard args.count == 3,
      let source = NSImage(contentsOfFile: args[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Uso: make-icon <sorgente> <cartella-uscita>"); exit(1)
}
let out = args[2]
let space = CGColorSpaceCreateDeviceRGB()
let rgba = CGImageAlphaInfo.premultipliedLast.rawValue

// Pixel della sorgente (riga 0 = in alto)
let w = source.width, h = source.height
let pixels = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: rgba)!
pixels.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))
let data = pixels.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
func px(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
    let i = (y * w + x) * 4
    return (Int(data[i]), Int(data[i + 1]), Int(data[i + 2]))
}

// 1. La scheda: tutto ciò che si stacca dal colore dello sfondo (letto nell'angolo)
let bg = px(2, 2)
func isCard(_ x: Int, _ y: Int) -> Bool {
    let p = px(x, y)
    return abs(p.r - bg.r) + abs(p.g - bg.g) + abs(p.b - bg.b) > 90
}
var left = 0; while left < w - 1 && !isCard(left, h / 2) { left += 1 }
var right = w - 1; while right > 0 && !isCard(right, h / 2) { right -= 1 }
var top = 0; while top < h - 1 && !isCard(w / 2, top) { top += 1 }
var bottom = h - 1; while bottom > 0 && !isCard(w / 2, bottom) { bottom -= 1 }
let card = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)

// 2. Raggio degli angoli della scheda: lungo la diagonale l'angolo arrotondato «arretra» di r·(1 − 1/√2)
var d = 0; while d < Int(card.width) / 2 && !isCard(left + d, top + d) { d += 1 }
let cardRadius = CGFloat(d) / (1 - 1 / 2.squareRoot()) + 4

// 3. Colore della carta: mediana di una fascia lungo i quattro lati (lontano dagli angoli), così il bordo
//    del riquadro ha lo stesso tono del disegno
var rs: [Int] = [], gs: [Int] = [], bs: [Int] = []
func sample(_ x: Int, _ y: Int) { let p = px(x, y); rs.append(p.r); gs.append(p.g); bs.append(p.b) }
let inset = Int(cardRadius), band = 12...40
for x in stride(from: left + inset, to: right - inset, by: 4) { for d in band { sample(x, top + d); sample(x, bottom - d) } }
for y in stride(from: top + inset, to: bottom - inset, by: 4) { for d in band { sample(left + d, y); sample(right - d, y) } }
func median(_ v: [Int]) -> CGFloat { CGFloat(v.sorted()[v.count / 2]) / 255 }
let paper = CGColor(red: median(rs), green: median(gs), blue: median(bs), alpha: 1)

let art = source.cropping(to: card)!
print("scheda \(Int(card.width))×\(Int(card.height)) a (\(left), \(top)), raggio ≈ \(Int(cardRadius)) px")

// 4. Tela 1024: riquadro macOS 824 con angoli 185 e ombra; dentro la scheda al 90%, senza i suoi angoli
let size = 1024
let canvas = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: rgba)!
canvas.interpolationQuality = .high
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
canvas.saveGState()
canvas.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
canvas.addPath(tilePath); canvas.setFillColor(paper); canvas.fillPath()
canvas.restoreGState()
canvas.saveGState()
canvas.addPath(tilePath); canvas.clip()
// Al 93% la sveglia in alto a sinistra resta dentro l'angolo arrotondato del riquadro.
let scale = tile.width * 0.93 / card.width
let artRect = CGRect(x: tile.midX - card.width * scale / 2, y: tile.midY - card.height * scale / 2,
                     width: card.width * scale, height: card.height * scale)
// Maschera sfumata: il disegno si fonde con la carta del riquadro invece di avere un bordo netto
let feather: CGFloat = 14
let maskContext = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
maskContext.setFillColor(gray: 0, alpha: 1); maskContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
maskContext.addPath(CGPath(roundedRect: artRect.insetBy(dx: feather, dy: feather),
                           cornerWidth: cardRadius * scale, cornerHeight: cardRadius * scale, transform: nil))
maskContext.setFillColor(gray: 1, alpha: 1); maskContext.fillPath()
let blurred = CIImage(cgImage: maskContext.makeImage()!)
    .clampedToExtent()
    .applyingGaussianBlur(sigma: Double(feather) / 2)
    .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
let mask = CIContext().createCGImage(blurred, from: blurred.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())!
canvas.clip(to: CGRect(x: 0, y: 0, width: size, height: size), mask: mask)
canvas.draw(art, in: artRect)
canvas.restoreGState()
let master = canvas.makeImage()!

// 5. Scrittura: AppIcon.png (1024) e iconset completo
func writePNG(_ image: CGImage, _ path: String) {
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}
func scaled(_ px: Int) -> CGImage {
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: rgba)!
    c.interpolationQuality = .high
    c.draw(master, in: CGRect(x: 0, y: 0, width: px, height: px))
    return c.makeImage()!
}
let iconset = out + "/AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
writePNG(master, out + "/AppIcon.png")
for base in [16, 32, 128, 256, 512] {
    writePNG(scaled(base), "\(iconset)/icon_\(base)x\(base).png")
    writePNG(scaled(base * 2), "\(iconset)/icon_\(base)x\(base)@2x.png")
}
print("scritti \(out)/AppIcon.png e \(iconset)")
