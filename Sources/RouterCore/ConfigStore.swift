import Foundation

/// Locates, creates-on-first-run, and loads the YAML config file.
public struct ConfigStore {
    public let fileURL: URL

    /// Default location: ~/.config/default-browser-router/config.yaml
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = home
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("default-browser-router", isDirectory: true)
                .appendingPathComponent("config.yaml", isDirectory: false)
        }
    }

    /// The template written when no config exists yet.
    public static let defaultTemplate: String = """
    # default-browser-router config
    #
    # First matching rule wins, evaluated top to bottom.
    # `browser` accepts a friendly name (Safari, Firefox, Brave, Chrome, Edge, Arc)
    # or an explicit bundle id (any value containing a dot, e.g. com.brave.Browser).

    default: Brave

    rules:
      # - domain: bitbucket.org          # matches the host or any subdomain
      #   browser: Safari
      # - domain: amazon.com
      #   browser: Firefox
      # - prefix: https://meet.google.com/   # matches a URL string prefix
      #   browser: Chrome
    """

    /// Creates the config directory and default file if the file is missing.
    /// Returns true if a new file was written.
    @discardableResult
    public func createIfMissing() throws -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            return false
        }
        try fm.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.defaultTemplate.write(to: fileURL, atomically: true, encoding: .utf8)
        return true
    }

    /// Reads the file and parses it. Creates the default template first if missing.
    public func load() throws -> Config {
        try createIfMissing()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return try ConfigLoader.parse(text)
    }
}
