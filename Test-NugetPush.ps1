[CmdletBinding()]
param
(
    [Parameter(Mandatory = $True)]
    [String]$Repository,

    [Parameter(Mandatory = $True)]
    [String]$ModuleName,

    [Parameter(Mandatory = $True)]
    [String]$PatToken
)

$PipelineHelperModule = Get-ChildItem `
    -Recurse | Where-Object { $_.Name -eq "PipelineHelper.psm1" }

Import-Module `
    -Name ($PipelineHelperModule.FullName | Convert-Path) `
    -Force

$BasicToken = New-BasicAuthToken `
    -AuthToken $PatToken

$PackageCurrentVersion = (Find-PublishedModules `
    -Repository $Repository `
    -BasicAuthToken $BasicToken `
    -ModuleName $ModuleName).Versions.Version

$ModulePath = Get-ChildItem `
    -Path $PSScriptRoot `
    -Name $ModuleName `
    -Directory

$PackageNewVersion = Get-NugetVersion `
    -ModuleName $ModuleName `
    -ModulePath $ModulePath

if (-not $PackageCurrentVersion)
{
    Write-Output ("Package {0} not found, run nuget push`nSetting pipeline Variable [RunNuget] to: True" `
        -f $ModuleName)

    Write-Host "##vso[task.setvariable variable=RunNuget]$True"
}
elseif ([version]$PackageNewVersion -gt [version]$PackageCurrentVersion)
{
    Write-Output ("Package new version {0} is > current version {1}, run nuget push`nSetting pipeline Variable [RunNuget] to: True" `
        -f $PackageNewVersion, $PackageCurrentVersion)

    Write-Host "##vso[task.setvariable variable=RunNuget]$True"
}
else
{
    Write-Output ("Package new version {0} is NOT > current version {1}, skip nuget push`nSetting pipeline Variable [RunNuget] to: False" `
        -f $PackageNewVersion, $PackageCurrentVersion)

    Write-Host "##vso[task.setvariable variable=RunNuget]$False"
}
