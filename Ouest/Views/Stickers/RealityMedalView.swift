import RealityKit
import SwiftUI
import UIKit

/// Physically rendered medal for the sticker detail sheet (iOS 18+).
///
/// A bevelled ring in the rarity-tier metal (`StickerType.tier`), a thin
/// enamel inlay in the sticker's foil colour, a dark enamel disc with a
/// guilloché rosette engraved across it, and the sticker's symbol struck in
/// foil-tinted metal on a clean centre. The back carries the "EARNED BY"
/// engraving. A generated studio environment lights the scene so the metal
/// picks up highlights as it moves.
///
/// Gestures: drag to spin and tilt (with momentum), tap to flip.
/// Reveal (`playsReveal`): drops in from above, spins one and a half turns,
/// lands face on with a burst of sparks in the foil colour.
/// Reduce Motion: no idle sway, a flip snaps instead of springing, and the
/// reveal is skipped apart from its haptic.
@available(iOS 18.0, *)
struct RealityMedalView: View {

    let stickerType: StickerType
    let userName: String
    let earnedDate: Date

    /// Play the unlock reveal once the scene is ready.
    var playsReveal = false

    /// Apparent diameter of the medal in points. The render canvas is larger
    /// so a tilted medal is never clipped, but the layout footprint stays at
    /// `diameter` so callers can treat it like the flat badge.
    var diameter: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = MedalMotion()
    @State private var showsBack = false

    /// Canvas is 25% larger than the medal; the camera is framed to match.
    private static let canvasScale: CGFloat = 1.25

