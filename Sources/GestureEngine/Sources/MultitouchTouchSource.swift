import Foundation
import GestureCore

/// Reads raw multi-finger data from the trackpad through Apple's PRIVATE
/// `MultitouchSupport.framework` (loaded at runtime with dlopen, so the project still builds
/// without it). This is the only file that touches the private API; to swap the OS
/// integration, replace this class with another `TouchSource`.
public final class MultitouchTouchSource: TouchSource {
    public var onFrame: ((TouchFrame) -> Void)?

    public enum SourceError: Error, CustomStringConvertible {
        case frameworkUnavailable
        case noTrackpadFound
        public var description: String {
            switch self {
            case .frameworkUnavailable: return "MultitouchSupport.framework could not be loaded."
            case .noTrackpadFound: return "No multitouch trackpad was found."
            }
        }
    }

    // Layout of Apple's MTTouch struct (96 bytes). Only the fields we read are named.
    private struct MTTouch {
        var frame: Int32
        var timestamp: Double
        var identifier: Int32
        var state: Int32
        var fingerID: Int32
        var handID: Int32
        var normX: Float
        var normY: Float
        var velX: Float
        var velY: Float
        var size: Float
        var zero1: Int32
        var angle: Float
        var majorAxis: Float
        var minorAxis: Float
        var absX: Float
        var absY: Float
        var absVelX: Float
        var absVelY: Float
        var zero2: Int32
        var zero3: Int32
        var density: Float
    }

    private typealias DeviceRef = UnsafeMutableRawPointer
    private typealias ContactCallback = @convention(c) (
        DeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32
    ) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (DeviceRef, ContactCallback) -> Void
    private typealias StartStop = @convention(c) (DeviceRef, Int32) -> Void
    private typealias Stop = @convention(c) (DeviceRef) -> Void

    private var handle: UnsafeMutableRawPointer?
    private var devices: [DeviceRef] = []
    // Owns the device objects; they must outlive start() or the callbacks stop/crash.
    private var deviceObjects: [AnyObject] = []

    // The C callback cannot capture context, so it reaches the live instance through this.
    private static weak var active: MultitouchTouchSource?

    public init() {}

    public func start() throws {
        guard let h = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW
        ) else { throw SourceError.frameworkUnavailable }
        handle = h

        guard let createSym = dlsym(h, "MTDeviceCreateList"),
              let registerSym = dlsym(h, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(h, "MTDeviceStart")
        else { throw SourceError.frameworkUnavailable }

        let create = unsafeBitCast(createSym, to: CreateList.self)
        let register = unsafeBitCast(registerSym, to: Register.self)
        let startDevice = unsafeBitCast(startSym, to: StartStop.self)

        guard let list = create()?.takeRetainedValue() as? [AnyObject], !list.isEmpty else {
            throw SourceError.noTrackpadFound
        }

        deviceObjects = list
        MultitouchTouchSource.active = self
        for object in list {
            let device = Unmanaged.passUnretained(object).toOpaque()
            devices.append(device)
            register(device) { dev, data, count, timestamp, _ in
                let id = dev.map { Int(bitPattern: $0) } ?? 0
                MultitouchTouchSource.active?.deliver(device: id, data: data, count: Int(count), timestamp: timestamp)
                return 0
            }
            startDevice(device, 0)
        }
    }

    public func stop() {
        if let h = handle, let stopSym = dlsym(h, "MTDeviceStop") {
            let stopDevice = unsafeBitCast(stopSym, to: Stop.self)
            devices.forEach { stopDevice($0) }
        }
        devices.removeAll()
        deviceObjects.removeAll()
        MultitouchTouchSource.active = nil
    }

    private func deliver(device: Int, data: UnsafeMutableRawPointer?, count: Int, timestamp: Double) {
        var touches: [Touch] = []
        if let data = data, count > 0 {
            let base = data.assumingMemoryBound(to: MTTouch.self)
            for i in 0..<count {
                let t = base[i]
                touches.append(Touch(
                    id: Int(t.identifier),
                    position: TouchPoint(x: Double(t.normX), y: Double(t.normY))
                ))
            }
        }
        onFrame?(TouchFrame(timestamp: timestamp, touches: touches, deviceID: device))
    }
}
