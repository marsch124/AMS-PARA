# AMS PARA – working notes

Memory for anyone (human or Claude) picking this project up. Keep it short and current.

## What this is

macOS/iOS app in the spirit of NotePlan: plain markdown vault organised as
Goals + PARA (Projects, Areas, Resources, Archive), tasks synced two-way with
Apple Reminders, daily/weekly notes, quick capture, full-text search.

Owner: Martin Schabbauer (project manager, part-time retired, Sweden, not a
developer). Communicate in short, friendly, concrete steps. He runs the app
from Xcode only: quit app (⌘Q) → **Integrate › Pull…** → **▶**. He cannot run
Terminal commands. Tell him "you can pull" only after CI is green.

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

## Not built (by choice)

Saved searches. Roadmap stopped there on his request.
