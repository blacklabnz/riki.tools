[CmdletBinding()]
param
(
    [Parameter(Mandatory = $True)]
    [String]$AutomationAccountName,

    [Parameter(Mandatory = $True)]
    [String]$ModuleName,

    [Parameter(Mandatory = $True)]
    [String]$StorageAccountName,

    [Parameter(Mandatory = $True)]
    [String]$StorageContainerName,

    [Parameter(Mandatory = $False)]
    [String]$WorkingDirectory,

    [Parameter(Mandatory = $False)]
    [Switch]$Verbosity
)

if ($WorkingDirectory)
{
    Write-Verbose ("Setting script working directory to {0}" -f $WorkingDirectory)

    Set-Location -Path $WorkingDirectory
}

$PipelineHelperModule = Get-ChildItem `
    -Recurse | Where-Object { $_.Name -eq "PipelineHelper.psm1" }

Import-Module `
    -Name ($PipelineHelperModule.FullName | Convert-Path) `
    -Force

$AutomationAccount = Get-AzResource `
    -Name $AutomationAccountName

$TargetModule = Get-AzAutomationModule `
    -ResourceGroupName $AutomationAccount.ResourceGroupName `
    -AutomationAccountName $AutomationAccountName `
    -Name $ModuleName

$ModulePath = Get-ChildItem `
    -Path $PSScriptRoot `
    -Name $ModuleName `
    -Directory

$ModuleNewVersion = Get-NugetVersion `
    -ModuleName $ModuleName `
    -ModulePath $ModulePath

if ([version]$ModuleNewVersion -gt [version]$TargetModule.Version)
{
    Write-Output ("New version detected for Module {0}, importing to automation account" `
        -f $ModuleName)

    $Module = Get-ChildItem `
        -Path $ModulePath `
        -Filter "*.zip"

    $StorageAccount = Get-AzResource `
        -Name $StorageAccountName

    $StorageAccountKey = (Get-AzStorageAccountKey `
        -ResourceGroupName $StorageAccount.ResourceGroupName `
        -Name $StorageAccountName).Value[0]

    $StorageAccountContext = New-AzStorageContext `
        -StorageAccountName $StorageAccountName `
        -StorageAccountKey $StorageAccountKey

    Import-AutomationModuleToBlob `
        -StorageAccountContext $StorageAccountContext `
        -ContainerName $StorageContainerName `
        -ModulePath $Module.FullName `
        -ModuleName $Module.Name `
        -Verbose:$Verbosity

    $BlobAccessUri = New-AzStorageBlobSASToken `
        -Context $StorageAccountContext `
        -Container $StorageContainerName `
        -Blob $Module.Name `
        -Permission r `
        -FullUri

    Update-AutomationModule `
        -ResourceGroupName $AutomationAccount.ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -ModuleName $ModuleName `
        -ModuleUri $BlobAccessUri `
        -sync `
        -Verbose:$Verbosity
}
else
{
    Write-Output ("Version is up to date for module {0}, skip importing to automation account" `
        -f $ModuleName)
}

