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
    #
    # Simple rules use a single inline condition:
    #   domain / prefix / url_contains / url_equals / url_regex / source_app
    #
    # Rich rules combine conditions with `match: all` or `match: any`.
    # (The "Edit Rules…" menu bar item edits this file; hand-editing works too.)

    default: Brave

    rules:
      # - domain: bitbucket.org          # host or any subdomain -> Safari
      #   browser: Safari
      # - prefix: https://meet.google.com/
      #   browser: Chrome
      # - match: all                     # all conditions must hold
      #   conditions:
      #     - source_app: Mail           # link came from Mail
      #     - url_contains: facebook
      #   browser: Safari
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

    /// Serializes and writes the config to disk (normalized; comments are not preserved).
    public func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let text = try ConfigSerializer.dump(config)
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
