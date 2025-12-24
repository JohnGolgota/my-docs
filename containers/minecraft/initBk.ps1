$basePath = Join-Path $env:HOME "Docs" "containers" "minecraft"
$dataPath = Join-Path $basePath "data"
$backupPath = Join-Path $basePath "data_backups"

$timeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupFolder = Join-Path $backupPath (get-date -Format "yyyy-MM-dd")
$backupFile = Join-Path $backupFolder "backup_$timeStamp.zip"

$logFile = Join-Path $backupFolder "backup.log"

# TODO: is this too much? it most certainly is!, should this be a module? maybe, but that'd mean more dependencies, so nose tu dime
Function Write-Log
{
  param(
    [string]$Message = '',
    [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
    [string]$Severity = 'Info'
  )
  Switch ($Severity)
  {
    'Warning' {
      $FormattedMessage = "[WARNING] $Message"
      Write-Host $FormattedMessage -ForegroundColor $host.PrivateData.WarningForegroundColor -BackgroundColor $host.PrivateData.WarningBackgroundColor
    }
    'Error' {
      $FormattedMessage = "[ERROR] $Message"
      Write-Host $FormattedMessage -ForegroundColor $host.PrivateData.ErrorForegroundColor -BackgroundColor $host.PrivateData.ErrorBackgroundColor
      exit 1
    }
    'Debug' {
      # Only log debug messages if debug stream shown
      If ($DebugPreference -ine 'SilentlyContinue')
      {
        $FormattedMessage = "[DEBUG] $Message"
        Write-Host $FormattedMessage -ForegroundColor $host.PrivateData.DebugForegroundColor -BackgroundColor $host.PrivateData.DebugBackgroundColor
      }
    }
    Default {
      Write-Host $Message
    }
  }
}

try
{
  Start-Transcript -Path $logFile -Append

  Write-Log -Message "Creating backup folder..."
  New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
  Write-Log -Severity Success -Message "Backup folder '$backupFolder' successfully created!"

  Write-Log -Message "Init backup: $( Get-Date )"
  Write-Log -Message "Backup origin: $dataPath"
  Write-Log -Message "Backup destination: $backupFile"

  if (!(Test-Path $dataPath))
  {
    Write-Log -Severity Error -Message "Data path '$dataPath' not found"
  }

  Write-Log -Message "Compressing data..."
  Compress-Archive -Path $dataPath -DestinationPath $backupFile -CompressionLevel Optimal

  $backupSize = (Get-Item $backupFile).Length
  $backupSizeMB = [math]::Round($backupSize / 1MB, 2)

  Write-Log -Severity Success -Message "Backup complete: $backupFile ($backupSizeMB MB)"

  # TODO: Make this a parameter, with default value 5
  $backupsToKeep = 5
  $oldBackups = Get-ChildItem $backupPath -Recurse -Filter "*.zip" |
      Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-($backupsToKeep))
      }

  if ($oldBackups.Count -gt 0)
  {
    Write-Log -Severity Warning -Message "Found $( $oldBackups.Count ) backups older than $backupsToKeep days, deleting..."
    $oldBackups | Remove-Item -Force
  }

}
catch
{
  Write-Log -Severity Error -Message "$( $_.Exception.Message )"
}
finally
{
  Stop-Transcript
}
