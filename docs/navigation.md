# Navigation Behavior

This document records where every navigation in MNGA lands, so layout work can be checked against it. It pins down intended behavior only. What the system does around it, such as which columns return after a rotation, is not part of the contract.

Evidence for each row:

- **Run**: observed on iPad mini (A20 Pro) or iPhone 18 Pro, iOS 27.2. Rows were first run on a 2.3.1 build, and the regression pass below was repeated after the root moved to one `NavigationSplitView`.
- **Code**: read from the code, not exercised yet.

## Structure

| Layout | Root | Used when |
|---|---|---|
| Three columns | `NavigationSplitView`, with a `NavigationStack` in each column | `usesColumnLayout` is true: both size classes are regular (iPad, unfolded iPhone Duo) |
| Single stack | The same split view, collapsed to one stack | `usesColumnLayout` is false: every iPhone, folded iPhone Duo, and a large iPhone in landscape |

The root is the same view in both layouts, so a change between them keeps the navigation state. Read `usesColumnLayout` from the environment below the root. Do not use the device idiom, or `horizontalSizeClass` below the root.

When the columns do not all fit, which in testing meant a window under about 1100 points wide, the system overlays the sidebar on the content column and no column width or split view style changes that. `hidesOverlaidSidebar()` closes the overlay after navigating from the sidebar to column 2, so apply it to those destinations.

| Column | Root content | Typically shows |
|---|---|---|
| 1, sidebar | `ForumListView` | Forum index, global search |
| 2, content | `TopicListPlaceholderView` | Topic lists, profiles, feeds |
| 3, detail | `TopicDetailsPlaceholderView` | Topics, and anything reached from them |

No column is restricted to one kind of screen. A topic list can sit in column 3, and a link in a signature can put a topic in column 2. What a column shows depends on the path taken, so rules follow the link's kind, not the destination's type.

## Navigation kinds

| Kind | How it is written | Single stack | Three columns |
|---|---|---|---|
| **Next column** | `NavigationLink` with the default `isDetailLink`, or `CrossStackNavigationLinkHack` | Push | From column 1, replaces column 2. From column 2, replaces column 3. Either clears the target's whole stack. From column 3, pushes in column 3 |
| **Same column** | `NavigationLink` with `.isDetailLink(false)` | Push | Pushes in the current column |
| **Current stack** | `.navigationDestination`, usually through `TopicDetailsActionModel` | Push | Pushes in the current column |
| **Sheet** | `.sheet` | Sheet | Sheet |
| **Cover** | `.fullScreenCover` | Cover | Cover |
| **External** | `OpenURLModel` | In-app Safari or system browser | Same |
| **Layout split** | Branches on `usesColumnLayout` | Push | Sheet |

Inside a sheet with its own stack, the three push kinds all push in that sheet's stack.

`CrossStackNavigationLinkHack` adds an `id` to the destination. Without it, selecting a different row from a dynamic list does not refresh the destination.

Plus-gated entries (`PlusCheckNavigationLink`, `withPlusCheck`, `checkPlus`) show a toast when locked, and tapping that toast opens the paywall sheet.

## Column 1

| From | Action | Kind | Three columns | Single stack | Evidence | Code |
|---|---|---|---|---|---|---|
| Forum index, favorites | Forum row | Next column | Replaces column 2. Column 3 keeps its content | Push | Run | `ForumRowLinkView` |
| Forum index | Trial or unlock button | Sheet | Sheet | Sheet | Code | `ForumListView` |
| Forum index | Navigate, from a pasteboard link | Deep link | See Deep links | Same | Code | `ForumListView` |
| User menu | My Profile | Next column | Replaces column 2. Column 3 keeps its content | Push | Run | `UserMenuView` |
| User menu | Favorite Topics | Next column | Replaces column 2 | Push | Code | `UserMenuView` |
| User menu | History (Plus) | Next column | Replaces column 2 | Push | Run (iPad) | `UserMenuView` |
| User menu | Short Messages (Plus) | Next column | Replaces column 2. Column 3 keeps its content | Push | Run (iPad) | `UserMenuView` |
| User menu | Notifications | Layout split | Sheet | Push | Code | `UserMenuView` |
| User menu | About & Feedback | Layout split | Sheet | Push | Run (iPad) | `UserMenuView` |
| User menu | Settings | Sheet | Sheet | Sheet | Code | `UserMenuView` |
| User menu | Sign In | Sheet | Sheet | Sheet | Code | `UserMenuView` |
| Global search | All Forums | Same column | Pushes in column 1 | Push | Run | `GlobalSearchView` |
| Global search | All Topics | Next column | Replaces column 2 | Push | Run | `GlobalSearchView` |
| Global search | All Users | Next column | Replaces column 2 | Push | Code | `GlobalSearchView` |
| Forum search results | Forum row | Next column | Replaces column 2 | Push | Code | `ForumSearchView` |

