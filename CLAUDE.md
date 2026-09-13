# PARAGON – working notes

Memory for anyone (human or Claude) picking this project up. Keep it short and current.

## What this is

macOS/iOS app in the spirit of NotePlan: plain markdown vault organised as
Goals + PARA (Projects, Areas, Resources, Archive), tasks synced two-way with
Apple Reminders, daily/weekly notes, quick capture, full-text search.

Owner: Martin Schabbauer (project manager, part-time retired, Sweden, not a
developer). **English is not his first language.** Write short, plain sentences with common
words. No idioms, no wordplay, no invented shorthand, and never a heading that stands in for
a sentence — "the word", "chains", "ladders" and "Serves… on an area" each cost a round trip
on 11 September because he could not tell what they meant. Name every button and screen
exactly as it is spelled in the app, and give whole URLs, never an abbreviation. **Write to him in English again** — he asked on **13 September 2026**: *"let's speak English
for some time. Sometimes that is easier for me, and I think it's easier in some respects
because the app is in English."* From 11 to 13 September it was Swedish prose with English
terms; that rule is on hold, not gone, so switch back the moment he asks. Either way the
reason behind it holds: he runs GitHub, TestFlight and the app in English, so button names,
screen names and field names are always quoted exactly as they appear there — *New Note*,
*Horizon*, *Aspiration*, *Serves…*, *Set a deadline…*, *Review*, *Run workflow*, *Update*.
Plain short sentences matter more than the language.
Communicate in short, friendly, concrete steps. He cannot run
Terminal commands. Since build 56 both apps come from TestFlight. When CI is green, tell him in two
short lines, naming which of the two things is meant (he asked for that, and equally
for no step-by-step lecture): **Run workflow** on GitHub, then **Update** in Apple's
TestFlight app on the phone and on the Mac. Give him the **whole URL**, not an abbreviation —
https://github.com/marsch124/AMS-PARAGON/actions/workflows/testflight.yml — he clicks it, and
after the repository rename the old shorthand sent him to the wrong place. Xcode is no longer part of his routine.

## Layout

- `Core/` – Swift package `ParagonCore` (models, markdown, vault, sync engine, search, capture). `swift test --package-path Core`.
- `App/Paragon/` – SwiftUI app (macOS + iOS). `App/ParagonShare/` – iOS share extension.
- `project.yml` – XcodeGen spec. `Paragon.xcodeproj/` is committed; CI regenerates it only when `project.yml` changes (keeps his signing Team).
- `Example Vault/` – sample vault incl. Goals, Calendar, Templates.
- `.github/workflows/ci.yml` – macOS runner: package tests, xcodegen, xcodebuild macOS + iOS Simulator.

## Rules

- Branch: `claude/ams-para-reminders-sync-s0ex53` only. No PRs unless asked.
- GitHub repo is `marsch124/AMS-PARAGON` since 11 September 2026 (it was `AMS-PARA`). GitHub
  forwards the old address, so a remote still pointing at the old name keeps working — which is
  how the session that renamed it carried on afterwards. The working branch keeps its original
  spelling, `claude/ams-para-reminders-sync-s0ex53`: it is only a label.
- No Swift toolchain in the remote container: verify via CI (`mcp__github__actions_list`, `get_job_logs`).
- Bump `BuildStamp.number` in `App/Paragon/AppModel.swift` on every push; it shows at the bottom of the sidebar so we know which build he runs.
- Add a section for that build to `Docs/VersionHistory.md` (user-facing wording) on every push. `Docs/HowItWorks.md` is the manual; update it when behaviour changes. Both are bundled (project.yml `Docs` resources) and shown by `HelpView`.
- Build N = CI run N, *usually*: a docs-only push spends a run without bumping the stamp, so
  the two drift apart (first at build 123, CI run 124). `BuildStamp.number` in the app and in
  TestFlight is the truth; match on that, not on the run number.
- Adding a source file needs a `project.yml` change so CI regenerates the committed project.

## Conventions

- Frontmatter YAML subset; empty values written as `key:`.
- Tasks: `- [ ]`, `- [x] @done(...)`, `- [-]`, `- [>]`, `>YYYY-MM-DD[THH:mm]`, `!`..`!!!`, `#tag`, `^tXXXXXX`, indented subtasks.
- Goals never sync to Reminders. Projects/areas link with `goal: <title>`.
- Colours: Projects green, Areas pink, Resources blue, Archive grey, Goals gold.
- All model writes that SwiftUI triggers mid-update go through `afterUpdate` / deferred Bindings (`sectionSelection`, `noteSelection`, `sheetSelection`, `errorPresented`).
- Navigation from links uses `AppModel.show(...)`: section first, note on the next turn.
- **Nothing but views inside a `@ViewBuilder`.** `var x = …`, `x.append(…)`, loops and
  early returns are not allowed there and fail the build with "'buildExpression' is
  unavailable: this expression does not conform to 'View'" (build 58). Assemble strings,
  arrays and conditions in a plain function or a computed property and let the view read
  the result. There is no Swift compiler in this container, so CI is the only check and a
  slip like this costs a whole build.
- **Nothing may be attached to a row in a `List(selection:)` that takes its click.**
  `.draggable` and `.onTapGesture` both do on macOS, and `.simultaneousGesture` did not save it
  either: builds 71 to 74 left the Inbox unusable because no line could be selected, and CI
  cannot catch it. Row actions belong on the context menu or the row's own buttons. Whatever
  the fix looks like, changing one thing per build is the only way to know which one it was.
- **`.position` makes a view claim its parent's whole size**, so gestures attached to it fire
  anywhere in the parent: in build 85 every map box swallowed clicks across the entire canvas
  and the last one drawn won them all. Place things on a canvas with `.offset` inside a
  top-leading stack instead — the view keeps its own size and hit area.
- **One gesture, not two, when a view must handle both a tap and a drag.** `.onTapGesture`
  beside `.gesture(DragGesture…)` on the same view argues over a click and the tap loses
  (build 85). Use a single `DragGesture(minimumDistance: 0)` and decide in `onEnded`: no
  movement is a tap.
- **The phone's navigation bar fits a back button, a title and one control.** Anything more
  collides: build 88 put a segmented Picker plus three buttons there and it rendered as
  overlapping letters. Branch the `.toolbar` on `isPhone` and give the phone one `Menu`
  (`ToolbarContentBuilder` takes `if`/`else`).
- **A `.principal` toolbar item is only the title when the title is inline.** With the default
  large title iOS draws its own below the bar and the principal view is not what a press lands
  on, so build 112's long press on the phone's "Browse" title did nothing until build 117 added
  `.navigationBarTitleDisplayMode(.inline)`. A hidden gesture also needs a second, findable
  target: the "Build N" row at the foot of the Browse list carries the same long press.
- **Shortcuts are the thing this project keeps getting wrong — check three things before
  choosing one.** Does macOS already own it (⌥⌘D hides the Dock, ⌥⌘W closes every window)?
  Does the *app's own* menu already carry it — a `WindowGroup` puts **New Window** on ⌘N, and
  `CommandGroup(after: .newItem)` leaves that in place and loses, so it must be
  `replacing:` (build 120)? And does the key exist on a Swedish keyboard — `[` and `]` are
  ⌥8 and ⌥9 there, which is why Back and Forward are ⌃⌘← / ⌃⌘→ and not the browsers' ⌘[ / ⌘]
  (build 118)? CI compiles the menu but never presses it, so none of this is caught here.
- A helper type that touches `AppModel` needs `@MainActor` on it (the model is main-actor
  bound), or the build fails with "main actor-isolated property … can not be referenced from
  a nonisolated context" (build 67).

## Recently fixed (build 30)

The "window scramble": expanding **Linked notes** (a DisclosureGroup above
the TextEditor in NoteEditorView) made the editor report its full text
height as a minimum, the NavigationSplitView grew to ~1300pt inside an
821pt window and every column looked scrolled under the toolbar. He called
this "pressing Linked Goals"; the header goal link was never the trigger.
Fix: the editor HStack sits in a GeometryReader with a fixed frame, so it
takes the remaining height and never demands more. Diagnostics stay:
**Help › Copy Diagnostics** (⌃⌘D since build 103; ⌥⌘D is macOS's own hide-the-Dock
shortcut and never reached the app) copies a log with clicks (hit view),
section/note changes and the window view tree; an OVERFLOW line appears
if it ever happens again. Build 29's 1pt window nudge was removed (it made
the window grow to the demanded height).

## Deleting notes (build 31)

Every note except Inbox can go to the system Trash: editor toolbar button
(⌘⌫) or right-click in the note list, both with a confirmation. Goals can
be archived too. `Vault.trash` uses `trashItem`, falling back to delete.

## Map (build 32)

Sidebar **Map**: a top-down diagram of what serves what. `NoteIndex.linkMap()`
(Core, `Vault/LinkMap.swift`) builds a tree: root goals → subgoals, areas,
projects (a project sits under its area when it has one, with a dashed second
link to its goal) → open top-level tasks and resources as chips. Notes with no
goal, loose resources, and archived or done notes go into dashed group boxes;
archived notes keep dashed links to the goal/area they still name. `MapView`
lays it out itself (`MapLayout`: parents centred over subtrees, fixed-size
boxes in a two-way ScrollView, lines in a Canvas). Clicking a box highlights
its neighbourhood (`upstream`/`downstream`) and opens the note. Goal matching
for `goal:` lines now lives in `NoteIndex.goal(matching:)`.

## Apple Calendar (build 33)

Read only. `EventKitCalendarStore` (own `EKEventStore`, full-access request on
first use) feeds `AppModel.eventsByDay`; Today and the daily note agenda show
the day's events above the tasks. Settings › Apple Calendar can turn it off.
Info.plist carries `NSCalendarsFullAccessUsageDescription` via `project.yml`.
Nothing is written to Calendar; tasks are not turned into events.

## Split view sizing (build 34)

