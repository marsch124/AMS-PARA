# How AMS PARA works

AMS PARA is a plain-text project and life management app. Everything you write is a markdown file in a folder you own. The app reads and writes those files; Apple Reminders and Apple Calendar stay in sync with them.

## The idea

- **Goals** say what you want in life. They sit above everything else.
- **Projects** are things with an end: a race, a move, a report. Each one should serve a goal.
- **Areas** are things you keep up over time: health, home, a client. They also serve goals. An area can sit under another one as a **sub-area** — Mobility under Health, say, or Yoga, Pliability and Stretching under Mobility. Right-click an area › **Part of** to put it under another, or to take it back out. Areas nest one level, no deeper, so the list stays a list.
- **Resources** are reference material: articles, checklists, ideas.
- **Archive** is where finished projects and closed areas go. They stay searchable.
- **Inbox** catches everything you have not sorted yet. Its screen is built for emptying: type at the top to capture, then work down the list with Today, Tomorrow, a date, or the menu to move it into a project or turn it into a note of its own. ↑ ↓ move, T is today, M tomorrow, D done, ⌫ deletes. Double-click a line to rename it, or right-click › Rename. The right-hand column shows the line you are on and where it can go: drag it there, or click one. "New note from this line…" makes a project, area or resource out of it instead.

That is PARA with a Goals layer on top. Every note answers "what does this serve?".

## Your vault

The vault is one folder. Pick it once under Settings › Vault. Inside it the app keeps:

- `Inbox.md`
- `Goals/`, `Projects/`, `Areas/`, `Resources/`, `Archive/`
- `Calendar/` for daily notes (`20260906.md`) and weekly notes (`2026-W36.md`)
- `Templates/` for the note skeletons, which you can edit
- `.ams-para/` for the app's own settings and sync bookkeeping

You can open the same folder in NotePlan, Obsidian or any text editor. If the folder lives in iCloud Drive, your iPhone can use the same vault.

## Notes

A note starts with a small block of settings between two `---` lines, then the text. The settings are plain `key: value` lines, for example:

```
---
title: Perform IM Jönköping 2027
type: project
status: active
area: Health
goal: Train for and do IM 70.3 for five years
due: 2027-08-15
tags: [sport, training]
---
```

Useful keys: `status` (active, on hold, done), `area`, `goal`, `due`, `tags`, `related`, `reviewed`, `order` (where the note sits when you have arranged the list by hand), `reminders-list` to sync into a Reminders list with a different name, `sync: false` to keep a note out of Reminders.

Links between notes use `[[Note title]]`. Unknown titles become a new resource note when you click them.

## Tasks

Tasks are ordinary list lines inside the notes:

- `- [ ] Book the hotel` is open
- `- [x] Book the hotel @done(2026-09-06)` is done
- `- [-] Cancelled` and `- [>] Moved to another day`
- `>2026-09-10` sets a date, `>2026-09-10T14:30` a date with a time
- `!`, `!!`, `!!!` set the priority
- `#tag` adds a tag
- an indented `- [ ]` under a task is a subtask
- `^t3cd432` at the end is the marker the app uses to match the task with its reminder. The editor hides it, so you will only see it in another editor. If it ever goes missing, the next sync puts it back.

While you type, the editor shows what the markdown means: headings grow, task boxes are coloured, a finished task is struck through, dates and tags stand out, and the symbols themselves fade. Nothing in the file changes; it stays plain markdown for NotePlan and every other editor.

The task box under the note header shows the same tasks as a checklist. Ticking there edits the line in the file. Its header row has a **Hide finished** switch (also in Settings › Tasks) that leaves out what is done or cancelled; a finished task with open subtasks always stays visible, and nothing is removed from the file.

Right-click any task, anywhere in the app, for the task menu:

- **Reschedule**: Today, Tomorrow, Next Monday, In a week, Pick a date, Remove date.
- **Repeat**: every day, week, 2 weeks, month, 3 months or year. When you tick a repeating task, the next one appears below it with the next date. In the file this is `@repeat(weekly)`.
- **Make this the next action** (in a project): the task gets a `#next` tag and a badge, and Today lists it under "Next actions". One per project.
- **Block time for this…**: opens Time Blocks with the title filled in.
- **Move to**: the Inbox, any active project or any active area. Subtasks move along. The reminder follows on the next sync. You can also drag the task onto another note in the middle column.

