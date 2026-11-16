$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot 'backend\.env'
if (-not (Test-Path $envPath)) {
    Copy-Item (Join-Path $projectRoot 'backend\.env.example') $envPath
}
# Update only non-secret settings; preserve the application key, password and database.
$settings = [ordered]@{
    APP_DEBUG = 'false'
    APP_URL = 'https://localhost:8443'
    SECURITY_REQUIRE_HTTPS = 'true'
    TRUSTED_PROXIES = '127.0.0.1,::1'
    CORS_ALLOWED_ORIGINS = ''
    LOG_STACK = 'daily'
    LOG_LEVEL = 'info'
}
$content = [IO.File]::ReadAllText($envPath)
foreach ($key in $settings.Keys) {
    $line = "$key=$($settings[$key])"
    $pattern = '(?m)^' + [regex]::Escape($key) + '=.*$'
    if ([regex]::IsMatch($content, $pattern)) {
        $content = [regex]::Replace($content, $pattern, $line)
    } else {
        $content += "`r`n$line"
    }
}
[IO.File]::WriteAllText($envPath, $content, [Text.UTF8Encoding]::new($false))
Push-Location (Join-Path $projectRoot 'backend')
try {
    php artisan config:clear
    if ($LASTEXITCODE -ne 0) { throw 'Laravel configuration could not be cleared.' }
} finally { Pop-Location }
Write-Host 'Week 14 HTTPS settings applied. Existing credentials and data were preserved.'
Write-Host 'Follow docs/WEEK14_SETUP.md to build the frontend and trust your local HTTPS certificate.'
