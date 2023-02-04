//
//  GradleW.swift
//  
//
//  Created by Mihael Isaev on 29.05.2022.
//

import Foundation

class GradleW {
	private let droidy: Droidy
	
	private var _projectPath: String { droidy.project.projectFolder.path }
	private var _pathToBin: String { droidy.project.projectFolder.appendingPathComponent("gradlew").path }
	
	init (_ droidy: Droidy) {
		self.droidy = droidy
	}
	
	func pathToAPK(arch: Arch, debug: Bool) -> URL {
		droidy.project.appBuildOutputsApkFolder
			.appendingPathComponent(debug ? "debug" : "release")
			.appendingPathComponent("app-\(arch.android)-\(debug ? "debug" : "release").apk")
	}
	
	func assembleDebug() {
		print("🧱 Building debug APK")
		let startDate = Date()
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["assembleDebug"]
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
			print("⛔️ Unable to assemble debug with gradlew: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
			fatalError()
		}
		print("🎉 Built in \(Double(round(1000 * Date().timeIntervalSince(startDate)) / 1000)) seconds")
	}
	
	func installDebug() {
		print("Install Debug on all devices started")
		let stdout = Pipe()
		let stderr = Pipe()

		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["installDebug"]
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
			print("⛔️ Unable to install debug with gradlew: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
			fatalError()
		}
		print("Install Debug on all devices finished")
	}
}
