import Flutter
import UIKit
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let downloadManager = BackgroundHlsDownloadManager.shared
  private let uploadManager = BackgroundVideoUploadManager.shared
  private let screenProtectionManager = ScreenProtectionManager.shared
  private let pronunciationRecorder = PronunciationRecorderManager.shared

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "q360education/downloads",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        let args = call.arguments as? [String: Any]
        let lectureId = args?["lectureId"] as? String ?? ""
        switch call.method {
        case "startIosHls":
          guard
            let urlString = args?["url"] as? String,
            let url = URL(string: urlString)
          else {
            result(FlutterError(code: "invalid_url", message: "Invalid HLS URL", details: nil))
            return
          }
          let title = args?["title"] as? String ?? "الفيديو"
          self.downloadManager.start(lectureId: lectureId, title: title, url: url)
          result(nil)
        case "iosDownloadStatus":
          result(self.downloadManager.status(for: lectureId))
        case "cancelIosHls":
          self.downloadManager.cancel(lectureId: lectureId)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      let uploadChannel = FlutterMethodChannel(
        name: "q360education/uploads",
        binaryMessenger: controller.binaryMessenger
      )
      uploadChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self, call.method == "enqueue",
          let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          let title = args["title"] as? String,
          let filePath = args["filePath"] as? String,
          let uploadUrl = args["uploadUrl"] as? String,
          let contentType = args["contentType"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          try self.uploadManager.enqueue(
            id: id,
            title: title,
            sourcePath: filePath,
            uploadUrl: uploadUrl,
            contentType: contentType
          )
          result(nil)
        } catch {
          result(FlutterError(
            code: "background_upload_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
      let protectionChannel = FlutterMethodChannel(
        name: "q360education/screen_protection",
        binaryMessenger: controller.binaryMessenger
      )
      protectionChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "enable":
          self.screenProtectionManager.enable(in: self.window)
          result(nil)
        case "disable":
          self.screenProtectionManager.disable()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      let pronunciationChannel = FlutterMethodChannel(
        name: "q360education/pronunciation_recorder",
        binaryMessenger: controller.binaryMessenger
      )
      pronunciationChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "recorder_unavailable", message: nil, details: nil))
          return
        }
        self.pronunciationRecorder.handle(call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    if identifier == BackgroundVideoUploadManager.sessionIdentifier {
      uploadManager.backgroundCompletionHandler = completionHandler
      uploadManager.reconnect()
    } else {
      downloadManager.backgroundCompletionHandler = completionHandler
      downloadManager.reconnect()
    }
  }
}

