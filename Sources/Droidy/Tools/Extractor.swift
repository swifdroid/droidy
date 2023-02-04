//
//  Extractor.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

struct Extractor {
    static func extract(name: String, archive archivePath: String, dest destinationPath: String) {
        let stdout = Pipe()
        let stderr = Pipe()
        
        let process = Process()
        let fileURL = URL(fileURLWithPath: archivePath)
        let filename = fileURL.lastPathComponent
        let purefilename = fileURL.deletingPathExtension().lastPathComponent
        let resultPath = URL(fileURLWithPath: destinationPath).deletingLastPathComponent().appendingPathComponent(purefilename).path
        if filename.hasSuffix(".tar.gz") {
            if !FileManager.default.fileExists(atPath: destinationPath) {
                try? FileManager.default.createDirectory(atPath: destinationPath, withIntermediateDirectories: false, attributes: nil)
            }
            process.launchPath = Bash.which("tar")
            process.arguments = ["xzf", archivePath, "--strip-components=1", "--directory", destinationPath]
        } else if filename.hasSuffix(".zip") {
            try? FileManager.default.removeItem(atPath: resultPath)
            process.launchPath = Bash.which("unzip")
            process.arguments = [archivePath, "-d", URL(fileURLWithPath: destinationPath).deletingLastPathComponent().path]
        } else {
            print("⛔️ Unabe to extract \(filename) cause this filetype is not suppeorted")
            fatalError()
        }
        
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
        print("🥡 Please wait... extracting \(name)")
        process.launch()
        process.waitUntilExit()
        group.wait()
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to extract \(name): \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
    }
}
