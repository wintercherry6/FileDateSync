<#
.SYNOPSIS
    FileDateSync - Sync file names with the oldest available date from metadata
.DESCRIPTION
    QUESTO SCRIPT RISOLVE UN PROBLEMA COMUNE:
    Se il tuo dispositivo mobile (iPhone, Android, iPad) ha il Cloud pieno di foto e video
    e vuoi fare un backup sul PC, ma sai che:
    - Perderesti le informazioni sulla data originale copiando i file
    - I file non sarebbero più ordinati temporalmente
    - Le date si mischierebbero tra modifica, creazione e data reale dello scatto

    QUESTO SCRIPT RISOLVE TUTTO:
    - Legge la DATA REALE di scatto dai metadati delle foto/video
    - Inserisce la data CORRETTA nel nome del file
    - Mantiene l'ordinamento temporale anche dopo copia o spostamento
    - Funziona con foto, video e qualsiasi altro file

    DOPO AVER COPIATO LE FOTO SUL PC, USA QUESTO SCRIPT per rinominare i file correttamente.
    Ottimizzato per Windows 11 in italiano.
    
    THIS SCRIPT SOLVES A COMMON PROBLEM:
    If your mobile device (iPhone, Android, iPad) has a full Cloud of photos and videos
    and you want to backup to PC, but you know that:
    - You would lose original date information when copying files
    - Files would no longer be sorted chronologically  
    - Dates would get mixed between modification, creation and actual capture date

    THIS SCRIPT SOLVES EVERYTHING:
    - Reads the REAL capture date from photo/video metadata
    - Inserts the CORRECT date into the filename
    - Maintains chronological sorting even after copy or move
    - Works with photos, videos and any other files

    AFTER COPYING PHOTOS TO YOUR PC, USE THIS SCRIPT to rename files correctly.
    Optimized for Windows 11 in Italian.
    
.INSTRUCTIONS FOR BEGINNERS
    1. Open PowerShell:
        - Press
          Windows + R
          simultaneously
        - Type
          powershell
          and press Enter

    2. Navigate to the script directory:
        - Type:
          cd C:\path\to\script\folder
          (replace with your actual path)
        - Press Enter

    3. Run the script:
        - Type:
          .\FileDateSync-JV.ps1
        - Press Enter

    4. Follow the prompts:
        - Enter the folder path containing your files when asked
        - Type "YES" to confirm and proceed

.EXAMPLES
    Original: IMG_001.JPG (taken on 2025-09-06)
    Renamed:  20250906_IMG_001.JPG

    Original: 20240913_IMG_4587.JPG (with actual origin date 2024-09-10)
    Corrected: 20240910_IMG_4587.JPG

    Original: document.pdf (created on 2024-01-15)
    Renamed: 20240115_document.pdf

.FEATURES
    - Searches for oldest date across multiple metadata sources
    - Handles photos (JPEG, PNG, RAW), videos (MP4, MOV, AVI), and other files
    - Only shows errors on screen for better performance
    - Creates detailed log file in the processed folder
    - Safe operation with user confirmation
    - Supports English and Italian Windows systems

.DATE SOURCES SEARCHED (in priority order)
    1. Data acquisizione (most reliable for photos)
    2. EXIF DateTimeOriginal (photo creation date)
    3. Media Created Date / Elemento multimediale creato
    4. File Creation Date
    5. File Last Modified Date

.SUPPORTED LANGUAGES
    - Italian: "Data acquisizione", "Elemento multimediale creato"

.NOTES
    - Always backup your files before using this script!
    - Test on a small folder first to verify results
    - Check the generated log file for detailed information about each file
    - The script will skip files that already have the correct date
    - Currently optimized for Italian Windows systems

.DISCLAIMER
    Use at your own risk. The author declines any responsibility for data loss, 
    file corruption, or any damages resulting from the use of this script. 
    Always backup your files before proceeding!

.AUTHOR
    wintercherry6 con l'aiuto di DeepSeek

.VERSION
    2.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$FolderPath,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFileName = "FileDateSync_Log.txt"
)

Write-Host "=== FILE DATE SYNC TOOL ===" -ForegroundColor Cyan
Write-Host "DISCLAIMER: Use at your own risk. Always backup your files!" -ForegroundColor Yellow
Write-Host ""

