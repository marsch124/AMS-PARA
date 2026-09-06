# Version history

The build number is shown at the bottom of the sidebar. Newest first.

## Build 39 · 6 September 2026

Hardening after a code audit. Nothing new to learn; the app is more careful with your files.

- A note changed on the iPhone, in iCloud or in another editor is never overwritten. The app reloads such changes every few seconds and when it comes to the front. If you were typing in that note at the same time, your version is kept as a "(conflict …)" copy next to it.
- Unsaved typing is written before every sync, before ticking a task, and when the app quits or goes to the background.
- Frontmatter lines the app does not understand (comments, nested values, keys with spaces) are kept exactly as written. Windows line endings are read correctly. Quoted values no longer gain backslashes.
- Reminders sync: renaming a project moves its reminders instead of cancelling its tasks; a second device never deletes reminders for notes it has not received yet; a task line copied into another note gets its own id; ids typed into a reminder title cannot hijack a task; a failure while talking to Reminders no longer leaves half-done work.
- A note the app cannot read is skipped and logged instead of hiding the whole vault. Files in Windows text encoding are read.
- Archiving a second note with the same name keeps both. Cancelled tasks keep their done stamp.
- Capture links can no longer point at files outside the vault or at the app's own settings; only web and mail links are kept. Captures that cannot be filed yet wait in the outbox instead of being dropped.
- Choosing a folder that cannot be opened leaves the current vault working.

## Build 38 · 6 September 2026

- Help window with "How it works" and this version history (Help menu on the Mac, Settings on the iPhone).

## Build 35 · 6 September 2026

- Settings › Apple Calendar lists every calendar with a switch, and a picker for the calendar new time blocks go to.
- New Time Blocks section: reserve blocks of time as events in Apple Calendar, separate from tasks. Click to edit, right-click to open in Calendar or delete.
- Every event in Today and daily notes can be opened in the Calendar app.

## Build 34 · 6 September 2026

- Root cause of the "columns hidden under the toolbar" problem fixed: the window no longer grows when a task is added, a section is opened or the list changes.

## Build 33 · 6 September 2026

- Today and daily notes show the day's Apple Calendar events above the tasks. Read only. Can be turned off in Settings.

## Build 32 · 6 September 2026

- Map: a top-down diagram of goals, areas, projects, tasks, resources and archive. Click a box to see its connections and open the note.

## Build 31 · 6 September 2026

- Move any note except the Inbox to the Trash: toolbar button, ⌘⌫, or right-click in the list. Goals can be archived.

## Build 30 · 6 September 2026

- Opening "Linked notes" no longer pushes the editor out of the window.

## Builds 28 and 29 · 6 September 2026

- Build number at the bottom of the sidebar.
- Help › Copy Diagnostics (⌥⌘D) copies a log for reporting problems.
- Following a goal link or a linked note navigates in two steps, the way two clicks would.
- Goal references match their goal even when case, punctuation or length differ. A missing goal shows a message in the bottom banner instead of a pop-up.

## Builds 22 to 27 · 6 September 2026

- The goal link in a project no longer creates a stray resource note.
- Several fixes for state changes during redraws: list selection, sheet and alert dismissal, search field text, saving when a note is swapped out.

## Build 21 · 6 September 2026

- Goals above PARA: life goals and dated goals, `goal:` links from projects and areas, the goal dashboard and goal flags in the weekly review. Goals never sync to Reminders.

## Build 20 · 5 September 2026

- Colour throughout the app: Projects green, Areas pink, Resources blue, Archive grey, Goals gold.

## Builds 16 to 19 · 5 September 2026

- App icon.
- Fix for the frozen window when opening a sheet.
- Fix for state changes published during view updates.

## Builds 10 to 15 · 5 September 2026

- The Xcode project, Info.plist, entitlements and shared scheme are committed, so the repository opens directly in Xcode. The project is regenerated only when its spec changes, keeping your signing Team.
- The Swift package moved into `Core/` so Xcode can open the project.

## Builds 7 to 9 · 5 September 2026

- Quick capture: menu bar panel, iOS share extension, `amspara://capture` link.
- Full-text search with filters for type, status, tag, area, folder, due date and open or done.

## Builds 4 to 6 · 5 September 2026

- Due times on tasks, subtasks, alarms in Reminders.
- Weekly notes, and week and month overviews in the Calendar section.

## Builds 1 to 3 · 5 September 2026

- Continuous integration on a Mac runner: core tests, macOS and iOS builds on every push.
- Daily notes with a calendar, markdown preview with clickable wikilinks, weekly review.

## Foundation · 5 September 2026

- The core: markdown notes with frontmatter, NotePlan style tasks, the PARA vault, the note index, and the two-way Reminders sync engine with tests.
- The app: sidebar, note list, editor with preview, task checklist, settings, example vault.
