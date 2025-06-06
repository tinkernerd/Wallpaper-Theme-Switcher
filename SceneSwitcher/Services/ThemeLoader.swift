import Foundation

struct ThemeGroup {
    let name: String
    let themes: [WallpaperTheme]
}

class ThemeLoader {
    static let defaultPath: URL = {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        return pictures.appendingPathComponent("Wallpapers")
    }()

    static var currentDirectory: URL {
        let stored = UserDefaults.standard.string(forKey: "wallpaperDirectory")
        return URL(fileURLWithPath: stored ?? defaultPath.path)
    }

    static func loadThemes(completion: @escaping ([WallpaperTheme], [ThemeGroup]) -> Void) {
        DispatchQueue.global().async {
            let basePath = currentDirectory
            AppLog.info("📂 Loading themes from: \(basePath.path)")

            var flatThemes: [WallpaperTheme] = []
            var groupedThemes: [ThemeGroup] = []

            guard let topFolders = try? FileManager.default.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else {
                AppLog.error("❌ Failed to read contents of: \(basePath.path)")
                DispatchQueue.main.async { completion([], []) }
                return
            }

            for folder in topFolders where folder.hasDirectoryPath {
                AppLog.info("🔍 Checking folder: \(folder.lastPathComponent)")

                let subfolders = (try? FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )) ?? []

                let themeSubfolders = subfolders.filter { $0.hasDirectoryPath }

                if themeSubfolders.isEmpty {
                    AppLog.info("✅ Flat Theme: \(folder.lastPathComponent)")
                    let theme = WallpaperTheme(name: folder.lastPathComponent, folderURL: folder)
                    if !theme.imageURLs.isEmpty {
                        flatThemes.append(theme)
                    }
                } else {
                    AppLog.info("📁 Theme Group: \(folder.lastPathComponent)")
                    for sub in themeSubfolders {
                        AppLog.info("   └─ SubTheme: \(sub.lastPathComponent)")
                    }
                    let subThemes = themeSubfolders.map {
                        WallpaperTheme(name: $0.lastPathComponent, folderURL: $0)
                    }.filter { !$0.imageURLs.isEmpty }

                    let flatten = UserDefaults.standard.bool(forKey: "flattenSingleSubthemes")
                    if flatten, subThemes.count == 1 {
                        let single = WallpaperTheme(name: folder.lastPathComponent, folderURL: subThemes[0].folderURL)
                        flatThemes.append(single)
                    } else if !subThemes.isEmpty {
                        let group = ThemeGroup(name: folder.lastPathComponent, themes: subThemes)
                        groupedThemes.append(group)
                    }
                }
            }

            AppLog.info("📦 Total flat themes: \(flatThemes.count), grouped themes: \(groupedThemes.count)")

            DispatchQueue.main.async {
                completion(flatThemes, groupedThemes)
            }
        }
    }
}
