# Version history

The build number is shown at the bottom of the sidebar. Newest first.

## Build 80 · 9 September 2026

- **Deleted.** A new sidebar section holding the notes you have deleted, newest first. Each one has **Put back**, which returns it to the folder it came from, and **Delete for good**; **Empty** in the toolbar clears the lot.
- **This closes a real hole on the iPhone.** Deleting used to put the file in the Mac's Trash, which the phone has no equivalent of — there the note was simply removed, and iCloud then took it off the Mac too. Now both behave the same way.
- Deleted notes are kept for **30 days** and then cleared out on their own. They sit in a hidden folder inside the vault, so they cost you nothing and never sync to Reminders.
- The wording follows: the button is now **Delete**, and it says where the note is going.
- Only whole notes are kept. A task deleted from a list is still gone straight away.

## Build 79 · 9 September 2026

- **The Inbox "File it" column now shows the shape of your vault.** Two headings — **Projects** in green, **Areas** in pink — instead of one long run of cards.
- **Sub-areas sit under their area**, indented, on a faint tint of their own colour and joined to the parent by a thin line, so a family reads as a family. They say "Sub-area" rather than "Area".
- Any area with sub-areas has a small **chevron** to fold its family away when the list gets long.
- Every card is still a click target and a drop target, exactly as before.

## Build 78 · 9 September 2026

- **Recent.** A new sidebar section listing the notes you opened most recently, newest first, of any kind. It survives quitting the app, and **Clear** in the toolbar empties it. On the phone it is under Browse › Plan.
- **Calendar › Notes.** A fourth view next to Day, Week and Month: every daily and weekly note you have written, newest first, with the first line of what you wrote so a day is recognisable. It has its own search field.
- **All actions** is now on the phone too, under Browse › Plan.

## Build 77 · 9 September 2026

- **Rename a note.** Right-click it in the list on the Mac, or long-press it on the phone → **Rename…**. Works for projects, areas, sub-areas, resources, goals and archived notes. The note screen also has a **Rename** button in its toolbar.
- The file on disk is renamed with it, and **every link follows**: `goal:`, `area:`, `parent:`, `related:` and any `[[wikilink]]` in another note is pointed at the new name, so nothing comes loose.
- The note's own `# Heading` is updated too, when it still said the old name. Headings further down are left alone.
- A name already taken by another note is refused rather than overwriting it.
- The list in Apple Reminders follows on the next sync — the tasks keep their reminders.

## Build 76 · 9 September 2026

- **Rename a task anywhere.** Right-click a task on the Mac, or long-press it on the phone, and the menu now has **Rename…**. The line turns into a field; type and press Return. Works in a note's task list, in Today, in All actions, in Done and in the calendar day.
- The date, repeat rule, tags, subtasks and the task's identity in Apple Reminders all stay as they were — only the wording changes.
- Renaming a **next action** no longer loses the marker: the badge is put back after the rename.

## Build 75 · 9 September 2026

- **Fix, properly this time: picking an inbox line works again.** Build 71 made the rows draggable and double-clickable, and on the Mac either of those takes the click the list needs to select a row — so no line could be marked, and nothing could be filed. Both are gone. Click a line, then click where it should go, exactly as before build 71.
- Renaming a line is on its **⋯ menu** (and the right-click menu): **Rename…**. Double-click is not back yet; I would rather leave it out than break selecting again.
- Dragging a line from the Inbox onto a destination is gone with it. Clicking a destination does the same thing in one click.

## Build 74 · 8 September 2026

- **Fix: you can pick an inbox line again.** Build 71's double-click-to-rename was swallowing the click the list needs to select a row, so marking a line and then pressing a destination stopped working. Sorry — selecting, the single keys and "click a destination" all work as before, and double-click still renames.
- **Sub-areas are now where you can find them.** Open an area note and the top row has a **Part of…** button: click it and pick the area it belongs to, or "Not part of another area" to take it back out. The right-click menu on an area in the list has the same choices.
- **New note › Area** now has a **Part of** picker, so a sub-area can be made as one from the start.
- Any area can now be picked as the parent, not only the top-level ones. Choosing one that is itself a sub-area lifts it up first — asking for "Yoga under Mobility" means Mobility is the level above.

## Build 73 · 8 September 2026

- **Sub-areas.** An area can now sit under another area: Mobility under Health, or Yoga, Pliability and Stretching under Mobility. Right-click an area › **Part of** and pick where it belongs, or pick "Nothing" to take it back out.
- The Areas list shows them indented under their area, and the small chevron folds them away.
- A sub-area is a normal note in every other way: its own tasks, its own list in Apple Reminders, its own box on the Map (drawn under its area), and its own destination in the Inbox "File it" column and in a task's **Move to** menu, where it reads "Health › Mobility".
- Arranging by hand still works and stays inside the family: a sub-area moves among its siblings, an area among the other areas.
- The note itself shows **Part of Health** at the top; click it to go there.
- Areas nest one level only. An area that already has sub-areas cannot become one until its children are moved out.

