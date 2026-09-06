# How AMS PARA works

AMS PARA is a plain-text project and life management app. Everything you write is a markdown file in a folder you own. The app reads and writes those files; Apple Reminders and Apple Calendar stay in sync with them.

## The idea

- **Goals** say what you want in life. They sit above everything else.
- **Projects** are things with an end: a race, a move, a report. Each one should serve a goal.
- **Areas** are things you keep up over time: health, home, a client. They also serve goals.
- **Resources** are reference material: articles, checklists, ideas.
- **Archive** is where finished projects and closed areas go. They stay searchable.
- **Inbox** catches everything you have not sorted yet.

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

Useful keys: `status` (active, on hold, done), `area`, `goal`, `due`, `tags`, `related`, `reviewed`, `reminders-list` to sync into a Reminders list with a different name, `sync: false` to keep a note out of Reminders.

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
- `^t3cd432` at the end is the id the app uses to match the task with its reminder. Leave it alone.

The task box under the note header shows the same tasks as a checklist. Ticking there edits the line in the file.

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

- **Today** shows the day's calendar events, overdue tasks, tasks due today, and undated tasks marked `!!` or more.
- **Calendar** lets you pick a day, week or month. A daily note is created the first time you open a day. The week and month views show what is due and what was done.
- A daily note shows the day's events and the tasks due that day above its own text. A weekly note shows the week.

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

Time Blocks are the one thing the app writes to Calendar. They are blocks of time you reserve, separate from tasks. Add one in the Time Blocks section: it becomes an ordinary event in the calendar chosen under "Time blocks go to", and shows on all your devices. Click a block to edit it, right-click to open it in Calendar or delete it. Nothing else in your calendars is ever changed.

## Archive and Trash

- **Archive** moves a project, area, resource or goal to the Archive folder, marks it archived and stops syncing its tasks. Use it for finished work.
- **Move to Trash** (⌘⌫ or right-click) puts the file in the Mac's Trash, so you can get it back from Finder. The Inbox note cannot be trashed.

## Mac and iPhone together

Keep the vault in iCloud Drive and pick the same folder on both devices. iCloud carries the files across. Each device syncs with Reminders on its own.

The app checks every few seconds whether files changed outside it and reloads them. It never writes over a newer file. If you were typing in a note that changed elsewhere at the same time, your text is saved as a copy named "… (conflict date time).md" next to the note, and the note shows the other version. Merge the two by hand when that happens; it is rare.

## Keyboard shortcuts

- ⌘N new note, ⇧⌘N quick capture, ⇧⌘F search everywhere, ⇧⌘R sync with Reminders
- ⌘⌫ move the open note to the Trash
- ⌥⌘D copy diagnostics, a log you can paste when reporting a problem

## When something looks wrong

Help › Copy Diagnostics (⌥⌘D) copies a short log: the build number, what was clicked, which section and note are open, and the window layout. Paste it into the chat with the developer. The build number is also shown at the bottom of the sidebar.
