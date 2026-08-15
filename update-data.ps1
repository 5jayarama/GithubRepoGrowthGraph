$dataFile = Join-Path $PSScriptRoot "data.json"
$envFile = Join-Path $PSScriptRoot ".env"
$startYear = 2008
$startMonth = 2   # GitHub opened publicly April 2008; Feb 2008 as a safe floor

# Load .env (simple KEY=VALUE parser, ignores blank lines and lines starting with #)
$envVars = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $idx = $line.IndexOf("=")
            $key = $line.Substring(0, $idx).Trim()
            $value = $line.Substring($idx + 1).Trim().Trim('"').Trim("'")
            $envVars[$key] = $value
        }
    }
} else {
    Write-Warning ".env file not found at $envFile - create one with GITHUB_TOKEN=your_token_here"
}

$token = $envVars["GITHUB_TOKEN"]

$headers = @{ Accept = "application/vnd.github+json" }
if ($token) {
    $headers["Authorization"] = "Bearer $token"
    $sleepSeconds = 2.5
} else {
    $sleepSeconds = 7
    Write-Warning "No GITHUB_TOKEN found in .env - this will be slow and may hit rate limits on a full run."
}

$now = Get-Date

# Build full month list from start to the last COMPLETED month (excludes the in-progress current month)
$months = @()
$y = $startYear; $m = $startMonth
while (($y -lt $now.Year) -or ($y -eq $now.Year -and $m -lt $now.Month)) {
    $months += "{0}-{1:D2}" -f $y, $m
    $m++
    if ($m -gt 12) { $m = 1; $y++ }
}

$currentMonthStr = "{0}-{1:D2}" -f $now.Year, $now.Month
Write-Output "Current month is $currentMonthStr - excluded (still in progress)."
Write-Output "Pulling $($months.Count) completed months (public repos only):"
Write-Output ($months -join ", ")

$results = @{}
$failures = @()

# Create the file up front (empty structure) so it exists from the start
'{"rows":[],"failures":[]}' | Set-Content -Path $dataFile -Encoding UTF8

function Save-Results {
    param($resultsTable, $path, $failedMonths)
    $sorted = $resultsTable.GetEnumerator() | Sort-Object Name | ForEach-Object {
        [PSCustomObject]@{ month = $_.Name; new_repos = $_.Value }
    }
    $output = [PSCustomObject]@{
        rows     = $sorted
        failures = $failedMonths
    }
    $output | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
    return $sorted.Count
}

foreach ($monthStr in $months) {
    $parts = $monthStr -split '-'
    $y = [int]$parts[0]; $m = [int]$parts[1]
    $lastDay = [DateTime]::DaysInMonth($y, $m)
    $mm = "{0:D2}" -f $m
    $query = "created:$y-$mm-01..$y-$mm-$lastDay"
    $encodedQuery = [uri]::EscapeDataString($query)
    $url = "https://api.github.com/search/repositories?q=$encodedQuery&per_page=1"

    $success = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -TimeoutSec 15 | ConvertFrom-Json
            $results[$monthStr] = $response.total_count
            Write-Output "$monthStr : $($response.total_count)"
            $success = $true
            break
        } catch {
            Write-Warning "$monthStr attempt $attempt failed: $_"
            if ($attempt -lt 3) { Start-Sleep -Seconds 3 }
        }
    }

    if (-not $success) {
        $failures += $monthStr
        Write-Warning "$monthStr FAILED after 3 attempts - skipping."
    }

    Save-Results -resultsTable $results -path $dataFile -failedMonths $failures | Out-Null

    Start-Sleep -Seconds $sleepSeconds
}

Write-Output "data.json updated ($($results.Count) months, $($failures.Count) failures)."