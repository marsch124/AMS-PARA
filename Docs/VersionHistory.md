# Version history

The build number is shown at the bottom of the sidebar. Newest first.

## Build 129 · 11 September 2026

- **A new app icon**, the first step of the rename to PARAGON. A white frame now sits outside the gold goals frame, with a small star resting on its top edge. Everything inside — the four PARA squares and the tick — is unchanged.
- The star fades out at the two smallest Mac sizes, which only ever appear in a Finder list. It is there in the Dock, in the sidebar and on the Home screen.

## Build 128 · 11 September 2026

- **A single tap puts the cursor in a note on the iPhone.** No more pressing and holding. The cause was a link-tap handler added in build 114: a text view uses your tap to place the cursor, and having a second handler watching for taps made that ambiguous. It is gone.
- **Following a `[[link]]` on the phone is done in Read**, which is one tap away in the bar below the note. Edit is for writing, Read is for reading and following links.
- The Read / Edit button is now just its icon, in a border.

## Build 127 · 11 September 2026

- **A Read / Edit button on the iPhone**, in the bar at the bottom of the note where it is always in reach. It says what it will switch to. A note left in Read looks exactly like an editor that refuses to type — which is what went wrong yesterday — so it is one tap now instead of a setting buried in the ⋯ menu. Split is gone from the phone; it was never useful on a screen that size.
- **The note text is no longer penned into a small window while you edit.** It grows to its full height and the page scrolls as one thing, so a long note reads properly instead of showing a slice of itself.

## Builds 123 to 126 · 11 September 2026

- Four builds spent chasing a fault that was not there. Typing in a note on the iPhone appeared to be broken; it was in fact set to Read, where there is nothing to type into. The changes made and undone in between left the app exactly where it started. Build 127 fixes the real inconvenience — and makes Read impossible to be stuck in without noticing.

## Build 122 · 11 September 2026

- **Fix: on the iPhone the long press into the Work section only ever worked once.** It opened Work the first time and did nothing every time after, until the app was quit. Now every press opens it. (The Work row at the foot of the Browse list was still there in the meantime — that was the way back in.)

## Build 121 · 10 September 2026

- **The "More" fold in the new-note sheet is gone.** Everything is on screen at once: name, kind, and whatever settings apply to that kind. Nothing to open.

## Build 120 · 10 September 2026

- **Fix: ⌘N opened an empty second window instead of the new-note sheet.** macOS puts its own **New Window** on ⌘N and it was winning; the app's New Note had the same shortcut and never got a look in. ⌘N is now New Note, and New Window is gone from the File menu — one window is what this app is for.

## Build 119 · 10 September 2026

- **New note (⌘N) asks one thing, not nine.** The name field is first with the cursor already in it, so a note is a name and Return. Under it, the four kinds as coloured buttons — the same gold, green, pink and blue as the sidebar — and one line saying what that kind is for.
- **Everything else is behind "More".** Template, what an area is part of, a goal's horizon and target date, the goal a project serves. It is shut every time the sheet opens, and the label says what is inside so you know when to open it.
- **A project can now name the goal it serves as you make it**, instead of being opened afterwards to add the line by hand.
- The heading says **New project**, not "Projects" — it is one note, not the list it lands in.

## Build 118 · 10 September 2026

- **Back and Forward.** Follow a link to another note and **Back** brings you where you were — the ‹ button at the top left of the window, ⌃⌘←, or **Go › Back** in the menu bar; ⌃⌘→ goes forward again. It remembers the whole trail, not just the last step, and steps over notes deleted in the meantime. (The iPhone already had its own back arrow.)
- **A link to a note that does not exist yet can make it.** ⌘-click the link — or click it in the new **Not made yet** list in the note's **Linked notes** section — and you are asked what kind of note it should be. It is created with the link's own words as its title, opened, and the link works from that moment. A link written inside a work note makes a work note.
- Links with no note behind them are no longer silent: they are listed under **Not made yet**, so a link you meant to follow up is visible rather than forgotten.
- **`[[Note|call it something else]]` and `[[Note#a heading]]` now work everywhere.** They already worked in Preview; clicking them in the editor, and the Linked notes lists, went looking for a note with the whole phrase as its name and never found one.
- While notes are still arriving from iCloud, the app no longer says a note does not exist — it says how many are still coming. Saying otherwise is how you end up with two copies of the same note.

