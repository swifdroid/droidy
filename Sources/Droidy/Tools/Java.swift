//
//  Java.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class Java {
    /// https://stackoverflow.com/questions/21423633/build-project-without-android-studio
    var versions = ["17"]
    var autoInstall = false
    
    init () {}
    
    func _install() {
        Brew.install("adoptopenjdk8", cask: true, tap: "adoptopenjdk/openjdk")
    }
    
    func prepare() {
        guard Bash.which("java") else {
            guard !autoInstall else {
                return _install()
            }
            print("""
                ⚠️ Java is not installed but it is required. Please install java v\(versions[0]) or higher.
                    👍 Either enable automatic installation by declaring `Droidy().automaticallyInstallJava()`
                    💁‍♂️ Or you could install it manually e.g. using brew:
                        brew tap adoptopenjdk/openjdk
                        brew install --cask adoptopenjdk8
                """)
            exit(1)
        }
        
        checkVersion()
    }
    
    func checkVersion() {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = Bash.which("java")
        process.arguments = ["-version"]
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
            print("⛔️ Unable to check java version: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            exit(1)
        }
        guard let str = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), str.count > 0 else {
            print("⛔️ Unable to check java version")
            exit(1)
        }
        
        for version in versions {
            if str.contains(version) {
                return
            }
        }
        
        print("⛔️ Java version \(str) differs with preferred version \(versions[0])")
        exit(1)
    }
}
