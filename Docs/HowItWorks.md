# How PARAGON works

PARAGON is a plain-text project and life management app. Everything you write is a markdown file in a folder you own. The app reads and writes those files; Apple Reminders and Apple Calendar stay in sync with them.

Every heading below opens and closes, so this page is a contents list you drill into rather than a wall of text. The box at the top searches it: type a word and only the parts that mention it are shown, already opened.

Throughout: **right-click** on the Mac is **long-press** on the iPhone. Where this page says one, the other works on the other device.

## The idea

- **Goals** say what you want in life. They sit above everything else.
- **Projects** are things with an end: a race, a move, a report. Each one should serve a goal.
- **Areas** are things you keep up over time: health, home, a client. They also serve goals. An area can sit under another one as a **sub-area** — Mobility under Health, say, or Yoga, Pliability and Stretching under Mobility. Right-click an area (long-press on the phone) › **Part of** to put it under another, or to take it back out. Areas nest one level, no deeper, so the list stays a list.
- **Resources** are reference material: articles, checklists, ideas.
- **Archive** is where finished projects and closed areas go. They stay searchable.
- **Inbox** catches everything you have not sorted yet. It has a screen of its own; see **The Inbox** below.

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

Several of these have a button at the top of the note as well, and it writes the same line: **Serves…** for `goal`, **Part of…** for `parent`, **Due** for `due`, and **Tags…** for `tags`.

Links between notes use `[[Note title]]`; see **Linking notes with [[ ]]** below.

### Making one

**⌘N** asks for a name — the cursor is already in the field, so a note is usually a name and Return. Under it are the four kinds in their own colours: **Goal**, **Project**, **Area**, **Resource**, with one line saying what the chosen one is for.

Under that, everything else a note can be given as it is made, all of it on screen: which template to start from, what an area is part of, a goal's horizon and target date, and the goal a project serves. Only the settings that apply to the kind you have chosen are shown.

### Renaming a note

Right-click a note in the list (long-press on the phone) › **Rename…**, or press **Rename** in the toolbar of the note itself. The file is renamed with it, and every note that pointed at the old name — `goal:`, `area:`, `parent:`, `related:` or a `[[wikilink]]` — is updated, so no link comes loose. The note's own `# Heading` follows when it still said the old name.

A name another note already uses is refused. In Apple Reminders the list follows on the next sync; the tasks keep their reminders. The Inbox and daily notes cannot be renamed.

### Archive and Deleted

- **Archive** moves a project, area, resource or goal to the Archive folder, marks it archived and stops syncing its tasks. Use it for finished work.
- **Delete** (⌘⌫, or right-click the note; long-press on the phone) moves a note to the **Deleted** section in the sidebar. Nothing is lost: each entry has **Put back**, which returns it to the folder it came from (or beside it, if that name has been taken since), and **Delete for good**. **Empty** in the toolbar clears the lot.
- Deleted notes are kept for **30 days**, then cleared out on their own. They live in a hidden folder inside the vault, so the phone and the Mac behave the same way and nothing there syncs to Reminders. The Inbox note cannot be deleted.
- Only whole notes go here. A task you delete from a list is gone from the note straight away.

### Which aspiration an area serves

An area can say which aspiration it belongs to, and a project which goal it delivers: **Serves…** at the top of the note, or right-click it in the list. A project is offered the dated goals first, an area the aspirations first. That is what makes Endurance the home of "an endurance athlete still racing at seventy" rather than leaving the aspiration floating on its own. An area is allowed to serve nothing — it is a standard you keep up, not a path to an outcome — so the review never asks about an area without one.

## Sub-areas

**Making one.** Open the area note and click **Part of…** in the top row, then pick the area it belongs to. "Not part of another area" takes it back out. The same choices sit on the right-click menu of an area in the list (long-press on the phone), and **New note › Area** has a **Part of** picker for making one from the start.

A sub-area is an ordinary area note with one extra line in its frontmatter, `parent: Health`. That means it behaves like any other area:

