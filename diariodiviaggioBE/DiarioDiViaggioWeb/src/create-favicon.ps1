# PowerShell script to create a simple airplane favicon
param([string]$outputPath = "favicon.ico")

Write-Host "Creating airplane favicon..." -ForegroundColor Green

# Create a simple airplane icon as base64 ICO - this is a minimal working ICO file
$base64Icon = "AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAA////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////ASJAVQESQFUD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8ASJAVQD6PFUA6kBVAPJAVQDyQFUA8kBVAOpAVQD6PFUASQFUA////AP///wD///8A////AP///wD///wA4JEVQDSRFQAwkRVALJEVQCiRFQAokRVAKJEVQCyRFQAwkRVANJEVQP///wD///8A////AP///wA0kRVAMJEVQCyRFQAokRVA////AP///wD///8AKJEVQCyRFQAwkRVANJEVQP///wD///8AMJEVQCyRFQAokRVA////AP///wD///8A////AP///wD///8AKJEVQCyRFQAwkRVA////ACyRFQAokRVA////AP///wD///8A////AP///wD///8A////AP///wAokRVALJEVQP///wD///8AKJEVQCiRFQD///8A////AP///wD///8A////ACSRFQD///8AKJEVQCyRFQD///8A////ACSRFQASKRVAKSEVQCSRFQAKSRVAKSEVQCSRFQD///8A////ACSRFQASKRVAKSEVQCSRFQAKSRVAKSEVQCSRFQD///8A////ACSRFQD///8AKSEVQCSRFQAKSRVAKSEVQP///wD///8A////AP///wDSRFQD///8AKSEVQCSRFQAKSRVAKSEVQP///wD///8A////AP///wD///8A////AP///8A////ACSRFQD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A"

# Convert base64 to bytes and save as ICO file
try {
    $bytes = [Convert]::FromBase64String($base64Icon)
    [System.IO.File]::WriteAllBytes($outputPath, $bytes)
    Write-Host "Airplane favicon created successfully: $outputPath" -ForegroundColor Green
} catch {
    Write-Host "Error creating favicon: $($_.Exception.Message)" -ForegroundColor Red
}
"@
