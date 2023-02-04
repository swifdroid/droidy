//
//  Xattr.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class Xattr {
    static func fixQuarantine(_ filePath: String) {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = Bash.which("xattr")
        process.arguments = ["-r", "-d", "com.apple.quarantine", filePath]
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
            print("⛔️ Unable to fix quarantine permission for \(filePath)")
            fatalError()
        }
    }
}
