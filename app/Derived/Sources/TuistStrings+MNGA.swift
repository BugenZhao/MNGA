// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
public enum MNGAStrings: Sendable {
  /// MNGA is an open source iOS client for NGA Forum, developed based on SwiftUI and Rust. If you've encountered some problems using MNGA App, or just want to request some new features, you may give feedback via GitHub, NGA short messages, or Email.
  public static let mngaDescription = MNGAStrings.tr("Localizable", "MNGA Description")
  /// Press the button on the top-right to share the link of MNGA!
  public static let mngaPleaseShare = MNGAStrings.tr("Localizable", "MNGA Please Share")
  /// This App is not supported by NGA officially. To avoid interference and banning from NGA, these workarounds may be necessary.
  public static let ngaWorkaround = MNGAStrings.tr("Localizable", "NGA Workaround")
  /// MNGA Plus offers unlimited forum browsing and interaction experiences, and allows you to access all premium features of MNGA.
  public static let plusExplanation = MNGAStrings.tr("Localizable", "Plus Explanation")
  /// MNGA's continued development and maintenance would not be possible without your support. More features are coming soon!
  public static let plusMoreFeature = MNGAStrings.tr("Localizable", "Plus More Feature")
  /// MNGA's continued development and maintenance would not be possible without your support. Thank you for unlocking MNGA Plus!
  public static let plusThanks = MNGAStrings.tr("Localizable", "Plus Thanks")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension MNGAStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
// swiftformat:enable all
// swiftlint:enable all
