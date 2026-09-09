import Foundation

/// The images sitting next to the one that was opened, in Finder order.
struct Playlist {
    private(set) var urls: [URL]
    private(set) var index: Int

    init(urls: [URL], index: Int) {
        self.urls = urls
        self.index = index
    }

    var current: URL? {
        urls.indices.contains(index) ? urls[index] : nil
    }

    static func around(_ url: URL) -> Playlist {
        let directory = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        var files = imageFiles(in: directory)

        if url.hasDirectoryPath {
            return Playlist(urls: files, index: 0)
        }
        if files.isEmpty {
            files = [url]
        }
        let target = url.standardizedFileURL
        let index = files.firstIndex { $0.standardizedFileURL == target } ?? 0
        return Playlist(urls: files, index: index)
    }

    static func imageFiles(in directory: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []
        return contents
            .filter { !$0.hasDirectoryPath && ImageLoader.canOpen($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Wraps around at both ends.
    mutating func step(_ delta: Int) -> URL? {
        guard !urls.isEmpty else { return nil }
        index = ((index + delta) % urls.count + urls.count) % urls.count
        return current
    }

    mutating func jump(to position: Int) -> URL? {
        guard !urls.isEmpty else { return nil }
        index = min(max(position, 0), urls.count - 1)
        return current
    }
}
