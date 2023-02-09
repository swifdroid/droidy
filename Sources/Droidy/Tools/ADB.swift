//
//  ADB.swift
//  
//
//  Created by Mihael Isaev on 29.05.2022.
//

import Foundation

class ADB {
	private let droidy: Droidy
	
	private var _projectPath: String { droidy.project.androidProjectFolder.path }
	private var _pathToBin: String { droidy.sdk.platformToolsFolder.appendingPathComponent("adb").path }
	
	init (_ droidy: Droidy) {
		self.droidy = droidy
	}
	
	struct Device: CustomStringConvertible {
		let id: String
		let archs: [Arch]
		var arch: Arch { archs.first! }
		let model, device: String
		let isEmulator: Bool
		
		var description: String {
			"Device[id: \(id) model: \(model) device: \(device) isEmulator: \(isEmulator) archs: \(archs.map { $0.android })]"
		}
	}
	
	func devicesList() -> [Device] {
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["devices", "-l"]
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
			print("⛔️ Unable to get connected devices: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
			fatalError()
		}
		guard let out = String(data: resultData, encoding: .utf8) else {
			print("📱 Unable to get connected devices")
			return []
		}
		let lines = out.components(separatedBy: "\n").compactMap { $0.contains(" device ") ? $0 : nil }
		guard lines.count > 0 else {
			print(out)
			return []
		}
		var devices: [Device] = []
		lines.forEach { line in
			let a = line.components(separatedBy: " device ")
			guard a.count == 2 else { return }
			let id = a[0].trimmingCharacters(in: .whitespacesAndNewlines)
			let isEmulator = id.contains("emulator")
			let b = a[1]
			let c = b.components(separatedBy: " ")
			let model = c[isEmulator ? 1 : 2].components(separatedBy: ":")[1]
			let device = c[isEmulator ? 2 : 3].components(separatedBy: ":")[1]
			devices.append(.init(id: id, archs: deviceArchs(id: id), model: model, device: device, isEmulator: id.contains("emulator")))
		}
		return devices
	}
	
	func deviceArchs(id: String) -> [Arch] {
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["-s", id, "shell", "getprop", "ro.vendor.product.cpu.abilist"]
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
			print("⛔️ Unable to get device \(id) archs: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
			fatalError()
		}
		guard let out = String(data: resultData, encoding: .utf8) else {
			print("📱 Unable to get device \(id) archs")
			return []
		}
		return out
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.components(separatedBy: ",")
			.compactMap { Arch.fromAndroid($0) }
	}
	
	func install(on device: Device, pathToAPK: String) {
		print("📲 Installing app on \(device.model)")
		let startDate = Date()
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["-s", device.id, "install", pathToAPK]
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
			print("⛔️ Unable to install apk on device \(device.id): \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
			exit(1)
		}
		guard let out = String(data: resultData, encoding: .utf8) else {
			print("📱 Unable to install apk on device \(device.id)")
            exit(1)
		}
		let lines = out.trimmingCharacters(in: .newlines).components(separatedBy: "\n")
		guard lines.count > 0, lines.last?.contains("Success") == true else {
			print("📱 Unable to install apk on device \(device.id):\n\(out)")
            exit(1)
		}
		print("🎉 Installed in \(Double(round(1000 * Date().timeIntervalSince(startDate)) / 1000)) seconds")
	}
	
	func start(on device: Device, activity: String) {
		print("📲 Starting app on \(device.model)")
		let startDate = Date()
		let stdout = Pipe()
		let stderr = Pipe()
		
		let intent = "\(droidy.project.applicationId)/.\(activity)"
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["-s", device.id, "shell", "am", "start", "-n", intent]
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
			print("⛔️ Unable to start app on device \(device.id): \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
			fatalError()
		}
		guard let out = String(data: resultData, encoding: .utf8) else {
			print("📱 Unable to start app on device \(device.id)")
			fatalError()
		}
		guard out.trimmingCharacters(in: .whitespacesAndNewlines) == "Starting: Intent { cmp=\(intent) }" else {
			print("📱 Unable to start app on device \(device.id):\n\(out)")
			fatalError()
		}
		print("🚀 Started in \(Double(round(1000 * Date().timeIntervalSince(startDate)) / 1000)) seconds")
	}
	
