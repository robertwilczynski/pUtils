function Get-SqlServer {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer
	)
	
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
	[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null
	
	$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SqlServer
	return $server
}

function Kill-DatabaseConnections {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName
	)
	$server = Get-SqlServer -SqlServer $SqlServer
	$server.KillAllProcesses($DatabaseName)	
}

function Drop-Database {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName,
	
		[Switch] 
		$KillAllConnections
	)
	$server = Get-SqlServer -SqlServer $SqlServer
	
	if ($KillAllConnections -eq $true) {
		$server.KillAllProcesses($DatabaseName)	
	}
	
	$server.Databases[$DatabaseName].Drop()
}

function Test-Database {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName
	)
	$server = Get-SqlServer -SqlServer $SqlServer
	if ($server.Databases[$DatabaseName] -ne $null) {
		return $true
	}
	return $false
}

function Backup-Database {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName,
		
		[Parameter(Mandatory=$false)]
		[string]
		$BackupDirectory,
		
		[Parameter(Mandatory=$false)]
		[string]
		$BackupFileName
	)
	$server = Get-SqlServer -SqlServer $SqlServer	
	
	$effectiveBackupDirectory = $BackupDirectory
	if ($effectiveBackupDirectory -eq $null -or $effectiveBackupDirectory -eq "") {
		$effectiveBackupDirectory = $server.Settings.BackupDirectory
	}
	
	$db = $server.Databases[$DatabaseName]
	if ($db -eq $null) {
		throw "Database $DatabaseName does not exist"
	}
	
	$effectiveBackupFilename = $BackupFileName
	if ($effectiveBackupFilename -eq $null -or $effectiveBackupFilename -eq "") {
		$timestamp = Get-Date -format yyyyMMddHHmmss
		$dbName = $db.Name
		$effectiveBackupFilename = $dbName + "_" + $timestamp + ".bak"
	}
	
	$backupFilePath = $effectiveBackupDirectory + "\" + $effectiveBackupFilename
	
	$smoBackup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup")
 	
	$smoBackup.Action = "Database"
	$smoBackup.BackupSetDescription = "Full Backup of " + $dbName
	$smoBackup.BackupSetName = $dbName + " Backup"
	$smoBackup.Database = $db.Name
	$smoBackup.MediaDescription = "Disk"
	$smoBackup.Devices.AddDevice($backupFilePath, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
	$smoBackup.SqlBackup($server)
	echo $error[0]
}

function Restore-Database {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$BackupFileLocation,		
		
		[Switch] 
		$OverwriteTargetDatabase,

		[Switch] 
		$KeepOriginalFileNames,
		
		# if not set this commandlet will not restore on the 
		# database the backup was taken from to avoid overwriting 
		# production database
		[Switch] 
		$AllowRestoreOnBackupSource
	)

	$server = Get-SqlServer -SqlServer $SqlServer
	if ($server.Databases[$DatabaseName] -ne $null -and $OverwriteTargetDatabase -eq $false) {
		throw "Database $DatabasseName already exists. Please use the -OverwriteTargetDatabase swith to overwrite."
	}
	
	$backupDevice = New-Object("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") ($BackupFileLocation, "File")
	$smoRestore = new-object("Microsoft.SqlServer.Management.Smo.Restore")
	 
	$smoRestore.NoRecovery = $false;
	$smoRestore.ReplaceDatabase = $OverwriteTargetDatabase;
	$smoRestore.Action = "Database"
	$smoRestorePercentCompleteNotification = 10;
	$smoRestore.Devices.Add($backupDevice)
	 
	$smoRestoreDetails = $smoRestore.ReadBackupHeader($server)

	$dt = $smoRestore.ReadFileList($server)
	$logFileRow = $dt.Rows | where { $_.Type -eq "L" }
	$dataFileRow = $dt.Rows | where { $_.Type -eq "D" }

	$backupSourceDatabaseName = $smoRestoreDetails.Rows[0]["DatabaseName"]
		 
	#give a new database name
	$smoRestore.Database = $DatabaseName
	 
	if ($KeepOriginalFileNames -eq $true) {	
		$dbFilename = $smoRestore.Database + "_Data.mdf"
		$logFilename = $smoRestore.Database + "_Log.ldf"
	}
	else {
		$dbFilename = $DatabaseName + "_Data.mdf"
		$logFilename = $DatabaseName + "_Log.ldf"
	}
	
	#specify new data and log files (mdf and ldf)
	$smoRestoreFile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
	# we take the logical file name that we want to move from the backup media
	$smoRestoreFile.LogicalFileName = $dataFileRow.LogicalName
	$smoRestoreFile.PhysicalFileName = $server.Information.MasterDBPath + "\" + $dbFilename
	$void = $smoRestore.RelocateFiles.Add($smoRestoreFile)
	
	$smoRestoreLog = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
	# we take the logical file name that we want to move from the backup media
	$smoRestoreLog.LogicalFileName = $logFileRow.LogicalName
	$smoRestoreLog.PhysicalFileName = $server.Information.MasterDBLogPath + "\" + $logFilename
	$void = $smoRestore.RelocateFiles.Add($smoRestoreLog)

	#restore database
	$void = $smoRestore.SqlRestore($server)	
}

