import Testing
@testable import Ouest

/// The profile header shader is the one place in the app that redraws
/// continuously. These tests pin the rule that any single accessibility or
/// battery signal is enough to freeze it — so a future "just animate it
/// anyway" change to one branch fails loudly.
@Suite("Mesh header motion policy")
struct MeshHeaderMotionPolicyTests {

    @Test("Animates only when every signal is clear")
    func animatesWhenClear() {
        #expect(MeshHeaderMotionPolicy.shouldAnimate(
            reduceMotion: false, dimFlashingLights: false, lowPowerMode: false, isActive: true
        ))
    }

    @Test("Reduce Motion alone freezes the header")
    func reduceMotionFreezes() {
        #expect(!MeshHeaderMotionPolicy.shouldAnimate(
            reduceMotion: true, dimFlashingLights: false, lowPowerMode: false, isActive: true
        ))
    }

    @Test("Dim Flashing Lights alone freezes the header")
    func dimFlashingLightsFreezes() {
        #expect(!MeshHeaderMotionPolicy.shouldAnimate(
            reduceMotion: false, dimFlashingLights: true, lowPowerMode: false, isActive: true
        ))
    }

    @Test("Low Power Mode alone freezes the header")
    func lowPowerFreezes() {
        #expect(!MeshHeaderMotionPolicy.shouldAnimate(
            reduceMotion: false, dimFlashingLights: false, lowPowerMode: true, isActive: true
        ))
    }

    @Test("Backgrounded or inactive scene freezes the header")
    func inactiveFreezes() {
        #expect(!MeshHeaderMotionPolicy.shouldAnimate(
            reduceMotion: false, dimFlashingLights: false, lowPowerMode: false, isActive: false
        ))
    }

    @Test("Mesh has no grain; grain variant does")
    func grainAmounts() {
        #expect(ProfileHeaderStyle.mesh.grainAmount == 0)
        #expect(ProfileHeaderStyle.grain.grainAmount > 0)
    }
}
