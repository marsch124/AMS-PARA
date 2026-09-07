# Version history

The build number is shown at the bottom of the sidebar. Newest first.

## Build 56 · 7 September 2026

- **The Mac app comes from TestFlight too.** One press of the build button now sends both the iPhone app and the Mac app. The Mac app installs into your Applications folder like any other app, appears in Spotlight and the Dock, and tells you itself when a new version is ready. No more quitting, pulling and pressing play in Xcode.

## Build 55 · 7 September 2026

- **The Xcode project carries your signing team.** Until now Xcode had to be told by hand which Apple account signs the app, which meant the project file was changed on your Mac every time you pressed play, and those changes then got in the way of the next Pull. The team is part of the project now, so pressing play no longer modifies anything.

## Build 54 · 7 September 2026

- **Hide finished tasks.** The task list under a note header can leave out what is done or cancelled. The switch is on the header row of the Tasks box ("Hide finished"), and in Settings › Tasks. A finished task that still has open subtasks is always shown, so nothing open can disappear. The file is untouched: the tasks are still there in the text and in Reminders.

## Build 53 · 7 September 2026

- **The note screen scrolls on the iPhone.** A note with a long task list ran off both ends of the screen at once: the first tasks were hidden behind the title bar, the last behind the tabs at the bottom, and nothing would move. The whole screen is one scrolling page now, so every task is reachable.
- **"Add a task" stays put.** It sits just above the tabs instead of being the last thing on the page, so you no longer have to scroll to the bottom to add something.
- The Mac and iPad keep the layout they had.

## Build 52 · 7 September 2026

- **One build number everywhere.** TestFlight used to count its own uploads, so the phone said "Build 50" while TestFlight said "1.0.5". Now TestFlight uses the app's own number, the one at the bottom of the sidebar and on the Browse tab. Both say the same thing.

## Build 51 · 7 September 2026

- **A sync button on the iPhone.** Today and Inbox have one in the top right corner, and Settings › Reminders sync has "Sync now". Until now the phone could only wait for the automatic sync, which also meant iOS never got round to asking for permission to use Reminders.

## Build 50 · 7 September 2026

- The app now declares which screen rotations it supports, which Apple requires before an upload is accepted. On the iPhone and iPad it can be used in any orientation.
- The TestFlight build job uses the newest build machine and the newest Xcode, because Apple only accepts builds made with the current system.

## Build 49 · 7 September 2026

- Fixes in the TestFlight build job: it now signs with the Apple team from the new `ASC_TEAM_ID` setting, and makes its log folder before writing to it. Nothing in the app itself changed.

## Build 48 · 7 September 2026

- **The iPhone app can now come from TestFlight.** A new build server job builds the phone app and sends it to Apple, so new versions reach the phone by themselves: no cable, no Xcode, no seven-day expiry. The one-time setup is in TESTFLIGHT.md and happens entirely in a browser.

## Build 47 · 7 September 2026

- **The editor draws markdown while you type.** Headings grow and turn bold, task boxes are coloured, a finished task is struck through, dates and priorities and tags stand out, and the syntax characters fade into the background. The text in the file does not change at all: it is still the same markdown, only easier to read.
- Bold, italics, `code`, quotes, `[[links]]` and the settings block at the top of a note are all shown for what they are.

## Build 46 · 7 September 2026

A pass over how the app looks.

- **The editor reads like a document,** not like code: proportional type, more line spacing, wider margins.
- **Empty sections say what belongs there** and offer the button that fills them, instead of a bare line of text. Projects, Areas, Resources, Goals, Archive, Done and the note pane each have their own.
- **Today starts with the date** and how much is due, and the sections read more calmly.
- Headings above the task list and the linked notes are quieter and carry their count.

## Build 44 · 7 September 2026

- **Backups.** The app saves a copy of the whole vault before every sync and once a day, keeping the last ten. They are plain folders in the vault under `.ams-para/Backups`, so you can also open one in Finder and drag a single note back. Settings › Backups has "Back up now", "Show in Finder" and "Restore a copy", and a switch for the backup before each sync. Restoring saves what you have now as a backup first, and leaves notes made since then alone.
- **See what a sync would do.** The sync button is now a menu: "Sync now", "Show me what would change…" and "Last sync report…". The preview rehearses the whole sync on a copy of your vault and a copy of your reminders, so the numbers are exactly what a real sync would do, and nothing is changed. From the preview you can go straight to "Sync now".
- **A readable sync report** instead of one line: what was created, updated, deleted, anything that changed in both places, and anything worth knowing.

## Build 43 · 7 September 2026

- **The `^t` markers are hidden in the editor.** Every synced task carries a marker like `^t3cd432` that links it to its reminder. It is still in the file, so NotePlan and the sync keep working, but the editor no longer shows it, so you cannot delete it by accident while editing.
- **A lost marker repairs itself.** If a task did lose its marker, the next sync recognises the task by its note and title and gives the same marker back, instead of deleting the reminder and making a new one. Anything you had added to that reminder stays.

## Build 42 · 7 September 2026

- **iPhone layout.** On a phone the app shows tabs: Today, Inbox, Browse and Capture. Browse holds Goals, Projects, Areas, Resources, Archive, Calendar, Time Blocks, Done, Review, Map, Search and Settings. Tap a note to open it, swipe back to return. iPad and Mac keep the three columns.

## Build 41 · 7 September 2026

- **Next action per project.** Right-click a task in a project: "Make this the next action". It gets a "next" badge, shows on the project row, and Today lists one next action per active project.
- **Drag tasks between notes.** Drag a task from any list onto a note in the middle column, or onto Inbox in the sidebar. Subtasks travel along, and the reminder follows on the next sync.
- **Reschedule with one click.** Right-click a task: Today, Tomorrow, Next Monday, In a week, Pick a date, Remove date.
- **Repeating tasks.** Right-click › Repeat: every day, week, 2 weeks, month, 3 months, year. When a repeating task is ticked, here or in Reminders, the next one appears below it with the next date. In the file it is `@repeat(weekly)`.
- **Done.** A new sidebar section with everything completed, day by day, for the last 30 days, and a count for this week.
- **Project progress.** Project rows show a small bar with done and total tasks, and "Due in 12 d" or "3 d overdue".
- **Drag tasks onto the calendar.** Drop a task on a day in the month grid or the week list to set its date.
- **Time block from a task.** Right-click a task › "Block time for this…" opens Time Blocks with the title filled in and a link back to the note.
- **Weekly plan.** The weekly note shows all seven days. Drop tasks onto a day to plan it there, tick them off in place.
- Under the hood: new files no longer need the project file rewritten, so pulls stop clashing with your Team setting after this one.

## Builds 39 and 40 · 6 September 2026

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
