import UniformTypeIdentifiers

enum SupportedDocumentTypes {
    static let openPanelContentTypes: [UTType]? = nil

    static let summary = "支持 macOS 可预览的文件。"

    static func isSupported(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        if values?.isPackage == true {
            return true
        }

        return values?.isDirectory != true
    }
}