- Its own tasks and its own list in Apple Reminders.
- Its own box on the Map, drawn under the area it belongs to.
- A destination of its own in the Inbox "File it" column and in a task's **Move to** menu, where it reads "Health › Mobility".

In the Areas list a sub-area is indented under its area, and the chevron on the area folds its sub-areas away. Dragging to arrange works inside a family: a sub-area moves among its brothers and sisters, an area among the other areas. The note itself shows **Part of Health** at the top — click it to go there.

Any area can be picked as the parent. Picking one that is already a sub-area lifts it up a level first, since areas nest one level only — asking for "Yoga under Mobility" means Mobility is the level above.

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

Right-click any task, anywhere in the app — long-press on the phone — for the task menu:

- **Reschedule**: Today, Tomorrow, Next Monday, In a week, Pick a date, Remove date.
- **Repeat**: every day, week, 2 weeks, month, 3 months or year. When you tick a repeating task, the next one appears below it with the next date. In the file this is `@repeat(weekly)`.
- **Make this the next action** (in a project): the task gets a `#next` tag and a badge, and Today lists it under "Next actions". One per project.
- **Block time for this…**: opens Time Blocks with the title filled in.
- **Rename…**: turns the line into a field. Type and press Return. The date, repeat, tags and subtasks stay, and so does the reminder it is linked to.
- **Move to**: the Inbox, any active project or any active area. Subtasks move along. The reminder follows on the next sync. You can also drag the task onto another note in the middle column.

You can also **drag** a task: onto a note in the middle column or onto Inbox to move it, onto a day in the Calendar's month grid or week list to set its date, or onto a day in the weekly note.

### Adding a task at the bottom of a note

The field says **Add a task…**. Type the words and press Return, or press the arrow.

The **ⓘ** beside the field opens the list of what else you can write in it: a date, a date and a
time, a priority, a tag, a repeat. Up to build 141 that list was the grey text inside the field,
where it was too long to read on the phone and disappeared as soon as you typed.

Beside it: **Snippet**, a ready-made block of tasks from Templates › Snippets, and on the phone
the **pencil** that turns writing on and off.

## The Inbox

Everything you capture lands here, and the screen is built for emptying it.

The middle column is the list of lines waiting to be sorted, with a capture field on top. Work down it with the buttons on each row — Today, Tomorrow, pick a date — or its **⋯** menu, which also holds **Rename…** and **New note from this line…** (a project, area or resource made out of the line).

### The keys

↑ and ↓ move down the list, **T** gives a line today's date, **M** tomorrow's, **D** ticks it off and **⌫** deletes it. Typing in the capture field never triggers them.

### Where it goes

The right-hand column shows the line you are on and everywhere it can go. Click a destination and the line moves there, and the next line is selected so you can keep going.

The destinations are grouped into **Projects** and **Areas**, with sub-areas indented under the area they belong to and a chevron to fold a family away.

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

### Seeing what a sync will do

The sync button is a menu. **Show me what would change…** rehearses the entire sync on a copy of your vault and a copy of your reminders and shows the result. Nothing is touched. From that sheet you can press **Sync now** to do it for real. **Last sync report…** shows the same for the sync you ran.

## Goals

New › Goal creates a goal, and the **Horizon** you pick says which kind it is.

**Aspiration** has no date: who you want to be in some part of your life, which stays true after every goal is reached. It is the A in PARAGON, and it is never ticked off.

**This year** and **Long term** are dated goals: a target date, a measure of what success looks like, and the aspiration they serve, chosen in the **Serves aspiration** box. Projects and areas link to a goal with the `goal:` line. The goal note shows how many projects and areas serve it, open tasks, activity in the last 30 days, and flags such as "Nothing serves this", "Past its target date" or "Achieved".

### How far a goal has come

Every goal shows a bar and a per cent, on its own page, in the Goals list and on its row in **Weekly review**. The figure is worked out from the projects under the goal. You never type it in.

Every project counts the same, whatever its size, so a project with forty small tasks does not drown one with three big ones.

