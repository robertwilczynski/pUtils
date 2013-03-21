function BuildNugetVersion
{
    param(
        [string] $Version, 
        [string] $PrereleaseTag
    )
    $FullNugetVersion = $Version
    if ($PrereleaseTag -ne $NULL -and $PrereleaseTag -ne "") {
        $FullNugetVersion = $Version + "-" + $PrereleaseTag
    }
    return $FullNugetVersion
}