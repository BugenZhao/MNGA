//
//  RustCall.swift
//  InteropApp
//
//  Created by Bugen Zhao on 6/23/21.
//

import Foundation
import SwiftProtobuf

struct LogicError: Error {
  public let error: String
}

private func extractByteBuffer(_ bb: ByteBuffer) -> (Data?, LogicError?) {
  var resError: LogicError? = nil
  var resData: Data? = nil

  if let err = bb.err {
    resError = LogicError(error: String(cString: err)) // copied
  } else {
    resData = Data(UnsafeRawBufferPointer(start: bb.ptr, count: Int(bb.len))) // copied
  }

  return (resData, resError)
}

// MARK: - Sync

func logicCall<Response: SwiftProtobuf.Message>(_ requestValue: SyncRequest.OneOf_Value) throws -> Response {
  let request = SyncRequest.with { $0.value = requestValue }
  let reqData = try! request.serializedData()
  let resByteBuffer = reqData.withUnsafeBytes { ptr -> ByteBuffer in
    let ptr = ptr.bindMemory(to: UInt8.self).baseAddress
    return rust_call(ptr, UInt(reqData.count))
  }

  let (resData, resError) = extractByteBuffer(resByteBuffer)
  defer { rust_free(resByteBuffer) }

  if let resData = resData {
    let res = try Response(serializedData: resData)
    return res
  } else {
    throw resError!
  }
}


// MARK: - Async

private class WrappedDataCallback {
  private let callback: (Data) -> Void
  private let errorCallback: (LogicError) -> Void

  init(
    callback: @escaping (Data) -> Void,
    errorCallback: @escaping (LogicError) -> Void
  ) {
    self.callback = callback
    self.errorCallback = errorCallback
  }

  func run(_ data: Data?, _ error: LogicError?) {
    DispatchQueue.main.async {
      logger.debug("running callback on thread `\(Thread.current)`")
      if let error = error {
        self.errorCallback(error)
      } else {
        self.callback(data!)
      }
    }
  }
}

private func byteBufferCallback(callbackPtr: UnsafeRawPointer?, resByteBuffer: ByteBuffer) -> Void {
  let (resData, resError) = extractByteBuffer(resByteBuffer)
  defer { rust_free(resByteBuffer) }
  let dataCallback: WrappedDataCallback = Unmanaged.fromOpaque(callbackPtr!).takeRetainedValue()

  logger.debug("before running callback on thread `\(Thread.current)`")
  dataCallback.run(resData, resError)
}

func logicCallAsync<Response: SwiftProtobuf.Message>(
  _ requestValue: AsyncRequest.OneOf_Value,
  requestDispatchQueue: DispatchQueue = .global(qos: .userInitiated),
  errorToastModel: ToastModel? = ToastModel.hud,
  onSuccess: @escaping (Response) -> Void,
  onError: @escaping (LogicError) -> Void = { _ in }
) {
  requestDispatchQueue.async {
    let request = AsyncRequest.with { $0.value = requestValue }
    let errorCallback = { (e: LogicError) in
      logger.error("logicCallAsync: \(e)")
      if let tm = errorToastModel { tm.message = .error(e.error) }
      onError(e)
    }
    let dataCallback = WrappedDataCallback(
      callback: { (resData: Data) in
        do {
          let res = try Response(serializedData: resData)
          onSuccess(res)
        } catch {
          let e = LogicError(error: "\(type(of: error)): \(error)")
          errorCallback(e)
        }
      },
      errorCallback: errorCallback
    )
    let dataCallbackPtr = Unmanaged.passRetained(dataCallback).toOpaque()
    let rustCallback = Callback(user_data: dataCallbackPtr, callback: byteBufferCallback)

    let reqData = try! request.serializedData()
    reqData.withUnsafeBytes { ptr -> Void in
      let ptr = ptr.bindMemory(to: UInt8.self).baseAddress
      rust_call_async(ptr, UInt(reqData.count), rustCallback)
    }
  }
}

@available(iOS 15.0.0, *)
func logicCallAsync<Response: SwiftProtobuf.Message>(
  _ requestValue: AsyncRequest.OneOf_Value,
  requestDispatchQueue: DispatchQueue = .global(qos: .userInitiated),
  errorToastModel: ToastModel? = ToastModel.hud
) async -> Result<Response, LogicError> {
  return await withCheckedContinuation { (continuation: CheckedContinuation<Result<Response, LogicError>, Never>) in
    logicCallAsync(requestValue, requestDispatchQueue: requestDispatchQueue, errorToastModel: errorToastModel)
    { (res: Response) in
      continuation.resume(returning: .success(res))
    } onError: { err in
      continuation.resume(returning: .failure(err))
    }
  }
}
