# סקריפט לראות לוגים של LocationServiceChecker ו-LocationServiceWorker ב-VSCode

# הוספת platform-tools ל-PATH
$env:Path += ";C:\Users\haith\AppData\Local\Android\sdk\platform-tools"

# ניקוי הלוגים הקודמים
Write-Host "Clearing previous logs..." -ForegroundColor Yellow
adb logcat -c

# הצגת לוגים של LocationServiceChecker ו-LocationServiceWorker
Write-Host "Showing logs for LocationServiceChecker and LocationServiceWorker..." -ForegroundColor Green
Write-Host "Close the app completely, then disable location service on your phone." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop viewing logs." -ForegroundColor Yellow
Write-Host ""

adb logcat -s LocationServiceChecker LocationServiceWorker

