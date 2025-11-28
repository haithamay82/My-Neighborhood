import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import UserNotifications
import FirebaseCore   // ← הוספנו

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let CHANNEL = "com.myneighborhood.app/location_settings"   // ← עודכן לפי ה־package החדש

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GMSServices.provideAPIKey("AIzaSyDsHGnkVvAbZPPLpO04HEff1FCqBqb0JSE")

    FirebaseApp.configure()   // ← הוספנו כדי להפעיל Firebase לפני Register
    GeneratedPluginRegistrant.register(with: self)

    // הגדרת platform channel לפתיחת הגדרות שירות המיקום
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

    // הגדרת location manager לבדיקת שירות המיקום
    locationManager.delegate = self

    // הפעלת Significant Location Changes כדי לזהות שינויי מיקום גם כאשר האפליקציה סגורה
    locationManager.requestAlwaysAuthorization()
    locationManager.startMonitoringSignificantLocationChanges()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // פתיחת הגדרות שירות המיקום ב-iOS
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

  // בדיקת שירות המיקום כאשר האפליקציה נכנסת לרקע
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    checkLocationService()
  }

  // בדיקת שירות המיקום כאשר האפליקציה חוזרת קדימה
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    checkLocationService()
  }

  // בדיקת שירות המיקום
  private func checkLocationService() {
    let isLocationEnabled = CLLocationManager.locationServicesEnabled()
    let prefs = UserDefaults.standard

    if !isLocationEnabled {
      // בדיקה אם כבר נשלחה התראה
      let notificationSent = prefs.bool(forKey: "location_service_notification_sent")

      if !notificationSent {
        print("📍 Location service is disabled - showing notification immediately")
        showLocationServiceNotification()
        prefs.set(true, forKey: "location_service_notification_sent")
      } else {
        print("📍 Location service is disabled but notification already sent - skipping")
      }
    } else {
      // אם שירות המיקום מופעל — איפוס הדגל
      print("📍 Location service is enabled - resetting notification flag")
      prefs.set(false, forKey: "location_service_notification_sent")
    }
  }

  // הצגת התראה על שירות מיקום מבוטל
  private func showLocationServiceNotification() {
    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = "שירות המיקום כבוי"
    content.body = "שירות המיקום במכשיר שלך כבוי. אנא הפעל אותו כדי להשתמש בתכונות מבוססות מיקום."
    content.sound = .default
    content.badge = 1

    let request = UNNotificationRequest(
      identifier: "location_service_disabled",
      content: content,
      trigger: nil
    )

    center.add(request) { error in
      if let error = error {
        print("Error showing location service notification: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - CLLocationManagerDelegate
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    checkLocationService()

    // אם למשתמש יש הרשאת "Always" — נמשיך לקבל מיקום גם ברקע
    if manager.authorizationStatus == .authorizedAlways {
      manager.startMonitoringSignificantLocationChanges()
    }
  }

  // נקרא כאשר יש שינוי משמעותי במיקום (גם כשהאפליקציה סגורה)
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    checkLocationService()
  }

  // נקרא כאשר יש שגיאה במיקום
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let clError = error as? CLError, clError.code == .locationUnknown {
      checkLocationService()
    }
  }
}
