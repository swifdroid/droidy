//
//  Java.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class Java {
    var version = "17.0.1"
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
                ⚠️ Java is not installed but it is required. Please install java v\(version).
                    👍 Either enable automatic installation by declaring `Droidy().automaticallyInstallJava()`
                    💁‍♂️ Or you could install it manually e.g. using brew:
                        brew tap adoptopenjdk/openjdk
                        brew install --cask adoptopenjdk8
                """)
            fatalError()
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
            fatalError()
        }
        guard let str = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), str.count > 0 else {
            print("⛔️ Unable to check java version")
            fatalError()
        }
        guard str.contains(version) else {
            print("⛔️ Java version differs with preferred version \(version)")
            fatalError()
        }
    }
}
