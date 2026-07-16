import Foundation

enum NativeExports {
    private static let moduleName = copiedBytes("yanheng-native")
    private static let loadConfigName = copiedBytes("load_config")
    private static let saveConfigName = copiedBytes("save_config")
    private static let fetchSnapshotName = copiedBytes("fetch_snapshot")
    private static let startTimerName = copiedBytes("start_timer")
    private static let stopTimerName = copiedBytes("stop_timer")

    private static var functions: [NativeFunction] = [
        NativeFunction(name: loadConfigName.0, nameLength: loadConfigName.1, context: nil, call: loadConfig),
        NativeFunction(name: saveConfigName.0, nameLength: saveConfigName.1, context: nil, call: saveConfig),
        NativeFunction(name: fetchSnapshotName.0, nameLength: fetchSnapshotName.1, context: nil, call: fetchSnapshot),
        NativeFunction(name: startTimerName.0, nameLength: startTimerName.1, context: nil, call: startTimer),
        NativeFunction(name: stopTimerName.0, nameLength: stopTimerName.1, context: nil, call: stopTimer)
    ]

    private static var module = NativeModule(
        abiVersion: nativeABIV2,
        structSize: MemoryLayout<NativeModule>.size,
        name: moduleName.0,
        nameLength: moduleName.1,
        functions: functions.withUnsafeBufferPointer { $0.baseAddress },
        functionCount: functions.count,
        constants: nil,
        constantCount: 0,
        resourceTypes: nil,
        resourceTypeLengths: nil,
        resourceTypeCount: 0,
        freeValue: freeNativeValue,
        capabilities: 0
    )

    static var modulePointer: UnsafePointer<NativeModule> { withUnsafePointer(to: &module) { $0 } }
}

private let encoder: JSONEncoder = {
    let value = JSONEncoder()
    value.outputFormatting = [.sortedKeys]
    return value
}()

private let decoder = JSONDecoder()
private let client = Sub2APIClient()
private var timer: DispatchSourceTimer?
private var timerCallback: NativeCallback?

private let loadConfig: NativeCall = { _, _, count, _, output, error in
    let errorPointer = error?.assumingMemoryBound(to: NativeError.self)
    guard count == 0 else { return fail(errorPointer) }
    do {
        setString(String(decoding: try encoder.encode(ConfigStore.load()), as: UTF8.self), output?.assumingMemoryBound(to: NativeValue.self))
        return nativeOK
    } catch { return fail(errorPointer) }
}

private let saveConfig: NativeCall = { _, arguments, count, _, output, error in
    let errorPointer = error?.assumingMemoryBound(to: NativeError.self)
    let args = arguments?.assumingMemoryBound(to: NativeValue.self)
    guard count == 1, let args, let json = stringArgument(args.pointee) else {
        return fail(errorPointer)
    }
    do {
        let config = try decoder.decode(YanhengConfig.self, from: Data(json.utf8))
        try ConfigStore.save(config)
        setNull(output?.assumingMemoryBound(to: NativeValue.self))
        return nativeOK
    } catch { return fail(errorPointer) }
}

private let fetchSnapshot: NativeCall = { _, arguments, count, host, output, error in
    let errorPointer = error?.assumingMemoryBound(to: NativeError.self)
    let args = arguments?.assumingMemoryBound(to: NativeValue.self)
    let typedHost = host?.assumingMemoryBound(to: NativeHost.self)
    guard count == 2,
          let args,
          let json = stringArgument(args.pointee),
          let callback = NativeCallback(value: args.advanced(by: 1).pointee, host: typedHost),
          callback.retain() else {
        return fail(errorPointer)
    }
    do {
        let config = try decoder.decode(YanhengConfig.self, from: Data(json.utf8))
        Task {
            do {
                let snapshot = try await client.fetchSnapshot(config: config)
                let body = String(decoding: try encoder.encode(snapshot), as: UTF8.self)
                callback.deliver(name: "snapshot.completed", payload: ["body": .string(body)], releaseAfter: true)
            } catch {
                callback.deliver(
                    name: "snapshot.failed",
                    payload: ["message": .string(error.localizedDescription)],
                    releaseAfter: true
                )
            }
        }
        setNull(output?.assumingMemoryBound(to: NativeValue.self))
        return nativeOK
    } catch {
        callback.release()
        return fail(errorPointer)
    }
}

private let startTimer: NativeCall = { _, arguments, count, host, output, error in
    let errorPointer = error?.assumingMemoryBound(to: NativeError.self)
    let args = arguments?.assumingMemoryBound(to: NativeValue.self)
    let typedHost = host?.assumingMemoryBound(to: NativeHost.self)
    guard count == 2,
          let args,
          let seconds = numberArgument(args.pointee),
          seconds >= 60,
          let callback = NativeCallback(value: args.advanced(by: 1).pointee, host: typedHost),
          callback.retain() else {
        return fail(errorPointer)
    }
    timer?.cancel()
    timerCallback?.release()
    timerCallback = callback
    let source = DispatchSource.makeTimerSource(queue: .main)
    source.schedule(deadline: .now() + seconds, repeating: seconds, leeway: .seconds(5))
    source.setEventHandler {
        timerCallback?.deliver(name: "refresh.timer", payload: [:], releaseAfter: false)
    }
    source.resume()
    timer = source
    setNull(output?.assumingMemoryBound(to: NativeValue.self))
    return nativeOK
}

private let stopTimer: NativeCall = { _, _, count, _, output, error in
    let errorPointer = error?.assumingMemoryBound(to: NativeError.self)
    guard count == 0 else { return fail(errorPointer) }
    timer?.cancel()
    timer = nil
    timerCallback?.release()
    timerCallback = nil
    setNull(output?.assumingMemoryBound(to: NativeValue.self))
    return nativeOK
}
