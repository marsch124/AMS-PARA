# AMS PARA – working notes

Memory for anyone (human or Claude) picking this project up. Keep it short and current.

## What this is

macOS/iOS app in the spirit of NotePlan: plain markdown vault organised as
Goals + PARA (Projects, Areas, Resources, Archive), tasks synced two-way with
Apple Reminders, daily/weekly notes, quick capture, full-text search.

Owner: Martin Schabbauer (project manager, part-time retired, Sweden, not a
developer). Communicate in short, friendly, concrete steps. He cannot run
Terminal commands. Since build 56 both apps come from TestFlight: when CI is
green, tell him to press **Run workflow** on the TestFlight page, then Update in
TestFlight on the phone and on the Mac. Xcode is no longer part of his routine.

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

## Recently fixed (build 30)

The "window scramble": expanding **Linked notes** (a DisclosureGroup above
the TextEditor in NoteEditorView) made the editor report its full text
height as a minimum, the NavigationSplitView grew to ~1300pt inside an
821pt window and every column looked scrolled under the toolbar. He called
this "pressing Linked Goals"; the header goal link was never the trigger.
Fix: the editor HStack sits in a GeometryReader with a fixed frame, so it
takes the remaining height and never demands more. Diagnostics stay:
**Help › Copy Diagnostics** (⌥⌘D) copies a log with clicks (hit view),
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
role — App Manager gives "Cloud signing permission error" at export. Both App IDs
need the App Group `group.com.schabbauer.amspara` enabled in the developer portal,
and `project.yml` declares `UISupportedInterfaceOrientations` (all four), without
which Apple rejects the binary. macOS signs with its own
`App/Config/AMSPara/AMSPara-macOS.entitlements` (via
`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`) which drops the App Group: the Mac App Store wants
team-prefixed groups, the share extension is iOS only, and `outboxURL` already falls back to
Application Support. The macOS platform must be added to the app record in App Store Connect
(Distribution › Add Platform) before the first Mac upload.

## Not built (by choice)

Saved searches. Roadmap stopped there on his request.