The notification shortcut differs by screen. The toolbar button appears only with unread notifications, unless a preference hides it, and never inside the notification sheet:

| Where | Three columns | Single stack | Code |
|---|---|---|---|
| Forum index toolbar | Not shown | Push | `ForumListView` |
| Topic list toolbar | Not shown | Sheet | `TopicListView` |
| Topic toolbar | Sheet | Sheet | `TopicDetailsView` |
| Column 3 placeholder toolbar | Sheet | Not applicable | `TopicDetailsPlaceholderView` |
| Notification toast | Sheet | Sheet | `MainToastModifier` |

All but the toast and the topic toolbar were run. The `Always Show Notification Badge` debug setting shows the toolbar button without unread notifications.

## Lists in column 2 or 3

Next-column rows replace column 3 from column 2, clearing its stack, and push from column 3. Same-column rows push where they are.

| From | Action | Kind | Evidence | Code |
|---|---|---|---|---|
| Topic list | Topic row, or Goto Topic in its context menu | Next column | Run (row, from both columns) | `TopicRowLinkView` |
| Topic list | Subforum shortcut row | Same column | Code | `ForumRowLinkView` |
| Topic list menu | Topped Topic | Next column | Code | `TopicListView` |
| Topic list menu | Recommended Topics | Same column | Run (column 2) | `TopicListView` |
| Topic list menu | Hot Topics (Plus) | Same column | Run (column 2) | `TopicListView` |
| Topic list bottom bar | Subforums | Sheet, then Current stack | Run (column 2) | `TopicListView` |
| Topic list bottom bar | New topic | Sheet | Code | `PostEditorView` |
| Hot, Recommended, Favorite, History, search lists | Topic row | Next column | Code | `TopicRowLinkView` |
| User search | User row | Next column | Code | `UserSearchView` |
| Profile, Topics tab | Topic row | Next column | Code | `UserProfileView` |
| Profile, Replies tab | Post row, opening that single post | Next column | Code | `UserProfileView` |
| Profile menu | New Short Message, Edit Signature | Sheet | Code | `UserProfileView` |
| Profile | Avatar, opening the image | Cover | Code | `UserView` |
| Profile | Link in signature | Current stack, see Post content | Code | `UserSignatureView` |
| Short messages | Conversation | Next column | Code | `ShortMessageListView` |
| Short messages | New message | Sheet | Code | `ShortMessageListView` |
| Notifications | Notification row, opening a post or conversation | Next column | Run | `NotificationListView` |

Selecting a subforum closes the sheet first, then pushes the forum on the stack behind it. Notifications appear only in a sheet on iPad, so their rows push in that sheet there.

`TopicRowLinkView` also has a context menu preview, which renders the topic without navigating. Searching inside a topic list swaps its content in place, and so do the profile tabs, the topic list order, and the favorite folder picker.

## Inside a topic

All of these use the current stack, so they push in whichever column or sheet holds the topic.

| Action | Destination | Evidence | Code |
|---|---|---|---|
| Avatar or user row | `UserProfileView` | Run | `UserView` |
| More menu, Goto Forum | `TopicListView` | Run | `TopicDetailsView` |
| More menu, Author Only (Plus) | Filtered `TopicDetailsView` | Code | `TopicDetailsView` |
| More menu, View Cached Topic | Local `TopicDetailsView` | Code | `TopicDetailsView` |
| Post menu, This Author Only (Plus) | Filtered `TopicDetailsView` | Run | `PostRowView` |
| Post menu, View Replies | `PostReplyChainView` | Code | `PostRowView` |
| Quote header in a post | `PostReplyChainView` | Run | `ContentCombiner` |
| Goto Topic, from a single post view | Full `TopicDetailsView` | Code | `TopicDetailsView` |

These do not push:

