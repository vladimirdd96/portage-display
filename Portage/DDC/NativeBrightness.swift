import Foundation
import CoreGraphics
import Darwin

// Runtime lookup keeps unavailable private system interfaces from breaking launch.
enum NativeBrightness {
    private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private typealias Getter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (UInt32, Float) -> Int32

    static func read(_ display: UInt32) -> Float? {
        guard let framework, let symbol = dlsym(framework, "DisplayServicesGetBrightness") else { return nil }
        let get = unsafeBitCast(symbol, to: Getter.self)
        var value: Float = 0
        guard get(display, &value) == 0, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    static func write(_ display: UInt32, value: Float) -> Bool {
        guard let framework, let symbol = dlsym(framework, "DisplayServicesSetBrightness") else { return false }
        let set = unsafeBitCast(symbol, to: Setter.self)
        return set(display, min(1, max(0, value))) == 0
    }
}