function Get-BackupFileInfo {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$BackupFileLocation
	)

	$server = Get-SqlServer -SqlServer $SqlServer
	
	$backupDevice = New-Object("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") ($BackupFileLocation, "File")
	$smoRestore = new-object("Microsoft.SqlServer.Management.Smo.Restore")
	 
	$smoRestore.NoRecovery = $false;
	$smoRestore.ReplaceDatabase = $false;
	$smoRestore.Action = "Database"
	$smoRestorePercentCompleteNotification = 10;
	$smoRestore.Devices.Add($backupDevice)
	 
	"Backup header"
	$smoRestore.ReadBackupHeader($server) | Format-List
	
	"Media header"
	$smoRestore.ReadMediaHeader($server) | Format-List
	
	"File list"
	$smoRestore.ReadFileList($server) | Format-List
}

function Create-Database {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName
	)
	
	$server = Get-SqlServer $SqlServer
	
	#Create a new database
	if ($server.Databases[$databaseName] -eq $null) {
		$db = New-Object `
			-TypeName Microsoft.SqlServer.Management.Smo.Database -argumentlist `
			$server, $DatabaseName
			
		$db.Create()
	} 
	else {
		
	}
}

function Sql-Get-Scalar {
	[cmdletbinding(DefaultParameterSetName='customauth')]
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName,

		[Parameter(Mandatory=$true)]   
		[string]
		$SqlCommand,
		
		[Parameter(Mandatory=$false, ParameterSetName='credauth')]
		[System.Management.Automation.PsCredential] 
		$credential,

		[Parameter(Mandatory=$false, ParameterSetName='customauth')]
		[string] 
		$authentication ="Integrated Security=SSPI;"
	)

	switch ($PsCmdlet.ParameterSetName) { 
		'credauth' {
			$plainCred = $credential.GetNetworkCredential()
			$authentication = "uid={0};pwd={1};" -f $plainCred.Username, $plainCred.Password
			Write-Debug "Using passed credentials, user: $($plainCred.Username)"
		}
		'customauth' {
			Write-Debug "Using custom authentication: $authentication"
		}
		default { throw "Parameter set name unknown: $($PsCmdlet.ParameterSetName)" }
	}

	$connectionString = "Server=$SqlServer;Database=$DatabaseName;$authentication;"

	write-host "Connection string: $connectionString"
	## Connect to the data source and open it
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = $connectionString
	$void = $SqlConnection.Open()

	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlCommand
	$SqlCmd.Connection  = $SqlConnection

	$result = $SqlCmd.ExecuteScalar()
	$void = $SqlCmd.Dispose()
	$void = $SqlConnection.Close()
	
	return $result;
}

function Invoke-SqlCommand {
	[cmdletbinding(DefaultParameterSetName='customauth')]
	param(
		[Parameter(Mandatory=$false)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$false)]
		[string] 
		$DatabaseName,

		[Parameter(Mandatory=$true)]   
		[string] 
		$SqlCommand,

		[Parameter(Mandatory=$false, ParameterSetName='credauth')]
		[System.Management.Automation.PsCredential] 
		$credential,

		[Parameter(Mandatory=$false, ParameterSetName='customauth')]
		[string] 
		$authentication ="Integrated Security=SSPI;"
	)

	switch ($PsCmdlet.ParameterSetName) { 
		'credauth' {
			$plainCred = $credential.GetNetworkCredential()
			$authentication = "uid={0};pwd={1};" -f $plainCred.Username, $plainCred.Password
			Write-Debug "Using passed credentials, user: $($plainCred.Username)"
		}
		'customauth' {
			Write-Debug "Using custom authentication: $authentication"
		}
		default { throw "Parameter set name unknown: $($PsCmdlet.ParameterSetName)" }
	}

	$connectionString = "Server=$$SqlServer;Database=$DatabaseName;$authentication;"

	write-debug "Connection string: $connectionString"
	## Connect to the data source and open it
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = $connectionString
	$SqlConnection.Open()
	$commands = [System.Text.RegularExpressions.Regex]::Split($SqlCommand, "^\s*GO\s*$", [System.Text.RegularExpressions.RegexOptions] "Multiline, IgnoreCase")

	foreach($sql in $commands)
	{
		if ($sql -eq "")
		{
			continue;
		}
        Write-Host "Executing: $sql"
        
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = $sql
		$SqlCmd.Connection  = $SqlConnection
		[void]$SqlCmd.ExecuteNonQuery()
		$SqlCmd.Dispose()
	}
	$SqlConnection.Close()
}

function Add-UserForLoginWithRole {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$SqlServer,

		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseName,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$Login,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$Role = "db_owner"		
	)

	$server = Get-SqlServer -SqlServer $SqlServer
	
	$dbLogin = $server.Logins[$Login]
	
	if ($dbLogin -eq $null) {
		Write-Host "Login $Login is not a valid SQL Server login on this instance."
		break;
	}
	
	$db = $server.Databases[$DatabaseName];
	Write-Host "Checking if login $Login is a user in database $DatabaseName"
	
	$dbUser = $db.Users[$Login]
	
	if ($dbUser -eq $null) {
		write-output "Creating user for login $Login"
		$dbUser = New-Object ("Microsoft.SqlServer.Management.Smo.User") ($db, $login)
		$dbUser.Login = $Login;
		$dbUser.Create()
	}

	if ($dbUser.IsMember($Role) -ne $true) {	
		# Not a member, so add that role
		$connection = new-object System.Data.SqlClient.SqlConnection("Data Source=$SqlServer;Integrated Security=SSPI;Initial Catalog=$DatabaseName");
		$connection.Open()
		$query = "EXEC sp_addrolemember @rolename = N'$role', @membername = N'$login'"
		$cmd = new-object "System.Data.SqlClient.SqlCommand" ($query, $connection)
		$cmd.ExecuteNonQuery() | out-null
		$connection.Close()	
	}
}