- A project marked **done** counts as a whole one.
- A project still running counts as the share of its tasks that are ticked. Sub-tasks and cancelled tasks are left out, and so a project with no tasks yet counts as nothing done.
- The goal's figure is the average of its projects.

**Areas are not counted.** An area is something you keep up, not something that finishes, so counting one would hold its goal below full for ever.

**An aspiration counts through its goals.** Each dated goal under it brings its own figure, one share each, and those goals bring their projects.

**No bar at all means there is nothing to measure yet** — no project under the goal. That is not the same as nought per cent, so the app draws nothing rather than an empty bar.

The per cent never says 100 until everything really is finished, and never says 0 once something has moved.

## Today, Calendar, daily and weekly notes

- **Today** shows the day's calendar events, one next action per active project, overdue tasks, tasks due today, and undated tasks marked `!!` or more.
- **All actions** lists every open task in the vault, grouped by its note, with a filter for All, With a date, No date and Next actions.
- **Done** lists what you completed, day by day, for the last 30 days.
- **Calendar** lets you pick a day, week or month. The day view can show a month grid with week numbers and a dot under every day that holds something — green for tasks due, red if one is overdue, blue for calendar events, grey for a day that already has a note. Under the grid is the day itself: its events, what is due, what got done, and a button to open or create the daily note. The grid is off to begin with, because the day itself is what the screen is for: press the **calendar** button in the day's top row to show it, and press it again to put it away. The button is lit while the grid is showing, and the app remembers your choice. Move with the arrows, the Today button, or the left and right arrow keys. Drop a task on a day to give it that date.
- A daily note shows the day's events and the tasks due that day above its own text. A weekly note shows all seven days as a plan: drop tasks onto a day, tick them off there.

## Apple Calendar and Time Blocks

The app reads events from the calendars you choose in Settings › Apple Calendar. Events appear in Today and in daily notes. Double-click an event, or use its arrow button, to open it in the Calendar app.

The Calendar section shows the day's schedule in the right-hand column: hours down the side, events in place, your time blocks on top, a red line for now, and a strip at the top for all-day events and tasks with no time. Press "Block time" or double-click an hour to reserve time; click a block to change or delete it; drag a task onto an hour to block that hour for it. The switch at the top of the column swaps between the schedule and the daily note.

### Plan the day

There is a second kind of block, and it is the opposite of a Time Block: it stays inside
PARAGON. Open it with **Go › Plan the Day…** (⇧⌘P) on the Mac, which gives it a window of its
own, or with **Plan the day…** at the top of the **Time Blocks** section on the iPhone.

The screen has three parts:

- **Calendar** on the left: what is already booked that day, read from Apple Calendar.
- **Time blocks** in the middle: your own blocks. They hang on the same hours as the calendar,
  so you can see whether a block lands inside something already booked.
- **Actions** on the right: what is due that day, then your next actions. Press one to make a
  block for it.

Press a block to change its name, its time or its length. Right-click it (long-press on the
iPhone) for **Remove**. The arrows at the top move a day at a time.

**A block is only for you.** It says where you mean to be, or what you mean to work on. It is
never written to Apple Calendar, it never becomes a task, and nothing outside the app sees it.

**Where the blocks are kept.** In that day's daily note, under a heading called **Plan**:

```
## Plan

- 09:30-11:00 Deep work on the IM plan
- 13:00-14:00 Pack for Granden
```

So they sync like everything else, and you can read and correct them by hand in any editor. If
the daily note does not exist yet, the first block makes it.

Time Blocks are the one thing the app writes to Calendar. They are blocks of time you reserve, separate from tasks. Add one in the Time Blocks section: it becomes an ordinary event in the calendar chosen under "Time blocks go to", and shows on all your devices. Click a block to edit it, right-click (long-press on the phone) to open it in Calendar or delete it. Nothing else in your calendars is ever changed.

## Weekly review

