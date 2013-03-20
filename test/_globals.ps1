$TempTestFolder = Resolve-Path ".\temp"
$TestDir = Resolve-Path ".\test"
$TestDataDir = "$TestDir\data"
$TempBackupDir = "$TempTestFolder\backups"
$DatabaseToBackup = "powershell-utils"

Import-Module Pester