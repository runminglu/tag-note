import XCTest
@testable import TagNote

final class MarkdownDocumentTests: XCTestCase {
    func testParsesSeedStyleNoteIntoDocumentBlocks() {
        let markdown = """
        # Welcome to TagNote!

        TagNote organizes your notes with **tags** instead of folders.

        ## Here's what makes it different:

        - **Tag freely** — every note can have multiple tags
        - **Filter by tags** — click tags in the sidebar
        - **Search everything** — full-text search works alongside tag filters

        ### Quick start

        1. Click **New note**
        2. Write in Markdown
        3. Add tags

        > Keep the notes you need.

        ---

        ```
        tsn export
        ```
        """

        let document = MarkdownDocument.parse(markdown)

        XCTAssertEqual(document.blocks, [
            .heading(level: 1, text: "Welcome to TagNote!"),
            .paragraph("TagNote organizes your notes with **tags** instead of folders."),
            .heading(level: 2, text: "Here's what makes it different:"),
            .unorderedList([
                MarkdownListItem(blocks: [.paragraph("**Tag freely** — every note can have multiple tags")]),
                MarkdownListItem(blocks: [.paragraph("**Filter by tags** — click tags in the sidebar")]),
                MarkdownListItem(blocks: [.paragraph("**Search everything** — full-text search works alongside tag filters")])
            ]),
            .heading(level: 3, text: "Quick start"),
            .orderedList(start: 1, items: [
                MarkdownListItem(blocks: [.paragraph("Click **New note**")]),
                MarkdownListItem(blocks: [.paragraph("Write in Markdown")]),
                MarkdownListItem(blocks: [.paragraph("Add tags")])
            ]),
            .quote([.paragraph("Keep the notes you need.")]),
            .horizontalRule,
            .code("tsn export")
        ])
    }

    func testPreservesSingleLineBreaksInsideParagraphs() {
        let document = MarkdownDocument.parse("""
        First line
        second line
        third line
        """)

        XCTAssertEqual(document.blocks, [
            .paragraph("First line\nsecond line\nthird line")
        ])
    }

    func testNormalizesWindowsLineEndingsAndIgnoresExtraBlankLines() {
        let document = MarkdownDocument.parse("# Title\r\n\r\n\r\nBody\r\n\r\n- one\r\n- two")

        XCTAssertEqual(document.blocks, [
            .heading(level: 1, text: "Title"),
            .paragraph("Body"),
            .unorderedList([
                MarkdownListItem(blocks: [.paragraph("one")]),
                MarkdownListItem(blocks: [.paragraph("two")])
            ])
        ])
    }
}
