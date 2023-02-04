//
//  Swift.swift
//  Droidy
//
//  Created by Mihael Isaev on 22.07.2021.
//

import Foundation

public enum Arch: String {
	// naming for switch arch
    case armv7 = "armv7-unknown-linux-android"
    case aarch64 = "aarch64-unknown-linux-android"
    case i686 = "i686-unknown-linux-android"
    case x86_64 = "x86_64-unknown-linux-android"
    
    var android: String {
        switch self {
        case .armv7: return "armeabi-v7a"
        case .aarch64: return "arm64-v8a"
        case .i686: return "x86"
        case .x86_64: return "x86_64"
        }
    }
	
	static func fromAndroid(_ value: String) -> Self? {
		switch value {
		case "armeabi-v7a": return .armv7
		case "arm64-v8a": return .aarch64
		case "x86": return .i686
		case "x86_64": return .x86_64
		default: return nil
		}
	}
}

class Swift {
    let toolchain: Toolchain
    let ndkPath: String
    
    init (_ toolchain: Toolchain, ndkPath: String) {
        self.toolchain = toolchain
        self.ndkPath = ndkPath
    }
    
    func build(_ arch: Arch, _ productName: String) {
        let stdout = Pipe()
        let stderr = Pipe()
        
        let process = Process()
        process.currentDirectoryPath = FileManager.default.currentDirectoryPath
        process.launchPath = toolchain._pathToAndroidBuild
        process.arguments = ["-target", arch.rawValue, "--product", productName]
        
        var env: [String: String] = ProcessInfo.processInfo.environment
        env["PATH"] = "\(ndkPath)/toolchains/llvm/prebuilt/darwin-x86_64/bin:" + (ProcessInfo.processInfo.environment["PATH"] ?? "")
        
        process.environment = env
        
        process.standardOutput = stdout
        process.standardError = stderr
        
        var resultData = Data()
        let group = DispatchGroup()
        group.enter()
        stdout.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty { // EOF on the pipe
                stdout.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                resultData.append(data)
            }
        }
		let startDate = Date()
        print("🧱 Building swift for \(arch.rawValue)")
        process.launch()
        process.waitUntilExit()
        group.wait()
        guard process.terminationStatus == 0 else {
            let data = resultData
            guard data.count > 0, let rawError = String(data: data, encoding: .utf8) else {
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                if errData.count > 0 {
                    let separator = ": error:"
                    var errString = String(data: errData, encoding: .utf8) ?? "exit code \(process.terminationStatus)"
                    errString = errString.contains(separator) ? errString.components(separatedBy: separator).last?.trimmingCharacters(in: .whitespaces) ?? "" : errString
                    print("🚨 Build failed: \(errString)")
                    fatalError()
                } else {
                    print("🚨 Build failed with exit code \(process.terminationStatus)")
                    fatalError()
                }
            }
            let errors: [CompilationError] = pasreCompilationErrors(rawError)
            guard errors.count > 0 else {
                print("🚨 Unable to parse compilation errors")
                fatalError(rawError)
            }
            var errorsCount = 0
            errors.forEach { error in
                errorsCount = errors.map { $0.places.count }.reduce(0, +)
                print(" ")
                for error in errors {
                    print(" " + error.file.lastPathComponent + " " + error.file.path)
                    print(" ")
                    for place in error.places {
                        let lineNumberString = "\(place.line) |"
                        let errorTitle = " ERROR "
                        let errorTitlePrefix = "   "
                        print("\(errorTitlePrefix)\(errorTitle) \(place.reason)")
                        let _len = (errorTitle.count + 5) - lineNumberString.count
                        let errorLinePrefix = _len > 0 ? (0..._len).map { _ in " " }.joined(separator: "") : ""
                        print("\(errorLinePrefix)\(lineNumberString) \(place.code)")
                        let linePointerBeginning = (0...lineNumberString.count - 2).map { _ in " " }.joined(separator: "") + "|"
                        print("\(errorLinePrefix)\(linePointerBeginning) \(place.pointer)")
                        print(" ")
                    }
                }
            }
            var ending = ""
            if errorsCount == 1 {
                ending = "found 1 error ❗️"
            } else if errorsCount > 1 {
                ending = "found \(errorsCount) errors ❗️❗️❗️"
            }
            print("🥺 Unable to continue cause of failed compilation, \(ending)\n")
            exit(0)
        }
		print("🎉 Built in \(Double(round(1000 * Date().timeIntervalSince(startDate)) / 1000)) seconds")
    }
    
    private class CompilationError {
        public let file: URL
        public struct Place {
            public let line: Int
            public let reason: String
            public let code: String
            public let pointer: String
        }
        public var places: [Place]
        
        public init (file: URL, places: [Place]) {
            self.file = file
            self.places = places
        }
    }
    
    private func pasreCompilationErrors(_ rawError: String) -> [CompilationError] {
        var errors: [CompilationError] = []
        var lines = rawError.components(separatedBy: "\n")
        while !lines.isEmpty {
            var places: [CompilationError.Place] = []
            let line = lines.removeFirst()
            func lineIsPlace(_ line: String) -> Bool {
                line.hasPrefix("/") && line.components(separatedBy: "/").count > 1 && line.contains(".swift:")
            }
            func placeErrorComponents(_ line: String) -> [String]? {
                let components = line.components(separatedBy: ":")
                guard components.count == 5, components[3].contains("error") else {
                    return nil
                }
                return components
            }
            guard lineIsPlace(line) else { continue }
            func parsePlace(_ line: String) {
                guard let components = placeErrorComponents(line) else { return }
                let filePath = URL(fileURLWithPath: components[0])
                func gracefulExit() {
                    if places.count > 0 {
                        if let error = errors.first(where: { $0.file == filePath }) {
                            places.forEach { place in
                                guard error.places.first(where: { $0.line == place.line && $0.reason == place.reason }) == nil
                                    else { return }
                                error.places.append(place)
                            }
                            error.places.sort(by: { $0.line < $1.line })
                        } else {
                            places.sort(by: { $0.line < $1.line })
                            errors.append(.init(file: filePath, places: places))
                        }
                    }
                }
                guard let lineInFile = Int(components[1]) else {
                    gracefulExit()
                    return
                }
                let reason = components[4]
                let lineWithCode = lines.removeFirst()
                let lineWithPointer = lines.removeFirst()
                guard lineWithPointer.contains("^") else {
                    gracefulExit()
                    return
                }
                places.append(.init(line: lineInFile, reason: reason, code: lineWithCode, pointer: lineWithPointer))
                if let nextLine = lines.first, lineIsPlace(nextLine), placeErrorComponents(nextLine)?.first == filePath.path {
                    parsePlace(lines.removeFirst())
                } else {
                    gracefulExit()
                }
            }
            parsePlace(line)
        }
        guard errors.count > 0 else { return [] }
        errors.sort(by: { $0.file.lastPathComponent < $1.file.lastPathComponent })
        return errors
    }
    
    func copyLibs(_ arch: Arch, _ androidProjectPath: String) {
        let outputPathURL = URL(fileURLWithPath: androidProjectPath)
            .appendingPathComponent("app")
            .appendingPathComponent("src")
            .appendingPathComponent("main")
            .appendingPathComponent("jniLibs")
            .appendingPathComponent(arch.android)
        
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = toolchain._pathToAndroidCopyLibs
        process.arguments = ["-target", arch.rawValue, "-output", outputPathURL.path]
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
        print("📑 Copying *.so files for \(arch.android)")
        process.launch()
        process.waitUntilExit()
        group.wait()
        guard process.terminationStatus == 0 else {
            print("⛔️ Unable to copy libs for \(arch.android): \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        let libPathURL = URL(fileURLWithPath: _libPath(arch).trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            try FileManager.default.contentsOfDirectory(atPath: libPathURL.path)
                .filter { $0.hasSuffix(".so") }
                .forEach {
                    try? FileManager.default.removeItem(atPath: outputPathURL.appendingPathComponent($0).path)
                    try? FileManager.default.copyItem(atPath: libPathURL.appendingPathComponent($0).path, toPath: outputPathURL.appendingPathComponent($0).path)
                }
        } catch {
            print("⛔️ Unable to get list of *.so files for \(arch.android) from \(libPathURL.path)")
            print(error)
            fatalError()
        }
    }
    
    private func _libPath(_ arch: Arch) -> String {
        let stdout = Pipe()
        let stderr = Pipe()

        let process = Process()
        process.launchPath = toolchain._pathToAndroidBuild
        process.arguments = ["-target", arch.rawValue, "--show-bin-path"]
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
            print("⛔️ Unable to get *.so files path for \(arch.android): \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
            fatalError()
        }
        guard let str = String(data: resultData, encoding: .utf8), str.count > 0 else {
            print("⛔️ Unable to get *.so files path for \(arch.android)")
            fatalError()
        }
        return str
    }
}
