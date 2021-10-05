//
//  Platform.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/5.
//

import Foundation
import SwiftUI

extension View {
  func mayGroupedListStyle() -> some View {
    #if os(iOS)
      self
        .listStyle(GroupedListStyle())
    #else
      self
    #endif
  }

  func mayInsetGroupedListStyle() -> some View {
    #if os(iOS)
      self
        .listStyle(InsetGroupedListStyle())
    #else
      self
    #endif
  }
}

extension View {
  func navigationTitleInline<S>(string title: S) -> some View where S: StringProtocol {
    #if os(iOS)
      self.navigationBarTitle(title, displayMode: .inline)
    #elseif os(macOS)
      self.navigationTitle(title)
    #endif
  }

  func navigationTitleInline(key title: LocalizedStringKey) -> some View {
    #if os(iOS)
      self.navigationBarTitle(title, displayMode: .inline)
    #elseif os(macOS)
      self.navigationTitle(title)
    #endif
  }

  func navigationTitleLarge<S>(string title: S) -> some View where S: StringProtocol {
    #if os(iOS)
      self.navigationBarTitle(title, displayMode: .large)
    #elseif os(macOS)
      self.navigationTitle(title)
    #endif
  }

  func navigationTitleLarge(key title: LocalizedStringKey) -> some View {
    #if os(iOS)
      self.navigationBarTitle(title, displayMode: .large)
    #elseif os(macOS)
      self.navigationTitle(title)
    #endif
  }
}

func copyToPasteboard(_ content: String) {
  #if os(iOS)
    UIPasteboard.general.string = content
  #elseif os(macOS)
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.writeObjects([content as NSString])
  #endif
}

extension ToolbarItemPlacement {
  static var mayNavigationBarLeading: Self {
    #if os(iOS)
      Self.navigationBarLeading
    #else
      Self.navigation
    #endif
  }

  static var mayNavigationBarLeadingOrAction: Self {
    #if os(iOS)
      Self.navigationBarLeading
    #else
      Self.primaryAction
    #endif
  }

  static var mayNavigationBarTrailing: Self {
    #if os(iOS)
      Self.navigationBarTrailing
    #else
      Self.primaryAction
    #endif
  }

  static var mayBottomBar: Self {
    #if os(iOS)
      Self.bottomBar
    #else
      Self.status
    #endif
  }
}

#if os(macOS)
  extension Color {
    static var secondarySystemGroupedBackground: Self {
      Color(NSColor.textBackgroundColor)
    }

    static var systemGroupedBackground: Self {
      Color(NSColor.windowBackgroundColor)
    }
  }
#endif
