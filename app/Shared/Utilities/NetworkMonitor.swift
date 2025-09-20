//
//  NetworkMonitor.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/09/20
//

import Combine
import Network

extension NWPath {
  // Just works.
  var effectiveInterface: NWInterface.InterfaceType {
    if usesInterfaceType(.wifi) { return .wifi }
    if usesInterfaceType(.cellular) { return .cellular }
    if usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
    return .other
  }
}

final class NetworkMonitor: ObservableObject {
  @Published var currentPath: NWPath? = nil

  private var cancellables = Set<AnyCancellable>()

  private let networkMonitor = NWPathMonitor()

  init() {
    networkMonitor.pathUpdateHandler = { [weak self] path in
      logger.debug("network changed: \(path.status), \(path.effectiveInterface)")
      self?.currentPath = path
    }
    $currentPath
      .removeDuplicates { $0?.effectiveInterface == $1?.effectiveInterface }
      .filter { $0?.status == .satisfied }
      .dropFirst()
      .sink { _ in self.logicInvalidateClient() }
      .store(in: &cancellables)
    networkMonitor.start(queue: DispatchQueue.global())
  }

  func logicInvalidateClient() {
    let _: InvalidateClientResponse = try! logicCall(.invalidateClient(.init()))
  }
}
