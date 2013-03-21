function SecureString-To-String ([System.Security.SecureString]$secureString) {
    [System.IntPtr]$unmanagedString = [System.IntPtr]::Zero;
    
    Try
    {
        $unmanagedString = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($secureString);
        return [System.Runtime.InteropServices.Marshal]::PtrToStringUni($unmanagedString);
    }
    Finally
    {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($unmanagedString);
    }
}

function Set-Account-Permission ([string]$AccountName, [string]$Permission) {
	Write-Host "Setting $Permission for account $AccountName"
	Start-Process `
		-FilePath ".\_deploy\bin\ntrights.exe" `
		-ArgumentList "+r", $Permission, "-u", $AccountName
}

function Set-Account-ServiceLogon-Permission ([string]$AccountName) {
	Set-Account-Permission -AccountName $AccountName -Permission "SeServiceLogonRight"
}

function Set-AppSetting {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$config,

		[Parameter(Mandatory=$true)]
		[string] 
		$name,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$value
	)

  $configPath = (Resolve-Path $config).Path 
  $xml = [xml](get-content $configPath)
  $root = $xml.get_DocumentElement();	
  (Select-Xml -Xml $xml -XPath "configuration/appSettings/add[translate(@key, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='$($name.ToLower())']").Node.SetAttribute("value", $value)
  $xml.Save($configPath)
}

function Set-ConnectionString {
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$config,

		[Parameter(Mandatory=$true)]
		[string] 
		$name,
		
		[Parameter(Mandatory=$true)]
		[string] 
		$connectionString
	)

  $configPath = (Resolve-Path $config).Path 
  $xml = [xml](get-content $configPath)
  $root = $xml.get_DocumentElement();	
  $item = (Select-Xml -Xml $xml -XPath "configuration/connectionStrings/add[translate(@name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='$($name.ToLower())']")
  
  if ($item -eq $null) {
	$connString = $xml.CreateElement("add")
	$connString.SetAttribute("name", $name)
	$connString.SetAttribute("connectionString", $connectionString)
	$xml.configuration["connectionStrings"].AppendChild($connString)
  } else {
	$item.Node.SetAttribute("connectionString", $connectionString)
  }
  $xml.Save($configPath)
}