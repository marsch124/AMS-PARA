# AMS PARA

A personal project and action management app built on plain markdown files, organised the PARA way
(Projects, Areas, Resources, Archive), with tasks that sync both ways with Apple Reminders.

It follows the NotePlan conventions: every note is a `.md` file in a folder you own (Finder, iCloud Drive,
NotePlan's own folder), frontmatter carries the metadata, and tasks are ordinary `- [ ]` lines inside the notes.
You can keep editing the same files in NotePlan, Obsidian or any text editor.

## What is in this repository

| Part | Where | What it does |
| --- | --- | --- |
| `AMSParaCore` | `Sources/AMSParaCore` | Swift package, no UI. Markdown notes with frontmatter, NotePlan style task lines, the PARA vault on disk, a note index (backlinks, tags, open tasks) and the two-way Reminders sync engine. |
| Unit tests | `Tests/AMSParaCoreTests` | Cover parsing, note editing, the vault and every sync scenario (create, edit, complete, delete, conflicts, second device). |
| `AMSPara` app | `App/AMSPara` | SwiftUI app for macOS 14 and iOS 17. Sidebar (Inbox, Today, Calendar, Weekly review, Projects, Areas, Resources, Archive), note list, markdown editor with rendered preview and clickable wikilinks, task checklist, Reminders sync via EventKit, settings. |
| `project.yml` | repository root | XcodeGen spec that produces the Xcode project for the app. |
| `Example Vault` | `Example Vault/` | A small sample vault to try the app with. |

## Building on the Mac

Requirements: Xcode 15.4 or newer (Xcode 16 recommended), and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd AMS-PARA
swift test                  # runs the core tests (no Xcode project needed)
xcodegen generate           # creates AMSPara.xcodeproj from project.yml
open AMSPara.xcodeproj      # select the AMSPara scheme, set your Team under Signing, run
```

If you prefer not to use XcodeGen: create a new multiplatform SwiftUI app in Xcode, add the files under
`App/AMSPara`, add the local package (File › Add Package Dependencies › Add Local, pick this folder) and
link `AMSParaCore`. Add `NSRemindersFullAccessUsageDescription` to the Info.plist and enable the
Calendars personal-information entitlement plus user-selected file access under App Sandbox.

The code in this repository was written without access to a Mac, so the first `swift test` and the first
Xcode build may surface compiler complaints that need a quick fix. The core logic is covered by tests so
behaviour problems should show up there first.

## First run

1. Start the app and choose a vault folder. An empty folder works; the app creates `Projects/`, `Areas/`,
   `Resources/`, `Archive/`, `Templates/`, `Inbox.md` and `.ams-para/config.json`.
   To try it out, copy `Example Vault` somewhere and choose that.
2. Press the sync button (⇧⌘R). macOS asks for Reminders access once.
3. Open Apple Reminders. You will find an `Inbox` list plus one list per project and area.

## The vault

```
My PARA/
├── Inbox.md                 quick capture, mirrored to the "Inbox" list
├── Calendar/                daily notes YYYYMMDD.md and weekly notes YYYY-Www.md, like NotePlan
├── Projects/                one note per project, mirrored to a list with the project's name
├── Areas/                   one note per area, mirrored too (can be switched off)
├── Resources/               reference material, any depth of sub-folders
├── Archive/                 inactive notes, never synced
├── Templates/               Project, Area, Resource, Daily and Weekly templates (edit as you like)
└── .ams-para/               config.json and per-device sync state
```

### Daily notes, weekly notes and the calendar

The Calendar section has three views. **Day** shows a date picker; picking a day opens
`Calendar/YYYYMMDD.md`, created from `Templates/Daily.md` when needed. **Week** lists the seven days of an
ISO week with everything due and done on each day and a button for the weekly note
(`Calendar/2026-W36.md`, from `Templates/Weekly.md`, the NotePlan naming). **Month** is a grid with the
number of tasks due and completed per day. The top of a daily note lists every task due that day, the top of
a weekly note lists what is due that week, both with arrows to move back and forth. Tasks written in daily
or weekly notes sync to one shared "Daily Notes" list in Reminders; a reminder added to that list lands in
today's daily note.

### Weekly review

The Weekly review section walks through: empty the inbox, reschedule overdue tasks, then a health check
of every active project and area. A project is flagged when it has no open task, has overdue tasks, is past
its due date, has not changed for 14 days, or has not been reviewed for 7 days (both configurable in
Settings). Right-click a project to mark it reviewed (writes `reviewed: YYYY-MM-DD` into the frontmatter),
put it on hold, mark it done or archive it. "Mark all reviewed" stamps every active project at once.

### Editor and preview

The editor toolbar switches between Edit, Split and Preview. The preview renders headings, lists, quotes,
code and inline styles, tasks can be ticked off in place, and `[[wikilinks]]` are clickable. A link to a
title that does not exist yet creates a new resource note with that title.

### Note frontmatter

```yaml
---
title: Website relaunch
type: project            # project | area | resource
status: active           # active | on-hold | done | archived
reviewed: 2026-09-05     # set by the weekly review
area: Business           # the area this project belongs to
due: 2026-11-30
tags: [web, marketing]
related: [Brand guide]   # notes this one links to (titles or paths)
reminders-list: Web      # optional, overrides the Reminders list name
sync: false              # optional, keeps this note out of Reminders
---
```

Every note also gets a `## Tasks` section by template; imported reminders are appended there.

### Task syntax (NotePlan compatible)

```
- [ ] Open task
- [x] Done task @done(2026-09-05 10:00)
- [-] Cancelled task
- [>] Task scheduled elsewhere
- [ ] Priority with !, !! or !!! anywhere in the line !!
- [ ] Due date >2026-09-10
- [ ] Due date with a time >2026-09-10T14:30
- [ ] Tags stay in the text #finance #call
- [ ] The sync adds a stable id at the end ^t3fa2c1
- [ ] A parent task
    - [ ] An indented line below it is a subtask
```

`*` bullets work too. Anything inside a code fence is ignored. A due time makes the reminder a timed one
with an alarm at that moment; a date alone is an all-day reminder.

Subtasks: Apple's EventKit has no public API for subtasks, so each subtask becomes its own reminder in the
same list, titled `Parent › Subtask`. Renaming the subtask in Reminders keeps the prefix out of your note,
renaming the parent in the note renames all its subtask reminders. In the app, right-click a task in the
checklist to add a subtask.

### Reference material

Resources are the "library" that supports projects, areas and life. Link them with `related:` in the
frontmatter or `[[wikilinks]]` in the text. The app shows linked notes and backlinks at the top of every
note, so a project sees its resources and a resource sees where it is used. Sub-folders inside
`Resources/` are fine (`Resources/Books/Deep Work.md`).

## How the Reminders sync works

- **Mapping.** `Inbox.md` ↔ the `Inbox` list. Each project or area note ↔ a list named like the note
  (or its `reminders-list`). All daily notes ↔ the `Daily Notes` list. Archived notes and notes with
  `sync: false` are left alone.
- **Identity.** On first sync every task line gets an id (`^t3fa2c1`). The mirrored reminder carries
  `ams-para:^t3fa2c1` in its notes field. Both survive edits, moves between notes and other devices.
- **Fields.** Title (including `#tags`), open/done, due date, due time and priority are kept identical on
  both sides.
- **Changes in a note** update, complete or delete the reminder. Moving a task line to another
  project note moves the reminder to that list.
- **Changes in Reminders** update or complete the task line. A new reminder in a mapped list is appended
  to the note's `## Tasks` section. Deleting a reminder marks the task `- [-]` cancelled instead of
  deleting your text.
- **Conflicts.** If the same task changed on both sides since the last sync the note wins (switchable to
  "the reminder wins" in Settings). Conflicts are listed in the sync report.
- **Devices.** EventKit identifiers are device local, so the sync state file is per device. A second Mac or
  iPhone links to the existing reminders through the marker and never creates duplicates.

## Roadmap

- Quick capture from the share sheet on iOS and a menu bar item on macOS
- Full-text search with tag and status filters
