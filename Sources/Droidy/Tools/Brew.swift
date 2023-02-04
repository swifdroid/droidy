//
//  Brew.swift
//  Droidy
//
//  Created by Mihael Isaev on 24.07.2021.
//

import Foundation

struct Brew {
    private static func tap(_ tap: String) {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = Bash.which("brew")
        process.arguments = ["tap", tap]
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
            print("⛔️ Unable to execute brew tap \(tap): \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
    }
    
    static func install(_ program: String, cask: Bool = false, tap: String? = nil) {
        guard Bash.which("brew") else {
            print("""
                ⛔️ Brew is not installed, so unable to install `\(program)` automatically
                ⛓ Go to https://docs.brew.sh/Installation
                """)
            fatalError()
        }
        if let tap = tap {
            self.tap(tap)
        }
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = Bash.which("brew")
        var args: [String] = ["install"]
        if cask {
            args.append("--cask")
        }
        args.append(program)
        process.arguments = args
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
        print("🍺 Trying to install `\(program)` via brew")
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to install \(program) via brew: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        print("🍻 Successfully installed `\(program)` via brew")
    }
}
