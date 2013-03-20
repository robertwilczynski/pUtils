properties {
    $BaseDir = Resolve-Path "."
	$SourceDir = "$BaseDir\src"	
    $OutputDir = "$BaseDir\output"
	$ReleaseDir = "$BaseDir\release"
	$ToolsDir = "$BaseDir\tools"
    $Version = "0.0.1"
    $FullVersion = "$Version.0"   
	$Configuration ="Debug"
    $nugeLocalRepository = "c:\nuget"
    $nugetHttpRepository = "http://www.nuget.org"
	$nugetExe = "$ToolsDir\.nuget\nuget.exe"	
}

# used for testing Powershell scripts
Import-Module Pester

task default -depends Test, Package-For-Nuget

task Package-For-Nuget {
}

task Push-To-Local-Nuget -depends default {

}
task Push-To-Nuget -depends default {

}

task Test {
	Invoke-Pester ./test
}