The review walks through the inbox, the projects that need attention and the goals. A project is flagged when it has no next action, has overdue tasks, is past its due date, is due after the goal it serves, has not changed for the number of days set in Settings, or is on hold. Marking a project reviewed writes `reviewed:` with today's date.

Two of those deserve a word.

**"Due after its goal"** means the project's own deadline falls later than the target date of the goal it serves. That cannot be true and the goal still be reached, so either the project has to come forward or the goal has to move. Set a project's deadline from the **Due** button at the top of the project note. Write the date in the field as 2031-12-01, or pick it in the calendar below; press the button again to change or clear it. A goal can be years away, so typing is usually quicker than clicking.

**"Projects with no goal"** is its own short list, above the inbox: the projects with no `goal:` line at all. Work with nothing above it is not an error — plenty of good work is simply something you want to do — so these are never counted as needing attention and never coloured as a problem. The review asks once. To answer, open the project and press **Serves…** at the top of the note; the same choice is on the right-click menu in the project list.

A goal is flagged when nothing serves it, when its target date has passed, when nothing has moved for 30 days, or when the only thing serving it is an area. A goal whose projects are all finished counts as served, not as neglected. That last one, **"No project yet"**, is the difference between a dated goal and a wish: an area is a standard you keep up, not a path to an outcome on a date. It applies to dated goals only. A goal reached through dated sub-goals is fine — those carry the projects — and so is an aspiration held by an area, which is exactly where an aspiration belongs.

## Map

The Map draws what serves what: goals at the top, then areas and projects, then open tasks and resources. Notes without a goal and archived notes sit in dashed boxes. Click a box to highlight its connections and open the note.

### Wiring it up by dragging

The Map is not only something to look at. Drag one box onto another and the link is written into the notes:

- A **project onto an area** — the project now belongs to that area.
- A **project or area onto a goal** — it now serves that goal.
- An **area onto another area** — it becomes a sub-area of it.
- A **goal onto a goal** — the first becomes a subgoal of the second.
- A **task chip onto a project or area** — the task moves into that note, subtasks and all.

The box you are over is outlined while it would accept the drop; anything that does not go together is refused and the drag springs back. The map redraws itself afterwards, so the new arrangement is on screen at once.

The boxes themselves are placed by the app, worked out from your links — there is no way to drag a box to a position of its own, because the next change would move it again.

### Arranging it by hand

The boxes are placed by the app, worked out from your links. If you would rather put some of them where you want them, press **Arrange** — the hand button at the **left** of the Map's toolbar, next to the zoom buttons. While it is on, a tinted strip across the top of the map says so, says what a drag will do, and has **Done** to leave the mode (Esc also works).

**While Arrange is on**, dragging a box moves it. Let go and it stays there. Dragging no longer links things — that is the whole point of the switch, so one drag never means two things.

**Moving several at once.** There are two ways to mark boxes, and they work together:

- **Tap a box** to mark it, tap it again to unmark it.
- **On the Mac, drag a rectangle across the empty background** and everything it touches is marked as well. It adds to whatever you had already tapped rather than replacing it. (On the phone a drag across the background scrolls the map, so there is no rectangle there — tapping does the job.)

The toolbar counts what is marked. Then drag any marked box and the whole set moves together, keeping its shape. Dragging a box that is *not* marked moves only that box and leaves your marks alone. Tap the empty background to clear the marks, and turning Arrange off clears them too.

**While Arrange is off** (the normal state), dragging links things as described above and nothing moves.

#### Where the position is kept

In the note itself, as one line in its frontmatter:

```
---
title: Mobility
type: area
map: 320,180
---
```

Two numbers: how far from the left and how far from the top, in points, measured at normal zoom. That has some useful consequences:

- **It travels with the note.** Rename the note, move it between folders, open the vault on the iPhone — the box stays where you put it, because the position is part of the file.
- **Both devices agree**, through iCloud, like everything else in the vault.
- **It is in your backups**, and in any other editor you open the file in.
- **Zoom does not disturb it.** The numbers are stored as if the map were at normal zoom, so zooming in and out moves the box on screen without changing what is written down.
- **If it is ever wrong**, the worst that happens is a box in an odd place. Delete the `map:` line in any editor and the app places it again.

