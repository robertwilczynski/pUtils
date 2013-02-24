function Create-Database {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$sqlServer = "localhost",

		[Parameter(Mandatory=$true)]
		[string] 
		$databaseName
	)

	$ret = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

	$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $sqlServer
	
	#Create a new database
	if ($server.Databases[$databaseName] -eq $null) {
		$db = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database -argumentlist $server, $databaseName
		$ret = $db.Create()
		
		return $True
	}
	else {
    $ret = Write-Output "Database $databaseName already exists"
    
    return $False
	}
}

function Add-Login {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$sqlServer = "localhost",

		[Parameter(Mandatory=$true)]
		[string] 
		$databaseName,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$loginName,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$role = "db_owner"		
	)

	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

	$server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $sqlServer
	
	$log = $server.Logins[$loginName]
	if ($log -eq $null) {
		write-output "Login $login not found - creating..."
		$log = New-Object ("Microsoft.SqlServer.Management.Smo.Login") ($server, $loginName)
		$log.LoginType = [Microsoft.SqlServer.Management.SMO.LoginType]::WindowsUser;

		$ret = $log.Create()
	} 
	else {
        write-output "Login $login already exists"
	}
	
	$db = $server.Databases[$databaseName];
	write-output "Checking if login $login is a user in database $databaseName"

	# Check to see if the login is a user in this database
	$userName = $loginName.Split('\')[1]
	$usr = $db.Users[$userName]
	if ($usr -eq $null) {
		write-output "Creating user $userName for login $loginName"	
		$usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') ($db, $userName)
		$usr.Login = $loginName;
		$ret = $usr.Create()
		$error[0]|format-list -force
	} else {
    write-output "Login $loginName is already a user in $($db.Name)"
	}

	# Check to see if the user is a member of the role
	
	if ($usr.IsMember($role) -ne $True) {	
		# Not a member, so add that role
		$cn = new-object system.data.SqlClient.SqlConnection("Data Source=$sqlServer;Integrated Security=SSPI;Initial Catalog=$databaseName");
		$ret = $cn.Open()
		$q = "EXEC sp_addrolemember @rolename = N'$role', @membername = N'$userName'"
		$cmd = new-object "System.Data.SqlClient.SqlCommand" ($q, $cn)
		$cmd.ExecuteNonQuery() | out-null
		$cn.Close()	
	}
}

function Invoke-SqlCommand {
	[cmdletbinding(DefaultParameterSetName='customauth')]
	param(
		[Parameter(Mandatory=$false)]
		[string] 
		$DatabaseServer = ".\SQLEXPRESS",

		[Parameter(Mandatory=$false)]
		[string] 
		$DatabaseName = "Northwind",

		[Parameter(Mandatory=$true)]   
		[string] 
		$SqlCommand,

		[Parameter(Mandatory=$false, ParameterSetName='credauth')]
		[System.Management.Automation.PsCredential] 
		$credential,

		[Parameter(Mandatory=$false, ParameterSetName='customauth')]
		[string] 
		$authentication ="Integrated Security=SSPI;",

		[Parameter(ParameterSetName='devauth')]
		[switch]
		$developmentAuthentication
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

	$connectionString = "Server=$DatabaseServer;Database=$DatabaseName;$authentication;"

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


function Sql-Get-Scalar {
	[cmdletbinding(DefaultParameterSetName='customauth')]
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$DatabaseServer,

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
		$authentication ="Integrated Security=SSPI;",

		[Parameter(ParameterSetName='devauth')]
		[switch]
		$developmentAuthentication
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

	$connectionString = "Server=$DatabaseServer;Database=$DatabaseName;$authentication;"

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