## Build 117 · 10 September 2026

- **Fix: the long press could not open Work on the iPhone.** The "Browse" title the press belongs to was drawn behind iPhone's own large title, so nothing ever reached it. The title is now the small one at the top of the screen and takes the press properly — and opening Work goes straight to it instead of only adding the row at the foot of the list.
- **A second way in on the iPhone: long-press the "Build 117" line** at the very bottom of the Browse list. Easier to hit than the title.

## Build 116 · 10 September 2026

- **Fix: choosing a note from the `[[` list spun the app.** Writing the chosen title told the editor to update, which told the app to update, which told the editor again. The chosen title is now written once and everything the editor reports back waits until the screen has finished drawing.

## Build 115 · 10 September 2026

- **Fix: the `[[` list was cut off at the bottom of the editor.** When the cursor is near the foot of the note there is no room under it, so the list now opens upwards instead — and it always stays inside the editor rather than sliding off an edge.

## Build 114 · 10 September 2026

Linking notes with `[[ ]]`.

- **Type `[[` and a list of your notes drops under the cursor.** Keep typing to narrow it, ↑ ↓ to move, Return or a click to put it in. It completes to `[[Title]]` and leaves the cursor after the brackets.
- **⌘-click a link to open that note** (a tap on the iPhone, and a plain click in Preview). An ordinary click still just places the cursor, so editing is never hijacked; on the Mac the pointer turns into a hand over a link.
- **Linked notes is now two lists: "Links to" and "Linked from"**, so you can see who points at whom instead of one mixed pile. Links in the text count as well as `goal:`, `area:`, `parent:` and `related:` lines.
- **Work notes and ordinary notes never see each other.** Inside a work note, `[[` offers work notes; everywhere else it offers the rest of the vault.
- A link to a note that does not exist yet says so when you click it. Making one from the link comes next.

## Build 113 · 10 September 2026

- **The coloured line along the top of the right-hand panel is gone.** Only the even tint is left.

## Build 112 · 10 September 2026

- **A separate place for work notes.** Plain notes in a `Work` folder in your vault, kept out of Today, All actions, the Map, the weekly review, the main search — and out of Reminders. No projects, no goals, no dates: notes and a list of them, with its own search box.
- **It is not in the sidebar.** To open it: **long-press the PARA heading** in the sidebar on the Mac (or ⌃⌘W), and **long-press the Browse title** on the iPhone. The row appears until you press **Hide** or quit the app.
- The Work folder is only created when you make the first note there, so a vault without work notes shows no sign of it.

## Build 111 · 10 September 2026

- **The iPhone gets the section's colour too.** The phone has no right-hand panel, so the note screen itself carries the tint of the section you came in through.

## Build 110 · 10 September 2026

- **The gradient at the top of the right-hand panel is gone.** The section's colour now sits evenly over the whole column, with the hairline along the top.

## Build 109 · 9 September 2026

- **The section's colour on the right-hand panel is stronger**, both over the whole column and in the wash at the top — the setting you chose from the preview.

## Build 108 · 9 September 2026

- **The section's colour now sits over the whole right-hand panel**, not only the top of it: the faintest tint everywhere, a little more at the top, and the hairline. The note's own text area keeps its plain background so reading and writing are unaffected.
- The "Linked notes" heading takes the note's colour, like "Tasks" already did.

## Build 107 · 9 September 2026

- **The right-hand panel now carries the colour of the section you are in** — green in Projects, pink in Areas, gold in Goals, blue in Resources and Templates, and so on. A hairline along the top and a wash that has faded away before it reaches the text. It follows the section rather than the note, so it stays put as you click from one note to the next.

## Build 106 · 9 September 2026

- **A sync will not start while notes are still coming from iCloud.** It would only see part of your vault. The app says how many are outstanding and asks you to try again in a moment. (Even before this, a sync never deleted a reminder whose note it could not read — that rule is what kept your Reminders intact today.)
- **The app is now told when a note arrives** instead of looking every ten seconds. macOS reports what iCloud is doing with the vault's files, so notes appear as they come down. The old check stays underneath as a backstop.

## Build 105 · 9 September 2026

- **A note iCloud cannot deliver now says "still coming from iCloud"** rather than showing a technical file error. Build 104's fix stands; this is the wording and the count behind it.

