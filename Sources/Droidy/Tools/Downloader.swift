//
//  Downloader.swift
//  Droidy
//
//  Created by Mihael Isaev on 23.07.2021.
//

import Foundation

class Downloader {
    static func download(_ name: String, _ size: String, _ link: String) -> String {
        let linkURL = URL(string: link)!
        let group = DispatchGroup()
        var localPath: String = ""
        group.enter()
        let task = URLSession.shared.downloadTask(with: linkURL) {
            if let error = $2 {
                print("⛔️ Unable to download \(name): \(error)")
                fatalError()
            }
            guard let response = $1 as? HTTPURLResponse, response.statusCode == 200 else {
                print("⛔️ Unable to download \(name), http code is not 200")
                fatalError()
            }
            guard let path = $0?.path else {
                print("⛔️ Unable to get path of the downloaded \(name)")
                fatalError()
            }
            guard FileManager.default.fileExists(atPath: path) else {
                print("⛔️ Seems downloaded \(name) has unexpectedly disappeared from the temp folder")
                fatalError()
            }
            localPath = path
            group.leave()
        }
        var progressPrints = 0
        let observer = task.progress.observe(\.fractionCompleted) { progress, _ in
            let p = progress.fractionCompleted * 100
            if p >= 25, progressPrints == 0 {
                progressPrints += 1
                print("25% not bad 😃")
            } else if p >= 50, progressPrints == 1 {
                progressPrints += 1
                print("50% hold on 🤗")
            } else if p >= 75, progressPrints == 2 {
                progressPrints += 1
                print("75% almost done 😏")
            }
        }
        task.resume()
        print("🚰 Please wait... downloading \(name) (about \(size)) from \(link)")
        group.wait()
        observer.invalidate()
        print("100% yaaay! 👍")
        let tmpFolder = URL(fileURLWithPath: localPath).deletingLastPathComponent()
        let finalTempPath = tmpFolder.appendingPathComponent(linkURL.lastPathComponent).path
        do {
            try? FileManager.default.removeItem(atPath: finalTempPath)
            try FileManager.default.moveItem(atPath: localPath, toPath: finalTempPath)
        } catch {
            print("⛔️ Unable to prepare temp file for \(name)\n\(error)")
            fatalError()
        }
        return finalTempPath
    }
}
