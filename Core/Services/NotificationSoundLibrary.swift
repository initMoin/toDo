import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum NotificationSoundLibrary {
   enum ImportError: LocalizedError {
      case unsupportedFormat
      case tooLarge
      case tooLong
      case unreadable

      var errorDescription: String? {
         switch self {
         case .unsupportedFormat:
            return String(localized: "Use MP3, M4A, CAF, WAV, AIFF, or AIF audio.")
         case .tooLarge:
            return String(localized: "Use a sound file smaller than 5 MB.")
         case .tooLong:
            return String(localized: "Use a sound that is 30 seconds or shorter.")
         case .unreadable:
            return String(localized: "toDō could not read this sound file.")
         }
      }
   }

   struct CustomSound: Equatable, Identifiable {
      var id: String { fileName }
      let fileName: String
      let displayName: String
   }

   static let supportedFileTypes: [UTType] = [.audio]
   static let maxDurationSeconds = 30
   static let maxBytes = 5 * 1024 * 1024

   private static let directNotificationExtensions: Set<String> = ["caf", "wav", "aiff", "aif"]
   private static let convertibleExtensions: Set<String> = ["mp3", "m4a"]
   private static var supportedExtensions: Set<String> {
      directNotificationExtensions.union(convertibleExtensions)
   }

   static var soundsDirectory: URL {
      let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
      return libraryDirectory.appendingPathComponent("Sounds", isDirectory: true)
   }

   static func currentCustomSoundName(userDefaults: UserDefaults = .standard) -> String? {
      userDefaults.string(forKey: AppPreferences.Keys.customNotificationSoundName)
         .flatMap { $0.isEmpty ? nil : $0 }
   }

   static func currentCustomSoundDisplayName(userDefaults: UserDefaults = .standard) -> String? {
      userDefaults.string(forKey: AppPreferences.Keys.customNotificationSoundDisplayName)
         .flatMap { $0.isEmpty ? nil : $0 }
   }

   static func listCustomSounds() -> [CustomSound] {
      let directory = soundsDirectory
      guard let urls = try? FileManager.default.contentsOfDirectory(
         at: directory,
         includingPropertiesForKeys: nil
      ) else {
         return []
      }

      return urls
         .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
         .map { url in
            CustomSound(
               fileName: url.lastPathComponent,
               displayName: url.deletingPathExtension().lastPathComponent
            )
         }
         .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
   }

   static func importSound(
      from url: URL,
      userDefaults: UserDefaults = .standard
   ) async throws -> CustomSound {
      let didAccess = url.startAccessingSecurityScopedResource()
      defer {
         if didAccess {
            url.stopAccessingSecurityScopedResource()
         }
      }

      try await validate(url)
      try FileManager.default.createDirectory(
         at: soundsDirectory,
         withIntermediateDirectories: true
      )

      let fileName = sanitizedFileName(for: url)
      let destinationURL = soundsDirectory.appendingPathComponent(fileName)

      if FileManager.default.fileExists(atPath: destinationURL.path) {
         try FileManager.default.removeItem(at: destinationURL)
      }

      if directNotificationExtensions.contains(url.pathExtension.lowercased()) {
         try FileManager.default.copyItem(at: url, to: destinationURL)
      } else {
         try convertToNotificationCAF(sourceURL: url, destinationURL: destinationURL)
      }

      let displayName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
      userDefaults.set(fileName, forKey: AppPreferences.Keys.customNotificationSoundName)
      userDefaults.set(displayName, forKey: AppPreferences.Keys.customNotificationSoundDisplayName)

      return CustomSound(fileName: fileName, displayName: displayName)
   }

   static func clearSelectedCustomSound(userDefaults: UserDefaults = .standard) {
      userDefaults.removeObject(forKey: AppPreferences.Keys.customNotificationSoundName)
      userDefaults.removeObject(forKey: AppPreferences.Keys.customNotificationSoundDisplayName)
   }

   private static func validate(_ url: URL) async throws {
      let fileExtension = url.pathExtension.lowercased()
      guard supportedExtensions.contains(fileExtension) else {
         throw ImportError.unsupportedFormat
      }

      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
      guard byteCount <= maxBytes else {
         throw ImportError.tooLarge
      }

      let asset = AVURLAsset(url: url)
      let durationTime = try await asset.load(.duration)
      let duration = CMTimeGetSeconds(durationTime)
      guard duration.isFinite, duration > 0 else {
         throw ImportError.unreadable
      }

      guard duration <= Double(maxDurationSeconds) else {
         throw ImportError.tooLong
      }
   }

   private static func sanitizedFileName(for url: URL) -> String {
      let rawBaseName = url.deletingPathExtension().lastPathComponent
      let safeBaseName = rawBaseName
         .components(separatedBy: CharacterSet.alphanumerics.inverted)
         .filter { !$0.isEmpty }
         .joined(separator: "-")
         .lowercased()

      let baseName = safeBaseName.isEmpty ? "todo-custom-sound" : safeBaseName
      let sourceExtension = url.pathExtension.lowercased()
      let storedExtension = directNotificationExtensions.contains(sourceExtension) ? sourceExtension : "caf"
      return "\(baseName)-\(UUID().uuidString.prefix(8)).\(storedExtension)"
   }

   private static func convertToNotificationCAF(sourceURL: URL, destinationURL: URL) throws {
      let inputFile = try AVAudioFile(forReading: sourceURL)
      let processingFormat = inputFile.processingFormat
      let outputFile = try AVAudioFile(
         forWriting: destinationURL,
         settings: processingFormat.settings,
         commonFormat: processingFormat.commonFormat,
         interleaved: processingFormat.isInterleaved
      )

      let frameCapacity = AVAudioFrameCount(processingFormat.sampleRate)
      guard let buffer = AVAudioPCMBuffer(
         pcmFormat: processingFormat,
         frameCapacity: frameCapacity
      ) else {
         throw ImportError.unreadable
      }

      while inputFile.framePosition < inputFile.length {
         try inputFile.read(into: buffer)
         if buffer.frameLength == 0 {
            break
         }
         try outputFile.write(from: buffer)
      }
   }
}
