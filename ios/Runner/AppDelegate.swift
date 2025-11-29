import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import UserNotifications
import FirebaseCore   // ← חובה כדי לאפשר Firebase

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let CHANNEL = "com.myneighborhood.app/location_settings"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 1️⃣ הפעלת Firebase — חייב ראשון
    FirebaseApp.configure()

    // 2️⃣ Google Maps
    GMSServices.provideAPIKey("AIzaSyDsHGnkVvAbZPPLpO04HEff1FCqBqb0JSE")

    // 3️⃣ רישום פלאגינים
    GeneratedPluginRegistrant.register(with: self)

    // ☑️ platform channel לפתיחת הגדרות מיקום
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let locationChannel = FlutterMethodChannel(
      name: CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    locationChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "openLocationSettings" {
        self?.openLocationSettings(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // ☑️ ניהול שירות מיקום - נדחה עד שהאפליקציה מוכנה
    // לא נבקש הרשאות מיד - זה יקרה מאוחר יותר דרך Flutter
    locationManager.delegate = self
    // הסרת הבקשה המיידית - תתבצע מאוחר יותר דרך Flutter
    // locationManager.requestAlwaysAuthorization()
    // locationManager.startMonitoringSignificantLocationChanges()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // פתיחת הגדרות שירות המיקום
  private func openLocationSettings(result: @escaping FlutterResult) {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        result(true)
      } else {
        result(FlutterError(code: "ERROR", message: "Cannot open settings", details: nil))
      }
    } else {
      result(FlutterError(code: "ERROR", message: "Invalid settings URL", details: nil))
    }
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    checkLocationService()
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    checkLocationService()
  }

  private func checkLocationService() {
    let isLocationEnabled = CLLocationManager.locationServicesEnabled()
    let prefs = UserDefaults.standard

    if !isLocationEnabled {
      let notificationSent = prefs.bool(forKey: "location_service_notification_sent")
      if !notificationSent {
        print("📍 Location service disabled — notifying user")
        showLocationServiceNotification()
        prefs.set(true, forKey: "location_service_notification_sent")
      }
    } else {
      prefs.set(false, forKey: "location_service_notification_sent")
    }
  }

  private func showLocationServiceNotification() {
    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = "שירות המיקום כבוי"
    content.body = "אנא הפעל את שירות המיקום כדי להשתמש באפליקציה."
    content.sound = .default
    content.badge = 1

    let request = UNNotificationRequest(
      identifier: "location_service_disabled",
      content: content,
      trigger: nil
    )

    center.add(request) { error in
      if let error = error {
        print("⚠️ Notification error: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - CLLocationManagerDelegate
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    checkLocationService()

    if manager.authorizationStatus == .authorizedAlways {
      manager.startMonitoringSignificantLocationChanges()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    checkLocationService()
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let e = error as? CLError, e.code == .locationUnknown {
      checkLocationService()
    }
  }
}