| Action | Result | Code |
|---|---|---|
| Post menu, Locate This Floor | Pops one level, then scrolls the view beneath to that floor. Offered in filtered and reply-chain views. The pop was run, from a filtered view opened in a reply chain | `TopicDetailsView`, `PostReplyChainView` |
| Jump to floor or page (Plus) | Sheet, then scrolls in place | `TopicJumpSelectorView` |
| Reply, quote, comment, edit, report | Editor sheet. Its image picker is a further sheet | `PostRowView`, `GlobalSheetsModifier`, `ContentEditorView` |
| Select Text | Sheet | `TextSelectionView` |
| Attachments | Sheet. An image closes it and opens the viewer, and any other file opens in-app Safari | `AttachmentsView` |
| Image in a post | Cover | `ContentImageView` |
| Share menu, Screenshot | Cover | `ShareLinksView` |
| Share menu, Open in Browser | External | `ShareLinksView` |
| Share menu, MNGA Link or NGA Link | System share sheet | `ShareLinksView` |

Column 3 can hold an arbitrary path, since these destinations link onward. Run confirmed topic, then forum, then a second topic, each with a working back button. Selecting a topic in column 2 then replaced that whole path.

## Post content

Links in content go through `ContentCombiner.visit(url:)`. Content links use the current stack of the `TopicDetailsActionModel` in the environment, wherever the content is shown. Evidence is Code, except that a topic link and a reply quote header were run.

| Content | Recognized as | Destination |
|---|---|---|
| `/read.php?tid=`, `mnga://topic/` | Topic | `TopicDetailsView`. Current stack. Run from column 3 and on the single stack |
| `/read.php?pid=`, `mnga://post/` | Post | Single post `TopicDetailsView`. Current stack |
| `/thread.php?stid=` or `fid=`, `mnga://forum/st/`, `mnga://forum/f/` | Forum | `TopicListView`. Current stack |
| `/nuke.php?uid=`, `mnga://user/` | User by ID | `RemoteUserProfileView`. Current stack |
| `/nuke.php?username=` | User by name | `RemoteUserProfileView`. Current stack |
| `[@user]` | Converted to a `/nuke.php` link | `RemoteUserProfileView`. Current stack |
| `[tid]` | Converted to a `/read.php` link | `TopicDetailsView`. Current stack |
| Any other URL, including other paths on NGA hosts | None | External, following the in-app Safari preference |
| A URL that fails to parse | None | Error toast |
| `[img]`, `[noimg]`, `[album]` | Image | Cover. `.mp4` is treated as video |
| `[flash]` video or audio, `[attach]` | Media | In-app Safari, regardless of the preference |
| `[quote]` with reply metadata | Reply | Header opens `PostReplyChainView`, unless already in one. Current stack |
| `[uid]`, `[pid]` | Metadata | Not tappable |

Rules for recognizing a link:

- It must use the `mnga` scheme or a host in `URLs.hosts`. Relative URLs resolve against the configured backend, so a custom backend outside that list sends them to the browser.
- On `read.php`, `tid` wins over `pid`. On `thread.php`, `stid` wins over `fid`. On `nuke.php`, `uid` wins over `username`. Other parameters, such as `page`, are ignored.

Each surface that renders content has its own action model, so links push in that surface's stack:

| Surface | Stack used by links | Code |
|---|---|---|
| Topic, reply chain | The topic's stack | `TopicDetailsView`, `PostReplyChainView` |
| Conversation | The conversation's stack | `ShortMessageDetailsView` |
| Signature on a profile | The profile's stack, so My Profile in column 2 pushes in column 2 | `UserProfileView` |
| Editor preview | None, on purpose. Recognized links do nothing, and other URLs still open | `GenericEditorView` |

## Deep links

`mnga://` URLs and valid pasteboard links open in a sheet with its own stack on both layouts, replacing any sheet already showing. Its root has a back button that closes it, and everything inside follows the kinds above. (Run, on both layouts)

The sheet is attached to `ForumListView` by `SchemesNavigationModifier`. A deep link shows a toast first, then presents after a short delay. A URL the app does not recognize is ignored, and an invalid pasteboard link shows an error toast.

## Sheets with their own stacks

| Sheet | Inside it | Evidence | Code |
|---|---|---|---|
| Notifications | Rows push in the sheet | Run | `NotificationListNavigationView` |
| Deep link | All navigation pushes in the sheet | Run | `SchemesNavigationModifier` |
| About & Feedback | A topic view, so its navigation pushes in the sheet | Run | `AboutNavigationView` |
| Settings | Plus, block words, list and post appearance, cache, About, What's New all push | Code | `PreferencesView` |
| What's New list | Each version pushes | Code | `AllWhatsNewView` |
| Paywall | Features is a further sheet | Code | `PlusSheetView`, `PlusView` |
| Subforums | Selecting one closes it | Code | `SubforumListView` |

