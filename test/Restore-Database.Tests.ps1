. ".\src\database.ps1"
. ".\test\_globals.ps1"

Describe "Restore-Database" {
	$SqlServer = "(local)"
	
	function Ensure-Database-Does-Not-Exist {
		param(
			$DatabaseName
		)
		$dbExists = Test-Database -SqlServer $SqlServer -DatabaseName $DatabaseName
		if ($dbExists) {
		Drop-Database `
			-SqlServer $SqlServer `
			-DatabaseName $DatabaseName `
			-KillAllConnections
		}
		
		$server = Get-SqlServer -SqlServer $SqlServer
		$db = $server.Databases[$DatabaseName]	
		$db | Should Be $null
	}
	
	function Ensure-Database-Exists {
		param(
			$DatabaseName
		)
		$dbExists = Test-Database -SqlServer $SqlServer -DatabaseName $DatabaseName
		if ($dbExists -eq $true) {
			Drop-Database `
				-SqlServer $SqlServer `
				-DatabaseName $DatabaseName `
				-KillAllConnections
		}
		
		Create-Database `
			-SqlServer $SqlServer `
			-DatabaseName $DatabaseName

		$server = Get-SqlServer -SqlServer $SqlServer
		$db = $server.Databases[$DatabaseName]	
		$db | Should Not Be Null
	}
	
	$DatabaseBackupToRestore = "$TestDataDir\powershell-utils.bak"
	$DatabaseToRestoreTo = "powershell-utils-restored"
			
	Context "When database doesn't exist " {		
			
		Context "When OverwriteTargetDatabase switch is specified" {		
			Ensure-Database-Does-Not-Exist `
				-DatabaseName $DatabaseToRestoreTo
		
			Restore-Database `
				-SqlServer $SqlServer `
				-DatabaseName $DatabaseToRestoreTo `
				-BackupFileLocation $DatabaseBackupToRestore `
				-OverwriteTargetDatabase

			It "Restores the database to a database with a supplied name" {
				$server = Get-SqlServer -SqlServer $SqlServer
				$db = $server.Databases[$DatabaseToRestoreTo]
				$db | Should Not Be Null
			}
		}	
		
		Context "When OverwriteTargetDatabase switch is not specified" {		
			Ensure-Database-Does-Not-Exist `
				-DatabaseName $DatabaseToRestoreTo
		
			Restore-Database `
				-SqlServer $SqlServer `
				-DatabaseName $DatabaseToRestoreTo `
				-BackupFileLocation $DatabaseBackupToRestore `
				-OverwriteTargetDatabase

			It "Restores the database to a database with a supplied name" {
				$server = Get-SqlServer -SqlServer $SqlServer
				$db = $server.Databases[$DatabaseToRestoreTo]
				$db | Should Not Be Null
			}
		}			
	}
	
	Context "When database exists" {		
			
		Context "When OverwriteTargetDatabase switch is specified" {		
			Ensure-Database-Exists `
				-DatabaseName $DatabaseToRestoreTo

			Restore-Database `
				-SqlServer $SqlServer `
				-DatabaseName $DatabaseToRestoreTo `
				-BackupFileLocation $DatabaseBackupToRestore `
				-OverwriteTargetDatabase

			It "Restores the database to a database with a supplied name" {
				$server = Get-SqlServer -SqlServer $SqlServer
				$db = $server.Databases[$DatabaseToRestoreTo]
				$db | Should Not Be Null
			}
		}	
		
		Context "When OverwriteTargetDatabase switch is not specified" {		
			Ensure-Database-Exists `
				-DatabaseName $DatabaseToRestoreTo
		
			try {
				Restore-Database `
					-SqlServer $SqlServer `
					-DatabaseName $DatabaseToRestoreTo `
					-BackupFileLocation $DatabaseBackupToRestore `
			} 
			catch [System.Exception] {
				$ex = $Error[0]
			}
			
			It "Fails restoring the database to a database with a supplied name" {
				$server = Get-SqlServer -SqlServer $SqlServer
				$db = $server.Databases[$DatabaseToRestoreTo]
				$db | Should Not Be Null
				$result = Sql-Get-Scalar `
					-SqlServer $SqlServer `
					-DatabaseName $DatabaseToRestoreTo `
					-SqlCommand "SELECT COUNT(*) from information_schema.tables"
				
				# we created a blank db so no tables are expected to be found
				# this prooves that the database was not restored
				$result | Should Be 0
			}
		}			
	}
}

