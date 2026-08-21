import AVFoundation
import Combine
import Foundation
import OSLog
import Speech

@MainActor
final class VoiceToDoTranscriptionService: ObservableObject {
   enum CaptureState: Equatable {
      case idle
      case requestingPermission
      case listening
      case stopped
      case failed(String)
   }

   @Published private(set) var state: CaptureState = .idle
   @Published private(set) var transcript = ""

   private let recorder = VoiceToDoRecorder()

   var isListening: Bool {
      state == .listening
   }

   var isRequestingPermission: Bool {
      state == .requestingPermission
   }

   func start(locale: Locale = .current) async {
      guard state != .requestingPermission, !isListening else { return }

      state = .requestingPermission
      transcript = ""
      AppLog.info("Voice capture: start requested")

      guard await requestSpeechAuthorization() else {
         state = .failed(String(localized: "Speech recognition permission is required."))
         return
      }
      AppLog.info("Voice capture: speech authorization granted")

      guard await requestMicrophoneAuthorization() else {
         state = .failed(String(localized: "Microphone access is required."))
         return
      }
      AppLog.info("Voice capture: microphone authorization granted")

      do {
         try await recorder.start(
            locale: locale,
            onTranscript: { [weak self] text in
               Task { @MainActor in
                  self?.transcript = text
               }
            },
            onCompletion: { [weak self] failureMessage in
               Task { @MainActor in
                  guard let self else { return }
                  if let failureMessage {
                     self.state = .failed(failureMessage)
                  } else {
                     self.state = .stopped
                  }
               }
            }
         )
         if state == .requestingPermission {
            state = .listening
         }
      } catch {
         let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
         state = .failed(message)
         AppLog.error("Voice capture failed: \(message)")
      }
   }

   func stop() async {
      AppLog.info("Voice capture: stop requested")
      await recorder.stop()
      if state == .listening {
         state = .stopped
      }
   }

   func reset() async {
      await recorder.stop()
      transcript = ""
      state = .idle
   }

   private func requestSpeechAuthorization() async -> Bool {
      switch SFSpeechRecognizer.authorizationStatus() {
      case .authorized:
         return true
      case .notDetermined:
         return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
               continuation.resume(returning: status == .authorized)
            }
         }
      default:
         return false
      }
   }

   private func requestMicrophoneAuthorization() async -> Bool {
      switch AVAudioApplication.shared.recordPermission {
      case .granted:
         return true
      case .denied:
         return false
      case .undetermined:
         return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
               continuation.resume(returning: granted)
            }
         }
      @unknown default:
         return false
      }
   }
}

private actor VoiceToDoRecorder {
   private static let logger = Logger(subsystem: "dev.iamshift.toDo", category: "VoiceCapture")

   private let audioEngine = AVAudioEngine()
   private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
   private var recognitionTask: SFSpeechRecognitionTask?
   private var hasInstalledAudioTap = false
   private var isAudioSessionActive = false
   private var captureID: UUID?

   func start(
      locale: Locale,
      onTranscript: @escaping @Sendable (String) -> Void,
      onCompletion: @escaping @Sendable (String?) -> Void
   ) async throws {
      stop()

      guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
         throw VoiceToDoCaptureError.speechUnavailable
      }
      guard recognizer.supportsOnDeviceRecognition else {
         throw VoiceToDoCaptureError.onDeviceRecognitionUnavailable
      }

      let currentCaptureID = UUID()
      captureID = currentCaptureID

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      request.requiresOnDeviceRecognition = true
      recognitionRequest = request

      do {
         Self.logger.info("Voice capture: audio session activating")
         let session = AVAudioSession.sharedInstance()
         try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
         try session.setActive(true, options: .notifyOthersOnDeactivation)
         isAudioSessionActive = true

         let inputNode = audioEngine.inputNode
         let format = inputNode.outputFormat(forBus: 0)
         Self.logger.info("Voice capture: input format \(format.sampleRate) Hz, \(format.channelCount) channels")
         guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceToDoCaptureError.microphoneUnavailable
         }

         inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
         }
         hasInstalledAudioTap = true
         Self.logger.info("Voice capture: tap installed")

         audioEngine.prepare()
         try audioEngine.start()
         Self.logger.info("Voice capture: engine started")

         recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
               onTranscript(result.bestTranscription.formattedString)
            }

            guard error != nil || result?.isFinal == true else { return }
            let failureMessage: String?
            if let error, !Self.isCancellationError(error) {
               failureMessage = error.localizedDescription
            } else {
               failureMessage = nil
            }

            Task {
               guard let self else { return }
               await self.finishCapture(
                  id: currentCaptureID,
                  failureMessage: failureMessage,
                  onCompletion: onCompletion
               )
            }
         }
      } catch {
         stop()
         throw error
      }
   }

   func stop() {
      captureID = nil

      if audioEngine.isRunning {
         audioEngine.stop()
      }
      removeAudioTapIfNeeded()

      recognitionRequest?.endAudio()
      recognitionTask?.cancel()
      recognitionTask = nil
      recognitionRequest = nil

      if isAudioSessionActive {
         do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            Self.logger.info("Voice capture: audio session deactivated")
         } catch {
            Self.logger.warning("Voice capture cleanup failed: \(error.localizedDescription)")
         }
         isAudioSessionActive = false
      }
   }

   private func finishCapture(
      id: UUID,
      failureMessage: String?,
      onCompletion: @escaping @Sendable (String?) -> Void
   ) {
      guard captureID == id else { return }
      stop()
      onCompletion(failureMessage)
   }

   private func removeAudioTapIfNeeded() {
      guard hasInstalledAudioTap else { return }
      audioEngine.inputNode.removeTap(onBus: 0)
      hasInstalledAudioTap = false
      Self.logger.info("Voice capture: tap removed")
   }

   nonisolated private static func isCancellationError(_ error: Error) -> Bool {
      let nsError = error as NSError
      return nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
   }
}

private enum VoiceToDoCaptureError: LocalizedError {
   case speechUnavailable
   case onDeviceRecognitionUnavailable
   case microphoneUnavailable

   var errorDescription: String? {
      switch self {
      case .speechUnavailable:
         return String(localized: "Speech recognition is unavailable.")
      case .onDeviceRecognitionUnavailable:
         return String(localized: "On-device speech recognition is unavailable for this language.")
      case .microphoneUnavailable:
         return String(localized: "The microphone is not ready. Try again.")
      }
   }
}