final class PronunciationRecorderManager: NSObject, AVAudioRecorderDelegate {
  static let shared = PronunciationRecorderManager()
  private var recorder: AVAudioRecorder?
  private var recordingPath: String?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async { result(granted) }
      }
    case "start":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        let maxDuration = args["maxDurationSeconds"] as? Int,
        (1...10).contains(maxDuration)
      else {
        result(FlutterError(code: "invalid_recording", message: "Invalid recording settings", details: nil))
        return
      }
      guard recorder == nil else {
        result(FlutterError(code: "recording_active", message: "A recording is already active", details: nil))
        return
      }
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        let settings: [String: Any] = [
          AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
          AVSampleRateKey: 16_000,
          AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 16_000,
          AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]
        let audioRecorder = try AVAudioRecorder(
          url: URL(fileURLWithPath: path),
          settings: settings
        )
        audioRecorder.isMeteringEnabled = true
        audioRecorder.delegate = self
        guard audioRecorder.record(forDuration: TimeInterval(maxDuration)) else {
          throw NSError(
            domain: "Q360Pronunciation",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "تعذر بدء تسجيل النطق"]
          )
        }
        recorder = audioRecorder
        recordingPath = path
        result(nil)
      } catch {
        recorder = nil
        recordingPath = nil
        try? AVAudioSession.sharedInstance().setActive(
          false,
          options: .notifyOthersOnDeactivation
        )
        result(FlutterError(
          code: "recording_start_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    case "amplitude":
      recorder?.updateMeters()
      let db = recorder?.averagePower(forChannel: 0) ?? -160
      let normalized = pow(10.0, Double(db) / 20.0)
      result(min(max(normalized, 0.0), 1.0))
    case "stop":
      guard let audioRecorder = recorder, let path = recordingPath else {
        result(nil)
        return
      }
      let durationMs = Int(audioRecorder.currentTime * 1000)
      audioRecorder.stop()
      recorder = nil
      recordingPath = nil
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
      result(["path": path, "durationMs": durationMs])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

final class ScreenProtectionManager: NSObject {
  static let shared = ScreenProtectionManager()
  private weak var protectedWindow: UIWindow?
  private var privacyView: UIView?
  private var isEnabled = false

  private override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(showPrivacy),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  func enable(in window: UIWindow?) {
    protectedWindow = window
    isEnabled = true
    updateForCaptureState()
  }

  func disable() {
    isEnabled = false
    hidePrivacy()
    protectedWindow = nil
  }

  @objc private func captureChanged() { updateForCaptureState() }

  @objc private func showPrivacy() {
    guard isEnabled else { return }
    installPrivacyView()
  }

  @objc private func applicationActive() { updateForCaptureState() }

  private func updateForCaptureState() {
    guard isEnabled else {
      hidePrivacy()
      return
    }
    if UIScreen.main.isCaptured {
      installPrivacyView()
    } else {
      hidePrivacy()
    }
  }

  private func installPrivacyView() {
    guard privacyView == nil, let window = protectedWindow else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
    let label = UILabel(frame: overlay.bounds.insetBy(dx: 24, dy: 24))
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    label.text = "المحتوى محمي\nتم إخفاؤه أثناء تسجيل الشاشة"
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .white
    label.font = .systemFont(ofSize: 19, weight: .semibold)
    overlay.addSubview(label)
    window.addSubview(overlay)
    privacyView = overlay
  }

  private func hidePrivacy() {
    privacyView?.removeFromSuperview()
    privacyView = nil
  }
}

final class BackgroundVideoUploadManager: NSObject, URLSessionTaskDelegate {
  static let shared = BackgroundVideoUploadManager()
  static let sessionIdentifier = "com.qimma.education.video-uploads"
  private let defaultsKey = "q360.ios.video.uploads"
  var backgroundCompletionHandler: (() -> Void)?

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: Self.sessionIdentifier
    )
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.allowsCellularAccess = true
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()

  private override init() {
    super.init()
    _ = session
  }

  func reconnect() {
    _ = session
  }

  func enqueue(
    id: String,
    title: String,
    sourcePath: String,
    uploadUrl: String,
    contentType: String
  ) throws {
    guard let remoteUrl = URL(string: uploadUrl) else {
      throw NSError(domain: "Q360Upload", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "رابط رفع الفيديو غير صالح"
      ])
    }
    let sourceUrl = URL(fileURLWithPath: sourcePath)
    let uploadDirectory = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent("BackgroundUploads", isDirectory: true)
    try FileManager.default.createDirectory(
      at: uploadDirectory,
      withIntermediateDirectories: true
    )
    let fileUrl = uploadDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(sourceUrl.pathExtension)
    try FileManager.default.copyItem(at: sourceUrl, to: fileUrl)

    var request = URLRequest(url: remoteUrl)
    request.httpMethod = "PUT"
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    let task = session.uploadTask(with: request, fromFile: fileUrl)
    task.taskDescription = id
    save(id: id, value: [
      "title": title,
      "filePath": fileUrl.path,
      "status": "uploading",
      "progress": 0.0
    ])
    let notification = UNMutableNotificationContent()
    notification.title = "جارٍ رفع فيديو الحصة"
    notification.body = title
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: "upload-\(id)",
        content: notification,
        trigger: nil
      )
    )
    task.resume()
  }

  private func save(id: String, value: [String: Any]) {
    var all = UserDefaults.standard.dictionary(forKey: defaultsKey) ?? [:]
    var merged = all[id] as? [String: Any] ?? [:]
    value.forEach { merged[$0.key] = $0.value }
    all[id] = merged
    UserDefaults.standard.set(all, forKey: defaultsKey)
  }

  private func info(for id: String) -> [String: Any] {
    let all = UserDefaults.standard.dictionary(forKey: defaultsKey) ?? [:]
    return all[id] as? [String: Any] ?? [:]
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    guard let id = task.taskDescription, totalBytesExpectedToSend > 0 else { return }
    save(id: id, value: [
      "status": "uploading",
      "progress": Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    ])
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let id = task.taskDescription else { return }
    let current = info(for: id)
    let title = current["title"] as? String ?? "فيديو الحصة"
    let responseCode = (task.response as? HTTPURLResponse)?.statusCode ?? 0
    let succeeded = error == nil && (200...299).contains(responseCode)
    save(id: id, value: [
      "status": succeeded ? "completed" : "failed",
      "progress": succeeded ? 1.0 : (current["progress"] as? Double ?? 0.0),
      "error": error?.localizedDescription ?? (succeeded ? "" : "HTTP \(responseCode)")
    ])
    if let path = current["filePath"] as? String {
      try? FileManager.default.removeItem(atPath: path)
    }

    let notification = UNMutableNotificationContent()
    notification.title = succeeded ? "اكتمل رفع الفيديو" : "تعذر رفع الفيديو"
    notification.body = title
    notification.sound = .default
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: "upload-\(id)",
        content: notification,
        trigger: nil
      )
    )
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async { [weak self] in
      self?.backgroundCompletionHandler?()
      self?.backgroundCompletionHandler = nil
    }
  }
}

