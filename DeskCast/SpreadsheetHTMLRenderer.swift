import Compression
import CoreGraphics
import Foundation

enum XLSXHTMLRenderer {
    static func render(url: URL) throws -> String {
        let archive = try ZipArchive(url: url)
        let sharedStrings = SharedStringsParser.parse(try archive.string(at: "xl/sharedStrings.xml"))
        let styles = StylesParser.parse(try archive.string(at: "xl/styles.xml"))
        let sheetPaths = WorkbookParser.sheetPaths(
            workbookXML: try archive.string(at: "xl/workbook.xml"),
            relationshipsXML: try archive.string(at: "xl/_rels/workbook.xml.rels")
        )

        for sheetPath in sheetPaths {
            let sheet = WorksheetParser.parse(
                try archive.string(at: "xl/" + sheetPath),
                sharedStrings: sharedStrings,
                styles: styles
            )
            if !sheet.rows.isEmpty {
                return renderHTML(sheet: sheet)
            }
        }

        throw CocoaError(.fileReadCorruptFile)
    }

    private static func renderHTML(sheet: Worksheet) -> String {
        let columnWeights = (sheet.minColumn...sheet.maxColumn).map { columnIndex in
            columnPixelWidth(sheet.columnWidths[columnIndex] ?? sheet.defaultColumnWidth)
        }
        let rowWeights = (sheet.minRow...sheet.maxRow).map { rowIndex in
            rowPixelHeight(sheet.rowHeights[rowIndex] ?? sheet.defaultRowHeight)
        }
        let totalColumnWeight = max(columnWeights.reduce(0, +), 1)
        let totalRowWeight = max(rowWeights.reduce(0, +), 1)
        let colgroup = columnWeights
            .map { "<col style=\"width: \(percentage($0, of: totalColumnWeight))%;\">" }
            .joined()
        var rows = ""
        let columnRange = sheet.minColumn...sheet.maxColumn

        for (rowOffset, rowIndex) in (sheet.minRow...sheet.maxRow).enumerated() {
            rows += "<tr style=\"height: \(percentage(rowWeights[rowOffset], of: totalRowWeight))%;\">"
            for columnIndex in columnRange {
                let cell = sheet.cells[CellAddress(row: rowIndex, column: columnIndex)]
                let style = cell.flatMap { sheet.styles[$0.styleIndex] } ?? .default
                let text = escape(cell?.text ?? "")
                rows += """
                <td style="\(style.css)">\(text)</td>
                """
            }
            rows += "</tr>"
        }

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        html, body {
            margin: 0;
            padding: 0;
            width: 100vw;
            height: 100vh;
            box-sizing: border-box;
            overflow: hidden;
            background: transparent;
        }
        .sheet {
            width: 100vw;
            height: 100vh;
            padding: 0 18px 18px 0;
            box-sizing: border-box;
        }
        table {
            border-collapse: collapse;
            table-layout: fixed;
            width: 100%;
            height: 100%;
            background: rgba(245, 246, 250, 0.82);
            font-family: "Songti SC", "STSong", serif;
        }
        td {
            box-sizing: border-box;
            border: 1px solid #111;
            color: #000;
            text-align: center;
            vertical-align: middle;
            white-space: normal;
            word-break: break-all;
            overflow: hidden;
            font-size: clamp(9px, min(1.2vw, 4.6vh), 28px);
            line-height: 1.04;
            padding: 0.04em 0.04em;
        }
        </style>
        </head>
        <body>
        <div class="sheet">
        <table>
        <colgroup>
        \(colgroup)
        </colgroup>
        \(rows)
        </table>
        </div>
        </body>
        </html>
        """
    }

    static func aspectRatio(url: URL) throws -> CGFloat {
        let archive = try ZipArchive(url: url)
        let sharedStrings = SharedStringsParser.parse(try archive.string(at: "xl/sharedStrings.xml"))
        let styles = StylesParser.parse(try archive.string(at: "xl/styles.xml"))
        let sheetPaths = WorkbookParser.sheetPaths(
            workbookXML: try archive.string(at: "xl/workbook.xml"),
            relationshipsXML: try archive.string(at: "xl/_rels/workbook.xml.rels")
        )

        for sheetPath in sheetPaths {
            let sheet = WorksheetParser.parse(
                try archive.string(at: "xl/" + sheetPath),
                sharedStrings: sharedStrings,
                styles: styles
            )
            if !sheet.rows.isEmpty {
                let width = (sheet.minColumn...sheet.maxColumn)
                    .map { columnPixelWidth(sheet.columnWidths[$0] ?? sheet.defaultColumnWidth) }
                    .reduce(0, +)
                let height = (sheet.minRow...sheet.maxRow)
                    .map { rowPixelHeight(sheet.rowHeights[$0] ?? sheet.defaultRowHeight) }
                    .reduce(0, +)
                return CGFloat(max(width / max(height, 1), 1))
            }
        }

        throw CocoaError(.fileReadCorruptFile)
    }

    private static func percentage(_ value: Double, of total: Double) -> String {
        String(format: "%.6f", (value / total) * 100)
    }

    private static func columnPixelWidth(_ excelWidth: Double) -> Double {
        max(12, floor(excelWidth * 7 + 5))
    }

    private static func rowPixelHeight(_ points: Double) -> Double {
        max(18, points * 4 / 3)
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct Worksheet {
    var cells: [CellAddress: SpreadsheetCell]
    var styles: [Int: SpreadsheetStyle]
    var minRow: Int
    var maxRow: Int
    var minColumn: Int
    var maxColumn: Int
    var columnWidths: [Int: Double]
    var rowHeights: [Int: Double]
    var defaultColumnWidth: Double
    var defaultRowHeight: Double

    var rows: [Int] {
        Array(minRow...maxRow)
    }
}

private struct CellAddress: Hashable {
    let row: Int
    let column: Int
}

private struct SpreadsheetCell {
    let text: String
    let styleIndex: Int
}

private struct SpreadsheetStyle {
    static let `default` = SpreadsheetStyle(background: nil)

    let background: String?

    var css: String {
        if let background {
            return "background: \(background);"
        }
        return ""
    }
}

private enum WorkbookParser {
    static func sheetPaths(workbookXML: String, relationshipsXML: String) -> [String] {
        let relationshipParser = AttributeXMLParser(elementName: "Relationship")
        relationshipParser.parse(relationshipsXML)
        let relationships = Dictionary(
            uniqueKeysWithValues: relationshipParser.elements.compactMap { element -> (String, String)? in
                guard let id = element["Id"], let target = element["Target"] else { return nil }
                return (id, target)
            }
        )

        let workbookParser = AttributeXMLParser(elementName: "sheet")
        workbookParser.parse(workbookXML)

        return workbookParser.elements.compactMap { element in
            guard let id = element["r:id"], let target = relationships[id] else { return nil }
            return target.hasPrefix("worksheets/") ? target : "worksheets/" + target
        }
    }
}

private enum SharedStringsParser {
    static func parse(_ xml: String) -> [String] {
        let parser = TextCollectingXMLParser(itemElementName: "si", textElementName: "t")
        parser.parse(xml)
        return parser.items
    }
}

private enum StylesParser {
    static func parse(_ xml: String) -> [Int: SpreadsheetStyle] {
        let parser = StylesXMLParser()
        parser.parse(xml)
        return parser.styles
    }
}

private enum WorksheetParser {
    static func parse(
        _ xml: String,
        sharedStrings: [String],
        styles: [Int: SpreadsheetStyle]
    ) -> Worksheet {
        let parser = WorksheetXMLParser(sharedStrings: sharedStrings)
        parser.parse(xml)
        return Worksheet(
            cells: parser.cells,
            styles: styles,
            minRow: parser.minRow,
            maxRow: parser.maxRow,
            minColumn: parser.minColumn,
            maxColumn: parser.maxColumn,
            columnWidths: parser.columnWidths,
            rowHeights: parser.rowHeights,
            defaultColumnWidth: parser.defaultColumnWidth,
            defaultRowHeight: parser.defaultRowHeight
        )
    }
}

private final class WorksheetXMLParser: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var cells: [CellAddress: SpreadsheetCell] = [:]
    var minRow = Int.max
    var maxRow = 1
    var minColumn = Int.max
    var maxColumn = 1
    var columnWidths: [Int: Double] = [:]
    var rowHeights: [Int: Double] = [:]
    var defaultColumnWidth = 8.43
    var defaultRowHeight = 15.0

    private var currentAddress: CellAddress?
    private var currentType: String?
    private var currentStyleIndex = 0
    private var currentValue = ""
    private var isReadingValue = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parse(_ xml: String) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "sheetFormatPr":
            if let defaultColumnWidth = Double(attributeDict["defaultColWidth"] ?? "") {
                self.defaultColumnWidth = defaultColumnWidth
            }
            if let defaultRowHeight = Double(attributeDict["defaultRowHeight"] ?? "") {
                self.defaultRowHeight = defaultRowHeight
            }
        case "col":
            guard let min = Int(attributeDict["min"] ?? ""),
                  let max = Int(attributeDict["max"] ?? ""),
                  let width = Double(attributeDict["width"] ?? "")
            else { break }
            for column in min...max {
                columnWidths[column] = width
            }
        case "row":
            if let row = Int(attributeDict["r"] ?? ""),
               let height = Double(attributeDict["ht"] ?? "") {
                rowHeights[row] = height
            }
        case "dimension":
            if let ref = attributeDict["ref"] {
                applyDimension(ref)
            }
        case "c":
            currentAddress = attributeDict["r"].flatMap(Self.address)
            currentType = attributeDict["t"]
            currentStyleIndex = Int(attributeDict["s"] ?? "") ?? 0
            currentValue = ""
        case "v":
            isReadingValue = true
            currentValue = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingValue {
            currentValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "v":
            isReadingValue = false
        case "c":
            if let currentAddress {
                let text: String
                if currentType == "s", let index = Int(currentValue), sharedStrings.indices.contains(index) {
                    text = sharedStrings[index]
                } else {
                    text = currentValue
                }
                cells[currentAddress] = SpreadsheetCell(text: text, styleIndex: currentStyleIndex)
            }
            currentAddress = nil
            currentType = nil
            currentStyleIndex = 0
            currentValue = ""
        default:
            break
        }
    }

    private func applyDimension(_ ref: String) {
        let endpoints = ref.split(separator: ":").map(String.init)
        let addresses = endpoints.compactMap(Self.address)
        guard let first = addresses.first else { return }
        let last = addresses.last ?? first
        minRow = min(first.row, last.row)
        maxRow = max(first.row, last.row)
        minColumn = min(first.column, last.column)
        maxColumn = max(first.column, last.column)
    }

    private static func address(_ string: String) -> CellAddress? {
        var column = 0
        var rowString = ""

        for scalar in string.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                column = (column * 26) + Int(scalar.value - UnicodeScalar("A").value + 1)
            } else if CharacterSet.decimalDigits.contains(scalar) {
                rowString.append(String(scalar))
            }
        }

        guard column > 0, let row = Int(rowString) else { return nil }
        return CellAddress(row: row, column: column)
    }
}

private final class StylesXMLParser: NSObject, XMLParserDelegate {
    var styles: [Int: SpreadsheetStyle] = [:]

    private var fills: [String?] = []
    private var xfFillIds: [Int] = []
    private var inFills = false
    private var inCellXfs = false
    private var inFill = false
    private var currentFillColor: String?

    func parse(_ xml: String) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        for (index, fillID) in xfFillIds.enumerated() {
            styles[index] = SpreadsheetStyle(background: fills.indices.contains(fillID) ? fills[fillID] : nil)
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "fills":
            inFills = true
        case "cellXfs":
            inCellXfs = true
        case "fill" where inFills:
            inFill = true
            currentFillColor = nil
        case "fgColor" where inFill:
            if let rgb = attributeDict["rgb"] {
                currentFillColor = "#" + String(rgb.suffix(6))
            }
        case "xf" where inCellXfs:
            xfFillIds.append(Int(attributeDict["fillId"] ?? "") ?? 0)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "fills":
            inFills = false
        case "cellXfs":
            inCellXfs = false
        case "fill" where inFill:
            fills.append(currentFillColor)
            inFill = false
            currentFillColor = nil
        default:
            break
        }
    }
}

private final class TextCollectingXMLParser: NSObject, XMLParserDelegate {
    let itemElementName: String
    let textElementName: String
    var items: [String] = []

    private var depth = 0
    private var currentText = ""
    private var isReadingText = false

    init(itemElementName: String, textElementName: String) {
        self.itemElementName = itemElementName
        self.textElementName = textElementName
    }

    func parse(_ xml: String) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == itemElementName {
            depth += 1
            currentText = ""
        } else if depth > 0, elementName == textElementName {
            isReadingText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingText {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == textElementName {
            isReadingText = false
        } else if elementName == itemElementName {
            items.append(currentText)
            depth = max(depth - 1, 0)
        }
    }
}

private final class AttributeXMLParser: NSObject, XMLParserDelegate {
    let elementName: String
    var elements: [[String: String]] = []

    init(elementName: String) {
        self.elementName = elementName
    }

    func parse(_ xml: String) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == self.elementName {
            elements.append(attributeDict)
        }
    }
}

private struct ZipArchive {
    let data: Data
    let entries: [String: ZipEntry]

    init(url: URL) throws {
        data = try Data(contentsOf: url)
        entries = try Self.readEntries(from: data)
    }

    func string(at path: String) throws -> String {
        guard let entry = entries[path] else { throw CocoaError(.fileNoSuchFile) }
        let payload = try entry.data(in: data)
        guard let string = String(data: payload, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return string
    }

    private static func readEntries(from data: Data) throws -> [String: ZipEntry] {
        guard let endOffset = data.lastRange(of: Data([0x50, 0x4b, 0x05, 0x06]))?.lowerBound else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let entryCount = Int(data.uint16(at: endOffset + 10))
        var offset = Int(data.uint32(at: endOffset + 16))
        var entries: [String: ZipEntry] = [:]

        for _ in 0..<entryCount {
            guard data.uint32(at: offset) == 0x02014b50 else { break }
            let method = Int(data.uint16(at: offset + 10))
            let compressedSize = Int(data.uint32(at: offset + 20))
            let uncompressedSize = Int(data.uint32(at: offset + 24))
            let nameLength = Int(data.uint16(at: offset + 28))
            let extraLength = Int(data.uint16(at: offset + 30))
            let commentLength = Int(data.uint16(at: offset + 32))
            let localHeaderOffset = Int(data.uint32(at: offset + 42))
            let nameStart = offset + 46
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            if let name = String(data: nameData, encoding: .utf8) {
                entries[name] = ZipEntry(
                    method: method,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                )
            }
            offset = nameStart + nameLength + extraLength + commentLength
        }

        return entries
    }
}

private struct ZipEntry {
    let method: Int
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int

    func data(in archiveData: Data) throws -> Data {
        let nameLength = Int(archiveData.uint16(at: localHeaderOffset + 26))
        let extraLength = Int(archiveData.uint16(at: localHeaderOffset + 28))
        let payloadStart = localHeaderOffset + 30 + nameLength + extraLength
        let payload = archiveData.subdata(in: payloadStart..<(payloadStart + compressedSize))

        switch method {
        case 0:
            return payload
        case 8:
            return try payload.inflated(to: uncompressedSize)
        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func inflated(to size: Int) throws -> Data {
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { destination.deallocate() }

        let decodedSize = withUnsafeBytes { sourceBuffer in
            compression_decode_buffer(
                destination,
                size,
                sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decodedSize == size else { throw CocoaError(.fileReadCorruptFile) }
        return Data(bytes: destination, count: decodedSize)
    }
}
