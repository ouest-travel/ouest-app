import RealityKit
import SwiftUI
import UIKit

/// Shared pieces of the RealityKit scenes (sticker medal, passport): the
/// studio lighting image, SwiftUI-to-texture rendering, and the base metal.
@available(iOS 18.0, *)
@MainActor
enum RealityStudio {

    enum Failure: Error {
        case textureRenderFailed
    }

    /// Renders a SwiftUI view in white on clear and uploads it as an opacity
    /// mask (`.raw` semantic). Sizes in the content are texture pixels, not
    /// UI points, so callers fix them deliberately.
    static func maskTexture<Content: View>(_ content: Content, size: CGSize) async throws -> TextureResource {
        let renderer = ImageRenderer(
            content: content
                .foregroundStyle(.white)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { throw Failure.textureRenderFailed }
        return try await TextureResource(
            image: image,
            withName: nil,
            options: .init(semantic: .raw, mipmapsMode: .allocateAndGenerateAll)
        )
    }

    /// Renders an opaque SwiftUI view as an sRGB colour texture for a
    /// material's base colour.
    static func colorTexture<Content: View>(_ content: Content, size: CGSize) async throws -> TextureResource {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage else { throw Failure.textureRenderFailed }
        return try await TextureResource(
            image: image,
            withName: nil,
            options: .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
        )
    }

    static func metal(_ color: UIColor, roughness: Float, clearcoat: Float = 0.25) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.metallic = .init(floatLiteral: 1)
        material.roughness = .init(floatLiteral: roughness)
        material.clearcoat = .init(floatLiteral: clearcoat)
        material.clearcoatRoughness = .init(floatLiteral: 0.3)
        return material
    }

    /// A small equirectangular "studio": bright overhead, a large soft key
    /// light upper-left, a rim light on the right and a faint floor bounce.
    /// Metals reflect this, which is what makes them read as metal.
    static func environmentImage() -> CGImage? {
        let size = CGSize(width: 512, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()

            func gradient(_ stops: [(CGFloat, CGFloat)], locations: [CGFloat]) -> CGGradient? {
                let colors = stops.map { UIColor(white: $0.0, alpha: $0.1).cgColor } as CFArray
                return CGGradient(colorsSpace: space, colors: colors, locations: locations)
            }

            if let sky = gradient([(0.85, 1), (0.42, 1), (0.12, 1)], locations: [0, 0.52, 1]) {
                cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }

            func softbox(at center: CGPoint, radius: CGFloat, brightness: CGFloat) {
                guard let glow = gradient([(brightness, 1), (brightness, 0)], locations: [0, 1]) else { return }
                cg.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
            }
            softbox(at: CGPoint(x: 150, y: 62), radius: 135, brightness: 1.0)
            softbox(at: CGPoint(x: 405, y: 92), radius: 85, brightness: 0.95)
            softbox(at: CGPoint(x: 256, y: 250), radius: 190, brightness: 0.45)

            // A bright horizon band: the classic highlight stripe on polished metal.
            cg.setFillColor(UIColor(white: 0.95, alpha: 0.55).cgColor)
            cg.fill(CGRect(x: 0, y: 120, width: size.width, height: 6))
        }.cgImage
    }

    /// Studio image-based light plus one key light, added to the scene.
    /// Returns the light entity so models can be made receivers of it.
    static func addLighting(to content: inout RealityViewCameraContent, name: String, keyFrom: SIMD3<Float>) async -> Entity? {
        var lightSource: Entity?
        if let image = environmentImage(),
           let environment = try? await EnvironmentResource(equirectangular: image, withName: name) {
            let light = Entity()
            light.components.set(ImageBasedLightComponent(source: .single(environment), intensityExponent: 1.1))
            content.add(light)
            lightSource = light
        }
        let key = DirectionalLight()
        key.light.intensity = 1400
        key.look(at: .zero, from: keyFrom, relativeTo: nil)
        content.add(key)
        return lightSource
    }
}
