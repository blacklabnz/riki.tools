[CmdletBinding()]
param
(
    [Parameter(Mandatory = $False)]
    [string]$ModuleName = "RikiGoogle",

    [Parameter(Mandatory = $False)]
    [string]$Author = "Neil Xu",

    [Parameter(Mandatory = $False)]
    [string]$CompanyName = "Riki",

    [Parameter(Mandatory = $False)]
    [switch]$Force,

    [Parameter(Mandatory = $False)]
    [ValidateSet("ScriptModule", "ManifestModule")]
    [string]$Type
)

$ModuleFolder = Get-ChildItem `
    -Path $PSScriptRoot `
    -Name $ModuleName `
    -Directory

$ModuleManifest = Get-ChildItem `
    -Path $ModuleFolder `
    -Name ("{0}.psd1" -f $ModuleName)

if ($ModuleManifest)
{
    Write-Verbose ("Module {0} with Manifest {1} already exists" `
            -f $ModuleFolder, $ModuleManifest)

    if (-Not $Force)
    {
        exit
    }
    else
    {
        Write-Verbose ("Force switch is present Module will be overwritten" `
                -f $ModuleFolder, $ModuleManifest)

        Remove-Item `
            -Path $ModuleFolder `
            -Recurse `
            -Force
    }
}

$ModulePath = New-Item `
    -Name $ModuleName `
    -ItemType Directory `
    -Force

$NewModuleScript = New-Item `
    -Path $ModulePath `
    -Name ("{0}.psm1" -f $ModuleName)

if ($Type -eq "ManifestModule")
{
    $NewLibraryFolder = New-Item `
        -Path $ModulePath `
        -Name "library" `
        -ItemType Directory `
        -Force

    $NewLibraryfile = New-Item `
        -Path $NewLibraryFolder `
        -Name "functions.ps1" `
        -Force
}

$Manifest = @{
    Path            = (".\{0}\{0}.psd1" -f $ModuleName)
    RootModule      = ".\{0}" -f $NewModuleScript.Name
    Author          = $Author
    CompanyName     = $CompanyName
    Copyright       = ("(c) 2019 {0}. All rights reserved." -f $CompanyName)
    ModuleVersion   = "1.0.0"
}

if ($Type -eq "ManifestModule")
{
    $Manifest += @{
        NestedModules = @(
            (".\library\{0}" -f $NewLibraryfile.Name)
        )
    }
}

New-ModuleManifest @Manifest

Write-Verbose ("Module scaffold created for {0}" `
        -f $ModuleName)