## Build 104 · 9 September 2026

**This is the fix for the empty vault.** Your diagnostics showed the app had loaded exactly one note and had not failed to read a single file — it never saw them. When iCloud has not sent a note to a device it can leave a hidden marker where the file belongs, and the app's note listing skipped hidden files. Finder showed you `Testproj.md` with a cloud; the app looked in the same folder and found nothing at all.

- **The app now sees those markers, counts them, and fetches the notes behind them** — a few per load, so it never sits still, with the rest listed as "still coming from iCloud".
- **Opening such a note now fetches it** instead of reporting it missing.
- Neither the restore nor anything you did caused this. The notes were in iCloud the whole time.

## Build 103 · 9 September 2026

- **Copy Diagnostics has a shortcut that works.** It was ⌥⌘D, which is macOS's own "hide the Dock" — the app never saw it. It is **⌃⌘D** now (control, not option), and it is still in the Help menu.

## Build 102 · 9 September 2026

- **A vault that is all in iCloud now fills in gradually instead of stopping the app.** Waiting for a note to come down takes time, so the app waits for a handful per load and asks for the rest, then picks up the next few seconds later. You see the count going down rather than a frozen app — and the phone cannot be killed for taking too long.

## Build 101 · 9 September 2026

- **The app now reads a note the way TextEdit does.** This is the real cause of today's scare. When iCloud keeps a file's contents off the Mac, a plain read of it fails — so TextEdit could open a note while the app called it unreadable and drew an empty vault. The app now asks macOS for the file properly, which makes iCloud fetch it first and wait for it. Notes appear whether or not they happen to be downloaded.
- **Fix: the iPhone app could be killed at launch.** Since build 95 the app asked iCloud about every file in the vault before it finished starting up. On a phone that can take long enough for iOS to give up and close the app. That now happens in the background, out of the way of starting.

## Build 100 · 9 September 2026

- **The app no longer shows an empty vault when it simply cannot read your notes.** If iCloud has the contents and this device does not, the app used to draw "No projects yet" — which looks exactly like losing everything. It now says how many notes are still coming, at the foot of the sidebar and in place of the empty-section message, with an **Ask iCloud again** button.
- **It asks iCloud for those notes itself.** A note it could not read because the contents are not here is now requested there and then, so it arrives without you going into Finder.
- **A sync report lists them too**, so it is plain that a sync ran while part of the vault was missing — and, as before, nothing is deleted in Reminders for a note the app cannot see.

## Build 99 · 9 September 2026

Hardening, first part: the things the app does that touch several notes at once.

- **Moving an action between notes can no longer lose it.** It used to be taken out of the first note and then written to the second; if that second write failed — the note had just changed on the other device — the action was gone from both. The order is turned round: the receiving note is written first, so the worst case is the action appearing twice, and the app says so and tells you which one to delete.
- **Making a note out of an Inbox line can no longer lose the line.** The line was removed first and the note made afterwards, so a name already in use meant the line vanished and no note appeared. The note is made first now.
- **Renaming tells you when it could not follow every link.** A rename rewrites `goal:`, `area:`, `parent:` and `[[links]]` in every note that named the old title. Failures were silently ignored, leaving links pointing at a title that no longer existed. Now you are told how many notes still name the old title, so you can search for it.
- **A rename makes a backup first.** It is the one action that can touch every note in the vault.
- **Rearranging a list reports once, not once per note.** And a note whose file changed while you were dragging is written again rather than skipped.
- Underneath all of these: when a note has changed on disk in the moment between reading and writing, the app now re-reads it and makes the same change to what is actually there, instead of giving up. Nothing of the other device's work is overwritten.

Hardening, second part: the backups.

- **Restoring a backup no longer stops halfway.** A single file it could not write used to abort the whole restore, leaving the vault half old and half new with no word about which. It now restores everything it can and tells you exactly which files it could not put back.
- **A backup is no longer lost to one unreadable file.** The same problem the other way round: one file that could not be copied meant no backup at all that day. Those files are skipped, listed inside the backup in `skipped.txt`, and the rest is saved. If nothing at all could be copied, you are told rather than left with an empty folder that looks like a safe copy.
- **A second backup in the same minute was invisible.** It got a slightly different folder name that the app could not read back, so it never appeared in the list and was never cleaned up.
- **A backup asks iCloud for anything missing first**, so it does not quietly copy a vault with holes in it.
- Restoring is now covered by tests: that a deleted note comes back, that a note made after the backup is left alone, that your current text is kept as a backup of its own first, and that a file it cannot write is reported.

