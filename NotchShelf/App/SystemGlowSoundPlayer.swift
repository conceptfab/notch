import AppKit

enum SystemGlowSoundPlayer {
    static func play() {
        NSSound(named: NSSound.Name("Tink"))?.play()
    }
}
