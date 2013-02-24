function Create-WebApplication {
	param(
		[Parameter(Mandatory=$true)]
		[string] 		
    $ApplicationName,

		[Parameter(Mandatory=$true)]
		[string] 		
    $ApplicationDir,
    
		[Parameter(Mandatory=$true)]
		[string] 
    $HostHeader,
    
		[Parameter(Mandatory=$true)]
		[string] 
    $AddLocalBinding,
    
		[Parameter(Mandatory=$false)]
		[string] 
    $LocalBindingPort,
    
		[Parameter(Mandatory=$true)]
		[string] 
    $AppPoolUsername,
    
		[Parameter(Mandatory=$true)]
		[string] 
    $AppPoolUserPassword
	)
  Write-Output "Removing existing application pool..."
  Remove-WebAppPool -Name $ApplicationName -ErrorAction SilentlyContinue
  
  Write-Output "Creating new application pool..."
  $appPool = New-WebAppPool -Name $ApplicationName -Force
  Set-ItemProperty IIS:\AppPools\$ApplicationName -name managedRuntimeVersion -value v4.0
  Set-ItemProperty IIS:\AppPools\$ApplicationName -name processModel -value @{userName=$AppPoolUsername;password=$AppPoolUserPassword;identitytype=3}
  Set-ItemProperty IIS:\AppPools\$ApplicationName -Name processModel.idleTimeout -value 0
  Set-ItemProperty IIS:\AppPools\$ApplicationName -Name recycling.periodicrestart.time -value 0

  Write-Output "Removing existing web site..."
  Remove-WebSite -Name $ApplicationName -ErrorAction SilentlyContinue
  
  Write-Output "Creating a new web site..."
  New-Website -Name $ApplicationName -ApplicationPool $ApplicationName -PhysicalPath $ApplicationDir -IPAddress "*" -Port 80 -HostHeader "$HostHeader" -Force | out-null 
  Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -name enabled -value false -location $ApplicationName
  Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/windowsAuthentication -name enabled -value true -location $ApplicationName

  if ($AddLocalBinding)
  {
    New-WebBinding -Name $ApplicationName -IPAddress 127.0.0.1 -Port $LocalBindingPort -Protocol "http"
  }  
}