final class BackgroundHlsDownloadManager: NSObject, AVAssetDownloadDelegate {
  static let shared = BackgroundHlsDownloadManager()
  private let sessionIdentifier = "com.qimma.education.hls-downloads"
  private let defaultsKey = "q360.ios.hls.downloads"
  var backgroundCompletionHandler: (() -> Void)?

  private lazy var session: AVAssetDownloadURLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: sessionIdentifier
    )
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.allowsCellularAccess = true
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return AVAssetDownloadURLSession(
      configuration: configuration,
      assetDownloadDelegate: self,
      delegateQueue: queue
    )
  }()

  private override init() {
    super.init()
    _ = session
  }

  func reconnect() {
    _ = session
  }

  func start(lectureId: String, title: String, url: URL) {
    let existing = status(for: lectureId)
    if existing["status"] as? String == "completed",
       let path = existing["path"] as? String,
       FileManager.default.fileExists(atPath: path) {
      return
    }
    session.getAllTasks { [weak self] tasks in
      guard let self = self else { return }
      if tasks.contains(where: { $0.taskDescription == lectureId }) { return }
      let asset = AVURLAsset(url: url)
      guard let task = self.session.makeAssetDownloadTask(
        asset: asset,
        assetTitle: title,
        assetArtworkData: nil,
        options: nil
      ) else {
        self.saveStatus(lectureId, [
          "status": "failed",
          "progress": 0.0,
          "error": "تعذر إنشاء مهمة تنزيل HLS"
        ])
        return
      }
      task.taskDescription = lectureId
      self.saveStatus(lectureId, [
        "status": "downloading",
        "progress": 0.0,
        "title": title,
        "url": url.absoluteString
      ])
      task.resume()
    }
  }

  func cancel(lectureId: String) {
    session.getAllTasks { [weak self] tasks in
      tasks.filter { $0.taskDescription == lectureId }.forEach { $0.cancel() }
      self?.saveStatus(lectureId, [
        "status": "cancelled",
        "progress": 0.0
      ])
    }
  }

  func status(for lectureId: String) -> [String: Any] {
    let all = UserDefaults.standard.dictionary(forKey: defaultsKey) ?? [:]
    return all[lectureId] as? [String: Any] ?? [
      "status": "pending",
      "progress": 0.0
    ]
  }

  private func saveStatus(_ lectureId: String, _ value: [String: Any]) {
    var all = UserDefaults.standard.dictionary(forKey: defaultsKey) ?? [:]
    var merged = all[lectureId] as? [String: Any] ?? [:]
    value.forEach { merged[$0.key] = $0.value }
    all[lectureId] = merged
    UserDefaults.standard.set(all, forKey: defaultsKey)
  }

  func urlSession(
    _ session: URLSession,
    assetDownloadTask: AVAssetDownloadTask,
    willDownloadTo location: URL
  ) {
    guard let id = assetDownloadTask.taskDescription else { return }
    saveStatus(id, ["path": location.path])
  }

  func urlSession(
    _ session: URLSession,
    assetDownloadTask: AVAssetDownloadTask,
    didLoad timeRange: CMTimeRange,
    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
    timeRangeExpectedToLoad: CMTimeRange
  ) {
    guard let id = assetDownloadTask.taskDescription else { return }
    let expected = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
    guard expected.isFinite && expected > 0 else { return }
    let loaded = loadedTimeRanges.reduce(0.0) {
      $0 + CMTimeGetSeconds($1.timeRangeValue.duration)
    }
    saveStatus(id, [
      "status": "downloading",
      "progress": min(max(loaded / expected, 0), 1)
    ])
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let id = task.taskDescription else { return }
    if let error = error as NSError? {
      let cancelled = error.domain == NSURLErrorDomain &&
        error.code == NSURLErrorCancelled
      saveStatus(id, [
        "status": cancelled ? "cancelled" : "failed",
        "error": error.localizedDescription
      ])
      return
    }
    var current = status(for: id)
    current["status"] = "completed"
    current["progress"] = 1.0
    saveStatus(id, current)
    let title = current["title"] as? String ?? "الفيديو"
    let content = UNMutableNotificationContent()
    content.title = "اكتمل التنزيل"
    content.body = title
    content.sound = .default
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: "download-\(id)",
        content: content,
        trigger: nil
      )
    )
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async { [weak self] in
      self?.backgroundCompletionHandler?()
      self?.backgroundCompletionHandler = nil
    }
  }
}
