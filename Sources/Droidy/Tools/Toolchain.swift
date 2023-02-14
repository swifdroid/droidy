//
//  Toolchain.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class Toolchain {
    var _path: String = ""
    var _binURL: URL {
        URL(fileURLWithPath: _path).appendingPathComponent("usr").appendingPathComponent("bin")
    }
    var _libURL: URL {
        URL(fileURLWithPath: _path).appendingPathComponent("usr").appendingPathComponent("lib")
    }
    var _pathToFrontendBin: String {
        _binURL.appendingPathComponent("swift-frontend").path
    }
    var _pathToAndroidBuild: String {
        _binURL.appendingPathComponent("android-swift-build").path
    }
    var _pathToAndroidCopyLibs: String {
        _binURL.appendingPathComponent("android-copy-libs").path
    }
    
    var version = "5.5.2"
    var url = "https://github.com/vgorloff/swift-everywhere-toolchain/releases/download/1.0.78/swift-android-toolchain.tar.gz"
    var predownloadedArchivePath: String?
    var autoDownload = false
    var defaultPath: String { Droidy.folderURL().appendingPathComponent("swift-\(version)-android").path }
    var archs: [Arch] = [.aarch64, .armv7, .i686, .x86_64]
	let ndkPath: String
    let projectFolder: URL
    
    private lazy var swift = Swift(self, ndkPath: ndkPath, projectFolder: projectFolder)
    
    init (ndkPath: String, projectFolder: URL) {
        self.ndkPath = ndkPath
        self.projectFolder = projectFolder
        _path = ProcessInfo.processInfo.environment["toolchainPath"] ?? ""
    }
    
    private func _download() {
        let archivePath: String
        if let path = predownloadedArchivePath {
            print("📦 Using local archive from \(path)")
            archivePath = path
        } else {
            archivePath = Downloader.download("toolchain archive", "300Mb", url)
        }
        Extractor.extract(name: "toolchain archive", archive: archivePath, dest: defaultPath)
        _path = defaultPath
        checkVersion()
    }
    
    func prepare() {
        guard _path.count > 0 else {
            guard !FileManager.default.fileExists(atPath: defaultPath) else {
                _path = defaultPath
                checkVersion()
                return print("🔦 Toolchain has been found at: \(defaultPath)")
            }
            guard !autoDownload else {
                return _download()
            }
            print("""
                ⚠️ Please set `toolchainPath` environment variable for the `Run` target which should point to swift android toolchain folder.
                🌏 If you haven't downloaded toolchain yet
                    👍 Either enable automatic downloading by declaring `Droidy().automaticallyDownloadToolchain()`
                    💁‍♂️ Or get it manually from \(url)
                            and provide a link to downloaded archive by declaring `Droidy().localToolchainArchive(...)`
                """)
            fatalError()
        }
        checkVersion()
    }
    
    func fixQuarantine() {
        let qarantineFixedPath = URL(fileURLWithPath: _path).appendingPathComponent(".quarantineFixed").path
        if FileManager.default.fileExists(atPath: qarantineFixedPath) {
            return
        }
        if let binFiles = try? FileManager.default.contentsOfDirectory(atPath: _binURL.path) {
            binFiles.forEach {
                Xattr.fixQuarantine(_binURL.appendingPathComponent($0).path)
                print("🔧 Quarantine file fix for toolchain/usr/bin/\($0)")
            }
        }
        if let libFiles = try? FileManager.default.contentsOfDirectory(atPath: _libURL.path) {
            libFiles.forEach {
                Xattr.fixQuarantine(_libURL.appendingPathComponent($0).path)
                print("🔧 Quarantine file fix for toolchain/usr/lib/\($0)")
            }
        }
        guard FileManager.default.createFile(atPath: qarantineFixedPath, contents: Data(), attributes: nil) else {
            print("Unable to create .quarantineFixed file to remember that quarantine is fixed already")
            return
        }
    }
    
    func checkVersion() {
        fixQuarantine()
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = _pathToFrontendBin
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
            print("⛔️ Unable to check toolchain version: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        guard let str = String(data: resultData, encoding: .utf8), str.count > 0 else {
            print("⛔️ Unable to check toolchain version")
            fatalError()
        }
        if let right = str.components(separatedBy: " version ").last, let left = right.components(separatedBy: " ").first {
            guard left.contains(version) || version.contains(left) else {
                print("⛔️ Toolchain version \(left) differs with preferred version \(version)")
                fatalError()
            }
        } else {
            guard str.contains(version) else {
                print("⛔️ Toolchain version differs with preferred version \(version)")
                fatalError()
            }
        }
    }
    
    func build(_ productName: String, _ androidProjectPath: String, arch: Arch? = nil) {
		var archsToBuildFor: [Arch] = []
		if let arch = arch {
			archsToBuildFor.append(arch)
		} else {
			archsToBuildFor = self.archs
		}
		archsToBuildFor.forEach {
            swift.build($0, productName)
            swift.copyLibs($0, androidProjectPath)
        }
    }
}