#### Placed and unplaced boxes together

A note with no `map:` line is placed by the app as before. So the two live side by side: the boxes you have parked stay put, everything else is arranged around them by the layout.

That means a **new note appears wherever the layout puts it**, which can be on top of a box you placed. Move either one and they sort themselves out. Task chips and the dashed group boxes are never parked — only proper notes are.

#### Putting a box back

- **Right-click a box while arranging › Place this one automatically** takes its `map:` line out. If the box is one of several marked, it offers to place all of them.
- **Reset all** in the toolbar (also only while arranging) does the same for every note at once, after asking.

Nothing else in the note changes either way.

### Exporting the map

The **Export** button in the Map's toolbar offers:

- **PDF** — vector, so it stays sharp however far you zoom or print it. The one to send to someone.
- **PNG** — a picture, for pasting into a mail or a document.
- **Copy image** — the same picture, straight to the clipboard.
- **Copy as outline** — the same tree as an indented list of text, which is often easier to read than a diagram and can be pasted anywhere.

On the Mac a save dialog asks where to put the file. On the iPhone the share sheet opens, so it can go to Files, Mail, Messages or anywhere else.

## Linking notes with [[ ]]

Type two square brackets in any note and a list of your notes appears under the cursor. Keep typing to narrow it down, use the arrow keys to move, and press Return — or click one — to put it in. What lands in the text is `[[The note's title]]`.

**Opening one.** Hold ⌘ and click the link on the Mac. On the iPhone, switch to **Read** with the button below the note and tap the link there. A plain click on the Mac still just puts the cursor where you clicked, so a link never gets in the way of writing. The pointer turns into a hand when it is over one.

**Coming back.** Following a link takes you to the other note; **Back** brings you here again. On the Mac it is the ‹ button at the top left of the window, or ⌃⌘←, with ⌃⌘→ to go forward again — the same as a web browser, and it remembers the whole trail, not just the last step. On the iPhone the ordinary back arrow does it.

**Both directions.** A note's **Linked notes** section lists **Links to** — the notes this one points at — and **Linked from** — the notes that point at it. You never have to remember who mentioned what: point from wherever you happen to be writing, and the other end knows.

**Linking to a note you have not written yet.** Write the link anyway. It appears under **Not made yet** in the Linked notes section, and clicking it — or ⌘-clicking the link in the text — offers to make that note there and then, with the link's own words as its title. Choose whether it should be a goal, project, area or resource and it is created, opened, and the link is a real link from that moment.

**What counts as a link.** Both `[[double brackets]]` in the text and the `goal:`, `area:`, `parent:` and `related:` lines at the top of a note.

**Renaming.** If you rename a note, every `[[link]]` to it is rewritten. Links are for connections that cut across the structure — a resource three projects use, a person who turns up in two areas — while Goals, Areas and Projects are the structure itself.

## Finding things again

- **Recent** in the sidebar lists what you opened last, newest first, whatever kind it was. It is remembered between launches; **Clear** empties it.
- **Calendar › Notes** lists every daily and weekly note you have written, newest first, with the first line of each and its own search field. Day, Week and Month are for finding a date; Notes is for finding what you wrote.
- **Search Everywhere** (⇧⌘F) looks inside every note and task; see below.

### Search Everywhere

Filters can be typed straight into the query:

- `type:project`, `type:area`, `type:goal`
- `status:active`, `status:done`
- `tag:web` or `#web`
- `area:Health`
- `in:Projects` to limit to a folder
- `due:overdue`, `due:today`, `due:week`, `due:month`, `due:none`, `due:any`
- `is:open`, `is:done`, `is:task`
- quotes for an exact phrase: `"race day"`

## Tools: templates, snippets and tags

The sidebar group **Tools** holds the three things you use *on* your notes rather than notes
themselves. Press the word **Tools** to fold the group away and again to open it.

