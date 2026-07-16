import Foundation

enum CallbackJSON {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case object([String: CallbackJSON])
}

final class NativeCallback {
    private let host: NativeHost
    private let handle: UInt64
    private var retained = false

    init?(value: NativeValue, host: UnsafePointer<NativeHost>?) {
        guard value.kind == valueCallback,
              let host,
              host.pointee.abiVersion == nativeABIV2,
              host.pointee.callbackRetain != nil,
              host.pointee.callbackRelease != nil,
              host.pointee.callbackPost != nil,
              host.pointee.pump != nil else { return nil }
        self.host = host.pointee
        self.handle = value.data
    }

    func retain() -> Bool {
        guard !retained, let raw = host.callbackRetain else { return false }
        let function = unsafeBitCast(raw, to: CallbackRetain.self)
        retained = function(host.context, handle) == nativeOK
        return retained
    }

    func release() {
        guard retained, let raw = host.callbackRelease else { return }
        let function = unsafeBitCast(raw, to: CallbackRelease.self)
        _ = function(host.context, handle)
        retained = false
    }

    func deliver(name: String, payload: [String: CallbackJSON], releaseAfter: Bool) {
        let postWork = { [self] in
            guard retained, let postRaw = host.callbackPost else { return }
            let arena = ValueArena()
            let arguments = [arena.encode(.string(name)), arena.encode(.object(payload))]
            var error = NativeError(code: nil, codeLength: 0, message: nil, messageLength: 0)
            let post = unsafeBitCast(postRaw, to: CallbackPost.self)
            _ = arguments.withUnsafeBufferPointer { buffer in
                withUnsafeMutablePointer(to: &error) { pointer in
                    post(host.context, handle, buffer.baseAddress.map(UnsafeRawPointer.init), buffer.count, pointer)
                }
            }
            pump()
            if releaseAfter { release() }
        }
        if Thread.isMainThread { postWork() } else { DispatchQueue.main.async(execute: postWork) }
    }

    private func pump() {
        guard let pumpRaw = host.pump else { return }
        let pump = unsafeBitCast(pumpRaw, to: HostPump.self)
        var error = NativeError(code: nil, codeLength: 0, message: nil, messageLength: 0)
        _ = withUnsafeMutablePointer(to: &error) { pump(host.context, 64, $0) }
    }

    deinit {
        if retained {
            if Thread.isMainThread { release() }
            else { DispatchQueue.main.async { [self] in release() } }
        }
    }
}

private final class ValueArena {
    private var byteBuffers: [UnsafeMutablePointer<UInt8>] = []
    private var valueBuffers: [(UnsafeMutablePointer<NativeValue>, Int)] = []

    func encode(_ value: CallbackJSON) -> NativeValue {
        switch value {
        case .null:
            return NativeValue(kind: valueNull, flags: 0, length: 0, data: 0)
        case .bool(let value):
            return NativeValue(kind: valueBool, flags: value ? valueTrueFlag : 0, length: 0, data: 0)
        case .number(let value):
            return NativeValue(kind: valueNumber, flags: 0, length: 0, data: value.bitPattern)
        case .string(let value):
            let bytes = Array(value.utf8)
            guard !bytes.isEmpty else { return NativeValue(kind: valueString, flags: 0, length: 0, data: 0) }
            let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
            pointer.initialize(from: bytes, count: bytes.count)
            byteBuffers.append(pointer)
            return NativeValue(
                kind: valueString,
                flags: 0,
                length: UInt64(bytes.count),
                data: UInt64(UInt(bitPattern: UnsafeRawPointer(pointer)))
            )
        case .object(let values):
            var children: [NativeValue] = []
            for key in values.keys.sorted() {
                children.append(encode(.string(key)))
                children.append(encode(values[key] ?? .null))
            }
            guard !children.isEmpty else { return NativeValue(kind: valueMap, flags: 0, length: 0, data: 0) }
            let pointer = UnsafeMutablePointer<NativeValue>.allocate(capacity: children.count)
            pointer.initialize(from: children, count: children.count)
            valueBuffers.append((pointer, children.count))
            return NativeValue(
                kind: valueMap,
                flags: 0,
                length: UInt64(values.count),
                data: UInt64(UInt(bitPattern: UnsafeRawPointer(pointer)))
            )
        }
    }

    deinit {
        byteBuffers.forEach { $0.deallocate() }
        valueBuffers.forEach { pointer, count in
            pointer.deinitialize(count: count)
            pointer.deallocate()
        }
    }
}