You can also **drag** a task: onto a note in the middle column or onto Inbox to move it, onto a day in the Calendar's month grid or week list to set its date, or onto a day in the weekly note.

## Reminders sync

The sync goes both ways. Press the sync button or ⇧⌘R, or let auto sync run at the interval set in Settings.

- Inbox tasks go to the Reminders list called Inbox.
- Each project and area gets a Reminders list with the note's name.
- Tasks in daily and weekly notes go to the Daily Notes list.
- Goals are never synced. They are direction, not to-dos.
- Completing, renaming, dating or deleting on either side carries over.
- If the same task changed in both places since the last sync, the note version wins and the sync report says so.
- Subtasks become separate reminders named "Parent › Child". Tasks with a time get an alarm.

Each device keeps its own sync bookkeeping, so the Mac and the iPhone can both sync the same vault.

## Goals

New › Goal creates a goal. A life goal has no date. A dated goal has a target date, a measure, and can point at a life goal. Projects and areas link to a goal with the `goal:` line. The goal note shows how many projects and areas serve it, open tasks, activity in the last 30 days, and flags such as "Nothing serves this", "Past its target date" or "Achieved".

## Today, Calendar, daily and weekly notes

- **Today** shows the day's calendar events, one next action per active project, overdue tasks, tasks due today, and undated tasks marked `!!` or more.
- **All actions** lists every open task in the vault, grouped by its note, with a filter for All, With a date, No date and Next actions.
- **Done** lists what you completed, day by day, for the last 30 days.
- **Calendar** lets you pick a day, week or month. The day view has a month grid with week numbers and a dot under every day that holds something — green for tasks due, red if one is overdue, blue for calendar events, grey for a day that already has a note. Under the grid is the day itself: its events, what is due, what got done, and a button to open or create the daily note. Move with the arrows, the Today button, or the left and right arrow keys. Drop a task on a day to give it that date.
- A daily note shows the day's events and the tasks due that day above its own text. A weekly note shows all seven days as a plan: drop tasks onto a day, tick them off there.

## Weekly review

The review walks through the inbox, the projects that need attention and the goals. A project is flagged when it has no next action, has overdue tasks, is past its due date, has not changed for the number of days set in Settings, or is on hold. Marking a project reviewed writes `reviewed:` with today's date.

## Map

The Map draws what serves what: goals at the top, then areas and projects, then open tasks and resources. Notes without a goal and archived notes sit in dashed boxes. Click a box to highlight its connections and open the note.

## Search

Search Everywhere (⇧⌘F) searches every note and task. Filters can be typed into the query:

- `type:project`, `type:area`, `type:goal`
- `status:active`, `status:done`
- `tag:web` or `#web`
- `area:Health`
- `in:Projects` to limit to a folder
- `due:overdue`, `due:today`, `due:week`, `due:month`, `due:none`, `due:any`
- `is:open`, `is:done`, `is:task`
- quotes for an exact phrase: `"race day"`

## Quick capture

- ⇧⌘N opens the capture panel in the app. On the Mac there is also a panel in the menu bar.
- On the iPhone, Share › AMS PARA sends text or a link.
- Other apps and Shortcuts can call `amspara://capture?text=Call%20the%20bank&target=inbox`.

Captures land in the Inbox, today's note or a project, and are filed the next time the app is active.

## Apple Calendar and Time Blocks

The app reads events from the calendars you choose in Settings › Apple Calendar. Events appear in Today and in daily notes. Double-click an event, or use its arrow button, to open it in the Calendar app.

The Calendar section shows the day's schedule in the right-hand column: hours down the side, events in place, your time blocks on top, a red line for now, and a strip at the top for all-day events and tasks with no time. Press "Block time" or double-click an hour to reserve time; click a block to change or delete it; drag a task onto an hour to block that hour for it. The switch at the top of the column swaps between the schedule and the daily note.

