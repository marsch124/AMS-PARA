import Foundation

/// Default note templates. Placeholders: `{{title}}`, `{{date}}`.
public enum Templates {
    public static let inbox = """
    ---
    title: Inbox
    type: inbox
    ---
    # Inbox

    Quick capture. Anything written here as a task shows up in the "Inbox" list in Apple Reminders.

    ## Tasks

    """

    public static let project = """
    ---
    title: {{title}}
    type: project
    status: active
    area:
    due:
    created: {{date}}
    tags: []
    related: []
    ---
    # {{title}}

    ## Outcome

    What does "done" look like?

    ## Tasks

    - [ ] Define the outcome and the first step

    ## Notes

    ## Log

    - {{date}}: Project created

    """

    public static let area = """
    ---
    title: {{title}}
    type: area
    status: active
    created: {{date}}
    tags: []
    ---
    # {{title}}

    ## Standard

    What does "good" look like in this area?

    ## Tasks

    ## Notes

    """

    public static let resource = """
    ---
    title: {{title}}
    type: resource
    created: {{date}}
    source:
    tags: []
    related: []
    ---
    # {{title}}

    ## Summary

    ## Key points

    ## Links

    """

    public static let daily = """
    # {{title}}

    ## Tasks

    ## Notes

    """

    public static let weekly = """
    # {{title}}

    ## Focus

    What matters most this week?

    ## Tasks

    ## Review

    - What went well?
    - What to change next week?

    """

    public static let goal = """
    ---
    title: {{title}}
    type: goal
    horizon: year
    status: active
    target:
    measure:
    goal:
    created: {{date}}
    tags: []
    ---
    # {{title}}

    ## Why

    What changes in my life when this is true?

    ## What done looks like

    ## Serving this goal

    Projects and areas link here with `goal: {{title}}` in their frontmatter.

    ## Notes

    """

    public static let defaults: [(String, String)] = [
        ("Project", project),
        ("Area", area),
        ("Resource", resource),
        ("Daily", daily),
        ("Weekly", weekly),
        ("Goal", goal),
    ]

    public static func minimal(kind: ParaKind) -> String {
        "---\ntitle: {{title}}\ntype: \(kind.frontmatterType)\ncreated: {{date}}\n---\n# {{title}}\n\n"
    }

    public static func fill(_ template: String, title: String, date: DateOnly) -> String {
        template
            .replacingOccurrences(of: "{{title}}", with: title)
            .replacingOccurrences(of: "{{date}}", with: date.description)
    }
}
