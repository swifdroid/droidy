//
//  Project.swift
//  Droidy
//
//  Created by Mihael Isaev on 24.07.2021.
//

import Foundation

public struct SigningConfig {
    let storeFile, storePassword, keyAlias, keyPassword: String
}

class Project {
    let swiftProjectFolder: URL
    lazy var projectFolder = swiftProjectFolder.appendingPathComponent("AndroidProject")
    var androidProjectFolder: URL { projectFolder }
    var appFolder: URL { projectFolder.appendingPathComponent("app") }
	var appBuildFolder: URL { appFolder.appendingPathComponent("build") }
	var appBuildOutputsFolder: URL { appBuildFolder.appendingPathComponent("outputs") }
	var appBuildOutputsApkFolder: URL { appBuildOutputsFolder.appendingPathComponent("apk") }
    var appSrcFolder: URL { appFolder.appendingPathComponent("src") }
    var appSrcMainFolder: URL { appSrcFolder.appendingPathComponent("main") }
    var manifestFile: URL { appSrcMainFolder.appendingPathComponent("AndroidManifest.xml") }
    var appSrcMainAssetsFolder: URL { appSrcMainFolder.appendingPathComponent("assets") }
    var appSrcMainJavaFolder: URL { appSrcMainFolder.appendingPathComponent("java") }
    var appSrcMainResFolder: URL { appSrcMainFolder.appendingPathComponent("res") }
    var applicationId = "com.my.app"
    var minSdkVersion = 24
    var targetSdkVersion = 32
    var compileSdkVersion = 32
    var versionCode = 1
    var versionName = "1.0"
    var signingConfig: SigningConfig = .init(storeFile: "", storePassword: "", keyAlias: "", keyPassword: "")
    var manifest: Manifest = .init()
    
    private let droidy: Droidy
    
    init (_ droidy: Droidy) {
        self.droidy = droidy
        self.swiftProjectFolder = droidy.swiftProjectFolder
    }
    
    func prepare() {
        if !FileManager.default.fileExists(atPath: projectFolder.path) {
            do {
                try FileManager.default.createDirectory(atPath: projectFolder.path, withIntermediateDirectories: false, attributes: nil)
                cookProjectBuildGradle()
                cookGradleWrapper()
                cookProjectSettingsGradle()
                cookProjectGradleProperties()
                cookProjectLocalProperties()
                cookProjectGitIgnore()
                cookAppFolder()
            } catch {
                print("⛔️ Unable to prepare android project\n\(error)")
                try! FileManager.default.removeItem(atPath: projectFolder.path)
                exit(1)
            }
        }
    }
    
