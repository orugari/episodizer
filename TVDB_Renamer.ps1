# ==============================================================
#  _  __           ____________ _   _  ____   _____ ______ _____ 
# | |/ /    /\    |___  /  ____| \ | |/ __ \ / ____|  ____|_   _|
# | ' /    /  \      / /| |__  |  \| | |  | | (___ | |__    | |  
# |  <    / /\ \    / / |  __| | . ` | |  | |\___ \|  __|   | |  
# | . \  / ____ \  / /__| |____| |\  | |__| |____) | |____ _| |_ 
# |_|\_\/_/    \_\/_____|______|_| \_|\____/|_____/|______|_____|
#
# A PowerShell script to automatically rename your TV show episode files using titles fetched from TheTVDB. It can also organize episodes into season folders.
# Please support me at https://ko-fi.com/kazenosei
# ==============================================================

param (
    [string]$apiKey,
    [string]$basePath,
    [string]$lang,
    [string]$seasonStyle,
    [switch]$organize,
    [switch]$flat
)

# === CONFIGURATION ===
$defaultConfig = @{ 
    apiKey      = "API_KEY"  #TVDB API KEY
    basePath    = "\\NAS\Video\Series"
    lang        = "fra"  # ex: fra, en, de, es, it
    seasonStyle = "Saison" # name of season folders. Will generate Saison 01
    organize    = $true
}

# === FINAL PARAMETERS ===
$finalApiKey      = if ($apiKey)      { $apiKey      } else { $defaultConfig.apiKey }
$finalBasePath    = if ($basePath)    { $basePath    } else { $defaultConfig.basePath }
$finalLang        = if ($lang)        { $lang        } else { $defaultConfig.lang }
$finalSeasonStyle = if ($seasonStyle) { $seasonStyle } else { $defaultConfig.seasonStyle }
$useOrganize      = if   ($PSBoundParameters.ContainsKey('organize')) { $true  }
                   elseif ($PSBoundParameters.ContainsKey('flat'))      { $false }
                   else                                         { $defaultConfig.organize }
if ($organize -and $flat) { Write-Error "❌ Use either -organize or -flat, not both."; exit }

# --- Affichage initial ---
Write-Host "# =============================================================="
Write-Host "#  _  __           ____________ _   _  ____   _____ ______ _____ "
Write-Host "# | |/ /    /\    |___  /  ____| \ | |/ __ \ / ____|  ____|_   _|"
Write-Host "# | ' /    /  \      / /| |__  |  \| | |  | | (___ | |__    | |  "
Write-Host "# |  <    / /\ \    / / |  __| | . `  | |  | |\___ \|  __|   | |  "
Write-Host "# | . \  / ____ \  / /__| |____| |\  | |__| |____) | |____ _| |_ "
Write-Host "# |_|\_\/_/    \_\/_____|______|_| \_|\____/|_____/|______|_____|"
Write-Host "#"
Write-Host "#"
Write-Host "# 💖 Support me at : https://ko-fi.com/kazenosei"
Write-Host "# ==============================================================`n"

Write-Host "`n📁 Folder : $finalBasePath"
Write-Host "🌍 Language : $finalLang"
Write-Host "📂 Season folder style : $finalSeasonStyle"
Write-Host "📦 Organization : " -NoNewline
if ($useOrganize) { Write-Host "organized" } else { Write-Host "flat" }
Write-Host "`n"

# --- Authentication  ---
$token   = (Invoke-RestMethod -Method Post -Uri "https://api4.thetvdb.com/v4/login" `
             -Body (ConvertTo-Json @{ apikey = $finalApiKey }) -ContentType "application/json").data.token
$headers = @{ Authorization = "Bearer $token"; "Accept-Language" = $finalLang }
$videoExtensions = @("*.mkv","*.mp4","*.avi","*.mov","*.wmv","*.flv")

# --- Loop through each series folder ---
Get-ChildItem -Path $finalBasePath -Directory | ForEach-Object {
    $serieFolder = $_.Name
    $fullPath    = $_.FullName

    if ((Read-Host "`nFolder: $serieFolder. Process ? (y/n)") -ne 'y') {
        return
    }