Root cause of every "columns hidden under the toolbar" report: on macOS the
NavigationSplitView representable sizes itself from its columns' NSHostingView
intrinsic content size, and a column whose content fills its space reports
"current height + toolbar inset" whenever it is re-measured (task added,
disclosure opened, section switched), so the split view grew past the window
each time. `AppModel.tameSplitViewColumns` walks the window, sets
`sizingOptions = []` on every NSHostingView under the NSSplitView (not inside
scroll views, so list rows keep their heights), and runs at launch, after
section/note changes and after every click; `repairOverflow` also resets the
host frame if it still overflows. Help › Copy Diagnostics shows "tamed N".

## Calendar choice, Time Blocks, open in Calendar (build 35)

Settings › Apple Calendar lists every calendar with a toggle (`visibleCalendarIDs`,
nil = all) and "Time blocks go to" (`timeBlockCalendarID`). Sidebar **Time
Blocks** (`TimeBlocksView`): a form (title, day, start, duration, calendar,
notes) writes ordinary events to Apple Calendar marked with URL
`amspara://timeblock` and the note marker `ams-para:timeblock`; the list shows
blocks from a week back to 60 days ahead, click to edit, right-click to open
in Calendar or delete. Blocks are deliberately separate from tasks. Every
event row has "Open in Calendar" (double-click, arrow button, context menu):
macOS `ical://ekevent/<id>`, iOS `calshow:`. Adding a source file needs a
`project.yml` change so CI regenerates the committed Xcode project.

## Hardening audit (build 39)

Three reviews (sync engine, vault/markdown/capture, app layer) and the fixes:
- `Frontmatter` keeps unknown lines as `.raw` entries in an ordered list; a
  leading `---` around prose is not frontmatter; CRLF/BOM handled; quotes unescaped.
- `Vault.save` throws `modifiedOnDisk` when the file is newer than
  `note.modifiedAt` (1 s tolerance) and returns the note with the new date;
  `saveConflictCopy` writes "<name> (conflict yyyy-MM-dd HHmm).md".
  `loadNote` decodes UTF-8 → UTF-16 (BOM) → CP1252; unreadable files land in
  `vault.skippedFiles` instead of failing `allNotes()`. `isNotePath` guards
  paths from links. `archive` never overwrites an older archived note.
- `Note.replace(task:previousID:)` matches by id/title and searches when lines
  moved. `@done` stamps survive on cancelled tasks.
- `SyncEngine.run`: ids persisted before Reminders is touched; every note
  change is recorded as a mutation and re-applied to a fresh copy on
  `modifiedOnDisk`; lists from existing links are fetched too (rename moves
  reminders); a link whose list was not fetched or whose note is missing is
  kept, never cancelled/deleted; marked reminders unknown to this device are
  never deleted; duplicate ids get fresh ones; `^t`/`@done` stripped from
  reminder titles; imported reminders get their marker after notes+state are
  saved; on error the partial state is saved before rethrowing.
  `InMemoryRemindersStore` has `beforeFetch`, `failNextCreate`, `failNextUpdate`.
- App: `flushEditor` hook (NoteEditorView) is called before every model write,
  before sync, on scene background and `NSApplication.willTerminate`;
  `saveText` keeps a conflict copy on `modifiedOnDisk`, `save` reloads and asks
  to redo; `checkForExternalChanges` (10 s signature poll + on activate)
  reloads; `openVault` opens the new folder before dropping the old scope;
  open/close refuse while syncing; `drainOutbox` requeues failures; capture
  keeps items on failure; `handle(url:)` never creates notes; the share
  extension fails visibly without the App Group.
- Not done (by choice): caching task parsing for the month view (perf only),
  limiting first sync of old daily notes.

## Task actions, Done, weekly plan (build 41)

Core: `RepeatRule` + `TaskItem.repeatRule` (`@repeat(weekly|2w|…)`, serialized
after the due date), `TaskItem.nextOccurrence`, `Note.complete(task:)` inserts
the next occurrence below (also in `SyncEngine.reconcile` when Reminders
completes it), `Note.taskBlock/removeTaskBlock/appendTaskBlock` move a task
with its subtasks, `Note.setNextAction` (`#next` tag, one per note),
`Note.nextAction`, `Note.progress`, `NoteIndex.nextActions()`.
App: `TaskActions.swift` has `TaskTransfer` (UTType
`com.schabbauer.amspara.task`, declared in Info.plist), `acceptsTaskDrop`,
`TaskContextMenu` (reschedule/repeat/next/block time/move/open),
`TaskDatePicker`. `TaskRow` is draggable with the menu; drops on note rows,
sidebar Inbox, month cells, week headers, weekly-note day rows. `DoneView`
(sidebar Done). `AppModel`: `setDueDate/setRepeat/makeNextAction/
clearNextAction/moveTask/blockTime/task(for:)`, `timeBlockDraft`.
Project: `type: syncedFolder` for App/Paragon and App/ParagonShare (Xcode 16
synchronized groups) so new source files need no regeneration; Info.plist and
entitlements live in `App/Config/<target>/`; CI commits `App/Config`.

## iPhone layout (build 42)

`PhoneRootView` (iOS only, used by ContentView when `horizontalSizeClass ==
.compact`): TabView with Today, Inbox, Browse (`PhoneBrowseView`: every
section + Settings) and a Capture tab that opens the quick-capture sheet.
`PhoneStack` wraps each tab in a NavigationStack with `PhoneRoute` (note,
section, settings); it pushes `NoteEditorView` when `selectedNotePath` changes
on the active tab and clears the selection when popped. Sections reuse
`NoteListView` by setting `model.section` on appear.

## iPhone note screen scrolls (build 53)

`NoteEditorView` was one fixed `VStack`: header, agendas, task checklist, links, editor,
add-a-task row. Nothing in it scrolled, which is fine on a Mac window and impossible on a
phone — a note with 25 tasks ran off both ends at once, the first tasks behind the
navigation bar and the last behind the tab bar, with no way to reach either.

The body is now `deskBody` (unchanged: the `GeometryReader` that keeps builds 30/34 honest)
or `phoneBody`, chosen by `horizontalSizeClass == .compact`. `phoneBody` is one `ScrollView`
over the same `sections`, with `editorPane` given a fixed 320pt — inside a scroll view there
is no leftover height to take — and `addTaskBar` pinned as a `.safeAreaInset(edge: .bottom)`
so it never has to be scrolled to. The shared pieces (`sections`, `editorPane`, `addTaskBar`)
are what both layouts are built from, so a change lands on both.

**Build 127 removed the 320pt box while editing — and the story of how long that took is
the lesson.** A `UITextView` scrolls itself, so on the phone the editor was one scroll view
inside another and the note was penned into a 320pt window. `MarkdownSyntaxEditor` takes
`scrolls:`; `phoneBody` passes `false` **only in Edit mode** and gives it
`.frame(minHeight: 320)`, and the iOS representable implements
`sizeThatFits(_:uiView:context:)` returning `uiView.sizeThatFits` for the proposed width but
never less than `leastHeight` (320). Two independent floors, because an early version had
none. Preview and Split still get `.frame(height: 320)` and a scrolling text view, since
`MarkdownPreview` is itself a `ScrollView` and needs a height handed to it. macOS passes
`true` throughout — builds 30/34 are about the Mac's editor never reporting its full height.

**The lesson, which cost a whole day: I never established the symptom before fixing it.**
He said he could not type in a note on the phone. I assumed the editor had collapsed, shipped
this change (123), took the blame, reverted it, shipped it again with floors (125), took the
blame again, reverted that too (126) — and 126 was byte-identical to 122 and *still* failed.
The actual cause was that his `editorMode` was set to **Preview**, where there is no text view
at all and no tap can ever place a cursor. Both "broken" builds had left Preview on the old
code path untouched, so neither had ever broken anything. Before changing code to fix a
report, find out what the user is actually looking at — one question would have saved two
reverts and his patience. Build 127 also puts an Edit/Preview toggle in the phone's add-task
bar so that mode can never again be a hidden setting three taps deep.

**Testing the phone layouts on this Mac.** Xcode 26.6 is installed, so the simulator is
usable without CI:

- `xcodebuild -scheme Paragon -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/amspara-dd build`
- the vault is a security-scoped bookmark, so there is no path to set — generate one with
  `URL.bookmarkData()` on the Mac and write it into the app's
  `Library/Preferences/com.schabbauer.AMSPara.plist` as `vaultBookmark`. It resolves in the
  simulator, which shares the Mac's filesystem.
- every route to a note is a tap, so `ContentView.onAppear` reads `PARAGON_OPEN_NOTE`
  (DEBUG only) and opens that note through the existing `amspara://` handler:
  `SIMCTL_CHILD_PARAGON_OPEN_NOTE=Inbox xcrun simctl launch booted com.schabbauer.AMSPara`
- `@AppStorage` values (`editorMode`) can be preset in the same plist to reach a mode.
- Screenshots with `xcrun simctl io booted screenshot`. Taps need the Simulator MCP, which
  wants `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` on his Mac;
  osascript keystrokes are TCC-blocked, so without that there is no way to tap.

**macOS builds locally only with signing off:** add
`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`.

## Hidden task markers (build 43)

`TaskIDMasking` (Core) hides `^tXXXXXX` in the editor: `hidden(in:)` strips them
for display, `restored(_:from:)` puts them back by matching unchanged task lines
first and pairing what is left between those anchors in order (so a renamed task
keeps its marker, a new one gets none). `NoteEditorView` keeps `baseText` (the
real text the shown text came from) and saves through `write(_:)`.
`SyncEngine.run` builds `recoverableIDs` from links whose id no longer exists,
keyed by "notePath\ntitle" from `lastTaskFingerprint`, and gives the old id back
to a matching task without one, so the reminder is not deleted and recreated.

## Backups and sync preview (build 44)