    func cookProjectSettingsGradle() {
        let text = """
            include ':app'
            rootProject.name = "\(projectFolder.lastPathComponent)"
            """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `settings.gradle` file")
            fatalError()
        }
        let filePath = androidProjectFolder.appendingPathComponent("settings.gradle").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `settings.gradle` file")
            fatalError()
        }
    }
    
    func cookProjectGradleProperties() {
        let text = """
            org.gradle.jvmargs=-Xmx1536m
            """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `gradle.properties` file")
            fatalError()
        }
        let filePath = androidProjectFolder.appendingPathComponent("gradle.properties").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `gradle.properties` file")
            fatalError()
        }
    }
    
    func cookProjectLocalProperties() {
        let text = """
            sdk.dir=\(droidy.sdk.sdkFolder.path)
            """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `local.properties` file")
            fatalError()
        }
        let filePath = androidProjectFolder.appendingPathComponent("local.properties").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `local.properties` file")
            fatalError()
        }
    }
    
    func cookProjectGitIgnore() {
        let text = """
        *.iml
        .gradle
        /local.properties
        /.idea/caches
        /.idea/libraries
        /.idea/modules.xml
        /.idea/workspace.xml
        /.idea/navEditor.xml
        /.idea/assetWizardSettings.xml
        /.idea/codeStyles/Project.xml
        .DS_Store
        /build
        /.build
        /captures
        .externalNativeBuild
        """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `.gitignore` file")
            fatalError()
        }
        let filePath = androidProjectFolder.appendingPathComponent(".gitignore").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `.gitignore` file")
            fatalError()
        }
    }
    
    func cookProjectBuildGradle() {
        print("🗼 Cooking build.gradle")
        let text = """
        import java.nio.file.Paths
        
        buildscript {
            ext.kotlin_version = '1.4.21'
            repositories {
                google()
                jcenter()
            }
            dependencies {
                classpath 'com.android.tools.build:gradle:4.1.3'
                classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
            }
        }

        allprojects {
            repositories {
                google()
                jcenter()
            }
        }

        task clean(type: Delete) {
            delete rootProject.buildDir
            delete new File(Paths.get(rootDir.toString(), "app/src/main/jniLibs").toString())
        }
        """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `build.gradle` file")
            fatalError()
        }
        let filePath = androidProjectFolder.appendingPathComponent("build.gradle").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `build.gradle` file")
            exit(1)
        }
    }
    
    func cookAppFolder() {
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(atPath: appFolder.path, withIntermediateDirectories: true, attributes: nil)
        }
        if !FileManager.default.fileExists(atPath: appSrcFolder.path) {
            try? FileManager.default.createDirectory(atPath: appSrcFolder.path, withIntermediateDirectories: true, attributes: nil)
        }
        if !FileManager.default.fileExists(atPath: appSrcMainFolder.path) {
            try? FileManager.default.createDirectory(atPath: appSrcMainFolder.path, withIntermediateDirectories: true, attributes: nil)
        }
        cookAppBuildGradle()
        cookAppProguardRules()
        cookAppGitIgnore()
        cookAppManifest()
        cookAssetsFiles()
        cookJavaFiles()
        cookResourceFiles()
    }
    
    func cookGradleWrapper() {
        guard !FileManager.default.fileExists(atPath: androidProjectFolder.appendingPathComponent("gradlew").path) else { return }
        print("🗜 Generating gradle wrapper")
        droidy.gradle.generateWrapper(projectPath: projectFolder.path)
    }
    
    /// https://stackoverflow.com/questions/21423633/build-project-without-android-studio
    
    func cookAppBuildGradle() {
        print("🗼 Cooking app/build.gradle")
        let text = """
        apply plugin: 'com.android.application'
        apply plugin: 'kotlin-android'
        
        android {
            ndkVersion "\(droidy.ndk.version)"
            compileSdkVersion \(compileSdkVersion)
            defaultConfig {
                applicationId "\(applicationId)"
                minSdkVersion \(minSdkVersion)
                targetSdkVersion \(targetSdkVersion)
                versionCode \(versionCode)
                versionName "\(versionName)"
                testInstrumentationRunner "android.support.test.runner.AndroidJUnitRunner"
            }
            signingConfigs {
                mySigning {
                    storeFile file("\(signingConfig.storeFile)")
                    storePassword "\(signingConfig.storePassword)"
                    keyAlias "\(signingConfig.keyAlias)"
                    keyPassword "\(signingConfig.keyPassword)"
                }
            }
            buildTypes {
                release {
                    minifyEnabled false
                    proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
                    signingConfig signringConfigs.mySigning
                }
                debug {
                    minifyEnabled false
                    proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
                }
            }
            sourceSets {}
            splits {
                abi {
                    enable true
                    reset()
                    include \(droidy.toolchain.archs.map { "'\($0.android)'" }.joined(separator: ", "))
                    universalApk false
                }
            }
        }
        
        dependencies {
            implementation fileTree(dir: 'libs', include: ['*.jar'])
            implementation 'com.android.support:appcompat-v7:28.0.0'
            implementation 'com.android.support.constraint:constraint-layout:2.0.4'
            testImplementation 'junit:junit:4.13.1'
            androidTestImplementation 'com.android.support.test:runner:1.0.2'
            androidTestImplementation 'com.android.support.test.espresso:espresso-core:3.0.2'
            
            implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
            implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.3.0'
        }
        
        repositories {
            mavenCentral()
        }
        """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `build.gradle` file")
            fatalError()
        }
        let filePath = appFolder.appendingPathComponent("build.gradle").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable save `build.gradle` file")
            fatalError()
        }
    }
    
    func cookAppProguardRules() {
        let filePath = appFolder.appendingPathComponent("proguard-rules.pro").path
        guard !FileManager.default.fileExists(atPath: filePath) else { return }
        print("🗼 Touching app/proguard-rules.pro")
        FileManager.default.createFile(atPath: filePath, contents: Data(), attributes: nil)
    }
    
    func cookAppGitIgnore() {
        let text = """
        /build
        """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `.gitignore` file")
            fatalError()
        }
        let filePath = appFolder.appendingPathComponent(".gitignore").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `.gitignore` file")
            fatalError()
        }
    }
    
    // TODO: localize values https://developer.android.com/guide/topics/resources/localization
    
    func cookAppManifest() {
        let text = """
        <?xml version="1.0" encoding="utf-8"?>
        <manifest xmlns:android="http://schemas.android.com/apk/res/android"
                  package="\(applicationId)">

            <uses-permission android:name="android.permission.INTERNET" />
            <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

            <application
                android:allowBackup="true"
                android:extractNativeLibs="false"
                android:icon="@mipmap/ic_launcher"
                android:label="@string/app_name"
                android:roundIcon="@mipmap/ic_launcher_round"
                android:supportsRtl="true"
                android:theme="@style/AppTheme">
                <activity android:name=".MainActivity">
                    <intent-filter>
                        <action android:name="android.intent.action.MAIN"/>
                        <category android:name="android.intent.category.LAUNCHER"/>
                    </intent-filter>
                </activity>
            </application>

        </manifest>
        """
        guard let data = text.data(using: .utf8) else {
            print("⛔️ Unable to cook `AndroidManifest.xml` file")
            fatalError()
        }
        let filePath = appSrcMainFolder.appendingPathComponent("AndroidManifest.xml").path
        try? FileManager.default.removeItem(atPath: filePath)
        guard FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil) else {
            print("⛔️ Unable to save `AndroidManifest.xml` file")
            fatalError()
        }
    }
    
    func cookAssetsFiles() {
        let assetsPath = appSrcMainAssetsFolder.path
        if !FileManager.default.fileExists(atPath: assetsPath) {
            do {
                try FileManager.default.createDirectory(atPath: assetsPath, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("⛔️ Unable to create `assets` folder")
                fatalError()
            }
        }
        cookAssetCACertFile()
    }
    
    func cookAssetCACertFile() {
        let certPath = appSrcMainAssetsFolder.appendingPathComponent("cacert.pem").path
        guard !FileManager.default.fileExists(atPath: certPath) else { return }
        let localPath = Downloader.download("mozilla's cacert.pem", "250Kb", "https://curl.se/ca/cacert.pem")
        do {
            try FileManager.default.moveItem(atPath: localPath, toPath: certPath)
        } catch {
            print("⛔️ Unable to move downloaded `cacert.pem` into assets folder")
            fatalError()
        }
    }
    
    func cookJavaFiles() {
        if !FileManager.default.fileExists(atPath: appSrcMainJavaFolder.path) {
            do {
                try FileManager.default.createDirectory(atPath: appSrcMainJavaFolder.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("⛔️ Unable to create folder: " + appSrcMainJavaFolder.path)
                fatalError()
            }
        }
        cookJavaAppFiles()
        cookJavaSwiftFiles()
    }
    
    func cookJavaAppFiles() {
        var appCodeFolder = appSrcMainJavaFolder
        var pathParts = applicationId.components(separatedBy: ".")
        while let part = pathParts.first {
            pathParts.removeFirst()
            appCodeFolder.appendPathComponent(part)
            if !FileManager.default.fileExists(atPath: appCodeFolder.path) {
                do {
                    try FileManager.default.createDirectory(atPath: appCodeFolder.path, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    print("⛔️ Unable to create folder: " + appCodeFolder.path)
                    fatalError()
                }
            }
        }
    }
    
    func cookJavaSwiftFiles() {
        
    }
    
    func cookResourceFiles() {
        // launcher icon in all sizes
        
        // values: colors, strings, styles
    }
}
