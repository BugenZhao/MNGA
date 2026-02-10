//
//  PostRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct RowMenuButtonView<MenuContent: View>: View {
  @ViewBuilder var menu: MenuContent

  @ScaledMetric var sizeBase: CGFloat = 24
  var size: CGFloat { max(sizeBase, 24) }

  var body: some View {
    Menu(content: { menu }) {
      Image(systemName: "ellipsis.circle.fill")
        .symbolRenderingMode(.hierarchical)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
        .maybeGlassEffect(in: .circle) // TODO: interactive is glitchy
    }
  }
}

struct PostRowHeaderView<MenuContent: View>: View {
  let post: Post
  let isAuthor: Bool
  let showMenu: Bool
  @ViewBuilder let menu: MenuContent

  @Environment(\.inSnapshot) var inSnapshot

  init(post: Post, isAuthor: Bool, showMenu: Bool, @ViewBuilder menu: () -> MenuContent) {
    self.post = post
    self.isAuthor = isAuthor
    self.showMenu = showMenu
    self.menu = menu()
  }

  @ViewBuilder
  var floor: some View {
    if post.floor != 0 {
      (Text("#").font(.footnote) + Text("\(post.floor)").font(.callout))
        .fontWeight(.medium)
        .foregroundColor(.accentColor)
    }
  }

  var body: some View {
    HStack {
      PostRowUserView(post: post, compact: false, isAuthor: isAuthor)
      Spacer()
      floor
      if showMenu, !inSnapshot {
        RowMenuButtonView { menu }
      }
    }
  }
}

struct PostRowView: View {
  let post: Post
  let isAuthor: Bool
  let screenshotTopic: Topic?
  let locateFloor: ((Post) -> Void)?

  @Binding var vote: VotesModel.Vote

  @EnvironmentObject<TopicDetailsActionModel>.Optional var action
  @EnvironmentObject<PostReplyModel>.Optional var postReply
  @EnvironmentObject<QuotedPostResolver>.Optional private var quotedPosts
  @EnvironmentObject var textSelection: TextSelectionModel
  @EnvironmentObject<ViewingImageModel>.Optional var viewingImage

  @Environment(\.enableAuthorOnly) var enableAuthorOnly
  @Environment(\.colorScheme) private var colorScheme

  @StateObject var authStorage = AuthStorage.shared
  @StateObject var pref = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var attachments: AttachmentsModel

  @State var showAttachments = false

  static func build(
    post: Post,
    isAuthor: Bool = false,
    screenshotTopic: Topic? = nil,
    vote: Binding<VotesModel.Vote>,
    locateFloor: ((Post) -> Void)? = nil,
  ) -> Self {
    let attachments = AttachmentsModel(post.attachments)
    return .init(
      post: post,
      isAuthor: isAuthor,
      screenshotTopic: screenshotTopic,
      locateFloor: locateFloor,
      vote: vote,
      attachments: attachments,
    )
  }

  private var user: User? {
    users.localUser(id: post.authorID)
  }

  var mock: Bool {
    post.id.tid.isMNGAMockID
  }

  var dummy: Bool {
    post.id == .dummy
  }

  var navID: NavigationIdentifier {
    // `pid == "0"` means this is the main floor of the topic, which is not a valid `pid` share link.
    // Use the topic link instead.
    if post.id.pid == "0" {
      return .topicID(tid: post.id.tid, fav: nil)
    }
    return .postID(post.id.pid)
  }

  @State var highlight = false
  var shouldHighlight: Bool {
    action?.scrollToPid == post.id.pid
  }

  @ViewBuilder
  var header: some View {
    PostRowHeaderView(post: post, isAuthor: isAuthor, showMenu: !dummy) {
      menu
    }
  }