### Tags

A tag is a single word you put on a note or on a task, so that everything about one subject
can be found together later. `#travel`, `#waiting`, `#next` are tags. A tag has no spaces in
it: write `#next-week`, not `#next week`.

#### The three ways to add one

There are three ways to put one on something, and the Tags screen can also make, rename and
delete tags on their own.

**1. The Tags… button at the top of a note.** This is the easy one. Open the note and press
the button in the top row. It says **Tags…** when the note has none and lists them once it
has. A small panel opens:

- A field at the top for a new tag. Write the word and press Return. The `#` is added for you,
  a space becomes a hyphen, and any `#` you type yourself is taken out — so "Claude #Productivity"
  becomes the one tag `#Claude-Productivity`. For two tags, add them one at a time.
- Under it, every tag you already use anywhere. Press one to put it on this note, press it
  again to take it off. A filled circle means the note has it.

**2. Typing the `tags:` line yourself.** Press the **pencil** so you are writing, go to the top
of the note, and edit the line between the two `---`. Both of these work:

```
tags: [travel, summer]
```

```
tags:
  - travel
  - summer
```

The button writes the first form, so a list you typed the second way is rewritten to one line
the next time the button saves. Nothing is lost — the two mean the same thing.

**3. On a task, with `#`.** Write the tag anywhere on the task's own line. Two tags is two
words:

```
- [ ] Book the ferry #travel #summer
```

A task's tag belongs to that task, not to the note it sits in. That is why the Tags screen
counts notes and tasks separately.

#### Making a tag before you use it

The **Tags** screen has a field at the top. Write a word there and press **Make**. The tag is
kept even though nothing carries it yet, so it is offered in the **Tags…** panel of every note
from then on. It is marked **not used yet** in the list until something takes it.

#### Renaming a tag, and deleting one

Right-click a tag in the **Tags** screen (long-press on the iPhone):

- **Rename…** changes it in every note and every task that carries it, in one go. Both places
  are rewritten: the `tags:` lines and the `#tag` words.
- **Delete…** takes it out of every note and every task. The notes and the tasks themselves are
  kept — only the tag is removed.

Two things are left alone on purpose. `#next`, which is how the app marks a next action, cannot
be renamed or deleted; doing so would break that. And a longer tag that starts with the same
letters is never touched: renaming `#travel` leaves `#travelling` as it is.

If a note cannot be written — it is open elsewhere, or iCloud has not finished with it — the app
says which ones still carry the old tag rather than letting it pass.

#### The Tags screen

**Tags** in the sidebar lists every tag you have used, the most used first, with how many notes
and how many tasks carry each one. Press a tag to open it: the notes that carry it, then the tasks, open
ones first. Press a note to open it, or tick a task where it stands — the list stays where it
is. The field at the top finds a tag by name.

Right-click a tag (long-press on the iPhone) for **Search for #tag**, which hands it to the
Search screen where you can combine it with anything else.

## Templates and snippets

Two kinds of ready-made text, both ordinary markdown files in the `Templates` folder inside your vault. **Templates** are what a new note starts as; **snippets** are blocks of tasks you drop into a note you are already in. The **Templates** section in the sidebar lists them all and lets you edit them without leaving the app.

### The templates

Every new note is a copy of the matching file, with `{{title}}` and `{{date}}` filled in.

- **Project** — Outcome ("what does done look like?"), Tasks with a first step already written, Notes, and a Log with the day it was created. Frontmatter: `status: active`, empty `area:` and `due:`, `tags`, `related`.
- **Area** — Standard ("what does good look like here?"), Tasks, Notes. Frontmatter: `status: active`, `tags`.
- **Resource** — a plain note for reference material, with `related` ready to point at what it supports.
- **Goal** — Why it matters, the measure, and a "Serving this goal" section reminding you that projects and areas link here with `goal:`. Frontmatter: `horizon`, `target`, `measure`.
- **Daily** — the shape of a day's note.
- **Weekly** — the shape of a week's plan.

