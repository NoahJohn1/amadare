// The launchd agent's program (built by scripts/install-resign-agent.sh). It runs scripts/resign-iphone.sh.
// It exists because launchd keeps relaunching a job until it takes the USB "iPhone plugged in" event, and
// only a program can take it, not a shell script.
import Foundation
import XPC

let script = CommandLine.arguments[1]
var pluggedIn = false
xpc_set_event_stream_handler("com.apple.iokit.matching", DispatchQueue.main) { _ in pluggedIn = true }

// Give launchd a moment to hand over the event that launched us, if any.
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    let check = Process()
    check.executableURL = URL(fileURLWithPath: "/bin/zsh")
    check.arguments = [script] + (pluggedIn ? ["--usb"] : [])
    check.terminationHandler = { exit($0.terminationStatus) }
    do { try check.run() } catch { print("Couldn't run \(script): \(error)"); exit(1) }
}
dispatchMain()
