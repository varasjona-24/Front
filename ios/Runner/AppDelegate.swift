import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "listenfy/bluetooth_audio",
                                      binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      if call.method != "getAudioDevices" {
        result(FlutterMethodNotImplemented)
        return
      }

      let session = AVAudioSession.sharedInstance()
      let outputs = session.currentRoute.outputs

      var devices: [[String: Any]] = []
      var outputKinds: [String] = []
      var bluetoothOn = false

      for output in outputs {
        let kind: String
        switch output.portType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
          kind = "bluetooth"
          bluetoothOn = true
        case .headphones, .headsetMic, .usbAudio:
          kind = "wired"
        case .builtInSpeaker:
          kind = "speaker"
        case .builtInReceiver:
          kind = "earpiece"
        default:
          kind = "unknown"
        }

        outputKinds.append(kind)
        devices.append([
          "name": output.portName,
          "address": "",
          "kind": kind,
          "battery": -1
        ])
      }

      result([
        "bluetoothOn": bluetoothOn,
        "devices": devices,
        "outputs": outputKinds
      ])
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
