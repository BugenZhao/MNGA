//
//  IntentHandler.swift
//  Widget Intents
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Intents

class IntentHandler: INExtension, ConfigurationIntentHandling {
  var groupStore: UserDefaults {
    UserDefaults(suiteName: Constants.Key.groupStore)!
  }

  func provideForumOptionsCollection(for intent: ConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetForum>?, Error?) -> Void) {
    let forums = [Forum](readFrom: groupStore, forKey: Constants.Key.favoriteForums) ?? []
    let items = forums.map(\.widgetForum)
    completion(INObjectCollection(items: items), nil)
  }

  override func handler(for intent: INIntent) -> Any {
    return self
  }
}

extension Forum {
  var widgetForum: WidgetForum {
    WidgetForum(identifier: self.idDescription, display: self.name, subtitle: self.info, image: nil)
  }
}
