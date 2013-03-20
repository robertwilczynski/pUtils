$config.buildFileName="build.ps1"
$config.framework = "4.0"
$config.taskNameFormat="Executing {0}"
$config.verboseError=$false
$config.coloredOutput = $true
$config.modules=$null

$config.taskNameFormat= { param($taskName) "Executing $taskName at $(get-date)" }
