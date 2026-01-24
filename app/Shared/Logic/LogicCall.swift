//
//  LogicCall.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import SwiftProtobuf

func logicCallAsync<Response: SwiftProtobuf.Message>(
  _ requestValue: AsyncRequest.OneOf_Value,
  requestDispatchQueue: DispatchQueue = .global(qos: .userInitiated),
  errorToastModel: ToastModel? = .banner,
  onSuccess: @escaping (Response) -> Void,
  onError: @escaping (LogicError) -> Void = { _ in },
) {
  let errorCallback = { (e: LogicError) in
    logger.error("logicCallAsync: \(e)")
    if let tm = errorToastModel { tm.message = .error(e.error) }
    onError(e)
  }
  basicLogicCallAsync(requestValue, requestDispatchQueue: requestDispatchQueue, onSuccess: onSuccess, onError: errorCallback)
}

func logicCallAsync<Response: SwiftProtobuf.Message>(
  _ requestValue: AsyncRequest.OneOf_Value,
  requestDispatchQueue: DispatchQueue = .global(qos: .userInitiated),
  errorToastModel: ToastModel? = .banner,
) async -> Result<Response, LogicError> {
  await withCheckedContinuation { (continuation: CheckedContinuation<Result<Response, LogicError>, Never>) in
    logicCallAsync(requestValue, requestDispatchQueue: requestDispatchQueue, errorToastModel: errorToastModel) { (res: Response) in
      continuation.resume(returning: .success(res))
    } onError: { err in
      continuation.resume(returning: .failure(err))
    }
  }
}