`VaultBackup` (Core, `Vault/VaultBackup.swift`): plain dated folders under
`.ams-para/Backups/<yyyy-MM-dd HHmm>~<reason>`, `makeBackup` skips when the
content signature (paths + mtimes of .md/.json/.txt outside Backups) matches the
last one, keeps 10, `restore` backs up first and never deletes newer notes,
`copyContents(to:)` clones the vault for the preview. `AppModel`: `backUp`,
`backUpNow`, `backUpDaily` (launch + openVault, keyed by `lastBackupDay`),
`restore`, `showBackupsInFinder`, `backsUpBeforeSync` (default on, runs inside
`syncNow`). `previewSync()` copies the vault to a temp folder and seeds an
`InMemoryRemindersStore` from EventKit (`seed(lists:records:)`), runs the real
engine there and shows `SyncReportView` through `AppSheet.syncReport`
(`reportToShow`/`reportIsPreview`) — never a second `.sheet` modifier.

## Look and feel (build 46)

`Views/Theme.swift`: `Theme` (gutter/gap/radius, `editorFont` = proportional
`.body`, `editorLineSpacing`), `SectionLabel` (uppercase caption + optional
count) and `EmptyStateView` (icon, title, sentence, one action button).
`NoteListView.emptyList(searching:)` shows a per-section empty state instead
of the list; `DetailView` uses `EmptyStateView` too. `TintStripe`/`KindBadge`
stay in ContentView. TodayView opens with the date and a due count.

## Live markdown editor (build 47)

`MarkdownHighlight` (Core) turns a note into `[MarkdownSpan]` (range + style):
block styles first (frontmatter, fences, heading, task, quote, rule), inline
after (bold/italic/code/wikilink), so the later, smaller span wins.
`MarkdownSyntaxEditor` (App) wraps NSTextView/UITextView in a representable and
maps the styles to attributes in `MarkdownAttributes`; the whole note is
restyled after each change (skipped over 200k characters). The binding is only
written back when the text really differs, so typing is never interrupted, and
`updateNSView` only replaces the string when it came from elsewhere. Replaces
the TextEditor in `NoteEditorView`; all the save, flush and masking logic is
unchanged.

## TestFlight (build 48)

