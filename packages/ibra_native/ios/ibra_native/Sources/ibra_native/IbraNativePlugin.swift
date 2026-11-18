import AVFoundation
import Flutter
import UIKit
import UserNotifications

/// IBRA BOOKING — التكاملات الأصلية على iOS:
/// تحويل/قص الأصوات إلى WAV متوافق مع إشعارات iOS (أقل من 30 ثانية)، المعاينة، المنطقة الزمنية.
public class IbraNativePlugin: NSObject, FlutterPlugin {
  private var player: AVAudioPlayer?
  private var stopTimer: Timer?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.ibraprogram/ibra_native", binaryMessenger: registrar.messenger())
    let instance = IbraNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    // لعرض الإشعارات والتفاعل معها أثناء فتح التطبيق
    if UNUserNotificationCenter.current().delegate == nil,
       let d = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate {
      UNUserNotificationCenter.current().delegate = d
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "timeZone":
      result(TimeZone.current.identifier)
    case "decodeToWav":
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let ms = try self.decodeToWav(
            input: args["input"] as? String ?? "",
            output: args["output"] as? String ?? "",
            startMs: (args["startMs"] as? NSNumber)?.int64Value ?? 0,
            endMs: (args["endMs"] as? NSNumber)?.int64Value ?? 0,
            maxMs: (args["maxMs"] as? NSNumber)?.int64Value ?? 29000)
          DispatchQueue.main.async { result(Int(ms)) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "decode_failed", message: error.localizedDescription, details: nil)) }
        }
      }
    case "durationMs":
      let path = args["path"] as? String ?? ""
      if let f = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) {
        result(Int(Double(f.length) / f.fileFormat.sampleRate * 1000))
      } else {
        result(0)
      }
    case "registerSound":
      // في iOS يكفي وجود الملف داخل Library/Sounds (يتم من Dart)
      result(args["path"] as? String)
    case "unregisterSound":
      result(nil)
    case "play":
      do {
        try play(
          path: args["path"] as? String ?? "",
          volume: (args["volume"] as? NSNumber)?.floatValue ?? 1,
          startMs: (args["startMs"] as? NSNumber)?.intValue ?? 0,
          endMs: (args["endMs"] as? NSNumber)?.intValue ?? 0,
          loop: args["loop"] as? Bool ?? false)
        result(nil)
      } catch {
        result(FlutterError(code: "play_failed", message: error.localizedDescription, details: nil))
      }
    case "stop":
      stopPlayer()
      result(nil)
    case "isIgnoringBatteryOptimizations":
      result(true)
    case "openBatterySettings":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func decodeToWav(input: String, output: String, startMs: Int64, endMs: Int64, maxMs: Int64) throws -> Int64 {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: input))
    let format = file.processingFormat
    let sr = format.sampleRate
    let channels = Int(format.channelCount)
    let total = file.length
    let startFrame = AVAudioFramePosition(Double(startMs) / 1000.0 * sr)
    var endFrame = endMs > startMs ? AVAudioFramePosition(Double(endMs) / 1000.0 * sr) : total
    endFrame = min(endFrame, total, startFrame + AVAudioFramePosition(Double(maxMs) / 1000.0 * sr))
    let frames = max(0, endFrame - startFrame)
    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
      throw NSError(domain: "ibra_native", code: 1, userInfo: [NSLocalizedDescriptionKey: "مقطع فارغ"])
    }
    file.framePosition = startFrame
    try file.read(into: buffer, frameCount: AVAudioFrameCount(frames))
    let n = Int(buffer.frameLength)
    var pcm = Data(capacity: n * channels * 2)
    if let fdata = buffer.floatChannelData {
      for i in 0..<n {
        for c in 0..<channels {
          let v = max(-1, min(1, fdata[c][i]))
          var s = Int16(v * 32767).littleEndian
          withUnsafeBytes(of: &s) { pcm.append(contentsOf: $0) }
        }
      }
    } else if let idata = buffer.int16ChannelData {
      for i in 0..<n {
        for c in 0..<channels {
          var s = idata[c][i].littleEndian
          withUnsafeBytes(of: &s) { pcm.append(contentsOf: $0) }
        }
      }
    }
    var out = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { out.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { out.append(contentsOf: $0) } }
    out.append("RIFF".data(using: .ascii)!)
    u32(UInt32(36 + pcm.count))
    out.append("WAVE".data(using: .ascii)!)
    out.append("fmt ".data(using: .ascii)!)
    u32(16); u16(1); u16(UInt16(channels)); u32(UInt32(sr))
    u32(UInt32(Int(sr) * channels * 2)); u16(UInt16(channels * 2)); u16(16)
    out.append("data".data(using: .ascii)!)
    u32(UInt32(pcm.count))
    out.append(pcm)
    let url = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try out.write(to: url)
    return Int64(Double(n) / sr * 1000)
  }

  private func play(path: String, volume: Float, startMs: Int, endMs: Int, loop: Bool) throws {
    stopPlayer()
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    let p = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    p.volume = volume
    p.numberOfLoops = (loop && endMs <= startMs) ? -1 : 0
    p.currentTime = Double(startMs) / 1000
    p.prepareToPlay()
    p.play()
    player = p
    if endMs > startMs {
      stopTimer = Timer.scheduledTimer(withTimeInterval: Double(endMs - startMs) / 1000, repeats: false) { [weak self] _ in
        self?.stopPlayer()
      }
    }
  }

  private func stopPlayer() {
    stopTimer?.invalidate()
    stopTimer = nil
    player?.stop()
    player = nil
  }
}