## Build 72 · 8 September 2026

- **Move an action to an area, not just a project.** Right-click any task › **Move to** now lists your active projects *and* your active areas (and the Inbox, if it is not already there). Before this, the menu only offered projects, so a task that had landed in the wrong area could not be moved back from the menu.

## Build 71 · 8 September 2026

- **Edit an inbox line where it sits.** Double-click it, or right-click › Rename. Enter saves. The date, tags and any subtasks stay as they were.
- **Drag an inbox line straight onto a destination** in the right-hand column, as well as clicking one.
- The stray arrow next to the "…" button on each inbox line is gone.
- **New note** now sits above the list it adds to, instead of over on the right by the search field.

## Build 70 · 8 September 2026

- **All actions.** A new sidebar section with every open task in the vault, grouped by the note it belongs to, with a filter for All, With a date, No date and Next actions. Tick tasks off in place, or press Open to go to the note. No more remembering a search.
- **Arrange projects and areas by hand.** Drag a note up or down in the list and it stays there. The position is written into the note itself as `order: 20`, so the Mac and the iPhone agree, and so does the "File it" column in the Inbox. Notes you have never dragged stay in alphabetical order, after the arranged ones.

## Build 69 · 8 September 2026

- **Fix: coming back to the Inbox shows "File it" again.** If you had opened a note elsewhere — including one you had just made from an inbox line — the right-hand column kept showing that note instead of your destinations. The Inbox now always opens on sorting; the raw note appears only when you ask for it with "Open the Inbox note".

## Builds 67 and 68 · 8 September 2026

- **The Inbox's right-hand column is now "File it".** It used to repeat the same list of tasks the middle column already shows. It holds the line you are sorting — with room to read a long one in full — and under it your active projects and areas, each with its open count.
- **Drag a line onto a destination, or select it and click one.** Either way it moves, and the selection steps to the next line so you can keep going.
- **New note from this line…** turns a captured line into a project, area or resource of its own when no destination fits.
- Goals are deliberately not destinations: they are direction, not lists to file work into. The raw Inbox note is still one click away.

## Build 66 · 8 September 2026

- **The Inbox is now a sorting screen.** There is only ever one inbox note, so the middle column used to be a list of one. It now holds everything waiting to be sorted, a line at a time, with a capture box at the top for typing new items straight in.
- Each line has **Today**, **Tomorrow** and **Pick a date** to hand, and a menu for the rest: move it into a project or area, turn it into a project, area, resource or goal of its own, block time for it, or delete it.
- **Keyboard**: ↑ and ↓ to move down the list, **T** for today, **M** for tomorrow, **D** for done, **⌫** to delete. The selection moves on by itself, so a full inbox takes a minute.
- When you reach the end it says **Inbox zero** instead of showing an empty list. The note itself stays readable in the right-hand column.

## Builds 63 to 65 · 7-8 September 2026

- **A gold frame around the app icon.** The four PARA squares now sit inside a gold ring, in the same colour goals have everywhere else in the app: everything you keep serves the goals around it.

## Build 62 · 7 September 2026

- A build server fix: it no longer asks Apple for a new signing certificate on every run, which had filled up the account's allowance. Nothing in the app changed.

## Build 61 · 7 September 2026

- **The Calendar section now uses the whole window.** The right-hand column shows the selected day as a schedule: hours down the side, your Apple Calendar events in place and in their own colours, and your time blocks drawn on top of them. A red line marks now.
- **Time blocks live there.** Press "Block time", or double-click an hour, to reserve one. Click a block to change its title, time, length, calendar or notes, or to delete it. All of it writes to Apple Calendar as before, so it shows on every device.
- **Drag a task onto an hour** and that hour is blocked for it, with a link back to the note it came from.
- All-day events and tasks due today without a time sit in a strip above the clock, so nothing is hidden.
- A **Schedule / Note** switch at the top of the column: the daily note is one click away, and it opens by itself when you pick a note.

## Builds 58 to 60 · 7 September 2026

The Calendar section's day view, rebuilt.

- **A month grid of our own** instead of the small system date picker: it fills the column, the cells are big enough to read and to drop a task onto.
- **Dots under the days** so you can see the shape of a month at a glance: green for tasks due (red if something is overdue), blue for calendar events, grey for a day that already has a note.
- **Week numbers** down the left.
- **The day itself below the grid** — its calendar events, what is due, anything undated in the daily note, what got done, and a button to open or create the note. It used to be a list of every daily note in the vault, newest first.
- **A proper header**: the day written out, its week number, and what it holds.
- **Moving around**: arrows for the previous and next day, a Today button, separate arrows for the month, and the left and right arrow keys once the calendar has focus.

## Build 57 · 7 September 2026

- Notes only. Both apps now come from TestFlight and Xcode is out of the loop; this build records that.

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
