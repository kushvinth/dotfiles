// rolock-hud: toast pill at the bottom of every screen (SwiftUI, real blur).
// Usage: rolock-hud <message> [--icon <png>] [--for <seconds>] [--instant]
// Without --for it stays up until SIGTERM; Hammerspoon swaps in a new one (--instant, no fade)
// to change the text. It also exits once its parent is gone, so a crash leaves no pill behind.
import AppKit
import SwiftUI

final class Model: ObservableObject {
  @Published var message: String
  init(_ message: String) { self.message = message }
}

struct Toast: View {
  @ObservedObject var model: Model
  let icon: NSImage?

  var body: some View {
    HStack(spacing: 8) {
      if let icon {
        Image(nsImage: icon)
          .resizable()
          .scaledToFill()
          .frame(width: 20, height: 20)
          .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
      }
      Text(model.message)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
    .padding(.leading, icon == nil ? 16 : 8)
    .padding(.trailing, 16)
    .padding(.vertical, 8)
    .background(.ultraThickMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    .animation(.easeInOut(duration: 0.15), value: model.message)
  }
}

let args = CommandLine.arguments
func option(_ name: String) -> String? {
  guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
  return args[i + 1]
}
let model = Model(args.count > 1 ? args[1] : "Read Only")
let icon = option("--icon").flatMap(NSImage.init(contentsOfFile:))
let duration = option("--for").flatMap(Double.init)
let instant = args.contains("--instant")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon, never takes focus

// Fixed, mouse-transparent panel; the pill centers itself inside, so text changes need no resize.
let size = NSSize(width: 640, height: 120)
var panels: [NSPanel] = []

func origin(_ screen: NSScreen) -> NSPoint {
  NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + 40)
}

func makePanel(on screen: NSScreen) -> NSPanel {
  let panel = NSPanel(
    contentRect: NSRect(origin: origin(screen), size: size),
    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
  panel.contentView = NSHostingView(
    rootView: Toast(model: model, icon: icon).frame(width: size.width, height: size.height))
  panel.backgroundColor = .clear
  panel.isOpaque = false
  panel.hasShadow = false
  panel.level = .screenSaver
  panel.ignoresMouseEvents = true
  panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
  panel.appearance = NSAppearance(named: .darkAqua)
  panel.alphaValue = instant ? 1 : 0
  panel.orderFrontRegardless()
  NSAnimationContext.runAnimationGroup { ctx in
    ctx.duration = 0.25
    panel.animator().alphaValue = 1
  }
  return panel
}

// Screen changes move the existing panels; only a new screen gets a new (fading-in) one.
func layout() {
  let screens = NSScreen.screens
  while panels.count > screens.count { panels.removeLast().orderOut(nil) }
  for (panel, screen) in zip(panels, screens) { panel.setFrameOrigin(origin(screen)) }
  for screen in screens.dropFirst(panels.count) { panels.append(makePanel(on: screen)) }
}

func fadeOutAndExit() {
  NSAnimationContext.runAnimationGroup({ ctx in
    ctx.duration = 0.2
    panels.forEach { $0.animator().alphaValue = 0 }
  }, completionHandler: { exit(0) })
}

// One pill at a time: the newest HUD replaces any other still running (an orphan
// from a reload or a double lock, an "Unlocked" toast still fading).
let pgrep = Process()
pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
pgrep.arguments = ["-x", "rolock-hud"]
let pids = Pipe()
pgrep.standardOutput = pids
if (try? pgrep.run()) != nil {
  let out = pids.fileHandleForReading.readDataToEndOfFile()
  pgrep.waitUntilExit()
  String(decoding: out, as: UTF8.self).split(separator: "\n")
    .compactMap { pid_t($0) }.filter { $0 != getpid() }.forEach { kill($0, SIGTERM) }
}

// Lock pills (no --for) detach the mouse from the cursor; an event tap only hides moves from
// apps. The timed "Unlocked" toast always re-attaches, so every unlock path restores it.
CGAssociateMouseAndMouseCursorPosition(duration == nil ? 0 : 1)

layout()
NotificationCenter.default.addObserver(
  forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
) { _ in layout() }

if let duration {
  DispatchQueue.main.asyncAfter(deadline: .now() + duration) { fadeOutAndExit() }
}
// Reparented to launchd (pid 1) = Hammerspoon died or reloaded.
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
  if getppid() == 1 {
    CGAssociateMouseAndMouseCursorPosition(1)  // no unlock toast will come to re-attach it
    exit(0)
  }
}
app.run()
