//
//  MNGAChatToolRegistry.swift
//  MNGA
//

import Foundation

enum MNGAChatToolRegistry {
  static func make() -> ChatToolRegistry {
    ChatToolRegistry(tools: [
      searchTopics,
      getTopic,
      listForumTopics,
      searchForums,
      getUser,
      getUserTopics,
      getUserPosts,
      getHotTopics,
    ])
  }

  private static let searchTopics = ClosureChatTool(
    definition: .init(
      name: "search_topics",
      displayName: "Searching Topics",
      description: "Search NGA topics by keyword, optionally within one forum. Use search_forums first when the forum ID is unknown. Returns {ok, page, total_pages, topics[]}; each topic has IDs, title, author, reply count, and Unix timestamps.",
      parameters: ToolSchema.object([
        "query": ToolSchema.string("Non-empty search keywords."),
        "forum_id": ToolSchema.nullableString("Forum identifier such as fid:510427 or stid:39223361, or null to search all forums."),
        "page": ToolSchema.integer("One-based result page.", minimum: 1, maximum: 1_000),
        "search_content": ToolSchema.boolean("Whether to search post content as well as titles."),
        "recommended_only": ToolSchema.boolean("Whether to return only recommended topics."),
      ]),
    ),
  ) { data in
    let arguments: SearchTopicsArguments = try decodeArguments(data)
    let page = try validatedPage(arguments.page)
    let query = try nonempty(arguments.query, named: "query")
    let scopedForumID = try arguments.forumID.map(forumID(from:))
    let result: Result<TopicSearchResponse, LogicError> = await logicCallAsync(
      .topicSearch(.with {
        if let scopedForumID { $0.id = scopedForumID }
        $0.page = page
        $0.searchContent = arguments.searchContent
        $0.recommendedOnly = arguments.recommendedOnly
        $0.key = query
      }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(PagedTopicsOutput(
      page: Int(page),
      totalPages: Int(response.pages),
      topics: response.topics.map(TopicToolSummary.init),
    ))
  }

  private static let getTopic = ClosureChatTool(
    definition: .init(
      name: "get_topic",
      displayName: "Loading Topic",
      description: "Fetch one page of an NGA topic, including post text and inline comments. Use another page when the required floor is not present. Returns {ok, topic, forum_name, page, total_pages, is_local_cache, posts[]}; text may include explicit truncation flags.",
      parameters: ToolSchema.object([
        "topic_id": ToolSchema.string("NGA topic ID (tid). Use the decimal ID from topic_context_json without adding a prefix."),
        "page": ToolSchema.integer("One-based topic page.", minimum: 1, maximum: 1_000),
      ]),
    ),
  ) { data in
    let arguments: GetTopicArguments = try decodeArguments(data)
    let topicID = try topicID(from: arguments.topicID.value)
    let page = try validatedPage(arguments.page)
    let cachedResult: Result<TopicDetailsResponse, LogicError> = await logicCallAsync(
      .topicDetails(.with {
        $0.topicID = topicID
        $0.page = page
        $0.localCache = true
      }),
      errorToastModel: nil,
    )
    let response: TopicDetailsResponse
    switch cachedResult {
    case let .success(cachedResponse):
      response = cachedResponse
    case .failure:
      let remoteResult: Result<TopicDetailsResponse, LogicError> = await logicCallAsync(
        .topicDetails(.with {
          $0.topicID = topicID
          $0.page = page
          $0.webApiStrategy = PreferencesStorage.shared.topicDetailsWebApiStrategy
        }),
        errorToastModel: nil,
      )
      response = try remoteResult.get()
    }
    let users = response.inPlaceUsers.reduce(into: [String: User]()) { result, user in
      result[user.id] = user
    }
    return try encodeOutput(TopicDetailsToolOutput(
      topic: TopicToolSummary(response.topic),
      forumName: response.forumName,
      page: Int(page),
      totalPages: Int(response.pages),
      isLocalCache: response.isLocalCache,
      posts: response.replies.map { PostToolSummary($0, users: users) },
    ))
  }

  private static let listForumTopics = ClosureChatTool(
    definition: .init(
      name: "list_forum_topics",
      displayName: "Loading Forum Topics",
      description: "List topics in an NGA forum by latest reply or topic creation time. Returns {ok, forum, page, total_pages, topics[]}.",
      parameters: ToolSchema.object([
        "forum_id": ToolSchema.string("Forum identifier such as fid:510427 or stid:39223361."),
        "page": ToolSchema.integer("One-based result page.", minimum: 1, maximum: 1_000),
        "order": ToolSchema.string("Sort order.", values: ["last_post", "post_date"]),
        "recommended_only": ToolSchema.boolean("Whether to return only recommended topics."),
      ]),
    ),
  ) { data in
    let arguments: ListForumTopicsArguments = try decodeArguments(data)
    let id = try forumID(from: arguments.forumID)
    let page = try validatedPage(arguments.page)
    let order: TopicListRequest.Order = switch arguments.order {
    case "last_post": .lastPost
    case "post_date": .postDate
    default: throw DomainToolError.invalidArgument("order")
    }
    let result: Result<TopicListResponse, LogicError> = await logicCallAsync(
      .topicList(.with {
        $0.id = id
        $0.page = page
        $0.order = order
        $0.recommendedOnly = arguments.recommendedOnly
      }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(ForumTopicsToolOutput(
      forum: ForumToolSummary(response.forum),
      page: Int(page),
      totalPages: Int(response.pages),
      topics: response.topics.map(TopicToolSummary.init),
    ))
  }

  private static let searchForums = ClosureChatTool(
    definition: .init(
      name: "search_forums",
      displayName: "Searching Forums",
      description: "Search NGA forums by name or keyword. Returns {ok, forums[]} with forum_id, name, and info; forum_id is directly usable by other tools.",
      parameters: ToolSchema.object([
        "query": ToolSchema.string("Non-empty forum name or keyword."),
      ]),
    ),
  ) { data in
    let arguments: SearchForumsArguments = try decodeArguments(data)
    let query = try nonempty(arguments.query, named: "query")
    let result: Result<ForumSearchResponse, LogicError> = await logicCallAsync(
      .forumSearch(.with { $0.key = query }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(ForumsToolOutput(forums: response.forums.map(ForumToolSummary.init)))
  }

  private static let getUser = ClosureChatTool(
    definition: .init(
      name: "get_user",
      displayName: "Loading User",
      description: "Fetch one NGA user by exact user ID or username. Provide exactly one lookup value. Returns {ok, user}; user is null when no exact match exists.",
      parameters: ToolSchema.object([
        "user_id": ToolSchema.nullableString("Exact NGA user ID, or null when looking up by username."),
        "username": ToolSchema.nullableString("Exact NGA username, or null when looking up by user ID."),
      ]),
    ),
  ) { data in
    let arguments: GetUserArguments = try decodeArguments(data)
    let userID = arguments.userID?.value.trimmingCharacters(in: .whitespacesAndNewlines)
    let username = arguments.username?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (userID?.isEmpty == false) != (username?.isEmpty == false) else {
      throw DomainToolError.invalidArgument("user_id/username")
    }
    let result: Result<RemoteUserResponse, LogicError> = await logicCallAsync(
      .remoteUser(.with {
        if let userID, !userID.isEmpty { $0.userID = userID }
        if let username, !username.isEmpty { $0.userName = username }
      }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(UserToolOutput(user: response.hasUser ? UserToolSummary(response.user) : nil))
  }

  private static let getUserTopics = ClosureChatTool(
    definition: .init(
      name: "get_user_topics",
      displayName: "Loading User Topics",
      description: "List topics created by an NGA user ID. Returns {ok, page, total_pages, topics[]}.",
      parameters: ToolSchema.object([
        "user_id": ToolSchema.string("Exact NGA user ID."),
        "page": ToolSchema.integer("One-based result page.", minimum: 1, maximum: 1_000),
      ]),
    ),
  ) { data in
    let arguments: UserPageArguments = try decodeArguments(data)
    let userID = try nonempty(arguments.userID.value, named: "user_id")
    let page = try validatedPage(arguments.page)
    let result: Result<UserTopicListResponse, LogicError> = await logicCallAsync(
      .userTopicList(.with {
        $0.authorID = userID
        $0.page = page
      }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(PagedTopicsOutput(
      page: Int(page),
      totalPages: Int(response.pages),
      topics: response.topics.map(TopicToolSummary.init),
    ))
  }

  private static let getUserPosts = ClosureChatTool(
    definition: .init(
      name: "get_user_posts",
      displayName: "Loading User Posts",
      description: "List recent topic replies by an NGA user ID. Returns {ok, page, posts[]} with topic metadata and a compact reply excerpt; inspect content_truncated before relying on completeness.",
      parameters: ToolSchema.object([
        "user_id": ToolSchema.string("Exact NGA user ID."),
        "page": ToolSchema.integer("One-based result page.", minimum: 1, maximum: 1_000),
      ]),
    ),
  ) { data in
    let arguments: UserPageArguments = try decodeArguments(data)
    let userID = try nonempty(arguments.userID.value, named: "user_id")
    let page = try validatedPage(arguments.page)
    let result: Result<UserPostListResponse, LogicError> = await logicCallAsync(
      .userPostList(.with {
        $0.authorID = userID
        $0.page = page
      }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(UserPostsToolOutput(
      page: Int(page),
      posts: response.tps.map(UserPostToolSummary.init),
    ))
  }

  private static let getHotTopics = ClosureChatTool(
    definition: .init(
      name: "get_hot_topics",
      displayName: "Loading Hot Topics",
      description: "Fetch hot NGA topics in one forum for the last day, week, or month. Returns {ok, forum, range, topics[]}.",
      parameters: ToolSchema.object([
        "forum_id": ToolSchema.string("Forum identifier such as fid:510427 or stid:39223361."),
        "range": ToolSchema.string("Hot-topic time range.", values: ["day", "week", "month"]),
        "limit": ToolSchema.integer("Maximum topics to return.", minimum: 1, maximum: 50),
      ]),
    ),
  ) { data in
    let arguments: HotTopicsArguments = try decodeArguments(data)
    let id = try forumID(from: arguments.forumID)
    guard 1 ... 50 ~= arguments.limit else { throw DomainToolError.invalidArgument("limit") }
    let range: HotTopicListRequest.DateRange = switch arguments.range {
    case "day": .day
    case "week": .week
    case "month": .month
    default: throw DomainToolError.invalidArgument("range")
    }
    let result: Result<HotTopicListResponse, LogicError> = await logicCallAsync(
      .hotTopicList(.with {
        $0.id = id
        $0.range = range
        $0.fetchPageLimit = 5
        $0.limit = UInt64(arguments.limit)
      }),
      errorToastModel: nil,
    )
    let response = try result.get()
    return try encodeOutput(HotTopicsToolOutput(
      forum: ForumToolSummary(response.forum),
      range: arguments.range,
      topics: response.topics.map(TopicToolSummary.init),
    ))
  }
}

private final class ClosureChatTool: ChatTool {
  let definition: ChatToolDefinition
  private let handler: (Data) async throws -> String

  init(
    definition: ChatToolDefinition,
    handler: @escaping (Data) async throws -> String,
  ) {
    self.definition = definition
    self.handler = handler
  }

  func execute(arguments: Data) async throws -> String {
    try await handler(arguments)
  }
}

private enum ToolSchema {
  static func object(_ properties: [String: Any]) -> [String: Any] {
    [
      "type": "object",
      "properties": properties,
      "required": properties.keys.sorted(),
      "additionalProperties": false,
    ]
  }

  static func string(_ description: String, values: [String]? = nil) -> [String: Any] {
    var schema: [String: Any] = ["type": "string", "description": description]
    if let values { schema["enum"] = values }
    return schema
  }

  static func nullableString(_ description: String) -> [String: Any] {
    [
      "anyOf": [["type": "string"], ["type": "null"]],
      "description": description,
    ]
  }

  static func integer(_ description: String, minimum: Int, maximum: Int) -> [String: Any] {
    [
      "type": "integer",
      "description": description,
      "minimum": minimum,
      "maximum": maximum,
    ]
  }

  static func boolean(_ description: String) -> [String: Any] {
    ["type": "boolean", "description": description]
  }
}

private enum DomainToolError: LocalizedError {
  case invalidArgument(String)

  var errorDescription: String? {
    switch self {
    case let .invalidArgument(name):
      "Invalid tool argument: \(name)"
    }
  }
}

private struct SearchTopicsArguments: Decodable {
  let query: String
  let forumID: FlexibleIdentifier?
  let page: Int
  let searchContent: Bool
  let recommendedOnly: Bool

  private enum CodingKeys: String, CodingKey {
    case query
    case forumID = "forum_id"
    case page
    case searchContent = "search_content"
    case recommendedOnly = "recommended_only"
  }
}

private struct GetTopicArguments: Decodable {
  let topicID: FlexibleIdentifier
  let page: Int

  private enum CodingKeys: String, CodingKey {
    case topicID = "topic_id"
    case page
  }
}

private struct ListForumTopicsArguments: Decodable {
  let forumID: FlexibleIdentifier
  let page: Int
  let order: String
  let recommendedOnly: Bool

  private enum CodingKeys: String, CodingKey {
    case forumID = "forum_id"
    case page
    case order
    case recommendedOnly = "recommended_only"
  }
}

private struct SearchForumsArguments: Decodable {
  let query: String
}

private struct GetUserArguments: Decodable {
  let userID: FlexibleIdentifier?
  let username: String?

  private enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case username
  }
}

private struct UserPageArguments: Decodable {
  let userID: FlexibleIdentifier
  let page: Int

  private enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case page
  }
}

private struct HotTopicsArguments: Decodable {
  let forumID: FlexibleIdentifier
  let range: String
  let limit: Int

  private enum CodingKeys: String, CodingKey {
    case forumID = "forum_id"
    case range
    case limit
  }
}

private struct FlexibleIdentifier: Decodable {
  let value: String

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      value = string
      return
    }
    if let integer = try? container.decode(Int64.self) {
      value = String(integer)
      return
    }
    if let integer = try? container.decode(UInt64.self) {
      value = String(integer)
      return
    }
    throw DecodingError.typeMismatch(
      Self.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Expected a string or integer identifier.",
      ),
    )
  }
}

private struct TopicToolSummary: Encodable {
  let topicID: String
  let title: String
  let authorID: String
  let authorName: String
  let forumID: String
  let replies: Int
  let postedAtUnixSeconds: UInt64
  let lastPostAtUnixSeconds: UInt64

  init(_ topic: Topic) {
    topicID = topic.id
    title = topic.subject.full.isEmpty ? topic.subjectContentCompat : topic.subject.full
    authorID = topic.authorID
    authorName = topic.authorNameDisplay
    forumID = topic.fid.isEmpty ? forumIdentifier(topic.parentForum.id) : "fid:\(topic.fid)"
    replies = Int(topic.repliesNum)
    postedAtUnixSeconds = topic.postDate
    lastPostAtUnixSeconds = topic.lastPostDate
  }
}

private struct ForumToolSummary: Encodable {
  let forumID: String
  let name: String
  let info: String

  init(_ forum: Forum) {
    forumID = forumIdentifier(forum.id)
    name = forum.name
    info = forum.info
  }
}

private struct UserToolSummary: Encodable {
  let userID: String
  let username: String
  let registrationAtUnixSeconds: UInt64
  let postCount: Int
  let reputation: Double
  let ipLocation: String
  let followedByCurrentUser: Bool
  let followingCount: Int
  let followerCount: Int

  init(_ user: User) {
    userID = user.id
    username = user.nameDisplayCompat
    registrationAtUnixSeconds = user.regDate
    postCount = Int(user.postNum)
    reputation = Double(user.fame) / 10
    ipLocation = user.ipLocation
    followedByCurrentUser = user.followed
    followingCount = Int(user.followingCount)
    followerCount = Int(user.followerCount)
  }
}

private struct CommentToolSummary: Encodable {
  let postID: String
  let authorID: String
  let authorName: String?
  let postedAtUnixSeconds: UInt64
  let content: String
  let contentTruncated: Bool

  init(_ post: Post, users: [String: User]) {
    postID = post.id.pid
    authorID = post.authorID
    authorName = users[post.authorID]?.nameDisplayCompat
    postedAtUnixSeconds = post.postDate
    let fullContent = post.content.chatPlainText
    content = String(fullContent.prefix(160))
    contentTruncated = content.count < fullContent.count
  }
}

private struct PostToolSummary: Encodable {
  let postID: String
  let floor: Int
  let authorID: String
  let authorName: String?
  let postedAtUnixSeconds: UInt64
  let score: Int
  let content: String
  let contentTruncated: Bool
  let comments: [CommentToolSummary]
  let commentsTruncated: Bool

  init(_ post: Post, users: [String: User]) {
    postID = post.id.pid
    floor = Int(post.floor)
    authorID = post.authorID
    authorName = users[post.authorID]?.nameDisplayCompat
    postedAtUnixSeconds = post.postDate
    score = Int(post.score)
    let fullContent = post.content.chatPlainText
    let contentLimit = post.floor == 0 ? 8_000 : 800
    content = String(fullContent.prefix(contentLimit))
    contentTruncated = content.count < fullContent.count
    comments = post.comments.prefix(3).map { CommentToolSummary($0, users: users) }
    commentsTruncated = comments.count < post.comments.count
  }
}

private struct UserPostToolSummary: Encodable {
  let topic: TopicToolSummary
  let postID: String
  let authorID: String
  let postedAtUnixSeconds: UInt64
  let content: String
  let contentTruncated: Bool

  init(_ item: TopicWithLightPost) {
    topic = TopicToolSummary(item.topic)
    postID = item.post.id.pid
    authorID = item.post.authorID
    postedAtUnixSeconds = item.post.postDate
    let fullContent = item.post.content.chatPlainText
    content = String(fullContent.prefix(1_200))
    contentTruncated = content.count < fullContent.count
  }
}

private struct PagedTopicsOutput: Encodable {
  let ok = true
  let page: Int
  let totalPages: Int
  let topics: [TopicToolSummary]
}

private struct TopicDetailsToolOutput: Encodable {
  let ok = true
  let topic: TopicToolSummary
  let forumName: String
  let page: Int
  let totalPages: Int
  let isLocalCache: Bool
  let posts: [PostToolSummary]
}

private struct ForumTopicsToolOutput: Encodable {
  let ok = true
  let forum: ForumToolSummary
  let page: Int
  let totalPages: Int
  let topics: [TopicToolSummary]
}

private struct ForumsToolOutput: Encodable {
  let ok = true
  let forums: [ForumToolSummary]
}

private struct UserToolOutput: Encodable {
  let ok = true
  let user: UserToolSummary?
}

private struct UserPostsToolOutput: Encodable {
  let ok = true
  let page: Int
  let posts: [UserPostToolSummary]
}

private struct HotTopicsToolOutput: Encodable {
  let ok = true
  let forum: ForumToolSummary
  let range: String
  let topics: [TopicToolSummary]
}

private func decodeArguments<Value: Decodable>(_ data: Data) throws -> Value {
  try JSONDecoder().decode(Value.self, from: data)
}

private func encodeOutput<Value: Encodable>(_ value: Value) throws -> String {
  let encoder = JSONEncoder()
  encoder.keyEncodingStrategy = .convertToSnakeCase
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  return String(decoding: try encoder.encode(value), as: UTF8.self)
}

private func validatedPage(_ page: Int) throws -> UInt32 {
  guard 1 ... 1_000 ~= page else { throw DomainToolError.invalidArgument("page") }
  return UInt32(page)
}

private func nonempty(_ value: String, named name: String) throws -> String {
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { throw DomainToolError.invalidArgument(name) }
  return trimmed
}

private func topicID(from rawValue: String) throws -> String {
  let value = try nonempty(rawValue, named: "topic_id")
  if value.allSatisfy(\.isNumber) { return value }

  let lowercased = value.lowercased()
  for prefix in ["tid:", "tid="] where lowercased.hasPrefix(prefix) {
    let candidate = value.dropFirst(prefix.count)
    guard !candidate.isEmpty, candidate.allSatisfy(\.isNumber) else {
      throw DomainToolError.invalidArgument("topic_id")
    }
    return String(candidate)
  }

  if let components = URLComponents(string: value),
     let queryValue = components.queryItems?.first(where: { $0.name.lowercased() == "tid" })?.value,
     !queryValue.isEmpty,
     queryValue.allSatisfy(\.isNumber)
  {
    return queryValue
  }

  if let components = URLComponents(string: value),
     components.scheme?.lowercased() == "mnga",
     components.host?.lowercased() == "topic",
     let candidate = components.path.split(separator: "/").first,
     candidate.allSatisfy(\.isNumber)
  {
    return String(candidate)
  }

  throw DomainToolError.invalidArgument("topic_id")
}

private func forumID(from rawValue: FlexibleIdentifier) throws -> ForumId {
  let value = try nonempty(rawValue.value, named: "forum_id")
  if value.allSatisfy(\.isNumber) {
    return .with { $0.fid = value }
  }
  if value.hasPrefix("stid:") {
    let component = try validatedForumIDComponent(value.dropFirst("stid:".count))
    return .with { $0.stid = component }
  }
  if value.hasPrefix("fid:") {
    let component = try validatedForumIDComponent(value.dropFirst("fid:".count))
    return .with { $0.fid = component }
  }
  if value.hasPrefix("##") {
    let component = try validatedForumIDComponent(value.dropFirst(2))
    return .with { $0.stid = component }
  }
  if value.hasPrefix("#") {
    let component = try validatedForumIDComponent(value.dropFirst())
    return .with { $0.fid = component }
  }
  throw DomainToolError.invalidArgument("forum_id")
}

private func validatedForumIDComponent(_ value: Substring) throws -> String {
  guard !value.isEmpty, value.allSatisfy(\.isNumber) else {
    throw DomainToolError.invalidArgument("forum_id")
  }
  return String(value)
}

private func forumIdentifier(_ id: ForumId) -> String {
  switch id.id {
  case let .fid(value): "fid:\(value)"
  case let .stid(value): "stid:\(value)"
  case nil: ""
  }
}
