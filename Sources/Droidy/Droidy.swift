import Foundation

internal func projectDirURL(buildDir: String) -> URL {
    URL(fileURLWithPath: projectDir(buildDir: buildDir))
}

internal func projectDir(buildDir: String) -> String {
    var workDir = FileManager.default.currentDirectoryPath
    
    if #available(macOS 13.0, *) {
        if workDir.contains("DerivedData"), let appDir = buildDir.split(separator: "Sources", maxSplits: 1).first {
            workDir = String(appDir)
        }
    }
    
    return workDir
}

public class Droidy {
    let projectFolder: URL
    let java = Java()
    let gradle = Gradle()
    let ndk = NDK()
    lazy var toolchain = Toolchain(ndkPath: ndk._path, projectFolder: projectFolder)
    lazy var sdk = SDK(self)
    lazy var project = Project(self)
	lazy var gradlew = GradleW(self)
	lazy var adb = ADB(self)
	
	var preferredDevice: ADB.Device?
    
    @discardableResult
    public init(buildDir: String = #file) {
        self.projectFolder = projectDirURL(buildDir: buildDir)
        
        let packageFilePath = projectFolder.appendingPathComponent("Package.swift").path
        if !FileManager.default.fileExists(atPath: packageFilePath) {
            print("""
                ⛔️ seems working directory is wrong
                    \(projectFolder.absoluteString)
                💁‍♂️ cause it doesn't contain the Package.swift file
                👉 to fix it please edit your scheme, open Options tab and set custom working directory to the project folder
                """)
            exit(1)
        }
    }
    
    // MARK: - Path
    
    static func folderURL() -> URL {
        let droidyPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".droidy")
        if !FileManager.default.fileExists(atPath: droidyPath.path) {
            do {
                try FileManager.default.createDirectory(at: droidyPath, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("⛔️ Unable to create .droidy path inside the home folder")
                fatalError()
            }
        }
        return droidyPath
    }
    
    // MARK: - Gradle
    
    @discardableResult
    public func preferredGradleVersion(_ version: String) -> Self {
        gradle.version = version
        return self
    }
    
    @discardableResult
    public func linkToGradle(_ link: String) -> Self {
        gradle.url = link
        return self
    }
    
    @discardableResult
    public func localGradleArchive(_ path: String) -> Self {
        guard !path.hasPrefix("~") else {
            print("⛔️ Please specify absolute path for the gradle archive, relatevie path doesn't work")
            fatalError()
        }
        gradle.predownloadedArchivePath = path
        return self
    }
    
    @discardableResult
    public func automaticallyDownloadGradle() -> Self {
        gradle.autoDownload = true
        return self
    }
    
    // MARK: - Toolchain
    
    @discardableResult
    public func preferredToolchainVersion(_ version: String) -> Self {
        toolchain.version = version
        return self
    }
    
    @discardableResult
    public func linkToToolchain(_ link: String) -> Self {
        toolchain.url = link
        return self
    }
    
    @discardableResult
    public func localToolchainArchive(_ path: String) -> Self {
        guard !path.hasPrefix("~") else {
            print("⛔️ Please specify absolute path for the toolchain archive, relatevie path doesn't work")
            fatalError()
        }
        toolchain.predownloadedArchivePath = path
        return self
    }
    
    @discardableResult
    public func automaticallyDownloadToolchain() -> Self {
        toolchain.autoDownload = true
        return self
    }
    
    @discardableResult
    public func architectures(_ archs: Arch...) -> Self {
        toolchain.archs = archs
        return self
    }
    
    // MARK: - NDK
    
    @discardableResult
    public func preferredNDKVersion(_ version: String) -> Self {
        ndk.version = version
        return self
    }
    
    @discardableResult
    public func linkToNDK(_ link: String) -> Self {
        ndk.url = link
        return self
    }
    
    @discardableResult
    public func localNDKArchive(_ path: String) -> Self {
        guard !path.hasPrefix("~") else {
            print("⛔️ Please specify absolute path for the NDK archive, relatevie path doesn't work")
            fatalError()
        }
        ndk.predownloadedArchivePath = path
        return self
    }
    
