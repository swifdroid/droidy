//
//  Bash.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

struct Bash {
    /// Checks if program is present
    public static func which(_ program: String) -> Bool {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "which \(program)"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return false
        }
        
        let data = outHandle.readDataToEndOfFile()
        guard data.count > 0 else {
            return false
        }
        return true
    }
    
    /// Returns path to program binary
    public static func which(_ program: String) -> String {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "which \(program)"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to find program named \(program), please install it")
            fatalError()
        }
        
        let data = outHandle.readDataToEndOfFile()
        guard data.count > 0, let path = String(data: data, encoding: .utf8) else {
            print("⛔️ Unable to find program named \(program), please install it")
            exit(1)
        }
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
