//
//  App.swift
//  KhinsiderDL
//
//  Created by Lakhan Lothiyi on 23/03/2023.
//

import Foundation
import ArgumentParser
import Khinsider

@main
struct KhinsiderDL: AsyncParsableCommand {
  @Argument(help: "Album URL to download")
  var url: String
  
  @Option(help: "Audio format [flac, mp3]")
  var format: String = "flac"
  
  func run() async throws {
    // example album url
    // https://downloads.khinsider.com/game-soundtracks/album/wii-original-system-soundtrack-wii-gamerip-2006
    // example track url
    // https://downloads.khinsider.com/game-soundtracks/album/wii-original-system-soundtrack-wii-gamerip-2006/1-01.%2520Wii%2520Menu.mp3
    // example dl url
    // https://vgmsite.com/soundtracks/wii-original-system-soundtrack-wii-gamerip-2006/czosweglcw/1-01.%20Wii%20Menu.flac
    guard let format = Khinsider.KHAlbum.Format(rawValue: format.lowercased()) else { throw ValidationError("Invalid format specified.") }
    guard let url = URL(string: url) else { throw ValidationError("Invalid URL.") }
    print("Searching for album...")
    guard let album = try await Khinsider.album(from: url) else { throw ValidationError("Couldn't find album.") }
    print("Found \(album.title), getting tracks...")
		
		let quality: Khinsider.KHAlbum.Format = await {
			if
				let formats = try? await album.availableFormats,
				formats.contains(.flac)
			{
				print("Downloading as flac...")
				return .flac
			} else {
				print("Flac not available, downloading as mp3...")
				return .mp3
			}
		}()
    
    let sourceUrls = await withTaskGroup(of: URL?.self) { group in
      try? await album.tracks.forEach { track in
        group.addTask {
          print("Scraping \(track.title)")
          return await track.getSourceLink(quality)
        }
      }
      
      var collected = [URL]()
      
      for await value in group {
        if let value {
          collected.append(value)
        }
      }
      
      return collected
    }
    
    print("Downloading \(sourceUrls.count) tracks.")
    
    sourceUrls.forEach { url in
      let filename = url.pathComponents.last!.removingPercentEncoding!
      do {
        print("Downloading \(filename)")
        let data = try Data(contentsOf: url)
        let wd = URL(filePath: FileManager.default.currentDirectoryPath)
        try data.write(to: wd.appending(path: filename), options: .atomic)
      } catch {
        print("[\(filename)] Failed with error \(error)")
      }
    }
  }
}