	func pids(on device: Device, attempt: Int = 1) -> [String] {
		guard attempt < 5 else {
			print("📱 Unable to get app pid on device \(device.id)")
			exit(1)
		}
		
		if attempt > 1 {
			sleep(1)
		}
		
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = Bash.which("sh")
		process.currentDirectoryPath = _projectPath
		process.arguments = ["-c", "\(_pathToBin) -s \(device.id) shell pidof -s \(droidy.project.applicationId)"]
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
			return pids(on: device, attempt: attempt + 1)
		}
		guard let out = String(data: resultData, encoding: .utf8) else {
			print("📱 Unable to get app pid on device \(device.id)")
			fatalError()
		}
		return out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
	}
	
	func kill(on device: Device) {
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["-s", device.id, "shell", "am", "force-stop", droidy.project.applicationId]
		process.standardOutput = stdout
		process.standardError = stderr

		let group = DispatchGroup()
		group.enter()
		stdout.fileHandleForReading.readabilityHandler = { fh in
			let data = fh.availableData
			if data.isEmpty {
				stdout.fileHandleForReading.readabilityHandler = nil
				group.leave()
			}
		}
		process.launch()
		process.waitUntilExit()
		group.wait()
	}
	
	func logcat(on device: Device) {
		let pids = pids(on: device)
		guard let pid = pids.first else {
			print("📱 Unable to to find launched app on device \(device.id)")
			return
		}
		
		let stdout = Pipe()
		let stderr = Pipe()
		
		let process = Process()
		process.launchPath = _pathToBin
		process.currentDirectoryPath = _projectPath
		process.arguments = ["-s", device.id, "logcat", "--pid", pid]
		process.standardOutput = stdout
		process.standardError = stderr

		let group = DispatchGroup()
		group.enter()
		stdout.fileHandleForReading.readabilityHandler = { fh in
			let data = fh.availableData
			if data.isEmpty {
				stdout.fileHandleForReading.readabilityHandler = nil
				group.leave()
			} else {
				if let str = String(data: data, encoding: .utf8) {
					str.trimmingCharacters(in: .newlines).components(separatedBy: "\n").forEach {
						if $0 == "--------- beginning of main" {
							print("🗞 LOGCAT STARTED")
						} else if $0 == "--------- beginning of crash" {
							print("💥 APP HAS BEEN CRASHED")
						} else {
							var components = $0.components(separatedBy: " ")
							guard components.count > 8 else {
								print($0.trimmingCharacters(in: .whitespacesAndNewlines))
								return
							}
							let time = components[1].components(separatedBy: ".")[0]
//							print("components.count: \(components.count) components: \(components)")
							let level = components[6]
							let tag = components[7].trimmingCharacters(in: .whitespacesAndNewlines)
							let trueLevel: String
							switch level {
							case "A": trueLevel = "🔴"
							case "D": trueLevel = "🟤"
							case "E": trueLevel = "🟠"
							case "I": trueLevel = "🔵"
							case "V": trueLevel = "🟣"
							case "W": trueLevel = "🟡"
							default: trueLevel = "⚪️"
							}
							components.removeFirst(8)
							components.removeAll(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).count == 0 || $0 == ":" })
							components.insert(tag, at: 0)
							components.insert("[\(time)]", at: 0)
							components.insert(trueLevel, at: 0)
							print(components.joined(separator: " "))
						}
					}
				} else {
					print("🛑🛑🛑🛑🛑🛑 Unable to convert data into string")
				}
			}
		}
		process.launch()
		process.waitUntilExit()
		group.wait()
		print("⛔️ Logcat error: \(String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)")
		print("🗞 Logcat stopped")
	}
}