### The snippets

**Snippets** in the sidebar lists every block and what is in it; the file itself is edited beside the list on the Mac, and one tap down on the iPhone. Pick a block to use from the **Snippet** button beside **Add a task** in any note (a symbol rather than the word on the phone), and its lines are added to that note's Tasks. The ones the app starts with:

- **Delegate** — "Ask {{who}} to {{what}}" due tomorrow, with a subtask to check they have it in a week.
- **Waiting for** — one line tagged `#waiting`, dated a week out, so it turns up in a review rather than being forgotten.
- **Meeting** — prepare it today (with agenda and "what do I need from them" as subtasks) and write it up tomorrow.
- **Decision** — "Decide: …" a week out at high priority, with the options, who else has a say, and telling the people it affects.
- **Errand** — one line tagged `#errand`.
- **Follow up** — one line a week out.

### Filling in the blanks

- `{{title}}` is the note's name and `{{date}}` is today; in snippets `{{tomorrow}}` and `{{week}}` (a week from today) work as well.
- Anything **else** in double braces — `{{who}}`, `{{what}}`, `{{meeting}}` — is a question. The app asks for it when you use the snippet and puts your answer in everywhere that name appears. Leave one blank and the braces stay in the task, so you can see what is still missing.

### More than one template for the same thing

A template says what it makes in its own `type:` line, so you can keep several side by side — a plain **Project** and a **Client project**, say. The Templates section groups them under the kind of note they make, in that kind's colour, and each group folds.

- **+** in the toolbar adds one. Give it a name and say what it makes; it starts as a copy of the one that kind uses now.
- The template **named after its kind** — Project, Area, Resource, Goal — is the one used unless you choose another.
- When a kind has more than one, **New note** grows a **Start from** picker.
- Right-click a template — long-press on the phone — to **Rename** or **Delete** it. Deleting the template only removes the template; notes already made from it are untouched.

### Changing them

Open **Templates** in the sidebar, pick a file and edit it. It saves itself a moment after you stop typing, and when you move to another template or leave the section; **Save** (⌘S) is there when you want to be sure. Or edit the files in `Templates/` in any other editor — it is the same thing.

- Add a snippet by writing a new `## Heading` with task lines under it. Delete one by deleting its heading and lines. Rename it by renaming the heading.
- Add a template of your own by putting a file in the folder; the six named above are the ones the app looks for when it makes a note, so a new file is for your own use.
- Delete a template and the app falls back to a bare note with just a title and a type.

**This page describes the ones the app starts with.** Once you change them, the manual will not follow — the Templates section always shows what you actually have.

## Quick capture

- ⇧⌘N opens the capture panel in the app. On the Mac there is also a panel in the menu bar.
- On the iPhone, Share › PARAGON sends text or a link.
- Other apps and Shortcuts can call `amspara://capture?text=Call%20the%20bank&target=inbox`.

Captures land in the Inbox, today's note or a project, and are filed the next time the app is active.

## Backups

The app saves a copy of the whole vault before every sync and once a day, keeping the last ten. They live inside the vault, in a hidden folder called `.ams-para/Backups`, as ordinary folders of markdown files.

- **Settings › Backups › Back up now** saves one immediately. Nothing is saved twice if nothing changed.
- **Show in Finder** opens the folder, where you can drag a single note back by hand.
- **Restore a copy** writes a whole backup back into the vault. What you have at that moment is saved as a backup first, and notes you created after the backup are left where they are.

Time Machine covers the rest: these backups sit inside the vault folder, so they do not protect against losing that folder itself.

## On the iPhone

**Reading or writing.** A note opens ready to write in. The **pencil** button at the bottom of the note (in the toolbar on the Mac) turns writing on and off. When the pencil is lit and its frame is solid, you are writing. When it is grey with a dashed frame, you are reading: the note is shown rendered — headings, bold, tappable links — and there is no cursor. If a note ever seems to refuse your typing, look at that button.


