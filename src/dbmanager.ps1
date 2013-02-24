. ".\_deploy\common.ps1" 
. ".\_deploy\database.ps1" 

function Execute-Sql-From-File($path) {
  try {
    $scriptFile = resolve-path "$path"
    $script = [System.IO.File]::ReadAllText($scriptFile)
    if ($script.Length -gt 0) {
        Invoke-SqlCommand `
          -SqlCommand $script `
          -DatabaseServer "$DatabaseServer" `
          -DatabaseName "$DatabaseName"
    }
  } 
  catch [system.exception] {
      Write-Host $_.Exception.ToString()
      return $false
  }
  return $true
}

function Get-Db-Version() {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName
	)
  $version = Sql-Get-Scalar `
    -DatabaseServer $DatabaseServer `
    -DatabaseName $DatabaseName `
    -SqlCommand "select top 1 [Version] from DbVersion order by [Id] desc"
    
  return $version
}

function Save-Db-Version() {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName,
		
		[Parameter(Mandatory=$true)]
		[string]		
		$Version
	)
  $void = Invoke-SqlCommand `
    -DatabaseServer $DatabaseServer `
    -DatabaseName $DatabaseName `
    -SqlCommand "insert into DbVersion values ('$Version', getutcdate())"  
}

function Reset-Db() {
    $void = Execute-Sql-From-File ".\Maintenance\DropAllObjects.sql" | Write-Host
    #Execute-Sql-From-File ".\install.db.sql" | Write-Host
    #Execute-Sql-From-File ".\init.db.sql" | Write-Host      
}

function GetVersionFromString([string]$text) {
    $parts = $text.Split('-')
    $versionPart = $parts[0]
    $versionParts = $versionPart.Split('.')
    $versionDescriptor = New-Object PsObject `
      -Property @{ `
        file = $text; `
        path = $null; `
        major = [int]$versionParts[0]; `
        minor = [int]$versionParts[1]; `
        revision = [int]$versionParts[2]; `
        scriptVersion = [int]$versionParts[3] `
      }

    return $versionDescriptor
}

function Execute-BeforeUpdateScripts {
  Write-Host "Running before update"
  $void = gci ".\BeforeUpdate\*.sql" | % { echo $_.FullName; Execute-Sql-From-File $($_.FullName) }
}
  
function Install-Latest-Baseline {
	[cmdletbinding(DefaultParameterSetName='customauth')]
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName
	)

	switch ($PsCmdlet.ParameterSetName) { 
		'devauth' {
			$authentication = 'User ID=sa;Password=pass'
			Write-Debug "Using development authentication: $authentication"
		}
		'credauth' {
			$plainCred = $credential.GetNetworkCredential()
			$authentication = "uid={0};pwd={1};" -f $plainCred.Username,$plainCred.Password
			Write-Debug "Using passed credentials, user: $($plainCred.Username)"
		}
		'customauth' {
			Write-Debug "Using custom authentication: $authentication"
		}
		default { throw "Parameter set name unknown: $($PsCmdlet.ParameterSetName)" }
	}

  Write-Host "Getting a list of baselines..."

  Write-Host "Running before update"
  $baselinePath = ".\Baseline"
  $baselinePathResolved = Resolve-Path $baselinePath -ErrorAction SilentlyContinue
  if ($baselinePathResolved -eq $null) {
	$currentPath = Resolve-Path ".\"
	throw "Unable to resolve baseline path (from current path $currentPath)"
  }
  Write-Host "Baseline path is: $baselinePathResolved"
  $baselineDirs = @()
  $baselineDirs += gci "$baselinePath\*" | where {$_.PsIsContainer} | % {    
    $scriptName = $_.name
    $versionDescriptor = GetVersionFromString $scriptName
    $versionDescriptor.file = $_.name
    $versionDescriptor.path = $_.fullname
    $versionDescriptor
  } | sort major, minor, revision, scriptVersion -Descending

  $latestBaseline = $baselineDirs[0]
  if ($latestBaseline -eq $null) {
    throw "there is no baseline to install"
  } 
  else {
    Write-Host "latest baseline is $($latestBaseline.path)"
  }
  
  $installScript = "$($latestBaseline.path)\install.db.sql"
  $initScript = "$($latestBaseline.path)\init.db.sql"
  $initTestDataScript = "$($latestBaseline.path)\init.db.testdata.sql"
  $scriptsToApply = @($installScript, $initScript, $initTestDataScript)
  
  Write-Host "Getting database version"
  $DatabaseVersion = Get-Db-Version `
    -DatabaseServer $DatabaseServer `
    -DatabaseName $DatabaseName
  if ($DatabaseVersion -eq $null) {
    Write-Host "No database version found - creating inital 0.0.0.0 version."
    $void = Save-Db-Version `
      -DatabaseServer $DatabaseServer `
      -DatabaseName $DatabaseName `
      -Version "0.0.0.0"
      
    $DatabaseVersion = Get-Db-Version `
      -DatabaseServer $DatabaseServer `
      -DatabaseName $DatabaseName
  }
  
  $BaselineVersionDescriptor = GetVersionFromString $latestBaseline.file
  
  $scriptsToApply | % { 
    echo "Applying script $($_.file)..." 
    $success = Execute-Sql-From-File $_
    if ($success -eq $true) {
      
      echo "Updating db to $NewDbVersion"
    } 
    else {
        throw "Executing update script $($_.file) failed - remaining update scripts will not be applied. Your database might be in an insonsistent version."
    }
  }  
  
  $NewDbVersion = "$($BaselineVersionDescriptor.major).$($BaselineVersionDescriptor.minor).$($BaselineVersionDescriptor.revision).$($BaselineVersionDescriptor.scriptVersion)"
  
  $void = Save-Db-Version `
    -DatabaseServer $DatabaseServer `
    -DatabaseName $DatabaseName `
    -Version $NewDbVersion
}

function Update-Database {
	[cmdletbinding(DefaultParameterSetName='customauth')]
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName
	)

	switch ($PsCmdlet.ParameterSetName) { 
		'devauth' {
			$authentication = 'User ID=sa;Password=pass'
			Write-Debug "Using development authentication: $authentication"
		}
		'credauth' {
			$plainCred = $credential.GetNetworkCredential()
			$authentication = "uid={0};pwd={1};" -f $plainCred.Username,$plainCred.Password
			Write-Debug "Using passed credentials, user: $($plainCred.Username)"
		}
		'customauth' {
			Write-Debug "Using custom authentication: $authentication"
		}
		default { throw "Parameter set name unknown: $($PsCmdlet.ParameterSetName)" }
	}

  Write-Host "Will try to update $DatabaseName to new version..."

  Write-Host "Getting database version"
  $DatabaseVersion = Get-Db-Version `
    -DatabaseServer $DatabaseServer `
    -DatabaseName $DatabaseName
  if ($DatabaseVersion -eq $null) {
    Write-Host "No database version found - creating inital 0.0.0.0 version."
    $void = Save-Db-Version `
      -DatabaseServer $DatabaseServer `
      -DatabaseName $DatabaseName `
      -Version "0.0.0.0"
    $DatabaseVersion = Get-Db-Version `
      -DatabaseServer $DatabaseServer `
      -DatabaseName $DatabaseName
  }
  $DatabaseVersionDescriptor = GetVersionFromString $DatabaseVersion
  
  Write-Host "Detected database version: $DatabaseVersion"
  # select last script from schemaversions table
  #Write-Host "Latest database version: $LatestDatabaseVersion"

  Write-Host "Executing update scripts..."

  # get a list of scripts
  $allScripts = gci ".\Updates\*.sql" | % {    
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($_.name)    
    $versionDescriptor = GetVersionFromString $scriptName
    $versionDescriptor.file = $_.name
    $versionDescriptor.path = $_.fullname
    $versionDescriptor
  } | sort major, minor, revision, scriptVersion
  
  
  # skip scripts that were already applied (version <= db version)
  $scriptsToApply = $allScripts | where { `
    $_.major -gt $DatabaseVersionDescriptor.major -or `
    ($_.major -eq $DatabaseVersionDescriptor.major -and $_.minor -gt $DatabaseVersionDescriptor.minor) -or `
    ($_.major -eq $DatabaseVersionDescriptor.major -and $_.minor -eq $DatabaseVersionDescriptor.minor -and $_.revision -gt $DatabaseVersionDescriptor.revision) -or `
    ($_.major -eq $DatabaseVersionDescriptor.major -and $_.minor -eq $DatabaseVersionDescriptor.minor -and $_.revision -eq $DatabaseVersionDescriptor.revision -and $_.scriptVersion -gt $DatabaseVersionDescriptor.scriptVersion)
  }  
    
  # those will be recreated from scratch
  # apply remaining scripts
  $void = $scriptsToApply | % { 
    echo "Applying script $($_.file)..." 
    $success = Execute-Sql-From-File $_.path
    if ($success -eq $true) {
      $NewDbVersion = "$($_.major).$($_.minor).$($_.revision).$($_.scriptVersion)"
      echo "Updating db to $NewDbVersion"
      $void = Save-Db-Version `
        -DatabaseServer $DatabaseServer `
        -DatabaseName $DatabaseName `
        -Version $NewDbVersion
    } 
    else {
        throw "Executing update script $($_.file) failed - remaining update scripts will not be applied. Your database might be in an insonsistent version."
    }
  }  
 
  # drop all stored procedures, functions and views
  Write-Host "Dropping all stored procedures, functions and views from database - will recreate them promptly"
  $void = Execute-Sql-From-File ".\Maintenance\DropFuncsSprocsAndViews.sql"

  # drop all stored procedures, functions and views
  Write-Host "Recreating stored procedures..."  
  $void = gci ".\Sprocs\*.sql" | % { Execute-Sql-From-File $_.fullname }
  
  Write-Host "Recreating functions..."
  $void = gci ".\Functions\*.sql" | % { Execute-Sql-From-File $_.fullname }
  
  Write-Host "Recreating views..."
  $void = gci ".\Views\*.sql" | % { Execute-Sql-From-File $_.fullname }
}