  @ViewBuilder
  var footer: some View {
    AdaptiveFooterView {
      voter
    } trailing: {
      Group {
        if !post.alterInfo.isEmpty {
          Image(systemName: "pencil")
        }
        if !post.attachments.isEmpty {
          Image(systemName: "paperclip")
        }
        DateTimeTextView.build(timestamp: post.postDate)
          .id(pref.postRowDateTimeStrategy)
        Image(systemName: post.device.icon)
          .frame(minWidth: 10)
      }.foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  @ViewBuilder
  var comments: some View {
    if !post.comments.isEmpty {
      Divider()
      HStack {
        Spacer().frame(width: 6, height: 1)
        VStack {
          ForEach(post.comments, id: \.hashValue) { comment in
            PostCommentRowView(comment: comment)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  @ViewBuilder
  var voter: some View {
    HStack(spacing: 4) {
      Button(action: { doVote(.upvote) }) {
        Image(systemName: vote.state == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
          .foregroundColor(vote.state == .up ? .accentColor : .secondary)
          .symbolEffect(.bounce, value: vote.state == .up)
          .frame(height: 24)
      }.buttonStyle(.plain)

      let font = Font.subheadline.monospacedDigit()
      let score = max(Int32(post.score) + vote.delta, 0)
      Text("\(score)")
        .foregroundColor(vote.state == .up ? .accentColor : .secondary)
        .font(vote.state == .up ? font.bold() : font)
        .contentTransition(.numericText(value: Double(score)))

      Button(action: { doVote(.downvote) }) {
        Image(systemName: vote.state == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
          .foregroundColor(vote.state == .down ? .accentColor : .secondary)
          .symbolEffect(.bounce, value: vote.state == .down)
          .frame(height: 24)
      }.buttonStyle(.plain)
    }
  }

  @ViewBuilder
  var signature: some View {
    if pref.showSignature, let sig = user?.signature, !sig.spans.isEmpty {
      Divider()
      UserSignatureView(content: sig, font: .subheadline, color: .secondary)
    }
  }

  @ViewBuilder
  var content: some View {
    BlockedView(content: BlockWordsStorage.content(user: user?.name ?? .init(), content: post.content.raw), revealOnTap: true) {
      PostContentView(post: post)
    }
  }

  @ViewBuilder
  var menu: some View {
    if let model = postReply, !mock, !dummy {
      ControlGroup {
        Button(action: { doQuote(model: model) }) {
          Label("Quote", systemImage: "quote.bubble")
        }
        Button(action: { doComment(model: model) }) {
          Label("Comment", systemImage: "tag")
        }
        if authStorage.authInfo.uid == post.authorID {
          Button(action: { doEdit(model: model) }) {
            Label("Edit", systemImage: "pencil")
          }
        } else {
          // Why reporting myself?
          Button(role: .destructive, action: { doReport(model: model) }) {
            Label("Report", systemImage: "exclamationmark.bubble")
          }
        }
      }
    }
    Section {
      Button(action: { textSelection.text = post.content.rawReplacingBr }) {
        Label("Select Text", systemImage: "selection.pin.in.out")
      }
      if !attachments.items.isEmpty {
        Button(action: { showAttachments = true }) {
          Label("Attachments (\(attachments.items.count))", systemImage: "paperclip")
        }
      }
      if let action, enableAuthorOnly, let user {
        Button(action: { withPlusCheck(.authorOnly) {
          action.navigateToAuthorOnly =
            user.isAnonymous ? .anonymous(post.id) : .uid(post.authorID)
        } }) {
          Label("This Author Only", systemImage: "person")
        }
      }
      if let action, action.hasQuotedReplies(for: post.id) {
        Button(action: { action.showQuotedReplies(for: post.id) }) {
          Label("View Replies", systemImage: "text.quote")
        }
      }
      if let locateFloor {
        Button(action: { locateFloor(post) }) {
          Label("Locate This Floor", systemImage: "scope")
        }
      }
    }
    ShareLinksView(navigationID: navID, viewScreenshot: { viewScreenshot() })
  }

  @ViewBuilder
  var swipeActions: some View {
    if let model = postReply, !mock {
      let quote = Button(action: { doQuote(model: model) }) {
        Label("Quote", systemImage: "quote.bubble")
      }
      let vote = Button(action: { doVote(.upvote) }) {
        if self.vote.state == .up {
          Label("Cancel", systemImage: "hand.thumbsup.slash")
        } else {
          Label("Vote Up", systemImage: "hand.thumbsup")
        }
      }

      Group {
        if pref.postRowSwipeVoteFirst {
          vote.tint(self.vote.state != .up ? .accentColor : nil)
          quote
        } else {
          quote.tint(.accentColor)
          vote
        }
      }
    }
  }

  @ViewBuilder
  var mainContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      content
      footer
      comments
      signature
    }
    .padding(.vertical, 2)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  var screenshotView: some View {
    ScreenshotContainerView(colorScheme: colorScheme, mngaURL: navID.mngaURL) {
      if let screenshotTopic {
        TopicSubjectView(topic: screenshotTopic, lineLimit: nil)
          .fixedSize(horizontal: false, vertical: true)
      }
      mainContent
    }
    .if(quotedPosts != nil) { $0.environmentObject(quotedPosts!) }
    // When taking screenshot of a single post, we want to show the full image.
    .environment(\.contentImageForceNotThumb, true)
  }

  var body: some View {
    mainContent
      .contextMenu { menu }
      .sheet(isPresented: $showAttachments) {
        NavigationView { AttachmentsView(model: attachments, isPresented: $showAttachments) }
          .presentationDetents([.medium, .large])
      }
      .environmentObject(attachments)
      .swipeActions(edge: pref.postRowSwipeActionLeading ? .leading : .trailing) { swipeActions }
      .onChange(of: shouldHighlight, initial: true) { _, shouldHighlight in
        guard shouldHighlight else { return }
        action?.scrollToPid = nil

        withAnimation { highlight = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          withAnimation { highlight = false }
        }
      }
      .listRowBackground(highlight ? Color.accentColor.opacity(0.1) : nil) // TODO: why not animated?
  }

  @MainActor
  func viewScreenshot() {
    if let url = screenshotView.snapshot() {
      viewingImage?.show(url: url)
    } else {
      ToastModel.showAuto(.error("Failed to render screenshot."))
    }
  }

  func doVote(_ operation: PostVoteRequest.Operation) {
    if mock || dummy {
      #if os(iOS)
        HapticUtils.play(type: .warning)
      #endif
      return
    }

    logicCallAsync(.postVote(.with {
      $0.postID = post.id
      $0.operation = operation
    })) { (response: PostVoteResponse) in
      if !response.hasError {
        withAnimation {
          vote.state = response.state
          vote.delta += response.delta
          #if os(iOS)
            if vote.state != .none {
              HapticUtils.play(style: .light)
            }
          #endif
        }
      } else {
        // not used
      }
    }
  }

  func doQuote(model: PostReplyModel) {
    if dummy { return }

    model.show(action: .with {
      $0.postID = post.id
      $0.forumID = .with { f in
        f.fid = post.fid
      }
      $0.operation = .quote
    }, pageToReload: .last)
  }

  func doComment(model: PostReplyModel) {
    model.show(action: .with {
      $0.postID = post.id
      $0.forumID = .with { f in
        f.fid = post.fid
      }
      $0.operation = .comment
    }, pageToReload: .exact(Int(post.atPage)))
  }

  func doEdit(model: PostReplyModel) {
    model.show(action: .with {
      $0.postID = post.id
      $0.forumID = .with { f in
        f.fid = post.fid
      }
      $0.operation = .modify
    }, pageToReload: .exact(Int(post.atPage)))
  }

  func doReport(model: PostReplyModel) {
    model.show(action: .with {
      $0.postID = post.id
      $0.operation = .report
    })
  }
}
