import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let CHANNEL = "com.example.flutter1/location_settings"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDsHGnkVvAbZPPLpO04HEff1FCqBqb0JSE")
    GeneratedPluginRegistrant.register(with: self)
    
    // ✅ הגדרת platform channel לפתיחת הגדרות שירות המיקום
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
    
    // ✅ הגדרת location manager לבדיקת שירות המיקום
    locationManager.delegate = self
    
    // ✅ הפעלת Significant Location Changes לבדיקה גם כאשר האפליקציה סגורה
    // זה יעבוד רק אם המשתמש נתן הרשאה "Always" למיקום
    locationManager.requestAlwaysAuthorization()
    locationManager.startMonitoringSignificantLocationChanges()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ פתיחת הגדרות שירות המיקום ב-iOS
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
  
  // ✅ בדיקת שירות המיקום כאשר האפליקציה עוברת לרקע
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    checkLocationService()
  }
  
  // ✅ בדיקת שירות המיקום כאשר האפליקציה חוזרת לקדמה
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    checkLocationService()
  }
  
  // ✅ בדיקת שירות המיקום
  private func checkLocationService() {
    let isLocationEnabled = CLLocationManager.locationServicesEnabled()
    
    let prefs = UserDefaults.standard
    
    if !isLocationEnabled {
      // בדיקה אם כבר שלחנו התראה
      let notificationSent = prefs.bool(forKey: "location_service_notification_sent")
      
      if !notificationSent {
        print("📍 Location service is disabled - showing notification immediately")
        showLocationServiceNotification()
        prefs.set(true, forKey: "location_service_notification_sent")
      } else {
        print("📍 Location service is disabled but notification already sent - skipping")
      }
    } else {
      // ✅ אם שירות המיקום מופעל, איפוס הסטטוס כדי שנוכל לשלוח התראה שוב אם ייסגר
      print("📍 Location service is enabled - resetting notification flag")
      prefs.set(false, forKey: "location_service_notification_sent")
    }
  }
  
  // ✅ הצגת התראה על שירות מיקום מבוטל
  private func showLocationServiceNotification() {
    let center = UNUserNotificationCenter.current()
    
    let content = UNMutableNotificationContent()
    content.title = "שירות המיקום כבוי"
    content.body = "שירות המיקום במכשיר שלך כבוי. אנא הפעל את שירות המיקום בהגדרות המכשיר כדי להשתמש בתכונות מבוססות מיקום."
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
    
    // אם יש הרשאה "Always", נמשיך לבדוק גם ברקע
    if manager.authorizationStatus == .authorizedAlways {
      manager.startMonitoringSignificantLocationChanges()
    }
  }
  
  // ✅ נקרא כאשר יש שינוי משמעותי במיקום (גם כאשר האפליקציה סגורה)
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // בדיקת שירות המיקום כאשר יש שינוי במיקום
    checkLocationService()
  }
  
  // ✅ נקרא כאשר יש שגיאה במיקום (יכול להצביע על שירות מיקום מבוטל)
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // אם השגיאה היא שירות מיקום מבוטל, נבדוק
    if let clError = error as? CLError, clError.code == .locationUnknown {
      checkLocationService()
    }
  }
}
