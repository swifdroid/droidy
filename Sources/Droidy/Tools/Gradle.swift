//
//  Gradle.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class Gradle {
    var _path: String = ""
    var _pathToBin: String {
        URL(fileURLWithPath: _path).appendingPathComponent("bin").appendingPathComponent("gradle").path
    }
    
    var version = "7.3.3"
    var url = "https://services.gradle.org/distributions/gradle-7.3.3-bin.zip"
    var predownloadedArchivePath: String?
    var autoDownload = false
    var defaultPath: String { Droidy.folderURL().appendingPathComponent("gradle-\(version)").path }
    
    init () {
        _path = ProcessInfo.processInfo.environment["gradlePath"] ?? ""
    }
    
    private func _download() {
        let archivePath: String
        if let path = predownloadedArchivePath {
            print("📦 Using local archive from \(path)")
            archivePath = path
        } else {
            archivePath = Downloader.download("gradle archive", "100Mb", url)
        }
        Extractor.extract(name: "gradle archive", archive: archivePath, dest: defaultPath)
        _path = defaultPath
    }
    
    func prepare() {
        guard _path.count > 0 else {
            guard !FileManager.default.fileExists(atPath: defaultPath) else {
                _path = defaultPath
                checkVersion()
                return print("🔦 Gradle has been found at: \(defaultPath)")
            }
            guard !autoDownload else {
                _download()
                checkVersion()
                return
            }
            print("""
                ⚠️ Please set `gradlePath` environment variable for the `Run` target which should point to gradle folder.
                🌏 If you haven't downloaded Gradle yet
                    👍 Either enable automatic downloading by declaring `Droidy().automaticallyDownloadGradle()`
                    💁‍♂️ Or get it manually from \(url)
                            and provide a link to downloaded archive by declaring `Droidy().localGradleArchive(...)`
                """)
            fatalError()
        }
        checkVersion()
    }
    
    func checkVersion() {
        let stdout = Pipe()
        let stderr = Pipe()
        
        let process = Process()
        process.launchPath = _pathToBin
        process.arguments = ["--version"]
        process.standardOutput = stdout
        process.standardError = stderr
        
        var resultData = Data()
        let group = DispatchGroup()
        group.enter()
        stdout.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty {
                stdout.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                resultData.append(data)
            }
        }
        process.launch()
        process.waitUntilExit()
        group.wait()
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to check gradle version: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        guard let str = String(data: resultData, encoding: .utf8), str.count > 0 else {
            print("⛔️ Unable to check gradle version")
            fatalError()
        }
        let installedVersion = str
            .components(separatedBy: "------------------------------------------------------------")[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "Gradle ", with: "")
        guard version == installedVersion else {
            print("⛔️ Preferred gradle version \(self.version) doesn't match installed version \(installedVersion)")
            exit(1)
        }
    }
    
    func generateWrapper(projectPath: String) {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = _pathToBin
        process.currentDirectoryPath = projectPath
        process.arguments = ["wrapper"]
        process.standardOutput = stdout
        process.standardError = stderr

        var resultData = Data()
        let group = DispatchGroup()
        group.enter()
        stdout.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty {
                stdout.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                resultData.append(data)
            }
        }
        process.launch()
        process.waitUntilExit()
        group.wait()
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to generate gradlew: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!). Please remove the `AndroidProject` directory from your Swift project before trying again.")
            exit(1)
        }
    }
}