    @discardableResult
    public func automaticallyDownloadNDK() -> Self {
        ndk.autoDownload = true
        return self
    }
    
    // MARK: - SDK
    
    @discardableResult
    public func linkToSDK(_ link: String) -> Self {
        sdk.url = link
        return self
    }
    
    @discardableResult
    public func localSDKArchive(_ path: String) -> Self {
        guard !path.hasPrefix("~") else {
            print("⛔️ Please specify absolute path for the SDK archive, relatevie path doesn't work")
            fatalError()
        }
        sdk.predownloadedArchivePath = path
        return self
    }
    
    @discardableResult
    public func automaticallyDownloadSDK() -> Self {
        sdk.autoDownload = true
        return self
    }
    
    // MARK: - Java
    
    @discardableResult
    public func automaticallyInstallJava() -> Self {
        java.autoInstall = true
        return self
    }
    
    // MARK: - Project
    
    @discardableResult
    public func projectPath(_ path: String) -> Self {
        project.projectFolder = URL(fileURLWithPath: path)
        return self
    }
    
    @discardableResult
    public func projectApplicationId(_ id: String) -> Self {
        project.applicationId = id
        return self
    }
    
    @discardableResult
    public func projectMinSdkVersion(_ value: Int) -> Self {
        project.minSdkVersion = value
        return self
    }
    
    @discardableResult
    public func projectTargetSdkVersion(_ value: Int) -> Self {
        project.targetSdkVersion = value
        return self
    }
    
    @discardableResult
    public func projectCompileSdkVersion(_ value: Int) -> Self {
        project.compileSdkVersion = value
        return self
    }
    
    @discardableResult
    public func projectVersionCode(_ code: Int) -> Self {
        project.versionCode = code
        return self
    }
    
    @discardableResult
    public func projectVersionName(_ value: String) -> Self {
        project.versionName = value
        return self
    }
    
    @discardableResult
    public func signingConfig(_ config: SigningConfig) -> Self {
        project.signingConfig = config
        return self
    }
    
    @discardableResult
    public func signingConfig(storeFile: String, storePassword: String, keyAlias: String, keyPassword: String) -> Self {
        signingConfig(.init(storeFile: storeFile, storePassword: storePassword, keyAlias: keyAlias, keyPassword: keyPassword))
    }
    
    // MARK: - Prepare
    
    private var prepared = false
    
    private func prepare() {
        guard !prepared else { return }
        prepared = true
        // NOTE: order is important
        java.prepare()
        gradle.prepare()
        toolchain.prepare()
        ndk.prepare()
        sdk.prepare()
        project.prepare()
    }
	
	// MARK: - Preferred ADB Device
	
	@discardableResult
	public func preferredDevice(id: String) -> Self {
		prepare()
		preferredDevice = adb.devicesList().first(where: { $0.id == id })
		return self
	}
	
	@discardableResult
	public func preferredDevice(model: String) -> Self {
		prepare()
		preferredDevice = adb.devicesList().first(where: { $0.model == model })
		return self
	}
	
	@discardableResult
	public func preferredDevice(device: String) -> Self {
		prepare()
		preferredDevice = adb.devicesList().first(where: { $0.device == device })
		return self
	}
    
    // MARK: - Execution
    
    @discardableResult
    public func build(_ productName: String) -> Self {
        prepare()
		toolchain.build(productName, project.projectFolder.path, arch: preferredDevice?.archs.first)
        return self
    }
    
    @discardableResult
    public func run() -> Self {
		guard let device = preferredDevice ?? adb.devicesList().first else {
			print("✅ No devices found to install and launch")
			return self
		}
		gradlew.assembleDebug()
		adb.install(on: device, pathToAPK: gradlew.pathToAPK(arch: device.arch, debug: true).path)
		adb.kill(on: device)
		adb.start(on: device, activity: "MainActivity")
		adb.logcat(on: device)
		return self
    }
}