Sync with Reminders from the phone with the button in the top right of Today and Inbox, or Settings › Reminders sync › Sync now. The first sync is when iOS asks for permission to use Reminders.

On the phone, a note's own actions — Rename, Archive and Delete — are behind the **⋯** button at the top right of the note. On the Mac they are buttons in the toolbar. The pencil is not in there: it is always on screen.

The phone shows four tabs. **Today** and **Inbox** are the same lists as on the Mac. **Browse** holds everything else: Goals, Projects, Areas, Resources, Archive, Calendar, Time Blocks, Done, Review, Map, Search, and Settings with Help. **Capture** opens the capture panel. Tap a note to open it and swipe from the left edge to go back. Long-press a task for the task menu. The share sheet in other apps has a PARAGON entry that sends text or a link to the Inbox.

## Mac and iPhone together

Keep the vault in iCloud Drive and pick the same folder on both devices. iCloud carries the files across. Each device syncs with Reminders on its own.

### How iCloud moves the files

There is no PARAGON server. Everything the app knows lives in the markdown files in your vault folder, and iCloud is what copies those files between the Mac and the phone — the same way it does for any other folder in iCloud Drive.

That has one consequence worth knowing. iCloud does not push every file to every device the moment it is written. It tells the other device that a file exists and leaves the contents behind until something asks for them. Until then there is only a marker where the file should be: the name is reserved, but the note is not really on the phone yet. This is normal iCloud behaviour, and it is why "Optimise storage" on a phone with little space left can leave a lot of your vault as markers.

The app therefore asks. When it starts, when you open a vault, and once a minute while it runs, it looks through the vault for anything that has not arrived and asks iCloud to fetch it. A few seconds later the file is there and the app reloads by itself. You do not have to do anything.

### When something takes a moment to arrive

Make a note or a template on the Mac and it usually appears on the phone within seconds of opening the app. If it does not, it is nearly always one of these:

- The phone has no connection, or is on a network that is being slow. iCloud is doing nothing until it can.
- The Mac has not finished uploading. Look at the file in Finder: a small cloud with an arrow means it is still on its way up.
- The phone app has been open the whole time and is between checks. Switch away and back, and it looks again.

While a template is on its way, the Templates list names it and says "coming from iCloud" instead of pretending it is not there.

### If a file seems stuck

Open the Files app on the iPhone, find your vault folder, and tap the file once. That is the same request the app makes, and it usually settles it. If a whole folder looks empty on the phone but is full on the Mac, check that both devices point at the same folder under Settings › Vault, and that iCloud Drive is switched on in iOS Settings.

### Editing the same note on both devices

The app checks every few seconds whether files changed outside it and reloads them. It never writes over a newer file. If you were typing in a note that changed elsewhere at the same time, your text is saved as a copy named "… (conflict date time).md" next to the note, and the note shows the other version. Merge the two by hand when that happens; it is rare.

A note that has not arrived yet is treated as a note that exists. The app will not make a fresh empty one in its place, which would leave you with two versions of the same note for iCloud to argue about. If you open one before it has landed, it says so and you can try again a moment later.

## Getting new versions

Both apps come from TestFlight. When a new build is sent, TestFlight tells you and you press
Update: on the iPhone in the TestFlight app, on the Mac in TestFlight for Mac. The Mac app
lives in your Applications folder like any other app.

## Keyboard shortcuts

- ⌘N new note, ⇧⌘N quick capture, ⇧⌘F search everywhere, ⇧⌘R sync with Reminders
- ⌃⌘← back to the note you came from, ⌃⌘→ forward again
- ⌘⌫ delete the open note (it waits in Deleted)
- ⌃⌘D copy diagnostics, a log you can paste when reporting a problem
- The sync button's menu holds the sync preview and the last report

## When something looks wrong

Help › Copy Diagnostics (⌃⌘D — control, not option) copies a short log: the build number, what was clicked, which section and note are open, and the window layout. Paste it into the chat with the developer. The build number is also shown at the bottom of the sidebar.
