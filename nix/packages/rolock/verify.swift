// Asks for Touch ID; exits 0 only on a successful fingerprint match.
// Biometrics only: no password fallback, so nothing has to be typed while input is frozen.
import Foundation
import LocalAuthentication

let context = LAContext()
context.localizedFallbackTitle = ""  // hide "Use Password…"

var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
  FileHandle.standardError.write("rolock-verify: Touch ID unavailable: \(error?.localizedDescription ?? "?")\n".data(using: .utf8)!)
  exit(2)  // not retryable (lid closed, locked out): readonly.lua points at Hyper+S+0
}

// Exit 1: try again. Exit 2: retrying cannot succeed.
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "unlock read-only mode") { ok, err in
  if ok { exit(0) }
  switch (err as? LAError)?.code {
  case .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled:
    FileHandle.standardError.write("rolock-verify: \(err!.localizedDescription)\n".data(using: .utf8)!)
    exit(2)
  default:
    exit(1)
  }
}
// Nobody can click Cancel while input is frozen, so give up on our own.
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
  context.invalidate()
  exit(1)
}
dispatchMain()
