//
//  MNGA_Widget.swift
//  MNGA Widget
//
//  Created by Bugen Zhao on 2021/10/6.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), configuration: ConfigurationIntent())
  }

  func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
    let entry = SimpleEntry(date: Date(), configuration: configuration)
    completion(entry)
  }

  func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    var entries: [SimpleEntry] = []

    // Generate a timeline consisting of five entries an hour apart, starting from the current date.
    let currentDate = Date()
    for hourOffset in 0 ..< 5 {
      let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
      let entry = SimpleEntry(date: entryDate, configuration: configuration)
      entries.append(entry)
    }

    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
  let configuration: ConfigurationIntent
}

struct MNGA_WidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    Text(entry.configuration.forum?.displayString ?? "")
    Text(entry.date, style: .time)
  }
}

@main
struct MNGA_Widget: Widget {
  let kind: String = "MNGA_Widget"

  var body: some WidgetConfiguration {
    IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
      MNGA_WidgetEntryView(entry: entry)
    }
      .configurationDisplayName("My Widget")
      .description("This is an example widget.")
  }
}

struct MNGA_Widget_Previews: PreviewProvider {
  static var previews: some View {
    MNGA_WidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent()))
      .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