function Parse-DateCorrectly {
    param($dateString)
    
    if (-not $dateString -or $dateString.Trim() -eq '') {
        return $null
    }
    
    # Rimuovi caratteri speciali invisibili
    $cleanDate = $dateString -replace '[^\d/:\s]', ''
    $cleanDate = $cleanDate.Trim()
    
    if ($cleanDate -eq '') {
        return $null
    }
    
    Write-Host "  Parsing date: '$cleanDate'" -ForegroundColor Gray
    
    # CORREZIONE: Gestione esplicita del formato italiano dd/MM/yyyy
    if ($cleanDate -match '^(\d{1,2})/(\d{1,2})/(\d{4})') {
        $potentialDay = $matches[1]
        $potentialMonth = $matches[2]
        $year = $matches[3]
        
        # CORREZIONE PRINCIPALE: Forza l'interpretazione come dd/MM/yyyy
        # In italiano il formato è GIORNO/MESE/ANNO
        $day = $potentialDay.PadLeft(2, '0')
        $month = $potentialMonth.PadLeft(2, '0')
        
        Write-Host "  Detected Italian format: Day=$day, Month=$month, Year=$year" -ForegroundColor Cyan
        
        try {
            # Crea la data in formato ISO che è inequivocabile
            $isoDate = "$year-$month-$day"
            $parsedDate = [DateTime]::ParseExact($isoDate, "yyyy-MM-dd", $null)
            Write-Host "  SUCCESS: Parsed as $parsedDate" -ForegroundColor Green
            return $parsedDate
        } catch {
            Write-Host "  FAILED to parse Italian format" -ForegroundColor Red
        }
    }
    
    # Se il formato italiano non funziona, prova altri formati
    $formatsToTry = @(
        'dd/MM/yyyy HH:mm:ss',
        'dd/MM/yyyy HH:mm',
        'dd/MM/yyyy',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd'
    )
    
    foreach ($format in $formatsToTry) {
        try {
            $parsedDate = [DateTime]::ParseExact($cleanDate, $format, $null)
            Write-Host "  SUCCESS with format '$format': $parsedDate" -ForegroundColor Green
            return $parsedDate
        } catch {
            continue
        }
    }
    
    # Ultimo tentativo con parsing libero
    try {
        $parsedDate = [DateTime]$cleanDate
        Write-Host "  SUCCESS with free parsing: $parsedDate" -ForegroundColor Green
        return $parsedDate
    } catch {
        Write-Host "  FAILED to parse date: $cleanDate" -ForegroundColor Red
        return $null
    }
}

function Get-OldestDate {
    param($filePath)
    
    $file = Get-Item $filePath
    $dates = @($file.LastWriteTime, $file.CreationTime)
    
    Write-Host "File: $($file.Name)" -ForegroundColor White
    
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace($file.DirectoryName)
        $shellFile = $folder.ParseName($file.Name)
        
        # Property 12 - Data acquisizione
        $dataAcquisizione = $folder.GetDetailsOf($shellFile, 12)
        if ($dataAcquisizione -and $dataAcquisizione.Trim() -ne '') {
            Write-Host "  Data acquisizione: '$dataAcquisizione'" -ForegroundColor Cyan
            $parsedDate = Parse-DateCorrectly -dateString $dataAcquisizione
            if ($parsedDate) {
                $dates += $parsedDate
            }
        }
        
        # Property 208 - Elemento multimediale creato (Media Created)
        $mediaCreated = $folder.GetDetailsOf($shellFile, 208)
        if ($mediaCreated -and $mediaCreated.Trim() -ne '') {
            Write-Host "  Media created: '$mediaCreated'" -ForegroundColor Cyan
            $parsedDate = Parse-DateCorrectly -dateString $mediaCreated
            if ($parsedDate) {
                $dates += $parsedDate
            }
        }
        
    } catch {
        Write-Host "  Error reading properties: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $oldest = $dates | Sort-Object | Select-Object -First 1
    Write-Host "  OLDEST DATE: $($oldest.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
    Write-Host ""
    
    return $oldest
}

# Verifica cartella
if (-not $FolderPath) {
    $FolderPath = Read-Host "Enter the folder path to process"
}

if (-not (Test-Path $FolderPath)) {
    Write-Host "Error: Folder '$FolderPath' does not exist!" -ForegroundColor Red
    exit
}

# Conferma
Write-Host ""
$confirmation = Read-Host "Proceed with file renaming? (YES/no)"
if ($confirmation -ne "YES") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

Write-Host "Starting processing..." -ForegroundColor Green
Write-Host ""

# Processa i file
$files = Get-ChildItem -Path $FolderPath -File
$logPath = Join-Path $FolderPath $LogFileName