`.github/workflows/testflight.yml`, manual dispatch only, a two-way matrix (iOS and
macOS, `fail-fast: false`) so one button ships both apps: xcodegen, PlistBuddy
sets CFBundleVersion/ShortVersion from `github.run_number` and adds
`ITSAppUsesNonExemptEncryption` (done in the workflow, not project.yml, so the
committed Xcode project and his signing Team are never touched), writes the
App Store Connect key to `~/private_keys/AuthKey_<ID>.p8`, archives for
`generic/platform=iOS` with `-allowProvisioningUpdates` + the three
`-authenticationKey…` flags (cloud signing, no Mac and no certificates needed),
then `-exportArchive` with `method: app-store-connect` and `destination: upload`.
Secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` (the workflow
passes the team on the xcodebuild command line; without a team, signing fails).
Since build 55 `project.yml` also sets `DEVELOPMENT_TEAM: D24ENP83QQ` (his own team),
so Xcode no longer rewrites `project.pbxproj` locally and his pulls stay clean.
`TESTFLIGHT.md` at the repo root is his step-by-step (browser only, no Mac).
The uploaded version is `1.0.<BuildStamp.number>` with CFBundleVersion
`<BuildStamp.number>.<run number>`, read out of `AppModel.swift` by the workflow, so
TestFlight and the app always show the same build number.
The job runs on `macos-26` and `xcode-select`s the highest Xcode on the image:
Apple rejects an upload built with an older SDK. The key must have the **Admin**
role — App Manager gives "Cloud signing permission error" at export. The archive is built
**unsigned** (`CODE_SIGNING_ALLOWED=NO`, no `-allowProvisioningUpdates`) and `-exportArchive`
does the signing: signing at archive time signs for *development*, and every runner being a
fresh machine that minted a new development certificate per run until the account hit Apple's
limit ("Choose a certificate to revoke", build 61). Forcing
`CODE_SIGN_IDENTITY="Apple Distribution"` instead fails — automatic signing rejects a manual
identity ("conflicting provisioning settings", build 63). How little signing is possible
differs per platform, so the matrix carries a `signing:` string: iOS archives fully unsigned,
macOS ad-hoc (`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-`) because a Mac App Store upload
needs the sandbox entitlement embedded and an unsigned build carries none ("App sandbox not
enabled", build 64). Both App IDs
need the App Group `group.com.schabbauer.amspara` enabled in the developer portal,
and `project.yml` declares `UISupportedInterfaceOrientations` (all four), without
which Apple rejects the binary. macOS signs with its own
`App/Config/Paragon/Paragon-macOS.entitlements` (via
`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`) which drops the App Group: the Mac App Store wants
team-prefixed groups, the share extension is iOS only, and `outboxURL` already falls back to
Application Support. The macOS platform must be added to the app record in App Store Connect
(Distribution › Add Platform) before the first Mac upload.

## Calendar schedule column (build 61)

`DayScheduleView.swift`: `CalendarDetailView` is the third column while `section == .calendar`
(wired in `DetailView`), with a Schedule/Note switch (`calendarDetailShowsNote`) that flips to
Note when a note is selected. `DayScheduleView` draws the day: `ScheduleItem` unifies events,
time blocks and timed tasks; `lanes(for:)` puts overlapping items side by side as `PlacedItem`
(a struct, because key paths cannot address tuple members); hours are drop targets that create
a one-hour block from a task. One `.sheet` only (build 44's lesson), keyed by `ScheduleSheet`,
for both new and existing blocks; it saves through `AppModel.saveTimeBlock`/`deleteTimeBlock`.

## Inbox triage (build 66)

`InboxView.swift`: `InboxTriageView` is the middle column while `section == .inbox` (wired in
`NoteListView`), because one inbox note made that column a list of one. Capture field on top,
then the open non-subtask lines with per-row actions and a menu; `TaskRef.triageID`
("path#lineIndex") is the selection id, since `TaskRef` identity shifts as lines move. Single
keys are guarded by `@FocusState` on the capture field so typing is never intercepted.
`AppModel.deleteTask` and `makeNote(from:kind:)` were added for it. The third column is
`InboxFileItView` (build 67): the selected line plus active projects and areas as click and
drop targets, sharing `AppModel.inboxSelection` with the middle column; `InboxItems` holds the
lookups so the two columns cannot drift apart. Goals are not destinations by choice. Whether the third column shows the note is an explicit `AppModel.inboxShowsNote`, not
"is a note selected": entering the section or picking a line resets it, so a note opened
elsewhere (or one just made from a line, which `createNote` selects) cannot take the column
over (build 69).

## All actions and hand-arranged lists (build 70)

`AllActionsView` (sidebar `.allActions`): every `index.openTasks()` grouped by note in
`model.notes` order, filtered by All / With a date / No date / Next actions.
Ordering: `Note.sortOrder` reads `order:` from frontmatter and `Note.byArrangedOrder` sorts
arranged notes first (then by title); `Vault.notes(kind:)` uses it, so the sidebar list, the
Inbox destinations and everything else agree. `AppModel.reorder(_:from:to:)` renumbers in tens
and writes `order:` into each note whose position changed; `NoteListView`'s `ForEach` carries
`.onMove`.

## Sub-areas (build 73)

An area note can carry `parent: <area title>`; `NoteIndex.parentArea(of:)`, `subAreas(of:)`,
`areaTree()` (→ `AreaBranch`) and `areasInFamilyOrder()` are the only places that resolve it.
One level only: an area whose own parent resolves is never a parent, which also keeps a pair
pointing at each other from dropping out of the list. `NoteListView` draws the Areas list flat
but two-deep (`visibleNotes`, indent from `parentArea`, a chevron writing to `foldedAreas`), and
`onMove` is mapped onto the row's family by `move(_:from:to:)`, so `AppModel.reorder` now also
takes an explicit `[Note]`. `AppModel.setParent` writes/removes the line and lifts the new
parent's own parent. `AreaParentOptions` (ContentView) holds the choices and is used by
`AreaParentMenu` (right-click a row) and `AreaParentChip` (the "Part of…" button in the
note header, build 74 — the context menu alone was unfindable); both take the model as a
parameter because context-menu content is built outside the row's hierarchy. The Inbox
destinations, the task "Move to" menu and `linkMap()` all use family order.


## Renaming notes (build 77)

`Vault.rename(_:to:)` writes `title:`, renames the file in the same folder (refusing a name in
use) and calls `Note.headingRenamed` for the first `# Heading`. Links are the caller's job:
`Note.retargeting(_:to:)` (Core, `Model/NoteRename.swift`) rewrites `goal`/`area`/`parent`/
`related` and `[[wikilinks]]` and returns nil when a note never mentioned the old name, so
`AppModel.renameNote` only saves the files that changed. Reached from the note row's context
menu (`NoteListView`, an `.alert` with a TextField — not an inline field, which would take the
row's click) and a toolbar button in `NoteEditorView`. Inbox and daily notes are excluded.

## Recent and the daily notes list (build 78)

`SidebarSection.recent` lists `AppModel.recentNotes`: `selectedNotePath`'s `didSet` pushes the
path onto `recentNotePaths` (newest first, 40 kept, in UserDefaults under `recentNotePaths`),
and `recentNotes` drops the ones whose file is gone. `notes(in:)` returns them in that order,
so the ordinary note list draws it. `CalendarMode.notes` adds a fourth Calendar view,
`DailyNotesListView`, over `index.dailyNotes` with its own `.searchable`; `DailyNoteRow` takes
`preview: true` there to show the first line of prose.

## Nested File it column (build 79)

`InboxFileItView` groups its destinations: `InboxItems.projects` and `InboxItems.areaBranches`
(the active part of `index.areaTree()`) under coloured headings, with `AreaDestinationGroup`
drawing an area's sub-areas indented beneath it — a rail overlay plus a per-row tick, and a
chevron writing to the view's `foldedAreas`. The chevron sits beside `DestinationRow`, never
inside it: the row is itself a Button. `DestinationRow` no longer indents itself; it tints a
sub-area's card instead.

## Deleted notes (build 80)

`Vault.trash` no longer uses `trashItem`: on iOS that fails and it fell through to
`removeItem`, so a delete on the phone was permanent and iCloud carried it to the Mac.
`Core/Vault/DeletedNotes.swift` moves the file into `.ams-para/Deleted/` instead, stamped
`deleted:` and `deleted-from:` in its frontmatter (nothing scans that folder, so it never
syncs), and offers `deletedNotes()`, `restore` (back to `deleted-from`, or "(restored)"
beside it), `purge` and `purgeDeleted(olderThan:)`. `AppModel` keeps `deletedNotes`
refreshed from `reload()`, runs `purgeOldDeleted()` (30 days) at launch and on open, and
`DeletedView` is the sidebar section.

## Map export and a navigable Help (build 81)

`MapExport` (App) renders `MapCanvas` at zoom 1 through `ImageRenderer` — the canvas takes no
environment object, so it renders off screen as is — for PNG (`nsImage`/`uiImage`) and PDF
(`render { size, draw in }` into a `CGContext(consumer:mediaBox:)`); `LinkMap.outline()` (Core)
is the text version. macOS saves through `NSSavePanel`, iOS through a `ShareSheet`
(`UIActivityViewController`) presented by MapView's only `.sheet`.

`HelpDocument` no longer renders one scroll: `HelpParts` splits a bundled document at its `##`
headings into `HelpSection`s drawn as `DisclosureGroup`s, `###` parses to `.subheading`, and a
search field filters the sections (a match forces them open). `Docs/HowItWorks.md` is written
for that shape — one subject per `##`, `###` inside the long ones.

## Dragging on the Map (build 82)

Boxes are `.draggable` and `.dropDestination(for: TaskTransfer.self)`; `MapCanvas.onDrop`
hands the pair to `MapView.link(_:onto:)`, which is the only place the rules live (project→area
`setArea`, project/area/goal→goal `setGoal`, area→area `setParent`, task chip→project/area
`moveTask`). Rather than a second UTType, `TaskTransfer` gained `isNote: Bool?`: a whole note
drags as one, and `AppModel.task(for:)` returns nil for those, so every existing task drop
target ignores them. `MapCanvas` keeps `targetedID` for the outline. The tap gesture and the
drag live on the same wrapper, which is fine here because the tap is ours, not a List's.

## Hand-placed map boxes (build 83)

`Note.mapPosition` reads `map: x,y` (unzoomed points, top left). `MapLayout.init` takes
`pinned: [String: CGPoint]` (`AppModel.pinnedMapPositions`) and overrides the computed frame of
any node whose `note.relativePath` is in it — after the automatic pass, so unpinned boxes keep
their places and the edges, drawn from the final frames, follow. `size` is the maximum
`maxX`/`maxY` rather than the column walk, or a parked box could fall outside the scroll area.
`MapNodeBox` is its own view because a live drag needs `@GestureState`: while `arranging` it
carries a `DragGesture` and a context menu, otherwise the `.draggable`/`.dropDestination` pair
from build 82 — an `if`, never both at once, so one gesture never means two things.
`AppModel.setMapPosition`/`clearMapPositions` write and remove the line. Build 84 marks
boxes for a group move: `MapView.marked` (node ids) is passed to `MapCanvas` as a binding, a
tap toggles membership while arranging, and the live offset moved out of `MapNodeBox` into
`MapCanvas` (`movingIDs` + `liveShift`) because one drag has to shift every marked box by the
same amount; `onMove` therefore hands back an array of (node, point). Build 85 adds a
rubber band: a `DragGesture` on the Canvas (gated by `including:` to macOS while arranging —
on iOS that drag scrolls the map) fills `band`, and on end unions the intersecting items into
`marked`, so sweeping and tapping compose.

## Templates and snippets (build 88)

`Core/Vault/Snippets.swift`: `Snippets.parse` splits `Templates/Snippets.md` at its `##`
headings into `Snippet`s (prose above the first heading is the file's own explanation),
`filled(_:answers:today:)` substitutes `{{date}}/{{today}}/{{tomorrow}}/{{week}}` itself and
asks for the rest through `Snippet.questions`; an unanswered placeholder is left in place
rather than emptied. The same file adds `Vault.templateNames/templateText(named:)/
saveTemplate`. `Templates.snippets` ships six blocks and is written by `bootstrap`.
App: `SidebarSection.templates` → `TemplatesView` (list) + `TemplateEditorView` (plain
TextEditor, ⌘S), sharing `AppModel.templateSelection`; `AppModel.snippets` is refreshed from
`reload()`, and the note's add-task bar has a Snippet menu that opens `SnippetSheet` when the
block has questions and otherwise inserts straight away through `AppModel.insert`.
Build 90: a template's own `type:` line says what it makes (`Vault.templates()` →
`TemplateFile`), so a kind can have several and `createNote(kind:title:extraFrontmatter:
template:)` takes the chosen one; `TemplateFile.defaultName(for:)` is the one used otherwise.
`TemplatesView` groups by kind in the kind's tint with folds, and has new/rename/delete.
`PhoneRoute.template` pushes the editor on the phone, where tapping a template did nothing.
Build 92: `TemplateEditorView` uses `MarkdownSyntaxEditor`, not a plain SwiftUI `TextEditor` —
the latter rendered the file in that column but never took a keystroke on macOS — and it saves
on a debounce as well as on ⌘S, on switching template and on disappearing.
Build 93: the groups are plain `Section`s with a fold button in the header (DisclosureGroups
inside a List drew their rows over each other); `NewTemplateSheet` replaced an `.alert`,
because a macOS alert silently drops everything that is not a TextField and the "makes a"
picker never appeared, so every new template came out a project; and
`currentVaultSignature()` includes the Templates folder and its files, or a template edited
on the other device is never noticed.

## Files iCloud has not sent yet (build 95)

A file written on the Mac reaches the iPhone as a hidden `.Name.md.icloud` stub until something
asks for it; every listing here skips hidden files or filters on `.md`, so it was invisible —
which is why a new template (and, unreported, a new note) never turned up on the phone.
`Core/Vault/CloudFiles.swift`: `realName(ofPlaceholder:)`, `placeholderURL(for:)`, `exists(_:)`
(a placeholder counts as the file being there), `isMissing`, `startDownload`, and
`Vault.downloadCloudFiles()` which walks the vault (skipping `.ams-para`) and asks for
everything missing, returning the relative paths. `AppModel.fetchCloudFiles` runs it at launch,
on `openVault` and from the 10 s poll at most once a minute; `templatesFromCloud` feeds the
"coming from iCloud" rows in `TemplatesView`. Every decision to *write* a file — `bootstrap`,
`createNote`, `rename`, `archive`, daily/weekly notes, `createTemplate`/`renameTemplate` — uses
`CloudFiles.exists`, or a note still on its way would be replaced by a fresh empty one and the
two would collide in iCloud; `loadNote` throws `VaultError.notDownloadedYet` for a placeholder.

## Multi-note writes and restore (build 99)

Hardening, part one: everything that writes more than one file goes through
`Core/Vault/VaultWrites.swift`, where the order and the failure handling live and can be
tested. `Vault.saveEach(_:change:)` applies one change to many notes and, on
`modifiedOnDisk`, re-reads that note and applies the change again before giving up;
`MultiSaveResult.failed` is what could not be written. `Vault.move(task:from:to:)` writes the
**target first** — a failure then means the task is in both notes, never in neither — and
reports `leftInSource`. `Vault.rename(_:to:updating:)` renames the note first (a throw leaves
every link untouched) and returns `staleLinks`, the notes that still name the old title.
`VaultError.taskNotFound` is new. `AppModel.moveTask/makeNote(from:)/renameNote/reorder` use
them and now *say* when something did not happen: `makeNote` creates the note before removing
the line, and `renameNote` backs the vault up first. `VaultWriteTests` forces each failure by
writing the file behind the app's back or by putting a folder where the file was.

Part two, backups: `Vault.restore` returns `RestoreResult` (written + failed) and keeps going
past a file it cannot write instead of stopping halfway; `makeBackup` skips a file it cannot
copy (writing their paths to `skipped.txt` beside `signature.txt`) rather than losing the whole
backup, and throws `VaultError.backupFailed` if it copied no note at all. `VaultBackup.date(
fromFolderPart:)` also parses "… 2~reason", the name a second backup in the same minute gets —
those were invisible in the list and so never pruned. `AppModel.backUp` asks iCloud for missing
files first, or the copy is quietly short. `RestoreTests` is the first exercise the way back
has ever had.

## An empty vault is never drawn without saying why (build 100)

What the restore incident actually was: every file in his vault was evicted to iCloud
("Optimize Mac Storage"), `loadNote` failed on all of them, `notes(kind:)` swallowed each one
into `skippedFiles`, and the app drew "No projects yet" — indistinguishable from having lost
the lot. The restore was not the culprit; the silence was.
`notes(kind:)` now sorts a failure into `Vault.notesWaitingForCloud` (when
`CloudFiles.isMissing` or `.notDownloadedYet`, and it asks for the download there and then) or
`skippedFiles` (really damaged). `AppModel` publishes both plus `vaultWarning`, shown by
`VaultWarningBar` (Theme.swift) at the foot of the sidebar and by `emptyList` in place of the
per-section empty state, both with "Ask iCloud again" → `fetchMissingNotes()`.
`SyncReport.warnings` lists the waiting notes too.
Build 101 found the cause underneath it: **a plain `Data(contentsOf:)` fails on a file whose
contents iCloud has not put on the device**, which is why TextEdit opened the very note the app
called unreadable. `CloudFiles.read(_:)` tries the plain read and, on failure, repeats it inside
`NSFileCoordinator().coordinate(readingItemAt:)`, which makes iCloud materialise the file and
waits; `loadNote` goes through it. Also build 101: the whole-vault walk moved into
`CloudFiles.downloadMissing(under:skipping:)` (no `Vault`, so it is Sendable-safe) and
`AppModel.fetchCloudFiles` runs it in a `Task.detached` — done synchronously in `init` since
build 95 it could hold up launch long enough for iOS to kill the app.
Build 102 bounds that: a coordinated read waits for the download, so `notes(kind:)` spends at
most `Vault.cloudFetchesPerLoad` (15) of them per `allNotes()` and reports the rest as waiting,
and `checkForExternalChanges` reloads while anything is waiting — materialising a file does not
change its modification date, so the vault signature would never notice them arriving.
**Build 104 is the real root cause**, found from his diagnostics ("notes: 1", no skipped-files
line — the app had not *failed* to read anything, it had seen nothing): iCloud had every note as
a hidden `.Name.md.icloud` stub and `notes(kind:)` enumerated with `.skipsHiddenFiles`. So the
whole vault was invisible and nothing was even reported. `notes(kind:)` now enumerates without
that option, turns a `.md` stub into its real path, asks for the download, and either fetches it
(within `cloudFetchesPerLoad`) or names it in `notesWaitingForCloud`; other dot-files are still
ignored by name. `loadNote` no longer refuses a path that is only a stub — the coordinated read
is what fetches it. `allNotes`/`notes(kind: .inbox)` use `CloudFiles.exists`.
Build 106 replaces the polling with the system telling us: `App/CloudWatcher.swift` runs an
`NSMetadataQuery` over the vault's path (scopes `…AccessibleUbiquitousExternalDocumentsScope`
+ `…UbiquitousDocumentsScope`, since the vault is a folder the user chose, not the app's own
container), debounced to one report every 2 s, wired to `AppModel.cloudFilesChanged` →
`reload()` while anything is outstanding. The 10 s poll stays as a backstop: a query that never
reports must not leave the app blind. Also build 106: `AppModel.syncNow(force:)` refuses to run
while `notesWaitingForCloud` is not empty — the engine never deletes a reminder whose note it
could not read (`loadedPaths` in `SyncEngine.run`, verified), but syncing half a vault is
needless risk.
**Rule: never let a read failure look like an absence.** A count of what could not be read
belongs in front of the user, not in the diagnostics log.