Time Blocks are the one thing the app writes to Calendar. They are blocks of time you reserve, separate from tasks. Add one in the Time Blocks section: it becomes an ordinary event in the calendar chosen under "Time blocks go to", and shows on all your devices. Click a block to edit it, right-click to open it in Calendar or delete it. Nothing else in your calendars is ever changed.

## Backups

The app saves a copy of the whole vault before every sync and once a day, keeping the last ten. They live inside the vault, in a hidden folder called `.ams-para/Backups`, as ordinary folders of markdown files.

- **Settings › Backups › Back up now** saves one immediately. Nothing is saved twice if nothing changed.
- **Show in Finder** opens the folder, where you can drag a single note back by hand.
- **Restore a copy** writes a whole backup back into the vault. What you have at that moment is saved as a backup first, and notes you created after the backup are left where they are.

Time Machine covers the rest: these backups sit inside the vault folder, so they do not protect against losing that folder itself.

## Seeing what a sync will do

The sync button is a menu. **Show me what would change…** rehearses the entire sync on a copy of your vault and a copy of your reminders and shows the result. Nothing is touched. From that sheet you can press **Sync now** to do it for real. **Last sync report…** shows the same for the sync you ran.

## Sub-areas

A sub-area is an ordinary area note with one extra line in its frontmatter, `parent: Health`. That means it behaves like any other area:

- Its own tasks and its own list in Apple Reminders.
- Its own box on the Map, drawn under the area it belongs to.
- A destination of its own in the Inbox "File it" column and in a task's **Move to** menu, where it reads "Health › Mobility".

In the Areas list a sub-area is indented under its area, and the chevron on the area folds its sub-areas away. Dragging to arrange works inside a family: a sub-area moves among its brothers and sisters, an area among the other areas. The note itself shows **Part of Health** at the top — click it to go there.

An area that already has sub-areas cannot itself become one; move its children out first.

## Archive and Trash

- **Archive** moves a project, area, resource or goal to the Archive folder, marks it archived and stops syncing its tasks. Use it for finished work.
- **Move to Trash** (⌘⌫ or right-click) puts the file in the Mac's Trash, so you can get it back from Finder. The Inbox note cannot be trashed.

## On the iPhone

Sync with Reminders from the phone with the button in the top right of Today and Inbox, or Settings › Reminders sync › Sync now. The first sync is when iOS asks for permission to use Reminders.

The phone shows four tabs. **Today** and **Inbox** are the same lists as on the Mac. **Browse** holds everything else: Goals, Projects, Areas, Resources, Archive, Calendar, Time Blocks, Done, Review, Map, Search, and Settings with Help. **Capture** opens the capture panel. Tap a note to open it and swipe from the left edge to go back. Long-press a task for the task menu. The share sheet in other apps has an AMS PARA entry that sends text or a link to the Inbox.

## Mac and iPhone together

Keep the vault in iCloud Drive and pick the same folder on both devices. iCloud carries the files across. Each device syncs with Reminders on its own.

The app checks every few seconds whether files changed outside it and reloads them. It never writes over a newer file. If you were typing in a note that changed elsewhere at the same time, your text is saved as a copy named "… (conflict date time).md" next to the note, and the note shows the other version. Merge the two by hand when that happens; it is rare.

## Getting new versions

Both apps come from TestFlight. When a new build is sent, TestFlight tells you and you press
Update: on the iPhone in the TestFlight app, on the Mac in TestFlight for Mac. The Mac app
lives in your Applications folder like any other app.

## Keyboard shortcuts

- ⌘N new note, ⇧⌘N quick capture, ⇧⌘F search everywhere, ⇧⌘R sync with Reminders
- ⌘⌫ move the open note to the Trash
- ⌥⌘D copy diagnostics, a log you can paste when reporting a problem
- The sync button's menu holds the sync preview and the last report

## When something looks wrong

Help › Copy Diagnostics (⌥⌘D) copies a short log: the build number, what was clicked, which section and note are open, and the window layout. Paste it into the chat with the developer. The build number is also shown at the bottom of the sidebar.
