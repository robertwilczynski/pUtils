function BuildReportingServiceProxy (
	$reportServerName = $(throw "reportServerName is required."), 
	$serverVersion = $(throw "serverVersion is required.")
)
{
    $reportServerUri = "http://$reportServerName/ReportService$serverVersion.asmx"
	$namespace = $null

    $proxy = New-WebServiceProxy -Uri $reportServerUri -UseDefaultCredential
	return $proxy
}

function CreateFolder (
	$proxy = $(throw "proxy is required, create one using BuildReportingServiceProxy function."), 
    $folder = $(throw "folder is required.")
)
{
	$normalizedPath = [string]$folder
	$normalizedPath = $normalizedPath.Trim('/')	
	$parts = $normalizedPath.Split("/")
	$intermediateFolder = "/"
	foreach ($part in $parts) {
		$children = $proxy.ListChildren($intermediateFolder, $false)
		$found = $false
		
		foreach ($c in $children) {
			if ($c.Name -eq $part -and $c.TypeName -eq "Folder") {
				$found = $true
				break;
			}
		}
		if ($found -eq $false) {
			$proxy.CreateFolder($part, $intermediateFolder, $null);
		}
		
		if ($intermediateFolder -eq "/"){
			$intermediateFolder = $intermediateFolder + $part
		}
		else {
			$intermediateFolder = $intermediateFolder + "/" + $part
		}
	}
}

function UploadDataSets (
	$proxy = $(throw "proxy is required, create one using BuildReportingServiceProxy function."), 
    $fromDirectory = $(throw "fromDirectory is required."), 
	$serverPath = $(throw "serverPath is required."),
	$dataSourcePath,
	$dataSourceName
)
{
    # coerce the return to be an array with the @ operator in case only one file
    $rsdFiles = @(get-childitem $fromDirectory *.rsd -rec|where-object {!($_.psiscontainer)})
     
    $uploadedCount = 0

	foreach ($fileInfo in $rsdFiles)
    {    
        $file = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.FullName)        
		Write-Output "Uploading: $file => $serverPath"
        $percentDone = (($uploadedCount/$rsdFiles.Count) * 100)        
        Write-Progress -activity "Uploading to $serverPath" -status $file -percentComplete $percentDone
        $bytes = [System.IO.File]::ReadAllBytes($fileInfo.FullName)
		$warnings = $null
		$dataSetName = $file
        $response = $proxy.CreateCatalogItem("DataSet", $dataSetName, "$serverPath", $true, $bytes, $null, [ref] $warnings)
        if ($warnings)
        {
            foreach ($warn in $warnings)
            {
                Write-Warning $warn.Message
            }
        }
		
		# if replacement datasource is defined we will set it on this data set
		if ($dataSourcePath -ne $NULL) {
			Write-Progress -activity "Overwriting data source on dataset $file" -status $file -percentComplete $percentDone
			# getting previous datasource from data set to find out the data source name to replace
			# for now we will only limit ourserves to replacing first one
			$name = $proxy.GetItemDataSources("$serverPath/$dataSetName")[0].Name
			
			# building a reference to our replacement data source
			$type = $proxy.GetType().Namespace			
			$reference = new-object "$type.DataSourceReference"
			$reference.Reference = $dataSourcePath
			$source = new-object "$type.DataSource"
			$source.Item = $reference
			$source.Name = $name
			
			# repalcing the datasource
			$response = $proxy.SetItemDataSources("$serverPath/$dataSetName", @($source))
		}
         
        $uploadedCount += 1
    }    
}

function UploadReports (
	$proxy = $(throw "proxy is required, create one using BuildReportingServiceProxy function."), 
    $fromDirectory = $(throw "fromDirectory is required."), 
	$serverPath = $(throw "serverPath is required.")
)
{    
    # coerce the return to be an array with the @ operator in case only one file
    $rdlFiles = @(get-childitem $fromDirectory *.rdl -rec|where-object {!($_.psiscontainer)})
	
    $uploadedCount = 0
     
    foreach ($fileInfo in $rdlFiles)
    {    
        $file = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.FullName)        
        $percentDone = (($uploadedCount/$rdlFiles.Count) * 100)        
        Write-Progress -activity "Uploading to $serverPath" -status $file -percentComplete $percentDone
        Write-Output "Uploading: $file => $serverPath"
        $bytes = [System.IO.File]::ReadAllBytes($fileInfo.FullName)
		$warnings = $null
        $response = $proxy.CreateCatalogItem("Report", $file, "$serverPath", $true, $bytes, $null, [ref] $warnings)
        if ($warnings)
        {
            foreach ($warn in $warnings)
            {
                Write-Warning $warn.Message
            }
        }
        $uploadedCount += 1
    }    
}

function CreateDataSource (
	$proxy = $(throw "proxy is required, create one using BuildReportingServiceProxy function."), 
    $name = $(throw "name is required."), 
	$parent = $(throw "parent is required."),
	$definition = $(throw "definition is required.")
)
{
	$file = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.FullName)        
	$percentDone = 0
	Write-Output "%$percentDone : Uploading $file to $serverPath"

	$warnings = $null

	$response = $proxy.CreateDataSource($name, $parent, $true, $definition, $null)
	
	if ($warnings)
	{
		foreach ($warn in $warnings)
		{
			Write-Warning $warn.Message
		}
	}
	
	$percentDone = 100
	Write-Output "%$percentDone : Uploading $file to $serverPath"	
}