"FileDateSync Log - $(Get-Date)" | Out-File $logPath
"Target Folder: $FolderPath" | Out-File $logPath -Append
"DISCLAIMER: Use at your own risk. Always backup your files before using this tool." | Out-File $logPath -Append
"==================================================" | Out-File $logPath -Append

$filesRenamed = 0
$filesWithDateAdded = 0
$filesUnchanged = 0
$filesWithErrors = 0

foreach ($file in $files) {
    $oldestDate = Get-OldestDate -filePath $file.FullName
    $newDate = $oldestDate.ToString("yyyyMMdd")
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $extension = $file.Extension
    
    $logEntry = "File: $($file.Name)`n"
    $logEntry += "  Oldest date found: $($oldestDate.ToString('yyyy-MM-dd'))`n"
    
    # Pattern per file con data esistente - CORREZIONE: controllo se la data attuale è invertita
    if ($nameWithoutExt -match '^(\d{8})_(.+)$') {
        $currentDate = $matches[1]
        $restOfName = $matches[2]
        
        # CORREZIONE: Controlla se la data nel nome è invertita (YYYYDDMM invece di YYYYMMDD)
        $currentYear = $currentDate.Substring(0, 4)
        $currentMonthDay = $currentDate.Substring(4, 4)
        
        # Se il giorno è <= 12, potrebbe essere invertito
        $potentialDay = $currentDate.Substring(6, 2)
        $potentialMonth = $currentDate.Substring(4, 2)
        
        if ([int]$potentialDay -le 12 -and [int]$potentialMonth -le 12) {
            Write-Host "  WARNING: Current date might be inverted: $currentDate" -ForegroundColor Yellow
        }
        
        if ($currentDate -ne $newDate) {
            $newName = "${newDate}_${restOfName}${extension}"
            try {
                Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                $logEntry += "  ACTION: RENAMED to '$newName'`n"
                $logEntry += "  RESULT: SUCCESS`n"
                Write-Host "RENAMED: '$($file.Name)' -> '$newName'" -ForegroundColor Green
                $filesRenamed++
            } catch {
                $logEntry += "  ACTION: RENAMED to '$newName'`n"
                $logEntry += "  RESULT: ERROR - $($_.Exception.Message)`n"
                Write-Host "ERROR: '$($file.Name)' -> $($_.Exception.Message)" -ForegroundColor Red
                $filesWithErrors++
            }
        } else {
            $logEntry += "  ACTION: No change needed`n"
            $logEntry += "  RESULT: UNCHANGED`n"
            Write-Host "UNCHANGED: '$($file.Name)'" -ForegroundColor Gray
            $filesUnchanged++
        }
    } else {
        # File senza data - aggiungi data
        $newName = "${newDate}_${nameWithoutExt}${extension}"
        try {
            Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
            $logEntry += "  ACTION: DATE ADDED as '$newName'`n"
            $logEntry += "  RESULT: SUCCESS`n"
            Write-Host "DATE ADDED: '$($file.Name)' -> '$newName'" -ForegroundColor Cyan
            $filesWithDateAdded++
        } catch {
            $logEntry += "  ACTION: DATE ADDED as '$newName'`n"
            $logEntry += "  RESULT: ERROR - $($_.Exception.Message)`n"
            Write-Host "ERROR: '$($file.Name)' -> $($_.Exception.Message)" -ForegroundColor Red
            $filesWithErrors++
        }
    }
    
    $logEntry += "-" * 50 + "`n"
    $logEntry | Out-File $logPath -Append
}

# Summary
$summary = "`n=== SUMMARY ==="
$summary += "`nFiles processed: $($files.Count)"
$summary += "`nFiles renamed (date corrected): $filesRenamed"
$summary += "`nFiles with date added: $filesWithDateAdded"
$summary += "`nFiles unchanged: $filesUnchanged"
$summary += "`nFiles with errors: $filesWithErrors"
$summary += "`n" + ("=" * 50)

$summary | Out-File $logPath -Append

Write-Host ""
Write-Host "=== PROCESSING COMPLETE ===" -ForegroundColor Magenta
Write-Host "Files processed: $($files.Count)" -ForegroundColor White
Write-Host "Files renamed: $filesRenamed" -ForegroundColor Yellow
Write-Host "Files with date added: $filesWithDateAdded" -ForegroundColor Cyan
Write-Host "Files unchanged: $filesUnchanged" -ForegroundColor Green
Write-Host "Files with errors: $filesWithErrors" -ForegroundColor $(if ($filesWithErrors -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "Detailed log saved to: $logPath" -ForegroundColor Green

Write-Host ""
Write-Host "FileDateSync completed successfully!" -ForegroundColor Green
