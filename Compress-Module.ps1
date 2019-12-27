[CmdletBinding()]
param
(
    [Parameter(Mandatory = $True)]
    [String]$ModuleName
)

$PipelineHelperModule = Get-ChildItem `
    -Recurse | Where-Object { $_.Name -eq "PipelineHelper.psm1" }

Import-Module `
    -Name ($PipelineHelperModule.FullName | Convert-Path) `
    -Force

$ModulePath = Get-ChildItem `
    -Path $PSScriptRoot `
    -Name $ModuleName `
    -Directory

$PackageNewVersion = Get-NugetVersion `
    -ModuleName $ModuleName `
    -ModulePath $ModulePath

$ArchiveTargets = Get-ChildItem `
    -Path $ModulePath `
    -Exclude @("*.nupkg", "*.nuspec", "*.png", "*.zip")

$ArchiveTargets | ForEach-Object { Write-Verbose ("Target to Add: {0}" -f $_.FullName) }

$ArchiveTargets | Compress-Archive `
    -DestinationPath (Join-Path `
        -Path $ModulePath `
        -ChildPath ("{0}.{1}.zip" -f $ModuleName, $PackageNewVersion)) `
        -Force
