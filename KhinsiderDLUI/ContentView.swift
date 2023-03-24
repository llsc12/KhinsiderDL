//
//  ContentView.swift
//  KhinsiderDLUI
//
//  Created by Lakhan Lothiyi on 23/03/2023.
//

import Foundation
import SwiftTUI
import Khinsider
import Combine

var cancellable = Set<AnyCancellable>()

struct ContentView: View {
  @State var console: String? = nil
  @State var isDownloading = false
  var body: some View {
    VStack {
      Text("KhinsiderDLUI")
        .padding()
        .border(.blue)
        .padding()
      VStack {
        Text("Enter query or URL")
        HStack {
          TextField { str in
            if !isDownloading {
              download(text: str)
            }
          }
          Spacer()
        }
        .border(.red)
      }
      .border(.white)
      
      if let console {
        VStack {
          let lines = console.components(separatedBy: "\n")
          ForEach(lines, id: \.self) { line in
            HStack {
              Text(line)
              Spacer()
            }
          }
          Spacer()
        }
        .border(.white)
      }
    }
  }
  
  func download(text: String) {
    conClear()
    isDownloading = true
    let q = text
    Task {
      var album: Khinsider.KHAlbum
      if let url = URL(string: text), url.isValid() {
        conPrint("URL found, checking on Khinsider...")
        if let khAlbum = try await Khinsider.album(from: url) {
          album = khAlbum
        } else {
          conPrint("[Fail] Couldn't find album on Khinsider.")
          isDownloading = false
          return
        }
      } else {
        conPrint("Searching for \(q) on Khinsider...")
        let results = try await Khinsider.search(q)
        guard let firstAlbum = results.first else {
          conPrint("[Fail] No albums found in search.")
          isDownloading = false
          return
        }
        album = firstAlbum
      }
      conPrint("Downloading album:\n  \(album.title)")
      var quality: Khinsider.KHAlbum.Format = .mp3
      if
        let formats = try? await album.availableFormats,
        formats.contains(.flac)
      {
        quality = .flac
        conPrint("Downloading as flac...")
      } else { conPrint("Downloading as mp3...") }
      guard let links = try? await album.allSourceLinks(quality) else {
        conPrint("[Fail] Failed to get tracks from album.")
        isDownloading = false
        return
      }
      
      for (i, link) in links.enumerated() {
        let filename = link.pathComponents.last!.removingPercentEncoding!
        do {
          conPrint("Downloading \(filename)")
          let data = try Data(contentsOf: link)
          let wd = URL(filePath: FileManager.default.currentDirectoryPath)
          try data.write(to: wd.appending(path: filename), options: .atomic)
        } catch {
          conPrint("[\(filename)] Failed with error \(error)")
          try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        if i % 6 == 0 {
          conClear()
        }
      }
      
      conClear()
      
      conPrint("\(links.count) tracks saved to\n\(FileManager.default.currentDirectoryPath)")
      
      isDownloading = false
    }
  }
  
  func conPrint(_ str: String) {
    if console == nil { console = "" }
    console?.append(str)
    console?.append("\n")
  }
  func conClear() { console = "" }
  func conRemove() { console = nil }
}


extension URL {
  func isValid() -> Bool {
    if let host = self.host {
      return !host.isEmpty
    }
    return false
  }
}