## The colour of the mode (build 107)

`ModeAccent` (Theme.swift, applied as `.modeAccent(_:)`) puts one even 8.5% tint of
`SidebarSection.tint` over the detail column (the 2pt hairline went in build 113: it read as a
border) — he chose the strength from a preview
artifact and had the top gradient removed in build 110, so change neither without asking; `DetailView.body` applies it to a
`detail` computed property holding the old `if`/`else` chain, so the ViewBuilder rule is kept.
Background and overlay, never a frame or an inset — the third column's intrinsic size is what
builds 30/34 were about. The tint follows the *section*, so it does not flicker as notes are
clicked. The phone has no such column, so `NoteEditorView.phoneBody` carries the same `.modeAccent`
(build 111).

## Work notes, kept apart (build 112)

A second set of notes he asked for: business notes with no planning and no Reminders, and no
sidebar row unless asked for. `Core/Vault/WorkNotes.swift` + `VaultConfig.workFolder` ("Work"):
`workNotes()`, `createWorkNote(title:)` (creates the folder only then, so an unused vault shows
no sign of it), `isWorkPath`, `searchWorkNotes`. **The exclusion is structural, not a filter:**
`allNotes()` walks the PARA folders and the Inbox and never goes there, so Today, All actions,
the Map, the review, the main search and — since `SyncEngine` starts from `allNotes()` — 
Reminders cannot see them, and nothing has to remember to exclude them. `AppModel.note(at:)`
falls back to `workNotes` so `NoteEditorView` and the row actions work unchanged; `save`/
`saveText` update whichever list holds the note; `canArchive` refuses them (archiving would
move one into the visible vault). `SidebarSection.work` is drawn only while
`AppModel.workRevealed`, which is session-only and never stored. In: a 1.2 s long press on the
sidebar's **PARA** header (a Section header, so it takes no click off a row), on the phone the
**Browse** title drawn as a `.principal` toolbar item (inline since build 117) or the
**Build N** row at the foot of Browse, or ⌃⌘W (not ⌥⌘W — macOS closes all
windows with that). The phone pushes the screen from `AppModel.workRequests`, a counter
bumped by every `revealWork()`, **not** from `workRevealed`: a Bool that is only ever set
true changes once, so the second long press did nothing at all (build 122). Anything a
repeatable gesture triggers needs a counter or an explicit request, never a latch. Out: the Hide button in the section's toolbar, or quitting.
Deliberately **not** in `Docs/HowItWorks.md`: the manual is bundled and visible to anyone
looking over his shoulder, so the gestures live in VersionHistory and here only.

## Linking with [[ ]] (build 114)

`Core/Markdown/WikiLinks.swift` holds every decision that is text rather than interface, so it
is testable: `draft(in:cursor:)` (the `[[` being typed — same line only, and a `]]` in between
closes it), `suggestions(for:among:limit:)` (prefix matches first, then contains),
`completing(_:draft:with:)` (returns the new text and where the cursor goes; swallows a `]]`
already after the cursor), `link(at:in:)`, `matches`, `titles`. `WikiLinkTests` covers them.
The editor's part: `MarkdownSyntaxEditor` gained `linkDraft` (out: what is being typed plus the
caret in the editor's coordinates), `completion` (in: the chosen title, written by the text view
itself so undo behaves), `openLink` and `onLinkKey`. **The list never writes into the text and
never takes focus** — it cannot, or typing would break — so the arrow keys, Return and Escape
arrive through `textView(_:doCommandBy:)` on macOS and are forwarded to `NoteEditorView.
handleLinkKey`. `LinkingTextView` (NSTextView subclass) takes ⌘-click only: a plain click must
keep placing the cursor. **iOS has no tap recogniser at all, and must not get one again (build 128).** 114 added a
`UITapGestureRecognizer` with `cancelsTouchesInView = false`, believing that made it yield.
It does not: a `UITextView`'s own single tap is what places the caret, and a second tap
recogniser on the same view makes that tap ambiguous, so the caret only appears on a press and
hold. That is the "long press to edit" he reported and put up with from 114 to 128, and it is
why three attempts at the editor's *layout* (123, 125, 127) never touched it — the fault was a
gesture, not a frame. On the phone, links are followed in Read mode, one tap away in the
add-task bar.
**Build 116, and the rule behind it:** a text view's delegate callbacks can land *inside* a
SwiftUI update, so the coordinator publishes `linkDraft` through a `DispatchQueue.main.async`
and never directly, and an `applying` flag keeps it silent while a chosen title is written in.
Picking a title beachballed the app without it — the same class of bug the model's `afterUpdate`
exists for.
`AppModel.linkableTitles(from:)`/`openWikiLink(_:from:)`/`backlinks(to:)` keep work notes and
ordinary notes from seeing each other in both directions. `NoteEditorView` splits the old mixed
list into **Links to** and **Linked from**.

## Back, Forward, and a link to a note that is not there (build 118)

