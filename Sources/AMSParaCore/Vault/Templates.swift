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

    public static let defaults: [(String, String)] = [
        ("Project", project),
        ("Area", area),
        ("Resource", resource),
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
