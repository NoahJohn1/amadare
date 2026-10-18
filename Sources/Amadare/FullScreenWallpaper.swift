import AppKit
import CoreImage
import SwiftUI

/// In full screen the window gets its own Space with nothing behind it to blur, so the frosted
/// window would show only grey. Instead, draw the display's desktop wallpaper, blurred, in its place.
/// Animated wallpapers that have no image file fall back to the plain frosted window.
struct FullScreenWallpaper: View {
    @State private var wallpaper: NSImage?

    var body: some View {
        ZStack {
            if let wallpaper {
                Image(nsImage: wallpaper)
                    .resizable()
                    .scaledToFill()
                    // Dim it the way the dark frosted window dims the desktop, so white text stays readable.
                    .overlay(Color.black.opacity(0.45))
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.3), value: wallpaper != nil)
        .onAppear {
            // The window may come back already in full screen.
            if let window = NSApp.windows.first(where: { $0.styleMask.contains(.fullScreen) }) {
                wallpaper = Self.blurredWallpaper(for: window.screen)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { note in
            wallpaper = Self.blurredWallpaper(for: (note.object as? NSWindow)?.screen)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            wallpaper = nil
        }
    }

    /// Blurred once when entering full screen, at a reduced size; blurring it live every frame
    /// under the rain would cost far more.
    static func blurredWallpaper(for screen: NSScreen?) -> NSImage? {
        guard let screen, let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let input = CIImage(contentsOf: url) else { return nil }
        let scale = min(1, 960 / input.extent.width)
        let small = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let blurred = small.clampedToExtent().applyingGaussianBlur(sigma: 22).cropped(to: small.extent)
        guard let image = CIContext().createCGImage(blurred, from: small.extent) else { return nil }
        return NSImage(cgImage: image, size: small.extent.size)
    }
}