    var body: some View {
        let canvas = diameter * Self.canvasScale
        let inset = (canvas - diameter) / 2

        RealityView { content in
            motion.reduceMotion = reduceMotion
            await MedalScene.build(
                in: &content,
                stickerType: stickerType,
                userName: userName,
                earnedDate: earnedDate,
                motion: motion
            )
            if playsReveal {
                motion.beginReveal()
            }
        } placeholder: {
            StickerBadgeView(stickerType: stickerType, isUnlocked: true, size: .large)
        }
        .frame(width: canvas, height: canvas)
        .padding(-inset)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    motion.dragChanged(translation: value.translation)
                }
                .onEnded { value in
                    motion.dragEnded(velocity: value.velocity)
                }
        )
        .onTapGesture {
            HapticFeedback.light()
            motion.flip()
        }
        .onChange(of: reduceMotion, initial: true) { _, newValue in
            motion.reduceMotion = newValue
        }
        .onAppear {
            motion.onFaceChange = { showsBack = $0 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stickerType.displayName) medal")
        .accessibilityValue(
            showsBack
                ? "Back. Earned by \(userName) on \(earnedDate.formatted(date: .long, time: .omitted))"
                : "Front"
        )
        .accessibilityHint("Double tap to flip")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Motion

/// Drives the medal's orientation every frame.
///
/// Yaw (spin) is either dragged directly, coasting after a flick, or springing
/// toward the nearest face. Pitch (tilt) always springs back to rest. A small
/// sinusoidal sway keeps the reflections alive while idle.
///
/// The reveal reuses the same springs: it starts the medal high, small and
/// wound back one and a half turns, then lets everything settle to rest.
@available(iOS 18.0, *)
@MainActor
final class MedalMotion {

    var entity: Entity?
    var subscription: EventSubscription?
    var reduceMotion = false
    var onFaceChange: ((Bool) -> Void)?
    /// Called once when a reveal lands face on, for the spark burst.
    var onRevealLanded: (() -> Void)?

    private var yaw: Float = 0
    private var yawVelocity: Float = 0
    private var targetYaw: Float = 0
    private var pitch: Float = 0
    private var pitchVelocity: Float = 0
    private var height: Float = 0
    private var heightVelocity: Float = 0
    private var scale: Float = 1
    private var scaleVelocity: Float = 0

    private var dragging = false
    private var coasting = false
    private var revealing = false
    private var dropped = true
    private var dragStartYaw: Float = 0
    private var dragStartPitch: Float = 0
    private var flipDirection: Float = 1
    private var elapsed: Float = 0

    private static let revealTurns: Float = 1.5
    /// Half a radius: the small medal stays inside the render canvas.
    private static let revealHeight: Float = 0.025
    private static let revealScale: Float = 0.72

    /// Radians of spin per point of finger travel: roughly a half turn across
    /// two thirds of the screen.
    private static let radiansPerPoint: Float = .pi / 260
    private static let maxTilt: Float = 0.5
    private static let maxFlick: Float = 24
    private static let coastFriction: Float = 3.5
    private static let captureSpeed: Float = 2.5

    private var showsBack: Bool {
        Int((targetYaw / .pi).rounded()).magnitude % 2 == 1
    }

    func tick(_ deltaTime: TimeInterval) {
        guard let entity else { return }
        let dt = Float(min(deltaTime, 1.0 / 30.0))
        elapsed += dt

        let swayYaw: Float = reduceMotion ? 0 : 0.10 * sin(elapsed * 0.9)
        let swayPitch: Float = reduceMotion ? 0 : 0.05 * sin(elapsed * 0.6 + 1)

        if !dragging {
            if coasting {
                yawVelocity -= yawVelocity * Self.coastFriction * dt
                yaw += yawVelocity * dt
                if abs(yawVelocity) < Self.captureSpeed {
                    coasting = false
                    // Land on the next face in the direction of travel.
                    let turns = yaw / .pi
                    targetYaw = (yawVelocity >= 0 ? turns.rounded(.up) : turns.rounded(.down)) * .pi
                    HapticFeedback.selection()
                    onFaceChange?(showsBack)
                }
            } else if revealing {
                // A softer spring so the one-and-a-half turns decelerate visibly.
                spring(&yaw, &yawVelocity, toward: targetYaw, dt: dt, stiffness: 45, damping: 9)
                if abs(yaw - targetYaw) < 0.12, abs(yawVelocity) < 1.5 {
                    revealing = false
                    HapticFeedback.success()
                    onRevealLanded?()
                }
            } else {
                spring(&yaw, &yawVelocity, toward: targetYaw + swayYaw, dt: dt)
            }
            spring(&pitch, &pitchVelocity, toward: swayPitch, dt: dt)
        }

        // Drop-in: height and scale settle quickly, with a light haptic on landing.
        spring(&height, &heightVelocity, toward: 0, dt: dt, stiffness: 120, damping: 16)
        spring(&scale, &scaleVelocity, toward: 1, dt: dt, stiffness: 120, damping: 16)
        if !dropped, height < 0.002 {
            dropped = true
            HapticFeedback.light()
        }

        entity.orientation =
            simd_quatf(angle: pitch, axis: [1, 0, 0])
            * simd_quatf(angle: yaw, axis: [0, 1, 0])
        entity.position.y = height
        entity.scale = SIMD3<Float>(repeating: scale)
    }

    private func spring(
        _ x: inout Float, _ v: inout Float, toward target: Float, dt: Float,
        stiffness: Float = 70, damping: Float = 11
    ) {
        v += (-stiffness * (x - target) - damping * v) * dt
        x += v * dt
    }

    /// Start the unlock reveal. Under Reduce Motion the medal simply appears
    /// at rest and only the success haptic plays.
    func beginReveal() {
        guard !reduceMotion else {
            HapticFeedback.success()
            return
        }
        coasting = false
        dragging = false
        targetYaw = 0
        yaw = -Self.revealTurns * 2 * .pi
        yawVelocity = 0
        height = Self.revealHeight
        heightVelocity = 0
        scale = Self.revealScale
        scaleVelocity = 0
        dropped = false
        revealing = true
    }

    func dragChanged(translation: CGSize) {
        if !dragging {
            dragging = true
            coasting = false
            revealing = false
            dragStartYaw = yaw
            dragStartPitch = pitch
            yawVelocity = 0
            pitchVelocity = 0
        }
        yaw = dragStartYaw + Float(translation.width) * Self.radiansPerPoint
        let tilt = dragStartPitch + Float(translation.height) * Self.radiansPerPoint * 0.6
        pitch = min(max(tilt, -Self.maxTilt), Self.maxTilt)
    }

    func dragEnded(velocity: CGSize) {
        dragging = false
        let flick = Float(velocity.width) * Self.radiansPerPoint
        yawVelocity = min(max(flick, -Self.maxFlick), Self.maxFlick)
        if abs(yawVelocity) > Self.captureSpeed * 1.5 {
            coasting = true
            flipDirection = yawVelocity >= 0 ? 1 : -1
        } else {
            targetYaw = (yaw / .pi).rounded() * .pi
            onFaceChange?(showsBack)
        }
    }

    func flip() {
        coasting = false
        revealing = false
        targetYaw += .pi * flipDirection
        if reduceMotion {
            yaw = targetYaw
            yawVelocity = 0
        }
        onFaceChange?(showsBack)
    }
}

// MARK: - Scene

@available(iOS 18.0, *)
@MainActor
enum MedalScene {

    // Medal geometry in metres. The camera is framed so this reads as
    // `diameter` points regardless of the physical size.
    private static let radius: Float = 0.05
    private static let ringWidth: Float = 0.0108      // ~11% of diameter, matches the flat badge
    private static let halfThickness: Float = 0.0032
    private static let bevel: Float = 0.0014
    private static let recess: Float = 0.0010
    private static let lip: Float = 0.0005
    private static let inlayWidth: Float = 0.0018    // foil enamel band between ring and disc
    private static var innerRadius: Float { radius - ringWidth }
    private static var discRadius: Float { innerRadius - inlayWidth }
    private static var faceZ: Float { halfThickness - recess }

    static func build(
        in content: inout RealityViewCameraContent,
        stickerType: StickerType,
        userName: String,
        earnedDate: Date,
        motion: MedalMotion
    ) async {
        // Camera: framed so the medal fills 80% of the canvas height.
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 30
        camera.position = [0, 0, 0.233]
        content.add(camera)

        // Lighting: a studio environment for reflections plus one key light
        // for a crisp specular glint.
        var lightSource: Entity?
        if let image = studioEnvironmentImage(),
           let environment = try? await EnvironmentResource(equirectangular: image, withName: "medal-studio") {
            let light = Entity()
            light.components.set(ImageBasedLightComponent(source: .single(environment), intensityExponent: 1.1))
            content.add(light)
            lightSource = light
        }
        let key = DirectionalLight()
        key.light.intensity = 1400
        key.look(at: .zero, from: [-0.35, 0.45, 0.8], relativeTo: nil)
        content.add(key)

        // Medal. `root` stays still so the spark burst is not spun with the medal.
        let root = Entity()
        let medal = Entity()
        let foil = UIColor(stickerType.foilColor)
        let foilAlt = UIColor(stickerType.foilAltColor)

        if let ringMesh = try? lathe(ringProfile()) {
            medal.addChild(ModelEntity(mesh: ringMesh, materials: [ringMetal(for: stickerType.tier)]))
        }
        if let inlayMesh = try? lathe(inlayProfile()) {
            medal.addChild(ModelEntity(mesh: inlayMesh, materials: [enamel(tint: foil)]))
        }
        if let discMesh = try? lathe(discProfile()) {
            medal.addChild(ModelEntity(mesh: discMesh, materials: [enamel()]))
        }

        // Front: guilloché engraving low and faint, in the foil; symbol raised, in the light foil.
        let faceWidth = discRadius * 2
        let faceMesh = MeshResource.generatePlane(width: faceWidth, height: faceWidth)
        if let mask = try? await maskTexture(guillocheRelief(), size: 1024) {
            let engraving = ModelEntity(mesh: faceMesh, materials: [relief(foil, mask: mask, roughness: 0.45, opacity: 0.7)])
            engraving.position = [0, 0, faceZ + 0.0002]
            medal.addChild(engraving)
        }
        if let mask = try? await maskTexture(symbolRelief(stickerType.icon)) {
            let symbol = ModelEntity(mesh: faceMesh, materials: [relief(foilAlt, mask: mask)])
            symbol.position = [0, 0, faceZ + 0.0005]
            medal.addChild(symbol)
        }

        // Back: the earned-by engraving.
        let reliefWidth = innerRadius * 2 * 0.9
        let reliefMesh = MeshResource.generatePlane(width: reliefWidth, height: reliefWidth)
        if let mask = try? await maskTexture(earnedByRelief(userName: userName, earnedDate: earnedDate)) {
            let back = ModelEntity(mesh: reliefMesh, materials: [relief(foilAlt, mask: mask)])
            back.position = [0, 0, -(faceZ + 0.0003)]
            back.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            medal.addChild(back)
        }

        if let lightSource {
            for child in medal.children {
                child.components.set(ImageBasedLightReceiverComponent(imageBasedLight: lightSource))
            }
        }
        root.addChild(medal)
        content.add(root)

        motion.entity = medal
        motion.onRevealLanded = {
            burstSparks(in: root, from: foilAlt, to: foil)
        }
        motion.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
            motion.tick(event.deltaTime)
        }
    }

    /// One burst of sparks off the rim, fading from the light foil to the
    /// foil colour, then the emitter is removed.
    private static func burstSparks(in parent: Entity, from start: UIColor, to end: UIColor) {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = [radius, radius, 0.004]
        emitter.birthLocation = .surface
        emitter.birthDirection = .normal
        emitter.speed = 0.10
        emitter.speedVariation = 0.04
        emitter.burstCount = 80
        emitter.mainEmitter.birthRate = 0
        emitter.mainEmitter.lifeSpan = 0.7
        emitter.mainEmitter.lifeSpanVariation = 0.2
        emitter.mainEmitter.size = 0.0025
        emitter.mainEmitter.sizeVariation = 0.001
        emitter.mainEmitter.color = .evolving(start: .single(start), end: .single(end))
        emitter.mainEmitter.opacityCurve = .quickFadeInOut
        emitter.mainEmitter.acceleration = [0, -0.15, 0]
        emitter.mainEmitter.dampingFactor = 2
        emitter.isEmitting = true
        emitter.burst()

        let sparks = Entity()
        sparks.components.set(emitter)
        parent.addChild(sparks)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            sparks.removeFromParent()
        }
    }

    // MARK: Profiles (radius, z) revolved around the Z axis; +Z faces the camera

    private static func ringProfile() -> [SIMD2<Float>] {
        let r = radius, ri = innerRadius, h = halfThickness
        return [
            [ri, h - recess],
            [ri + lip, h],
            [r - bevel, h],
            [r, h - bevel],
            [r, -h + bevel],
            [r - bevel, -h],
            [ri + lip, -h],
            [ri, -h + recess],
            [ri, h - recess]
        ]
    }

    /// Thin enamel band inside the ring, front and back.
    private static func inlayProfile() -> [SIMD2<Float>] {
        let ro = innerRadius + 0.0003   // overlap the ring wall so no seam shows
        let ri = discRadius
        return [
            [ri, faceZ],
            [ro, faceZ],
            [ro, -faceZ],
            [ri, -faceZ],
            [ri, faceZ]
        ]
    }

    private static func discProfile() -> [SIMD2<Float>] {
        let r = discRadius + 0.0003   // overlap the inlay so no seam shows
        return [
            [0, faceZ],
            [r, faceZ],
            [r, -faceZ],
            [0, -faceZ]
        ]
    }

    /// Revolves a 2D profile into a surface of revolution with flat shading
    /// along the profile and smooth shading around the circumference.
    private static func lathe(_ profile: [SIMD2<Float>], segments: Int = 96) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let centroid = profile.reduce(SIMD2<Float>.zero, +) / Float(profile.count)

        for i in 0..<(profile.count - 1) {
            let a = profile[i], b = profile[i + 1]
            let d = b - a
            if (a.x == 0 && b.x == 0) || simd_length(d) < 1e-7 { continue }

            // Outward normal of this profile segment (convex cross-sections only).
            var n = simd_normalize(SIMD2<Float>(d.y, -d.x))
            if simd_dot(n, (a + b) / 2 - centroid) < 0 { n = -n }

            let base = UInt32(positions.count)
            for j in 0...segments {
                let t = Float(j) / Float(segments) * 2 * .pi
                let c = cos(t), s = sin(t)
                positions.append([a.x * c, a.x * s, a.y])
                positions.append([b.x * c, b.x * s, b.y])
                let n3 = simd_normalize(SIMD3<Float>(n.x * c, n.x * s, n.y))
                normals.append(n3)
                normals.append(n3)
            }

            // Pick a winding whose face normal agrees with the vertex normal.
            let a0 = Int(base), b0 = a0 + 1, b1 = a0 + 3, a1 = a0 + 2
            let tri1 = simd_cross(positions[b0] - positions[a0], positions[b1] - positions[a0])
            let tri2 = simd_cross(positions[b1] - positions[a0], positions[a1] - positions[a0])
            let probe = simd_length(tri1) > simd_length(tri2) ? tri1 : tri2
            let flip = simd_dot(probe, normals[a0]) < 0

            for j in 0..<segments {
                let a0 = base + UInt32(2 * j), b0 = a0 + 1, a1 = a0 + 2, b1 = a0 + 3
                if flip {
                    indices += [a0, b1, b0, a0, a1, b1]
                } else {
                    indices += [a0, b0, b1, a0, b1, a1]
                }
            }
        }

        var descriptor = MeshDescriptor(name: "lathe")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    // MARK: Materials

    private static func metal(_ color: UIColor, roughness: Float, clearcoat: Float = 0.25) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.metallic = .init(floatLiteral: 1)
        material.roughness = .init(floatLiteral: roughness)
        material.clearcoat = .init(floatLiteral: clearcoat)
        material.clearcoatRoughness = .init(floatLiteral: 0.3)
        return material
    }

    /// The ring metal for a rarity tier. Albedos are material properties,
    /// not UI colours, so they are deliberately literals: warm bronze, neutral
    /// silver, yellow gold, and a cool near-white platinum under a thick coat.
    private static func ringMetal(for tier: StickerTier) -> PhysicallyBasedMaterial {
        switch tier {
        case .bronze:
            return metal(UIColor(red: 0.80, green: 0.50, blue: 0.26, alpha: 1), roughness: 0.30)
        case .silver:
            return metal(UIColor(red: 0.84, green: 0.86, blue: 0.90, alpha: 1), roughness: 0.20)
        case .gold:
            return metal(UIColor(red: 1.00, green: 0.78, blue: 0.33, alpha: 1), roughness: 0.18)
        case .platinum:
            return metal(UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1), roughness: 0.12, clearcoat: 0.6)
        }
    }

    /// Satin enamel: dark for the inner disc, or tinted for the foil inlay.
    /// The dark albedo is a material property, not a UI colour, so it is
    /// deliberately a literal.
    private static func enamel(tint: UIColor? = nil) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: tint ?? UIColor(red: 0.075, green: 0.082, blue: 0.10, alpha: 1))
        material.metallic = .init(floatLiteral: 0.35)
        material.roughness = .init(floatLiteral: 0.5)
        return material
    }

    /// Metal cut to the shape of a mask: the symbol and engravings.
    private static func relief(
        _ color: UIColor, mask: TextureResource, roughness: Float = 0.32, opacity: Float = 1
    ) -> PhysicallyBasedMaterial {
        var material = metal(color, roughness: roughness)
        material.blending = .transparent(opacity: .init(scale: opacity, texture: .init(mask)))
        return material
    }

    // MARK: Textures

    private static let textureSize: CGFloat = 512

    /// Renders a SwiftUI view in white on clear and uploads it as an opacity
    /// mask. Font sizes here are texture pixels, not UI points, so they are
    /// intentionally fixed.
    private static func maskTexture<Content: View>(_ content: Content, size: CGFloat = textureSize) async throws -> TextureResource {
        let renderer = ImageRenderer(
            content: content
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        )
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { throw MedalSceneError.textureRenderFailed }
        return try await TextureResource(
            image: image,
            withName: nil,
            options: .init(semantic: .raw, mipmapsMode: .allocateAndGenerateAll)
        )
    }

    /// The symbol, sized to sit inside the clean centre of the guilloché.
    private static func symbolRelief(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 190, weight: .semibold))
    }

    /// Engine-turned rosette: two families of offset circles whose
    /// interference makes the pattern, cleared from a centre disc that is
    /// outlined by a single ring. Drawn in disc units where the disc radius
    /// is 63, matching the design mockups.
    private static func guillocheRelief() -> some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let unit = size.width / 2 / 63 * 0.97
            let stroke = StrokeStyle(lineWidth: 0.22 * unit)
            let white = GraphicsContext.Shading.color(.white)

            func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }

            context.stroke(circle(centre.x, centre.y, 27 * unit), with: white, style: stroke)

            // The rosette lives outside the centre disc.
            context.clip(to: circle(centre.x, centre.y, 27 * unit), options: .inverse)
            for i in 0..<24 {
                let a = CGFloat(i) / 24 * 2 * .pi
                context.stroke(circle(centre.x + cos(a) * 16 * unit, centre.y + sin(a) * 16 * unit, 40 * unit), with: white, style: stroke)
            }
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * 2 * .pi
                context.stroke(circle(centre.x + cos(a) * 6 * unit, centre.y + sin(a) * 6 * unit, 54 * unit), with: white, style: stroke)
            }
        }
    }

    private static func earnedByRelief(userName: String, earnedDate: Date) -> some View {
        VStack(spacing: 14) {
            Text("O")
                .font(.custom("Fraunces", size: 84))
                .fontWeight(.bold)
                .opacity(0.75)
            Text("EARNED BY")
                .font(.system(size: 36, weight: .semibold))
                .tracking(7)
                .opacity(0.55)
            Text(userName.uppercased())
                .font(.system(size: 56, weight: .bold))
                .tracking(8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("ON \(earnedDate.formatted(.dateTime.month(.wide).day().year()).uppercased())")
                .font(.system(size: 30, weight: .medium))
                .tracking(4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .opacity(0.55)
        }
        .padding(.horizontal, 64)
    }

    /// A small equirectangular "studio": bright overhead, a large soft key
    /// light upper-left, a rim light on the right and a faint floor bounce.
    /// Metals reflect this, which is what makes the ring read as metal.
    private static func studioEnvironmentImage() -> CGImage? {
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

            // A bright horizon band: the classic highlight stripe on a polished ring.
            cg.setFillColor(UIColor(white: 0.95, alpha: 0.55).cgColor)
            cg.fill(CGRect(x: 0, y: 120, width: size.width, height: 6))
        }.cgImage
    }
}

enum MedalSceneError: Error {
    case textureRenderFailed
}

// MARK: - Preview

@available(iOS 18.0, *)
#Preview("RealityKit medal") {
    ZStack {
        OuestTheme.Colors.background.ignoresSafeArea()
        VStack(spacing: OuestTheme.Spacing.xxxl) {
            RealityMedalView(stickerType: .og, userName: "TimTime", earnedDate: .now)
            RealityMedalView(stickerType: .globeTrotter, userName: "TimTime", earnedDate: .now)
            RealityMedalView(stickerType: .firstTrip, userName: "TimTime", earnedDate: .now)
        }
    }
}

@available(iOS 18.0, *)
#Preview("RealityKit medal, reveal") {
    ZStack {
        OuestTheme.Colors.background.ignoresSafeArea()
        RealityMedalView(stickerType: .jetSetter, userName: "TimTime", earnedDate: .now, playsReveal: true)
    }
}

@available(iOS 18.0, *)
#Preview("RealityKit medal, dark") {
    ZStack {
        OuestTheme.Colors.background.ignoresSafeArea()
        RealityMedalView(stickerType: .shutterbug, userName: "TimTime", earnedDate: .now)
    }
    .preferredColorScheme(.dark)
}
