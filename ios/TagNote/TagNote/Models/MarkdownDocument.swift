import Foundation
import Markdown

struct MarkdownDocument: Equatable {
    var blocks: [MarkdownBlock]

    static func parse(_ markdown: String) -> MarkdownDocument {
        let document = Document(parsing: markdown, options: [.disableSmartOpts])
        return MarkdownDocument(blocks: document.children.compactMap(Self.block(from:)))
    }

    private static func block(from markup: Markup) -> MarkdownBlock? {
        switch markup {
        case let heading as Heading:
            return .heading(level: heading.level, text: inlineMarkdown(in: heading))
        case let paragraph as Paragraph:
            return .paragraph(inlineMarkdown(in: paragraph))
        case let list as UnorderedList:
            return .unorderedList(listItems(in: list))
        case let list as OrderedList:
            return .orderedList(start: Int(list.startIndex), items: listItems(in: list))
        case let quote as BlockQuote:
            return .quote(quote.children.compactMap { block(from: $0.detachedFromParent) })
        case let code as CodeBlock:
            return .code(code.code.trimmedMarkdownBlock)
        case _ as ThematicBreak:
            return .horizontalRule
        default:
            let rendered = markup.format().trimmedMarkdownBlock
            return rendered.isEmpty ? nil : .paragraph(rendered)
        }
    }

    private static func listItems(in list: Markup) -> [MarkdownListItem] {
        list.children.compactMap { child -> MarkdownListItem? in
            guard let item = child as? ListItem else {
                return nil
            }
            return MarkdownListItem(blocks: item.children.compactMap { block(from: $0.detachedFromParent) })
        }
    }

    private static func inlineMarkdown(in container: Markup) -> String {
        container.children
            .map(inlineMarkdown(from:))
            .joined()
            .trimmedMarkdownBlock
    }

    private static func inlineMarkdown(from markup: Markup) -> String {
        switch markup {
        case _ as SoftBreak, _ as LineBreak:
            return "\n"
        default:
            return markup.detachedFromParent.format()
        }
    }
}

struct MarkdownListItem: Equatable {
    var blocks: [MarkdownBlock]

    var inlineText: String {
        blocks.map(\.inlineText).joined(separator: "\n")
    }
}

enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([MarkdownListItem])
    case orderedList(start: Int, items: [MarkdownListItem])
    case quote([MarkdownBlock])
    case code(String)
    case horizontalRule

    var inlineText: String {
        switch self {
        case let .heading(_, text), let .paragraph(text), let .code(text):
            return text
        case let .unorderedList(items):
            return items.map(\.inlineText).joined(separator: "\n")
        case let .orderedList(_, items):
            return items.map(\.inlineText).joined(separator: "\n")
        case let .quote(blocks):
            return blocks.map(\.inlineText).joined(separator: "\n")
        case .horizontalRule:
            return ""
        }
    }
}

private extension String {
    var trimmedMarkdownBlock: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
