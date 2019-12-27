[CmdletBinding()]
param
(
    [Parameter(Mandatory = $False)]
    [string[]]$ModuleNames = @("RikiTools", "RikiGoogle", "RikiJwt"),

    [Parameter(Mandatory = $False)]
    [switch]$Major,

    [Parameter(Mandatory = $False)]
    [switch]$Minor,

    [Parameter(Mandatory = $False)]
    [switch]$Verbosity = $False
)

# Import PipelineHelper script module
$PipelineHelperModule = Get-ChildItem `
    -Recurse ` | Where-Object { $_.Name -eq "PipelineHelper.psm1" }

Import-Module `
    -Name ($PipelineHelperModule.FullName | Convert-Path) `
    -Force

foreach ($ModuleName in $ModuleNames)
{
    [bool]$UpdateModuleVersion = $False

    $ModulePath = Get-ChildItem `
        -Path $PSScriptRoot `
        -Name $ModuleName `
        -Directory

    $ModuleChanged = Test-ModuleChange `
        -ModulePath $ModulePath `
        -Verbose:$Verbosity

    $Dependencies = Get-ModuleDependencies `
        -ModuleName $ModuleName `
        -ModulePath $ModulePath `
        -Verbose:$Verbosity

    $DependencyChanged = $False

    if ($Dependencies)
    {
        foreach ($Dependency in $Dependencies)
        {
            $DependencyModulePath = Get-ChildItem `
                -Path $PSScriptRoot `
                -Name $Dependency `
                -Directory

            $DependencyModuleChanged = Test-ModuleChange `
                -ModulePath $DependencyModulePath `
                -Verbose:$Verbosity

            if ($DependencyModuleChanged)
            {
                $DependencyChanged = $true

                break
            }
        }
    }

    if (($DependencyChanged) -or ($ModuleChanged))
    {
        $UpdateModuleVersion = $True
    }

    if ($UpdateModuleVersion)
    {
        if ($ModuleChanged)
        {
            Write-Output ("Changes detected in Moudle {0}, module verison will be updated" `
                -f $ModuleName)
        }

        if ($DependencyChanged)
        {
            Write-Output ("Changes detected in dependencies {1} for Moudle {0}, module verison will be updated" `
                -f $ModuleName, $Dependency)
        }

        Update-ModuleVersion `
            -ModuleName $ModuleName `
            -ModulePath $ModulePath `
            -Major:$Major `
            -Minor:$Minor `
            -Verbose:$Verbosity
    }
    else
    {
        Write-Output ("Changes NOT detected in Moudle {0}, not updating the version" `
            -f $ModuleName)
    }
}

Write-Output "Finished updating module manifest"