`AppModel.Visit` (section + path) with `backStack`/`forwardStack` (both `@Published`, so the
buttons enable themselves) and `currentVisit`. `recordVisit` is called from
`selectedNotePath`'s `didSet`, so *every* route to a note is history, not only links; the
section stored is the one already set, because `show(section:notePath:)` sets it a turn
earlier. `expectedVisit` is the one arrival a Back or Forward will cause and is skipped once,
which is what keeps `goBack` from pushing what it just left straight back on. It is armed
**only when the target is not already on screen** and cleared again three `afterUpdate` hops
later (guarded by `expectedVisitToken`, so a second Back does not clear the first's): both
routes into `show` are no-ops when the path is unchanged, so an unconditional guard would
never be cleared and would eat the next genuine visit to that note — an adversarial review
found this before CI did. `goBack`/`goForward` step over notes that are gone (`note(at:)` nil)
*and* over the note already displayed, so a press never consumes a step without moving.
`clearHistory()` runs on `openVault`/`closeVault` (the same relative path is a different note
in another vault) and `hideWork()` calls `forgetWorkVisits()` — hidden has to mean hidden, or
Forward would put a work note back on screen with the section behind it.
Reached from a `ToolbarItemGroup(placement: .navigation)` in `NoteEditorView`'s desk branch,
and from `CommandMenu("Go")` so the shortcut works when no note is open. **⌃⌘← / ⌃⌘→, not the
browsers' ⌘[ / ⌘]:** on his Swedish keyboard those brackets are ⌥8 and ⌥9, so the menu would
advertise a key he does not have — the third time this project has paid for a shortcut chosen
from a US layout (⌥⌘D, ⌥⌘W). The phone is untouched: `PhoneStack` already pushes a route per
note, so the system back arrow is the same thing.

`openWikiLink` no longer only complains: with no match it sets `AppModel.LinkToCreate`
(title, source path, `isWork`) and opens `AppSheet.noteFromLink` — both **inside
`afterUpdate`**, since the ⌘-click lands in the text view's delegate (build 116's rule).
`NoteFromLinkSheet` (in `NewNoteSheet.swift`, so no new file and no `project.yml` change)
asks only for the kind; the title is the link's words and is not editable, or the link would
still point at nothing. `createNoteFromLink` routes a work note's link to `createWorkNote`.
`NoteEditorView.missingLinks(from:)` + `MissingLinksList` draw them as **Not made yet** under
Linked notes — the context of build 74: an action only reachable by a modifier-click is an
action nobody finds. `AppModel.open(reference:)` (the Preview's links) goes through
`openWikiLink` too; it used to make a Resource silently, so Preview and the editor answered
the same link differently.
**Neither offers to create while `notesWaitingForCloud` is not empty**: "there is no such
note" is not something this app may say with half a vault unread (build 100's rule), and
saying it would make a duplicate of a note already in iCloud.
`WikiLinks.target(of:)` (Core) is new: `[[Note|shown as this]]` and `[[Note#a heading]]` name
"Note". `matches(in:)` goes through it, so clicking, backlinks and **Not made yet** all agree
with the preview, which had always parsed them that way.

## New note asks one thing (build 119)

He called the old sheet "long and a bit crude" and picked this shape from a preview artifact
before anything was built. `NewNoteSheet` is now: name field first with `@FocusState`
(`DispatchQueue.main.async { nameFocused = true }` in `onAppear` — focus does not always take
in the appearing turn), the four kinds as `KindChoice` buttons in `ParaKind.tint` rather than
a segmented Picker, one line of `hint`, then `settingsFields`. **Build 121 removed the fold**:
119 put those fields behind a "More" button and he asked for everything on screen at once, so
they sit under a `Divider()` with no toggle — the win was the *order* (name first) and the
one-line hint, not the hiding. `hasMoreToOffer` now only decides whether there is a divider at
all, and `pick(_:)` clears `servesGoal`/`parentArea`/`target` on a change of kind so a choice
never follows you across.
New: a project can set `goal:` at creation. `ParaKind.singularName` (extension in
`NewNoteSheet.swift`) exists because `displayName` is the plural name of the list a note lands
in — wrong for the one note being made, which is how the old sheet came to label a new project
"Projects".

## Becoming PARAGON (build 129 on)

He is renaming the app from AMS PARA to PARAGON. Agreed with him from a brief he approved
(https://claude.ai/code/artifact/0e196e75-3832-4398-9c98-80240d90c64e), in four phases, each
one its own build so a red light means one thing:

1. **The icon** (build 129, done). A white frame outside the gold one with a small star on its
   top edge. `Tools/make_icon.py` draws the whole icon and is the only place it is drawn — the
   gold frame of build 111 was added by a one-off script and never written back, so from 111 to
   129 the committed script did not reproduce what shipped and this change had to start by
   measuring the PNG. Never draw the icon anywhere but that file.
2. **The name everywhere he sees it** (build 130, done). Also `PRODUCT_NAME: PARAGON` on the
   app target — on the Mac, Finder and the Dock read the bundle's *file* name, so
   `CFBundleDisplayName` alone leaves "AMSPara" on screen; the target and folder are
   untouched, and `PRODUCT_BUNDLE_IDENTIFIER` is now pinned explicitly so it can never
   follow a target rename. `CFBundleDisplayName`/`CFBundleName`, every visible
   string in the app, the permission prompts, the share extension's name, `Docs/HowItWorks.md`,
   `Docs/VersionHistory.md`, `README.md`, `TESTFLIGHT.md`, this file, the Example Vault.
3. **The name inside the code** (build 131, done). `App/AMSPara/` → `App/Paragon/`,
   `App/AMSParaShare/` → `App/ParagonShare/`, `App/Config/*` and the entitlements files with
   them, `AMSParaCore` → `ParagonCore` (and its tests), the two targets, the scheme, the
   project (`Paragon.xcodeproj`), `AMSParaApp` → `ParagonApp`, both workflows, and the debug
   `AMSPARA_OPEN_NOTE` → `PARAGON_OPEN_NOTE`. One substitution did nearly all of it, because
   `AMSParaCore`/`AMSParaShare`/`AMSParaApp` all fall out of `AMSPara` → `Paragon`; the bundle
   ids were held back behind a sentinel so they could not be caught by it. The diagnostics
   filter that picks our own stack frames is now case-insensitive on "paragon": the app's
   module is `PARAGON` (from `PRODUCT_NAME`) and the package's is `ParagonCore`, so a single
   spelling would have quietly matched half of them.
4. **Outside the app** (done 11 September 2026, by him, from a runbook:
   https://claude.ai/code/artifact/b6bd5eea-34c4-4d39-acb1-0b90e762d486). The App Store Connect
   name, the iCloud vault folder, and the GitHub repository — `AMS-PARA` → **`AMS-PARAGON`**,
   keeping the AMS. I expected the rename to end that session's access; it did not, because
   GitHub forwards the old address and the clone's remote still resolved.

**The rebrand is finished.** Nothing is left outstanding.

**Four identifiers deliberately keep the old name.** `com.schabbauer.AMSPara` (a new bundle id
is a different app: new TestFlight, fresh install, his settings gone), `ams-para:^t…` (the
marker in every mirrored reminder's notes — rename it and every existing reminder is orphaned),
`.ams-para` (the vault's state folder: sync state, backups, deleted notes), the Application
Support fallback folder in `AppModel.outboxURL`, and `amspara://`
(the capture link his Shortcuts use; `paragon://` can be *added* beside it, never instead).
The App Group `group.com.schabbauer.amspara` likewise: it is enabled in the developer portal
under that name.

## The aspiration chain (build 132 on)

He brought a spec from another session — "The Aspiration Chain"
(https://claude.ai/code/artifact/644b6073-0301-4c86-881c-a77a1ad78775): Area → Aspiration →
Goal → Project → Task, with rules the app should enforce and a review cadence per level.
**Most of it was already built**, under other names: `horizon: life` is the aspiration,
a dated goal pointing at it with `goal:` is the spec's Goal (the code already called it a
"life goal" with dated subgoals), `measure:` is the spec's criterion, and the review already
flagged `noNextAction`, `nothingServing`, `pastDue`, `pastTarget`.

**Deliberately not adopted:** the spec roots the whole chain on the Area. PARAGON roots on
goals, with areas and projects pointing up at them via `area:`/`goal:`. Both express the same
links — the difference is only what the Map hangs from — so adopting the spec's shape would
mean reworking the Map and re-filing his notes to connect nothing new. Agreed with him to keep
PARAGON's shape and take the spec's questions and checks.

Build 132 closed the gaps that were real, all pure computation over existing frontmatter:
`ProjectHealth.Flag.noGoal`, `.dueAfterGoal` (project `due:` later than its goal's `target:`),
and `GoalHealth.Flag.noProjectYet` (only an area serves it). That last one is **dated goals
only**: a life goal held by an area is the aspiration sitting inside its area, which is the
shape the model wants — `GoalTests.testReviewListsGoalsAttentionFirst` caught me flagging it
as a fault in build 132's first push.

**`noGoal` is not an alarm, by design.** `ProjectHealth.needsAttention` ignores it, the same
way it ignores `.onHold`, and `ReviewReport.projectsWithoutGoal` gathers them into one
"Hobby or homeless?" section instead. In a vault written before the chain, `noGoal` is true of
nearly every project, and a review where everything is red says nothing. Any future check that
would be true of most of his existing notes needs the same treatment.

Build 132 also added `AppModel.setDeadline` and `ProjectDeadlineChip` in the note header:
`due:` on a project was read by the review but **nothing in the app had ever written it**, so
the `pastDue` flag had never once been able to fire and `dueAfterGoal` would have been born
dead. Worth checking, when adding a rule, that something can actually produce the data it reads.

**Build 133 renamed the `horizon: life` label to "Aspiration"** (it was "Life goal"), and the
dated goal's picker to "Serves aspiration". His reason, and it is a good one: PARAGON is PARA
plus aspiration, goal and north star, so the app was using a different word for the idea in its
own name — which is exactly what confused him when he first met the New Note sheet. **The stored
value is still `horizon: life`**: only `GoalHorizon.label` and the picker title changed, so no
vault touched and no migration. The star on the icon reads as the north star, unplanned but apt.

**Build 134 gave an area a `goal:` it can actually set** — `AreaGoalChip`/`AreaGoalMenu`/
`AreaGoalOptions` in ContentView, mirroring the `AreaParent*` trio, wired into the note header
and the list's context menu. `setGoal` had existed since the Map work but **`MapView` was its
only caller**, so the area half of "No project or area serves this" was unreachable in practice.
He spotted it from the chain diagram — "areas have no real goals attached" — and he was right.
That is now twice in one day that a rule read a line nothing could write (the other was `due:`
on a project, build 132). **When adding a check, confirm something can produce the data it reads.**

**Build 135:** a row in the review opens its note **without leaving `.review`**. `DetailView`
falls through to `NoteEditorView` for any section that is not calendar/templates/inbox, so
selecting a note while the section stays `.review` leaves the review list in the middle column
and puts the note in the third — the review can be worked straight down. On the phone the same
call pushes one screen and the system back arrow returns to the list. Build 134's buttons used
`show(section: .kind(.project), …)`, which threw the review away; he asked for a back arrow,
but not leaving is better than going back. **A row inside a working screen should select, not
navigate away.**

**Build 136: a graphical `DatePicker` alone is unusable for a date years out.** He was asked
to set a project deadline to 2031-12-01 and counted about forty presses. `ProjectDeadlineChip`
now leads with a `TextField` (the app's existing `YYYY-MM-DD` convention, as in the New Note
sheet's target date and the add-task bar's `>2026-09-10`); the calendar stays below and writes
into the field, and **Set reads the field, not the calendar**. **Build 137** made it one component at his suggestion: `DateChoiceView` in `Views/Theme.swift`
(`current`, optional `clearTitle`, optional `cancel`, and one `choose: (DateOnly?) -> Void`
where nil means cleared). `ProjectDeadlineChip` and `TaskDatePicker` are both thin wrappers
around it now. `cancel` exists because `TaskDatePicker` is presented as a `.sheet` in
`InboxView` and a `.popover` in `NoteEditorView`, and a sheet cannot be dismissed by clicking
away. **Left alone deliberately:** the Time Blocks pickers (a day *and* a time, and never more
than 60 days out) and the New Note sheet's target field, which he designed with me and which
is one short row per line.

**Build 138: an `HStack` in a column too narrow does not overflow — it squeezes.** Every child
is proposed a smaller and smaller width until the `Text` inside wraps, which is how the weekly
review drew "2031-08-01" over three lines and "projects" as "project s" in his screenshot.
`WrappingHStack` (a `Layout` in `Views/Theme.swift`) measures children with `.unspecified`, so
each keeps its natural width and only whole items move to the next line. **Never put
`.fixedSize()` on it** — that proposes a nil width and turns it back into one endless row; the
modifier that matters on the container is `.lineLimit(1)`, which stops a child's own text from
breaking mid-word. Titles in those rows are `.lineLimit(2)`.

**Build 140.** "Hobby or homeless?" was my own wordplay, taken from the Cowork spec, and he
asked what it meant — exactly what the language rule at the top of this file forbids. The
section is **"Projects with no goal"**. More important, the heading asked a question the app
could not answer: a project had no way to be given a `goal:` except the Map drag. `AreaGoal*`
is now `NoteGoal*` and serves both kinds, ordering the menu by kind (a project delivers a dated
goal, so those first; an area holds an aspiration, so those first), wired into the note header
and the list's context menu for `.project` as well as `.area`. **Third time a rule read a line
nothing convenient could write.** When a screen asks a question, check the answer is one click
away from where it is asked.

**Build 141: roll-up progress.** `Core/Vault/GoalProgress.swift` — `GoalProgress`
(projectsDone/Total, tasksDone/Total, `fraction`) and `NoteIndex.progress(of:)`, pure
computation over frontmatter, nothing written. The decisions worth keeping:

- **One share per project, not one per task.** A goal's figure is the *average* of its
  projects' shares, so a project with forty small tasks cannot drown one with three big ones.
  A finished project is 1; a running one is done/total top-level tasks; a project with no
  tasks yet is 0 (it is a project that has not started, which is a real answer).
- **Areas are excluded.** An area never finishes, so counting one would hold its goal below
  full for ever. This is the same reasoning as `noProjectYet`.
- **`fraction` is `nil`, not 0, when there is nothing to measure**, and `GoalProgressBar`
  draws nothing at all in that case. An empty bar would say "no progress"; the truth is "no
  projects yet". Same family as build 100's rule — never let an absence look like a zero.
- **`percent` never rounds to 100 below 1.0, nor to 0 above 0.** Both read as an answer.
- **A goal is finished by its `status:`, not by its boxes** (`Note.isFinishedProject`): he
  marks a project done from the review, and the last task is often one he decided not to do.
- **`Note.declaredKind` reads `type:` and falls back to the folder.** Archiving moves the
  file, so an archived project's `kind` is `.archive` and it would silently drop out of its
  goal's totals. `DeletedNotes` already used this trick; it is now shared. An archived note
  that was *not* marked done is skipped altogether: it was dropped, not left undone, and
  counting it as 0 would hold its goal down for ever.
- `NoteIndex.linked(to:)` is the whole set pointing at a goal, archived and finished
  included; `serving(_:)` is now the live subset of it. That fixed a real fault:
  a goal whose projects were all marked done read as **"No project or area serves this"**,
  because `serving` filtered done projects out and `nothingServing` saw an empty list.
- Shown by `GoalProgressBar` (Theme.swift) in three places, so they cannot drift: the
  `GoalHealthRow` in the review (inside the build 138 `WrappingHStack`, as one item so the
  bar and its per cent wrap together), `NoteRow` in the Goals list (the row holds one note
  and cannot roll up by itself, so `goalProgress` is passed in), and `GoalDashboardView`,
  which also now lists the finished projects, struck through.

**Build 142: one symbol in two states, and the add-a-task bar.** Two things, and the first is
a rule for the whole app.

- **`StateToggle` (Theme.swift): a control shows the state you are in, never the state you
  would get.** The mode button swapped its own symbol — an eye while editing, a pencil while
  reading — and an eye reads just as naturally as "you are reading now". His words: *"Det
  måste vara så man förstår vad som är valt."* It is always a pencil now; **on** is the tint
  at 20% fill with a solid tinted border, **off** is grey with a **dashed** border (his idea,
  and it matches what dashed already means on the Map: loose, not connected). Used by the
  phone's bar and by the Mac's toolbar, which lost its segmented Picker. **Spread this to the
  other two-state controls** (Hide finished, the Calendar's Schedule/Note switch, the Map's
  Arrange) when next in that code.
- **Split is gone**, at his request. `EditorMode` is `edit`/`preview` only; a stored
  `"split"` no longer decodes and `@AppStorage` falls back to `.edit`, so nothing to migrate.
- **The add-a-task field's placeholder is "Add a task…".** It was 84 characters of syntax,
  which fits nowhere on a phone (cut at "for a") and disappears the moment he types. That
  moved into `TaskSyntaxButton`/`TaskSyntaxHelp` behind a **ⓘ** — its own `.popover` on its
  own button, never a second `.sheet` on the note screen (build 44). On the phone **Add** is
  an arrow that only takes colour when there is text, and **Snippet** is a symbol, so the
  field gets about twice the width. He picked this from a preview artifact
  (https://claude.ai/code/artifact/41ce5a0b-ee32-459a-8c90-1b20fc5e9879) — the third time a
  preview before any code has been the cheap way to get a layout right.

**A naming rule earned twice in two days.** I offered "Building blocks" for a sidebar group
holding Templates, Snippets and Tags. He rejected it *for the right reason*: "tags är ju inte
buildingblocks. Det är snarare ett system för att filtrera eller gruppera." A group name has
to be true of every member, or it is the same fault as "Hobby or homeless?" wearing a plainer
coat. **"Blocks" alone is also out** — the sidebar already has **Time Blocks**.

**Build 143: Tools.** A folding sidebar group (`SidebarSection.tools`, `@AppStorage
"toolsFolded"`) holding **Templates**, **Snippets** and **Tags** — the three things you use
*on* notes rather than notes themselves. He named it after rejecting "Building blocks"; note
also that plain **"Blocks" is out** because **Time Blocks** already exists.
- `Core/Vault/Tags.swift`: `TagUse` (tag + note/open/finished counts) and `NoteIndex.tagUses()`,
  which counts in **one pass over the notes** — one pass per tag would be 60 × 400 scans every
  time the list is drawn. `notesTagged(_:)` is frontmatter tags only and `tasksTagged(_:)` is
  the tasks; the old `notes(tagged:)` mixed the two, which is why it could not back a readable
  list. `NoteIndex.normalized(_:)` is the one place a tag is lower-cased and de-hashed.
- `TagsView` is **one screen, not two columns**: a tag opens in place. A tag detail in a third
  column would have needed a new `PhoneRoute` and a second layout to keep working. Plain
  `List`, every row a `Button`, **nothing tagged for selection** — one note can carry two tags
  and would appear twice, which is the builds 71–74 fault exactly. Folds are Section headers
  with a button, never `DisclosureGroup` (build 93). Rows call
  `show(section: .tags, notePath:)` so the list stays put (build 135).
- `SnippetsView` needed no selection: the file *is* the thing, so `DetailView` shows
  `TemplateEditorView(name: Snippets.fileName)` whenever the section is `.snippets`, and the
  phone gets a `NavigationLink` to `PhoneRoute.template` instead (that enum is inside
  `#if os(iOS)`, so the link is too).
- `Snippet` carries `lines: [String]`, not a `body` — I assumed otherwise and caught it before
  pushing.

**The Rules line "adding a source file needs a `project.yml` change" is stale for App files.**
Since build 41 both app targets are `type: syncedFolder`; `DayScheduleView.swift`,
`InboxView.swift` and now `TagsView.swift` were all added with no project change. It still
holds for anything that is not a source file in those folders (Docs resources, Info.plist keys).

**Build 144: `NoteTagsChip`, and the fourth time this has happened.** Build 143 shipped a Tags
screen over a line **nothing in the app could write** — `tags:` had to be typed by hand. That
is the same fault as `due:` (132), an area's `goal:` (134) and a project's `goal:` (140). The
rule has earned a stronger form: **before shipping a screen that reads a field, find the
control that writes it. If there isn't one, that control is part of the same build.**
- `AppModel.setTags(_:on:)`/`toggleTag(_:on:)`/`cleanTag(_:)`. `cleanTag` strips a leading `#`
  and turns spaces into hyphens, because a tag with a space could never be written as `#tag`
  on a task line — the two ways of writing a tag have to stay interchangeable.
- An empty list writes `tags:` rather than removing the key: the templates ship that line and
  a note should not silently lose it.
- `NoteTagsChip` (TagsView.swift) reads `live` back out of the model each time rather than
  trusting the `note` it was handed: a toggle saves and reloads, so the passed copy is one
  behind. A popover, not a Menu — a Menu cannot hold the TextField for a new tag, the same
  limit that made build 93 replace an alert with a sheet.
- He asked for **all three ways to stay** and to be written down together: the button, the
  `tags:` line (inline or indented — the button rewrites to inline, and that is stated), and
  `#tag` on a task. `Docs/HowItWorks.md` has them in one place under **Tools**.

**Build 145: a tag can be renamed, deleted, and made before it is used.** All three were
missing and he asked for all three in one message.
- `Note.changingTag(_:to:)` (Core, Tags.swift) returns nil when the note never carried the tag,
  so `Vault.changeTag` writes only what really changed — the same shape as build 77's
  `retargeting(_:to:)`, and it goes through `saveEach`, so an outside edit is re-applied and a
  note that still cannot be written is **named**, never swallowed (build 99).
- **The body is rewritten with the task parser's own pattern**, `(?<!\S)#tag(?![\p{L}\p{N}_/\-])`,
  case-insensitive. That is the only way rename and parse can agree: `#travelling` is not
  `#travel`, and `## Heading` is not a tag. Removing a tag calls `tidySpaces`, which keeps the
  indent and squeezes the gap the tag left.
- **`#next` is refused.** It is `Note.nextActionTag`; renaming it would silently break every
  next action. Any tag the app gives meaning to needs the same guard.
- **Work notes are deliberately not touched** by a rename: `allNotes()` excludes them by
  design (build 112) and the Tags screen never shows them, so including them here would be the
  one place that leaks.
- **A tag with nothing on it has nowhere to live in a markdown vault**, so `Vault.knownTags()`
  keeps the made-but-unused ones in `.ams-para/tags.json`. `AppModel.allTagNames` and
  `tagUses()` merge them in, and `TagUse.isUnused` draws them as "not used yet". A remembered
  tag is *not* forgotten when it comes into use — it stays offered, which is what you want from
  a tag you deliberately made.
- `TagsView` gained the make-bar (`.safeAreaInset(edge: .top)`), a **Rename…**/**Delete…**
  context menu, and the `.alert` + `.confirmationDialog` pair copied from `TemplatesView` —
  a macOS alert silently drops everything that is not a TextField (build 93).

**Build 146.** Two things, one of them my own fault.
- **The Calendar day view's month grid is off by default** (`@AppStorage "showsMonthGrid"`),
  toggled by a `StateToggle` in the day header — the first place build 142's control has been
  spread to, and the remaining candidates are unchanged (Hide finished, the Calendar's
  Schedule/Note switch, the Map's Arrange). Thirty-one dated cells took more of the column
  than the day itself. The header's two texts gained `.lineLimit(2)` and the arrow group
  `.fixedSize()` at the same time: the row gained a button, and build 138 is about what a
  narrow column does to an HStack.
- **`cleanTag` only stripped a *leading* `#`** (my build 144 code), so "Claude #Productivity"
  typed into a tag field became the single tag `Claude-#Productivity` — which the task
  parser's own pattern can never match, so it could never be written on a task line. It now
  replaces **every** `#` with a space, joins the words with hyphens, squeezes repeated
  hyphens and trims them off the ends. He found it in a screenshot, not I.
  **`cleanTag` lives in the App target and has no tests.** Anything that decides the shape of
  a stored value belongs in Core where it can be tested — move it there next time it changes.

## Plan the day (build 147)

His own idea, drawn as a sketch and then chosen from a preview artifact
(https://claude.ai/code/artifact/82be810e-11ca-4c7b-8fc2-3863ff07cfbd): three parts side by
side — the day's Calendar, his own blocks, the day's actions. He picked shape **B** (calendar
and blocks on a shared hour ruler, actions a plain list) and **the daily note** as the home.

**A plan block is deliberately not a Time Block.** Build 35's Time Blocks *are* events in Apple
Calendar; a plan block never leaves PARAGON. Both are kept, side by side in the Time Blocks
section, precisely so the difference stays visible — swapping one silently for the other was
the thing to avoid.

- `Core/Vault/DayPlan.swift`: `PlanBlock` (minutes since midnight, a title, and an `index` that
  is its position in the sorted plan) and `DayPlan`, which owns the `## Plan` section of a daily
  note. **Liberal in what it reads** (any dash, spaces or not, `*` bullets, one-digit hours),
  **strict in what it writes** (`- 09:30-11:00 Title`). The section is created above `## Tasks`
  when missing and nothing else in the note is touched.
- **The dashes in `lineRegex` are written as themselves.** A Swift raw string passes a
  backslash-u escape through as plain characters, so `[-\u{2013}\u{2014}]` would have been a
  character class of backslashes and braces. Caught while writing, not by CI.
- `DayPlanTests` covers reading, writing, the section being made, emptying it, and the
  round trip. That is the answer to build 146's note: **anything that decides the shape of a
  stored value goes in Core.**
- `AppModel.planBlocks(for:)` never writes — asking for a plan must not make a daily note.
  `savePlan(_:for:)` is the only writer and creates the note when a first block is added.
- `PlannerView`: an hour ruler, two lanes, an actions list. Items are placed with `.offset`
  inside a `ZStack(alignment: .topLeading)`, **never `.position`** (build 85). `PlacedEvent` is
  a struct because a `ForEach` id is a key path and a key path cannot address a tuple member
  (build 61). One `.sheet` for both a new block and an existing one (build 44).
- **macOS gets a `Window` scene**, `ParagonApp.plannerWindowID`, opened by ⇧⌘P from **Go** and
  from the Time Blocks section. Two things went wrong in one edit and are worth remembering:
  a scene placed between the `WindowGroup` and its `.commands` breaks the modifier chain, so
  extra scenes belong beside `MenuBarExtra` at the end; and `@Environment(\.openWindow)` is
  read by a **View**, not by the `App` struct — hence `PlannerMenuButton`, the same shape as
  `HelpMenuButtons`.
- iOS has no windows: `PhoneRoute.planner` pushes the same view.
- **Not built yet, by choice:** dragging a block to move it in time or to change its length.
  That is the second round; the columns had to work first.

**Build 148: the planner is the section, not a menu item.** He objected, and he was right:
"vi var ju överens om att timeblocks inte ska finnas i kalendern, utan vara i noten… Det
verkar inte alls vara som alternativ B." **The agreed drawing said the Time Blocks row becomes
the planner; build 147 left the old Apple Calendar form as what a click on that row gave you**
and hid the planner behind ⇧⌘P. Nothing was wrong with the planner — he had simply never seen
it. `DetailView` shows `PlannerView` for `.timeBlocks` on the Mac, and on the phone
`NoteListView` does (no third column there); the Apple Calendar blocks keep their form, now
named as such, one button away. Nothing was deleted.
**The rule this earns: when a preview artifact has been agreed, the build has to match it.**
Quietly keeping the old thing as the default is a change to the agreement, not a safe choice.
`CalendarBlocksLink` is a `ViewModifier`, not an `#if` in the middle of a modifier chain —
the same shape that broke the scene list in build 147, and `ToolbarItem(placement:
.topBarTrailing)` does not exist on macOS anyway.

**Build 149: the planner's Actions column is `TaskRow`.** He asked for checkboxes, editing,
scrolling, and to see *what an action serves*. `TaskRow` already carried the first three —
the tick, the rename, the task menu, the date popover — so the hand-rolled button row was
thrown away. **Reach for `TaskRow` for any list of tasks; a new one only repeats work and
drifts.** Its `.draggable` is safe here because this list has no selection of its own
(builds 71–74 were about `List(selection:)`).
`servesLine(for:)` answers the last part: the goal the task's note serves in gold, else the
area in pink. That is the chain the whole app is built on, and a list of actions without it
is just a list. A caption under the heading says what the list *is* ("due today or earlier,
then your next actions").
The phone stacks: `lanesRow` then `actionRows` in **one** `ScrollView`, never two nested
(build 127). `LazyVStack` rather than `List` so the same rows serve both platforms.

**Build 150: the planner is the window, not a window.** He asked whether all three parts could
live in the ordinary app window instead of a floating one, and chose **"A with the floating
window as an extra"** from a preview
(https://claude.ai/code/artifact/c8934eb1-0b1e-46ca-a3e7-4a3a90b2a5ae). So `PlannerView` split
into two halves that also stand alone: `PlannerActionsView` is the middle column
(`NoteListView`, `.timeBlocks`) and `PlannerDayView` is the detail column (`DetailView`,
`.timeBlocks`); `PlannerView` is just the two side by side, for the ⇧⌘P `Window` and for the
phone. Both read **`AppModel.plannerDay`**, not each its own `@State`, or the two columns would
show different days. The old `TimeBlocksView` (Apple Calendar) is one button away, in the
planner's single `.sheet`.
- **The bug this build fixed is a lesson about this file.** `ContentView.swift` holds **two**
  long `if`/`else` chains that both branch on `model.section` and both contain
  `} else if model.section == .snippets {`. Build 148's single-occurrence replacement matched
  the first (in `NoteListView`), so the Mac's detail column never got a `.timeBlocks` branch
  and said "No note open". **Anchor an edit in that file on something that appears once**, and
  read back the line numbers of every match before replacing.
- **Overlapping items share the width.** `place(_:)` sorts spans by start and greedily gives
  each the first lane whose last item has finished; a gap with nothing running closes the group
  off, so an uncrowded hour still gets the full width. The lane count comes out of the group,
  and `GeometryReader` hands the width in — the same rule `DayScheduleView.lanes(for:)` has had
  since build 61.
- `let box = card(…)`, not `let card = card(…)`: a local shadows the method of the same name
  inside its own initial value.
- Removed with it: `plannerWay` in `TimeBlocksView` and the `PhoneRoute.planner` /
  `.calendarBlocks` cases, which nothing reached any more.

**Build 151: one plan block at a time can go into Apple Calendar.** His idea, and a good one:
the two kinds stay apart by default, and he decides per block. Right-click a block → a
**Toggle** in the context menu (a tick, per build 142: the control shows the state you are in),
and the same tick in the block's sheet, because an action only a right-click reveals is an
action nobody finds (build 74).
- **The tie is stored in the event, not in the note.** `PlanBlockLink` (Core, DayPlan.swift)
  writes one line into the event's own notes: `ams-para:planblock <day> <start> <title>`. The
  daily note stays a plain `- 09:30-11:00 Title`, which is the whole point of the feature, and
  there is nowhere on such a line to keep a minted id without changing what the file looks
  like. So **the key is the block's own identity**. It deliberately leaves the *end* time out,
  so making a block longer keeps the tie; `DayPlanTests` pins all of that.
- **Every change through the app rewrites the line and the key together**, which is why
  `AppModel.savePlanBlock(_:on:replacing:inAppleCalendar:)` is one async function rather than a
  save plus a toggle: moving a block changes the key the event is found by, so two separate
  calls would race and the second would look for a key the first had just changed. The event is
  read **before** the line is rewritten, against the block as it still is.
- **A line edited by hand in the note loses the tie, and the event is then left alone** — never
  deleted on a guess. Said out loud in `Docs/HowItWorks.md` and in VersionHistory; build 100's
  rule applies to writes as well as reads.
- `EventKitCalendarStore.timeBlocks(on:)` reads one day **ignoring the visible-calendar
  filter**: a calendar he has hidden must not make a block look absent. `AppModel.
  planBlocksInCalendar` is per day, not `timeBlocks`, which only spans −7 to +60 days while the
  planner can stand on any date.
- Removing a block removes its event: the tick said "this block is also in Apple Calendar", and
  with the block gone there is nothing for the event to be.

Still open, in the order agreed: dragging and resizing a plan block; then Goals and Aspirations
screens if the one review is not enough; then the status vocabulary (reached / missed / dropped), last because it edits his
notes. Also queued: **spread `StateToggle`** to the other two-state controls (Hide finished,
the Calendar's Schedule/Note switch, the Map's Arrange).

## Not built (by choice)

Saved searches. Roadmap stopped there on his request.

