//
//  NDK.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class NDK {
    var _path: String = ""
    
    var version = "21.4.7075529"
//    var version = "23.1.7779620"
    var url = "https://dl.google.com/android/repository/android-ndk-r21e-darwin-x86_64.zip"
//    var url = "https://dl.google.com/android/repository/android-ndk-r23b-darwin.dmg"
    var predownloadedArchivePath: String?
    var autoDownload = false
    var homePath: String { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("android-ndk-r\(version.components(separatedBy: ".")[0])e").path }
//    var homePath: String { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("android-ndk-r\(version.components(separatedBy: ".")[0])").path }
    var defaultPath: String { Droidy.folderURL().appendingPathComponent("android-ndk-r\(version.components(separatedBy: ".")[0])e").path }
//    var defaultPath: String { Droidy.folderURL().appendingPathComponent("android-ndk-r\(version.components(separatedBy: ".")[0])").path }
    
    init () {
        _path = ProcessInfo.processInfo.environment["ndkPath"] ?? defaultPath
    }
    
    private func _download() {
        let archivePath: String
        if let path = predownloadedArchivePath {
            print("📦 Using local archive from \(path)")
            archivePath = path
        } else {
            archivePath = Downloader.download("NDK archive", "1Gb", url)
        }
        Extractor.extract(name: "NDK archive", archive: archivePath, dest: defaultPath)
        _path = defaultPath
        checkVersion()
    }
    
    func prepare() {
        guard _path.count > 0 else {
            guard !FileManager.default.fileExists(atPath: defaultPath) else {
                _path = defaultPath
                checkVersion()
                return print("🔦 NDK has been found at: \(defaultPath)")
            }
            guard !autoDownload else { return _download() }
            print("""
                ⚠️ Please set `ndkPath` environment variable for the `Run` target which should point to NDK folder.
                🌏 If you haven't downloaded NDK yet
                    👍 Either enable automatic downloading by declaring `Droidy().automaticallyDownloadNDK()`
                    💁‍♂️ Or get it manually from \(url)
                            and provide a link to downloaded archive by declaring `Droidy().localNDKArchive(...)`
                """)
            fatalError()
        }
        checkVersion()
    }
    
    func checkVersion() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: _path).appendingPathComponent("source.properties")), let str = String(data: data, encoding: .utf8) else {
            print("⛔️ Unable to check NDK version, file `source.properties` not found in NDK path")
            fatalError()
        }
        guard str.contains(version) else {
            print("⛔️ NDK version \(str) differs with preferred version \(version)")
            fatalError()
        }
    }
}