## Build 96 · 9 September 2026

- **The manual explains iCloud.** "Mac and iPhone together" now says how the files actually move between the two devices, why a new note or template can take a moment to appear on the phone, what the "coming from iCloud" line means, and what to do if something looks stuck.

## Build 95 · 9 September 2026

- **A new template made on the Mac now arrives on the iPhone.** iCloud does not send a file to the phone until something asks for it; until then there is only a hidden stub, which the app walked straight past — so the template looked as though it had never left the Mac. The app now asks iCloud for everything it is missing at launch, when you open a vault and once a minute after that. Templates still on their way are listed as "coming from iCloud".
- **The same was true of notes**, not only templates: one written on the Mac could stay invisible on the phone. Fixed by the same change.
- **A note or template that is on its way is no longer written over.** Because the stub is not the file, the app thought the note was missing and could make a fresh empty one in its place — which would then collide with the real one in iCloud. Everything that creates, renames or archives a file now counts a file that iCloud is still sending as being there.

## Build 93 · 9 September 2026

- **Fix: the Templates list drew its rows on top of each other.** The headings and the rows below them overlapped. Plain sections now, with a fold arrow in each heading.
- **Fix: New template really asks what it makes.** The choice was in a Mac alert, which quietly drops anything that is not a text field — so the picker never appeared and every new template came out a project. It is a proper panel now, with the name, what it makes, and a sentence explaining what a template is for.
- **The Save button says "Saved" when there is nothing to save**, instead of going grey. Your typing is written a moment after you stop; the dimmed button made it look as though nothing had happened.
- **A template edited on one device now reaches the other.** The app watches the notes for outside changes but was not watching the Templates folder, so an edit made on the Mac sat there until the phone was restarted.
- A template that is not the default for its kind says so: "One way to start a project note. Pick it under New note › Start from."

## Build 92 · 9 September 2026

- **Fix: you can type in a template.** The editor showed the file but would not take a keystroke on the Mac. It is the same editor the notes use now — proven, and it colours the markdown while you write.
- **Templates save themselves** a moment after you stop typing, and when you switch to another one or leave the section. **Save** (⌘S) is still there when you want to be sure.

## Build 91 · 9 September 2026

- **The manual now says "long-press" where it meant it.** It said "right-click" throughout, which is a Mac instruction and no help on the iPhone. Every place that offers a menu now names both, and there is a line near the top saying that right-click on the Mac is long-press on the phone.

## Build 90 · 9 September 2026

- **Templates are grouped and colour-coded** by the kind of note they make — Goals gold, Projects green, Areas pink, Resources blue — and each group folds.
- **You can have more than one template for the same kind.** Press **+** to add, say, a "Client project" beside the plain Project one; it starts as a copy of the current one. When a kind has more than one, **New note** grows a **Start from** picker. The template named after its kind stays the default.
- **Rename** and **Delete** a template by right-clicking it. Deleting removes only the template; notes made from it are untouched.
- **Fix: templates can be opened and edited on the iPhone.** Tapping one did nothing there — the phone had no way to push the editor. It opens like a note now.

## Build 89 · 9 September 2026

- **Fix: the note screen's top bar on the iPhone.** Edit / Split / Preview, Archive, Rename and Delete were all separate buttons up there, and on a phone they collided — the three-way switch was squeezed into a few overlapping letters next to the title.
- They are one **⋯** menu now: the view mode at the top, then Rename, Archive and Delete. The Mac keeps the row of buttons, which it has room for.

## Build 88 · 9 September 2026

- **Templates, in the app at last.** A new **Templates** section in the sidebar lists the files a new note starts from — Project, Area, Resource, Goal, Daily, Weekly — and lets you edit and save them without leaving AMS PARA. They were always there in your vault's `Templates` folder; now you can reach them.
- **Snippets.** Ready-made blocks of tasks you drop into a note: press **Snippet** beside Add a task. The app starts with **Delegate**, **Waiting for**, **Meeting**, **Decision**, **Errand** and **Follow up**.
- A snippet can ask for words. `{{who}}`, `{{what}}` and the like are filled in from a small form; `{{date}}`, `{{tomorrow}}` and `{{week}}` are worked out for you.
- Snippets live in `Templates/Snippets.md`, one `##` heading each — add, rename or delete them by editing that file, in the app or anywhere else.
- Help › How it works now lists every template and snippet and what is in them.

