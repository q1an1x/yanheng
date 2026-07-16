import Foundation

let nativeOK: Int32 = 0
let nativeError: Int32 = 1
let nativeABIV2: UInt32 = 2
let valueNull: UInt32 = 0
let valueBool: UInt32 = 1
let valueInteger: UInt32 = 2
let valueNumber: UInt32 = 3
let valueString: UInt32 = 4
let valueArray: UInt32 = 6
let valueMap: UInt32 = 7
let valueCallback: UInt32 = 9
let valueTrueFlag: UInt32 = 1

struct NativeValue {
    var kind: UInt32
    var flags: UInt32
    var length: UInt64
    var data: UInt64
}

struct NativeError {
    var code: UnsafePointer<UInt8>?
    var codeLength: Int
    var message: UnsafePointer<UInt8>?
    var messageLength: Int
}

struct NativeHost {
    var abiVersion: UInt32
    var structSize: Int
    var context: UnsafeMutableRawPointer?
    var callbackRetain: UnsafeRawPointer?
    var callbackRelease: UnsafeRawPointer?
    var callbackPost: UnsafeRawPointer?
    var wake: UnsafeRawPointer?
    var pump: UnsafeRawPointer?
    var hasPermission: UnsafeRawPointer?
    var resourceGet: UnsafeRawPointer?
    var eventLoopID: UInt64
    var ownerThreadToken: UInt64
}

typealias CallbackRetain = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Int32
typealias CallbackRelease = @convention(c) (UnsafeMutableRawPointer?, UInt64) -> Int32
typealias CallbackPost = @convention(c) (
    UnsafeMutableRawPointer?, UInt64, UnsafeRawPointer?, Int, UnsafeMutableRawPointer?
) -> Int32
typealias HostPump = @convention(c) (UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Int32
typealias NativeCall = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeRawPointer?, Int, UnsafeRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
) -> Int32

struct NativeFunction {
    var name: UnsafePointer<UInt8>?
    var nameLength: Int
    var context: UnsafeMutableRawPointer?
    var call: NativeCall?
}

struct NativeConstant {
    var name: UnsafePointer<UInt8>?
    var nameLength: Int
    var value: UnsafePointer<NativeValue>?
}

struct NativeModule {
    var abiVersion: UInt32
    var structSize: Int
    var name: UnsafePointer<UInt8>?
    var nameLength: Int
    var functions: UnsafePointer<NativeFunction>?
    var functionCount: Int
    var constants: UnsafePointer<NativeConstant>?
    var constantCount: Int
    var resourceTypes: UnsafePointer<UnsafePointer<UInt8>?>?
    var resourceTypeLengths: UnsafePointer<Int>?
    var resourceTypeCount: Int
    var freeValue: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    var capabilities: UInt64
}

func copiedBytes(_ string: String) -> (UnsafePointer<UInt8>, Int) {
    let bytes = Array(string.utf8)
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: max(bytes.count, 1))
    if !bytes.isEmpty { pointer.initialize(from: bytes, count: bytes.count) }
    return (UnsafePointer(pointer), bytes.count)
}

func stringArgument(_ value: NativeValue) -> String? {
    guard value.kind == valueString else { return nil }
    guard value.length > 0 else { return "" }
    guard let pointer = UnsafeRawPointer(bitPattern: UInt(value.data))?.assumingMemoryBound(to: UInt8.self) else {
        return nil
    }
    return String(bytes: UnsafeBufferPointer(start: pointer, count: Int(value.length)), encoding: .utf8)
}

func numberArgument(_ value: NativeValue) -> Double? {
    switch value.kind {
    case valueInteger:
        return Double(Int64(bitPattern: value.data))
    case valueNumber:
        return Double(bitPattern: value.data)
    default:
        return nil
    }
}

func setNull(_ output: UnsafeMutablePointer<NativeValue>?) {
    output?.pointee = NativeValue(kind: valueNull, flags: 0, length: 0, data: 0)
}

func setString(_ string: String, _ output: UnsafeMutablePointer<NativeValue>?) {
    let bytes = Array(string.utf8)
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: max(bytes.count, 1))
    if !bytes.isEmpty { pointer.initialize(from: bytes, count: bytes.count) }
    output?.pointee = NativeValue(
        kind: valueString,
        flags: 0,
        length: UInt64(bytes.count),
        data: UInt64(UInt(bitPattern: UnsafeRawPointer(pointer)))
    )
}

private let errorCode = copiedBytes("YANHENG_NATIVE")
private let errorMessage = copiedBytes("invalid native call")

func fail(_ error: UnsafeMutablePointer<NativeError>?) -> Int32 {
    error?.pointee = NativeError(
        code: errorCode.0,
        codeLength: errorCode.1,
        message: errorMessage.0,
        messageLength: errorMessage.1
    )
    return nativeError
}

@_cdecl("yanxu_native_module_v2")
public func yanhengNativeModuleV2() -> UnsafeRawPointer {
    UnsafeRawPointer(NativeExports.modulePointer)
}

public func freeNativeValue(_ raw: UnsafeMutableRawPointer?) {
    guard let raw else { return }
    let value = raw.assumingMemoryBound(to: NativeValue.self)
    if value.pointee.kind == valueString,
       let pointer = UnsafeMutableRawPointer(bitPattern: UInt(value.pointee.data)) {
        pointer.deallocate()
    }
    value.pointee = NativeValue(kind: valueNull, flags: 0, length: 0, data: 0)
}
