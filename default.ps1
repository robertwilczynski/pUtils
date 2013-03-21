properties {
    $ProjectName = "pUtils"
    $BaseDir = Resolve-Path "."
	$SourceDir = "$BaseDir\src"	
    $OutputDir = "$BaseDir\output"    
	$ReleaseDir = "$BaseDir\release"
	$ToolsDir = "$BaseDir\tools"
    $ShortVersion = "0.0.1"
    $Version = "$ShortVersion.0"
	$Configuration ="Debug"
    $LocalNugetRepository = "c:\nuget"
    $NugetOrgRepository = "https://nuget.org/"
	$NugetExe = "$ToolsDir\.nuget\nuget.exe"	
    $NuspecPath = "$SourceDir\pUtils.nuspec"
    $NugetOutputDir = "$OutputDir\nuget"
    $NugetPackagePath = "$NugetOutputDir\pUtils.$Version.nupkg"
}

# used for testing Powershell scripts
Import-Module Pester

# dogfooding our own utils to aid with nuget packaging
. ".\src\tools\utils\nuget.ps1"

task default -depends Test, Package-For-Nuget, Push-To-Local-Nuget

task Publish -depends Test, Package-For-Nuget, Push-To-Nuget

task Package-For-Nuget {
    # clean up after previous build
    if ((Test-Path $NugetOutputDir)) {
        rm $NugetOutputDir -Recurse -Force
    }
    # make sure we have a place to put the package
    $void = mkdir $NugetOutputDir

    $packageVersion = BuildNugetVersion -Version $Version
    $basePath = $SourceDir
    exec {         
        & "$NugetExe" pack "$NuspecPath" `
            -Version $packageVersion `
            -Prop Configuration=$Configuration `
            -OutputDirectory $NugetOutputDir `
            -BasePath $basePath
    }
}

task Push-To-Local-Nuget -depends Package-For-Nuget {
    cp $NugetPackagePath $LocalNugetRepository
}

task Push-To-Nuget -depends Package-For-Nuget {
    exec { 
        & "$NugetExe" push "$NugetPackagePath" `
            -Source $NugetOrgRepository
    }
}

task Test {
	Invoke-Pester ./test
}