Other global presentations are in `ContentView` and `GlobalSheetsModifier`: sign in, the activity sheet, the launch What's New sheet, in-app Safari, post, short message, and signature editors, text selection, and the image viewer.

Alerts and confirmation dialogs, such as renaming a favorite folder or discarding a draft, do not navigate and are left out.

## Column visibility

The full screen button in a topic hides columns 1 and 2, and column 3 keeps its stack. It shows only in the three-column layout. (Run)

Known issues: the button also shows on topics inside sheets, such as a deep link, where it can only affect the columns behind the sheet. It also shows on a topic in column 2, reachable after unfolding, where it hides that topic and leaves the placeholder. The column button brings it back. (Run)

## Folding on iPhone Duo

Folding and unfolding change the layout while the app runs. Moving between layouts is best effort, because the columns and the single stack cannot represent each other exactly.

- Unfolded, the inner display shows columns 2 and 3 with the sidebar overlaid. The three-column behavior in this document applies, except that the sidebar closes after navigating.
- Folding merges the columns into one back stack: the content column first, then the detail column. (Run)
- Unfolding moves a topic opened while folded into column 3. (Run)
- A presented sheet stays presented across a fold. (Run)
- The rotation lock applies only when folded, and the setting says so. On the inner display the system ignores it. (Run)
- The notification list pushed from the forum index while folded stays in the sidebar, and a row opened from it lands in column 2 after unfolding. While the list is on that stack, the sheet shortcut stays hidden. (Run)

## Rules for new navigation

1. Pick the kind by intent. To open content beside the current list, use next column. To stay in the current context, use same column or current stack.
2. Use `CrossStackNavigationLinkHack` for next-column links inside dynamic lists.
3. `.navigationDestination` always pushes in the current column. It cannot target another column.
4. Apply `GlobalSheetsModifier` to any new stack presented as a sheet, so reply and image flows work inside it.
5. Add new navigation to this document.

## Regression pass

Run this after changing the root structure or any link's kind. Add forum 275 to favorites first, so it appears in column 1. It and `MNGA Meta` open without signing in. Steps 7 and 8 need an account. To reach Plus entries on a simulator, set the `cachedUnlockStatus` default to the data `{"paid":{}}` while it is shut down.

On iPad, in landscape:

1. Open forum 275 from column 1. Column 2 changes and column 3 stays.
2. Open a topic from column 2. It fills column 3 with no back button.
3. In that topic, tap the avatar, go back, then use More, Goto Forum. Each pushes in column 3 with a back button.
4. In the forum now in column 3, open a topic. It pushes in column 3.
5. Open another topic from column 2. Column 3 is replaced and the back button is gone.
6. In column 2, open Recommended Topics. It pushes in column 2 and column 3 stays.
7. From the user menu, open My Profile. Column 2 is replaced and column 3 stays.
8. Search from column 1. All Forums pushes in column 1, and All Topics replaces column 2.
9. Open About & Feedback from the user menu. It is a sheet.
10. Run `xcrun simctl openurl booted mnga://topic/45150945`. It is a sheet, and Goto Forum pushes inside it.
11. Tap the full screen button in a topic. Only column 3 remains, with its content intact.
12. In `MNGA Meta`, open the FAQ topic and tap its first link. The linked topic pushes in the same column.

On iPhone, walk the same path. Every step pushes on one stack, except that step 10 is a sheet and step 11 does not exist.

On iPhone Duo, use the `duo-hinge` skill:

1. Unfold, open a forum from the sidebar, and check that the sidebar closes.
2. Open a topic and a link inside it, then fold. The same topic stays on screen, and back walks through the first topic to the forum.
3. Open a topic while folded, then unfold. It is in column 3.
4. Fold with a deep link sheet open. The sheet stays.
5. Rotate while folded. The bars stay usable beside the camera.

On a large iPhone, rotate to landscape. It stays on one stack.

To test notifications without real ones, temporarily append `Notification` values to `response.notis` in `NotificationModel`'s `onResponse`, and do not commit that. Seeding the sled cache does not work, because a simulator launch clears it.