## Build 87 · 9 September 2026

- **You can no longer be in Arrange mode without noticing.** A tinted strip runs across the top of the map while it is on, saying what a drag will do and how many boxes are marked, with **Reset all** and **Done** in it. Esc leaves the mode too.
- **The zoom and Arrange buttons moved to the left** of the Map's toolbar, where the eye starts. Export stays on the right.

## Build 86 · 9 September 2026

- **Fix: tapping a box and sweeping a rectangle work again.** In build 85 neither did, and it was my mistake twice over.
  - Every box was placed in a way that made its touch area cover the whole map, so the box drawn last quietly swallowed every click anywhere on the canvas. Boxes now claim only their own space.
  - The tap and the drag were two separate gestures on the same box, and they argued over which one a click belonged to. One gesture now handles both: no movement means a tap, movement means a move.
- The background works the same way — sweep to mark, click to clear — through a single gesture.

## Build 85 · 9 September 2026

- **Mark boxes by sweeping a rectangle.** On the Mac, with **Arrange** on, drag across the empty background and every box the rectangle touches is marked.
- It **adds to** what you already tapped rather than replacing it, so tapping single boxes and sweeping a cluster can be used together.
- On the phone a drag across the background scrolls the map, so there is no rectangle there; tapping boxes works as before.

## Build 84 · 9 September 2026

- **Move several boxes at once on the Map.** With **Arrange** on, tap boxes to mark them — the toolbar counts them — then drag any one of them and the whole set moves together, keeping its shape.
- Tap a marked box again to unmark it, tap the empty background to clear the marks. Turning Arrange off clears them too.
- Dragging a box that is not marked still moves only that box, and leaves your marks alone.
- Right-click a marked box › **Place these N automatically** hands the whole set back to the layout.

## Build 83 · 9 September 2026

- **Park the map's boxes where you want them.** A new **Arrange** button in the Map's toolbar. While it is on, dragging a box moves it and it stays where you let go; while it is off, dragging links things as before. One drag never means two things.
- **The position lives in the note**, as a `map: 320,180` line in its frontmatter — so it travels with the note when you rename or move it, it is the same on the Mac and the iPhone, it is in your backups, and zooming does not disturb it. Delete the line in any editor and the app places the box again.
- Notes you have not placed are still arranged by the app, around the ones you have. A brand new note can therefore land on top of a box you parked; move either one.
- **Right-click a box while arranging › Place this one automatically**, or **Reset all** in the toolbar, hands them back to the layout.
- Only proper notes can be parked; task chips and the dashed group boxes always follow the layout.

## Build 82 · 9 September 2026

- **The Map is now something you work in, not only look at.** Drag a box onto another and the link is written into the notes:
  - a **project onto an area** puts the project in that area;
  - a **project or area onto a goal** makes it serve that goal;
  - an **area onto another area** makes it a sub-area;
  - a **goal onto a goal** makes it a subgoal;
  - a **task chip onto a project or area** moves the task there.
- The box under the pointer is outlined while it would take the drop. A pair that means nothing is refused and the drag springs back.
- The map redraws straight away, so you see the new shape immediately.
- Boxes still can't be dragged to a position of your own choosing: the layout is worked out from your links, so a hand-placed box would be moved again by the next change.

## Build 81 · 9 September 2026

- **Export the Map.** A new **Export** button in the Map's toolbar: **PDF** (vector, so it prints and zooms without going fuzzy), **PNG**, **Copy image**, and **Copy as outline** — the same tree as indented text you can paste anywhere. The Mac asks where to save; the phone opens the share sheet.
- **Help is now something you can navigate.** How it works and Version history are no longer one long scroll: every heading opens and closes, and a search box at the top filters the page down to the parts that mention what you typed, already opened. **Open all** / **Close all** in the same row.
- **The manual has been reorganised** to match: related things sit together (renaming and deleting are under Notes, the sync preview under Reminders sync, Recent and Search under "Finding things again"), the Inbox has a section of its own, and long sections have sub-headings.

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