# Series search
$escapedQuery = [uri]::EscapeDataString($serieFolder)
$searchUrl = "https://api4.thetvdb.com/v4/search?type=series&query=$escapedQuery"
$results = Invoke-RestMethod -Uri $searchUrl -Headers $headers

    


    if (!$results -or ($results.data.Count -eq 0) {
        Write-Host "❌ No series found for '$serieFolder'"
        return
    }

    # Selection if multiple results
    if ($results.data.Count -gt 0) {
        Write-Host "`nChoose the serie :"
        for ($i = 0; $i -lt $results.data.Count; $i++) {
            $s = $results.data[$i]
            # year
            $y = '???'
            if     ($s.year -and $s.year -match '^\d{4}$')               { $y = $s.year }
            elseif ($s.first_air_time -and $s.first_air_time -match '^\d{4}-\d{2}-\d{2}$') {
                try { $y = ([datetime]$s.first_air_time).Year } catch {}
            }
            # Display description
            $o = ''
            if ($s.overviews -and $s.overviews.PSObject.Properties.Name -contains $finalLang -and $s.overviews.$finalLang) {
                $desc = $s.overviews.$finalLang
                $o = if ($desc.Length -gt 100) {
                    $desc.Substring(0,100) + '...'
                } else {
                    $desc
                }
            }
            # Found
            $title = if ($s.translations -and $s.translations.PSObject.Properties.Name -contains $finalLang -and $s.translations.$finalLang) {
                         $s.translations.$finalLang
                     } else {
                         $s.name
                     }
                     
            Write-Host "[$i] $($title) ($y) - $o"
        }
        do {
            $idx = Read-Host "`nIndex to use"
        } while ($idx -notmatch '^\d+$' -or $idx -ge $results.data.Count)
        $serieId = $results.data[[int]$idx].tvdb_id
    }
    else {
        $serieId = $results.data[0].tvdb_id
        Write-Host "✅ Selected series : $($results.data[0].name)"
    }

    # Retrieve video files
    $videoFiles = Get-ChildItem -Path $fullPath -Include $videoExtensions -File -Recurse |
    Where-Object { 
        $_.Name -match 'S(\d{1,2})\s*E(\d{1,3})' -or $_.Name -match '(\d{1,2})x(\d{1,3})'
    }

    if (!$videoFiles -or $videoFiles.Count -eq 0) {
        Write-Host "⚠️ No file with SxxExx or xExx pattern found."
        return
    }

    # Detect present seasons
    $detected = $videoFiles | ForEach-Object {
        if ($_.Name -match 'S(\d{1,2})\s*E(\d{1,3})') { [int]$matches[1] }
        elseif ($_.Name -match '(\d{1,2})x(\d{1,3})') { [int]$matches[1] }
    } | Sort-Object -Unique

    foreach ($season in $detected) {
        # Dynamic patterns (quantifiers properly escaped)
        $pat1 = "S{0:00}\s*E\d{{1,3}}" -f $season
        $pat2 = "{0}x\d{{1,3}}"      -f $season


        $seasonFiles = $videoFiles | Where-Object {
            $_.Name -match $pat1 -or $_.Name -match $pat2
        }

        # Retrieve all official episodes of the series, paginated,
#  with extended timeout and max page size (500)
$allSeasonEps = @()
$pageEp = 0
do {
    Try {
        # Request 500 episodes per page to reduce the number of requests
        $url = "https://api4.thetvdb.com/v4/series/${serieId}/episodes/official/${finalLang}?page=${pageEp}"
        # Use Invoke-WebRequest for timeout control
        $raw = Invoke-WebRequest -Uri $url `
                                 -Headers $headers `
                                 -TimeoutSec 120 `
                                 -ErrorAction Stop

        # JSON conversion
        $respEp = $raw.Content | ConvertFrom-Json

        $allSeasonEps += $respEp.data.episodes
        write-host "https://api4.thetvdb.com/v4/series/${serieId}/episodes/official/${finalLang}?page=${pageEp}"
        $pageEp++
    }
    Catch {
        Write-Host "⚠️ Network error or timeout on page $pageEp : $($_.Exception.Message)"
        Write-Host "→ Waiting 5 seconds and retrying..."
        Start-Sleep -Seconds 5
        # Don’t increment $pageEp to retry same page
    }
} while ($respEp.links.next)

        
        # Filter by season number
        $seasonEpisodes = $allSeasonEps | Where-Object { $_.seasonNumber -eq $season }

        # Check episode count
        if ($seasonFiles.Count -ne $seasonEpisodes.Count) {
            Write-Host "`n⚠️ Season $season : files=$($seasonFiles.Count), API=$($seasonEpisodes.Count)"
            if ((Read-Host 'Continue anyway? (y/n)') -ne 'y') {
                continue
            }
        }

        # Renaming and moving
        foreach ($file in $seasonFiles) {
            if ($file.Name -match 'S(\d{1,2})\s*E(\d{1,3})' -or $file.Name -match '(\d{1,2})x(\d{1,3})') {
                $epNum = [int]$matches[2]
                $edata = $seasonEpisodes | Where-Object { $_.number -eq $epNum }
                if ($edata) {
                    # Title in chosen language
                    $titleLanguage = $edata.name

                    if ([string]::IsNullOrWhiteSpace($titleLanguage)) {
                        # No title in selected language → try EN translation
                        try {
                            $respTrans = Invoke-RestMethod -Uri `
                                "https://api4.thetvdb.com/v4/episodes/$($edata.id)/translations/eng" `
                                -Headers $headers
                            $titleEn = $respTrans.data.name
                        } catch {
                            $titleEn = $null
                        }

                        if ([string]::IsNullOrWhiteSpace($titleEn)) {
                            # Still nothing → fallback to SxxEyy.ext
                            $new = "S{0:00}E{1:00}{2}" -f $season, $epNum, $file.Extension
                        } else {
                            # Use English title
                            $safeEn = $titleEn -replace '/','-' -replace '[\\:*?"<>|]',''
                            $new    = "S{0:00}E{1:00} - {2}{3}" -f $season, $epNum, $safeEn, $file.Extension
                        }
                    }
                    else {
                        # Title in selected language available
                        $safeLanguage = $titleLanguage -replace '/','-' -replace '[\\:*?"<>|]',''
                        $new    = "S{0:00}E{1:00} - {2}{3}" -f $season, $epNum, $safeLanguage, $file.Extension
                    }

                    # Calculate destination path
                    if ($useOrganize) {
                        $sf = "{0} {1:00}" -f $finalSeasonStyle, $season
                        $sp = Join-Path $fullPath $sf
                        if (-not (Test-Path $sp)) { New-Item -ItemType Directory -Path $sp | Out-Null }
                        $dest = Join-Path $sp $new
                    } else {
                        $dest = Join-Path $file.DirectoryName $new
                    }

                    # === DEBUG ===
                    # Write-Host "🔧 Moving: '$($file.FullName)' → '$dest'"
                    Try {
    # Move-Item with literal source (disable wildcard interpretation)
    Move-Item -LiteralPath $file.FullName `
              -Destination   $dest `
              -Force `
              -ErrorAction Stop

    # Check if file actually moved
    if (Test-Path $dest) {
        Write-Host "✅ $($file.Name) → $new"
    }
    else {
        # Fallback to .NET if Move-Item didn’t work
        [System.IO.File]::Move($file.FullName, $dest)
        Write-Host "✅ [Fallback .NET] $($file.Name) → $new"
    }
}
Catch {
    Write-Host "❌ Failed to move '$($file.Name)' → '$dest' : $($_.Exception.Message)"
}


                }

                else {
                    Write-Host "❗ Episode $epNum not found in API"
                }
            }
        }
    }
}
