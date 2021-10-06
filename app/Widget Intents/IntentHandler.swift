//
//  IntentHandler.swift
//  Widget Intents
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Intents

class IntentHandler: INExtension, ConfigurationIntentHandling {
  override init() {
    super.init()
    logicInitialConfigure()
  }

  func provideForumOptionsCollection(for intent: ConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetForum>?, Error?) -> Void) {
    basicLogicCallAsync(.forumList(.init())) { (response: ForumListResponse) in
      let forums = response.categories.flatMap { $0.forums }
      let items = forums.map(\.widgetForum)
      completion(INObjectCollection(items: items), nil)
    }
  }

  override func handler(for intent: INIntent) -> Any {
    // This is the default implementation.  If you want different objects to handle different intents,
    // you can override this and return the handler you want for that particular intent.

    return self
  }
}

extension Forum {
  var widgetForum: WidgetForum {
    WidgetForum(identifier: self.idDescription, display: self.name, subtitle: self.info, image: nil)
  }
}
