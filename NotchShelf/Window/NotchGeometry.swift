import AppKit

/// The notch rectangle in global (bottom-left origin) screen coordinates, matching
/// the coordinate space used by `NSEvent.mouseLocation`.
struct NotchGeometry: Equatable {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchRect: CGRect
    let hasNotch: Bool

    /// Pure initializer, testable without a real `NSScreen`.
    init(screenFrame: CGRect, safeAreaTop: CGFloat,
         auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) {
        hasNotch = safeAreaTop > 0
        let notchOriginX: CGFloat
        if let left = auxLeftWidth, let right = auxRightWidth {
            notchWidth = screenFrame.width - left - right + 4
            notchOriginX = screenFrame.minX + left - 2
        } else {
            notchWidth = 185
            notchOriginX = screenFrame.midX - notchWidth / 2
        }
        notchHeight = safeAreaTop > 0 ? safeAreaTop : 32
        notchRect = CGRect(
            x: notchOriginX,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }

    /// True when a global screen point falls inside the notch hit-region.
    func contains(_ point: CGPoint) -> Bool {
        notchRect.contains(point)
    }
}

extension NotchGeometry {
    /// Reads geometry from the built-in notch screen, falling back to the main screen.
    @MainActor
    static func current() -> NotchGeometry {
        let screen = notchScreen
        return NotchGeometry(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxRightWidth: screen.auxiliaryTopRightArea?.width
        )
    }

    /// The built-in notch screen, or the main screen as a fallback.
    @MainActor
    static var notchScreen: NSScreen {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }
}
