# PowerShell script to create a basic favicon.ico from SVG
# This script provides instructions for favicon conversion

Write-Host "Airplane Favicon Setup Instructions" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

Write-Host "Option 1: Use online converter (Recommended)" -ForegroundColor Yellow
Write-Host "1. Go to https://favicon.io/favicon-converter/"
Write-Host "2. Upload the 'favicon-32x32.svg' file"
Write-Host "3. Download the generated favicon.ico"
Write-Host "4. Replace the existing favicon.ico file"
Write-Host ""

Write-Host "Option 2: Use modern SVG favicon (Already configured)" -ForegroundColor Yellow
Write-Host "- Modern browsers already support SVG favicons"
Write-Host "- Your index.html is updated to use the airplane SVG"
Write-Host "- This will work in Chrome, Firefox, Safari, and Edge"
Write-Host ""

Write-Host "Option 3: Manual conversion with Paint or GIMP" -ForegroundColor Yellow
Write-Host "1. Open favicon-32x32.svg in a browser and take a screenshot"
Write-Host "2. Open the screenshot in Paint or GIMP"
Write-Host "3. Resize to 16x16 and 32x32 pixels"
Write-Host "4. Save as ICO format"
Write-Host ""

Write-Host "Files created:" -ForegroundColor Cyan
Write-Host "- favicon-16x16.svg (16x16 airplane icon)"
Write-Host "- favicon-32x32.svg (32x32 airplane icon)"
Write-Host "- airplane-favicon.svg (original design)"
Write-Host "- index.html (updated with new favicon references)"
Write-Host ""

Write-Host "Your favicon should now show an airplane icon!" -ForegroundColor Green

# Try to open the converter page in browser
try {
    Start-Process "https://favicon.io/favicon-converter/"
    Write-Host "Opening favicon converter in browser..." -ForegroundColor Green
} catch {
    Write-Host "Could not open browser automatically. Please visit https://favicon.io/favicon-converter/ manually." -ForegroundColor Yellow
}
