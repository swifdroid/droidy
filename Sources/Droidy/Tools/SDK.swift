//
//  SDK.swift
//  Droidy
//
//  Created by Mihael Isaev on 24.07.2021.
//

import Foundation

class SDK {
    let droidy: Droidy
    
    var _path: String = ""
    
    var url = "https://dl.google.com/android/repository/commandlinetools-mac-7583922_latest.zip"
    var predownloadedArchivePath: String?
    var autoDownload = false
    var buildToolsVersionToInstall: String { "\(droidy.project.compileSdkVersion).0.0" }
    
    var homePath: String { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library").appendingPathComponent("Android").path }
    var defaultPath: String { Droidy.folderURL().appendingPathComponent("android").path }
    var sdkFolder: URL { URL(fileURLWithPath: _path).appendingPathComponent("sdk") }
    var cmdLineToolsBinFolder: URL { sdkFolder.appendingPathComponent("cmdline-tools").appendingPathComponent("bin") }
	var platformToolsFolder: URL { sdkFolder.appendingPathComponent("platform-tools") }
    
    init (_ droidy: Droidy) {
        self.droidy = droidy
        _path = ProcessInfo.processInfo.environment["sdkPath"] ?? ""
    }
    
    private func _download() {
        let archivePath: String
        if let path = predownloadedArchivePath {
            print("📦 Using local archive from \(path)")
            archivePath = path
        } else {
            archivePath = Downloader.download("SDK-cli archive", "100Mb", url)
        }
        Extractor.extract(name: "SDK-cli archive", archive: archivePath, dest: defaultPath)
        let sdkFolder = Droidy.folderURL().appendingPathComponent("android").appendingPathComponent("sdk")
        do {
            try FileManager.default.createDirectory(at: sdkFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("⛔️ Unable to create folder for android SDK")
            fatalError()
        }
        do {
            try FileManager.default.moveItem(at: Droidy.folderURL().appendingPathComponent("cmdline-tools"), to: sdkFolder.appendingPathComponent("cmdline-tools"))
        } catch {
            print("⛔️ Unable to move android SDK files into the right path")
            fatalError()
        }
        _path = defaultPath
    }
    
    func prepare() {
        guard _path.count > 0 else {
            guard !FileManager.default.fileExists(atPath: defaultPath) else {
                _path = defaultPath
                acceptAllLicenses()
                installPlatformTools()
                return print("🔦 SDK has been found at: \(defaultPath)")
            }
//            guard !FileManager.default.fileExists(atPath: homePath) else {
//                _path = homePath
//                acceptAllLicenses()
//                return print("🔦 SDK has been found at: \(homePath)")
//            }
            guard !autoDownload else {
                _download()
                acceptAllLicenses()
                installPlatformTools()
                return
            }
            print("""
                ⚠️ Please set `sdkPath` environment variable for the `Run` target which should point to SDK folder.
                🌏 If you haven't downloaded SDK yet
                    👍 Either enable automatic downloading by declaring `Droidy().automaticallyDownloadSDK()`
                    🤖 Or install Android Studio and SDK will be installed with it into ~/Library/Android
                    💁‍♂️ Or get command line tools manually from \(url)
                            and provide a link to downloaded archive by declaring `Droidy().localSDKArchive(...)`
                """)
            fatalError()
        }
        acceptAllLicenses()
        installPlatformTools()
    }
    
    func installPlatformTools() {
        guard !FileManager.default.fileExists(atPath: platformToolsFolder.path) else { return }
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = "/usr/bin/env"
        print("sdkFolder.path: \(sdkFolder.path)")
        print("tools: \(cmdLineToolsBinFolder.appendingPathComponent("sdkmanager").path)")
        process.currentDirectoryPath = sdkFolder.path
        process.arguments = ["bash", "-c", "yes | " + cmdLineToolsBinFolder.appendingPathComponent("sdkmanager").path + " --install \"platforms;android-\(droidy.project.compileSdkVersion)\" \"platform-tools\" \"build-tools;\(buildToolsVersionToInstall)\" --sdk_root=" + sdkFolder.path]
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
                print("🤖 " + (String(data: data, encoding: .utf8) ?? "----"))
                resultData.append(data)
            }
        }
        print("🤖 Trying to install SDK build tools \(buildToolsVersionToInstall) via SDK manager")
        process.launch()
        process.waitUntilExit()
        group.wait()
        
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to install SDK build tools: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        print("👍 SDK build tools has been installed successfully")
        updatePlatforforms()
    }
    
    func updatePlatforforms() {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = cmdLineToolsBinFolder.appendingPathComponent("sdkmanager").path
        process.currentDirectoryPath = sdkFolder.path
        process.arguments = ["--update", "--sdk_root=" + sdkFolder.path]
        process.standardOutput = stdout
        process.standardError = stderr

        var resultData = Data()
        let group = DispatchGroup()
        group.enter()
        var noUpdates = false
        stdout.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty {
                stdout.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                if String(data: data, encoding: .utf8)?.contains("No updates available") == true {
                    noUpdates = true
                }
                resultData.append(data)
            }
        }
        print("🤖 Checking for SDK build tools update")
        process.launch()
        process.waitUntilExit()
        group.wait()
        
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to install SDK build tools: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        if !noUpdates {
            print("👍 SDK build tools has been updated")
        } else {
            print("👍 SDK build tools are up-to-date")
        }
    }
    
    func acceptAllLicenses() {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["bash", "-c", "yes | " + cmdLineToolsBinFolder.appendingPathComponent("sdkmanager").path + " --licenses --sdk_root=\(sdkFolder.path)"]
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
            print("⛔️ Unable to accept cli licenses: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
    }
}
