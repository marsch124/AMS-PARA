# AMS PARA – working notes

Memory for anyone (human or Claude) picking this project up. Keep it short and current.

## What this is

macOS/iOS app in the spirit of NotePlan: plain markdown vault organised as
Goals + PARA (Projects, Areas, Resources, Archive), tasks synced two-way with
Apple Reminders, daily/weekly notes, quick capture, full-text search.

Owner: Martin Schabbauer (project manager, part-time retired, Sweden, not a
developer). Communicate in short, friendly, concrete steps. He cannot run
Terminal commands. Since build 56 both apps come from TestFlight. When CI is green, tell him in two
short lines, naming which of the two things is meant (he asked for that, and equally
for no step-by-step lecture): **Run workflow** on GitHub
(`.../actions/workflows/testflight.yml`), then **Update** in Apple's TestFlight app on
the phone and on the Mac. Xcode is no longer part of his routine.

## Layout

- `Core/` – Swift package `AMSParaCore` (models, markdown, vault, sync engine, search, capture). `swift test --package-path Core`.
- `App/AMSPara/` – SwiftUI app (macOS + iOS). `App/AMSParaShare/` – iOS share extension.
- `project.yml` – XcodeGen spec. `AMSPara.xcodeproj/` is committed; CI regenerates it only when `project.yml` changes (keeps his signing Team).
- `Example Vault/` – sample vault incl. Goals, Calendar, Templates.
- `.github/workflows/ci.yml` – macOS runner: package tests, xcodegen, xcodebuild macOS + iOS Simulator.

## Rules

- Branch: `claude/ams-para-reminders-sync-s0ex53` only. No PRs unless asked.
- GitHub repo name stays `AMS-PARA` (access is scoped to it); local folder is "AMS PARA".
- No Swift toolchain in the remote container: verify via CI (`mcp__github__actions_list`, `get_job_logs`).
- Bump `BuildStamp.number` in `App/AMSPara/AppModel.swift` on every push; it shows at the bottom of the sidebar so we know which build he runs.
- Add a section for that build to `Docs/VersionHistory.md` (user-facing wording) on every push. `Docs/HowItWorks.md` is the manual; update it when behaviour changes. Both are bundled (project.yml `Docs` resources) and shown by `HelpView`.
- Build N = CI run N. Adding a source file needs a `project.yml` change so CI regenerates the committed project.

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
Project: `type: syncedFolder` for App/AMSPara and App/AMSParaShare (Xcode 16
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

**Testing the phone layouts on this Mac.** Xcode 26.6 is installed, so the simulator is
usable without CI:

- `xcodebuild -scheme AMSPara -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/amspara-dd build`
- the vault is a security-scoped bookmark, so there is no path to set — generate one with
  `URL.bookmarkData()` on the Mac and write it into the app's
  `Library/Preferences/com.schabbauer.AMSPara.plist` as `vaultBookmark`. It resolves in the
  simulator, which shares the Mac's filesystem.
- every route to a note is a tap, so `ContentView.onAppear` reads `AMSPARA_OPEN_NOTE`
  (DEBUG only) and opens that note through the existing `amspara://` handler:
  `SIMCTL_CHILD_AMSPARA_OPEN_NOTE=Inbox xcrun simctl launch booted com.schabbauer.AMSPara`
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
`App/Config/AMSPara/AMSPara-macOS.entitlements` (via
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

## Not built (by choice)

Saved searches. Roadmap stopped there on his request.

