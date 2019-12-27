function Test-ModuleChange
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$ModulePath
    )

    $Arguments = @("describe", "--abbrev=0", "--tags")

    $LatestTag = git $Arguments

    Write-Verbose ("Latest tag found {0}" -f $LatestTag)

    $Arguments = @("log", "$($LatestTag)..HEAD", "--pretty=format:`"%h`"")

    $Commits = git @Arguments

    Write-Verbose ("Following commits retrieved since latest tag {0}" -f $LatestTag )

    $Commits | Write-Verbose

    if (-Not $Commits)
    {
        Write-Verbose ("No Commits found since latest Tag" `
            -f $LatestTag)

        exit
    }

    $Arguments = @("diff", "$($LatestTag)..HEAD", "--name-only")

    $FileChanges = git @Arguments

    Write-Verbose ("Following file changes detected after commit at latest tag {0}" -f $LatestTag)

    $FileChanges | Write-Verbose

    foreach ($FileChange in $FileChanges)
    {
        if ($FileChange -match "Riki")
        {
            if (($FileChange | Convert-Path).Contains($ModulePath.ToString()))
            {
                return $True
            }
        }
    }

    return $False
}

function Update-Version
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$CurrentVersion,

        [Parameter(Mandatory = $False)]
        [switch]$Major,

        [Parameter(Mandatory = $False)]
        [switch]$Minor
    )

    $SemVersion = $CurrentVersion.split('.')

    $CurrentMajor = $SemVersion[0]

    $CurrentMinor = $SemVersion[1]

    $CurrentPatch = $SemVersion[2]

    $NewPatch = (($CurrentPatch -as [int]) + 1).Tostring()

    $NewVersion = "{0}.{1}.{2}" -f $CurrentMajor, $CurrentMinor, $NewPatch

    if ($Major)
    {
        $NewMajor = (($CurrentMajor -as [int]) + 1).Tostring()

        $NewVersion = ("{0}.0.0" -f $NewMajor)
    }

    if ($Minor -and (-not $Major))
    {
        $NewMinor = (($CurrentMinor -as [int]) + 1).Tostring()

        $NewVersion = "{0}.{1}.0" -f $CurrentMajor, $NewMinor
    }

    return $NewVersion
}

function Update-ModuleVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [String]$ModuleName,

        [Parameter(Mandatory = $True)]
        [String]$ModulePath,

        [Parameter(Mandatory = $True)]
        [switch]$Major,

        [Parameter(Mandatory = $True)]
        [switch]$Minor
    )

    $ModuleManifest = Get-childItem `
        -Path $ModulePath | Where-Object { $_.Name -eq ("{0}.psd1" -f $ModuleName) }

    if (-not $ModuleManifest)
    {
        Write-Output ("Manifest module {0} does not exist" `
            -f $ModuleName)

        exit
    }

    $ManifestObject = Get-Content `
        -Path $ModuleManifest.FullName | Out-String | Invoke-Expression

    $NewVersion = Update-Version `
        -CurrentVersion $ManifestObject.ModuleVersion `
        -Major:$Major `
        -Minor:$Minor

    $ManifestObject.ModuleVersion = $NewVersion

    # Update version in module manifest
    Update-ModuleManifest `
        -Path $ModuleManifest.FullName @ManifestObject

    Write-Verbose ("{0} module version updated to {1}" `
        -f $ModuleName, $ManifestObject.ModuleVersion)

    # Update version in module manifest
    $ModuleNuspec = Get-childItem `
        -Path $ModulePath | Where-Object { $_.Name -eq ("{0}.nuspec" -f $ModuleName) }

    Add-Type -AssemblyName System.xml.linq

    $NuspecXml = [System.Xml.Linq.xDocument]::Load($ModuleNuspec.FullName)

    $NuspecXml.Element("package").Element("metadata").Element("version").value = $NewVersion

    $NuspecXml.save($ModuleNuspec.FullName)

    Write-Verbose ("{0} nuget package version updated to {1}" `
        -f $ModuleName, $NewVersion)
}

function Get-ModuleDependencies
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [String]$ModuleName,

        [Parameter(Mandatory = $True)]
        [String]$ModulePath
    )

    $ModuleNuspec = Get-childItem `
        -Path $ModulePath | Where-Object { $_.Name -eq ("{0}.nuspec" -f $ModuleName) }

    Add-Type -AssemblyName System.xml.linq

    $NuspecXml = [System.Xml.Linq.xDocument]::Load($ModuleNuspec.FullName)

    if ($NuspecXml.Element("package").Element("metadata").Element("dependencies"))
    {
        $Dependencies = $NuspecXml.Element("package").Element("metadata").Element("dependencies").Elements("dependency")

        return $Dependencies.attributes("id").Value
    }

    Write-Verbose ("No dependencies detected in module {0}" `
        -f $ModuleName)

    return
}

function New-BasicAuthToken
{
    [CmdletBinding()]
    param
    (
        # This Value is not mandatory, keeping the parameter as place holder
        [Parameter(Mandatory = $False)]
        [String]$UserName = "Pat",

        [Parameter(Mandatory = $True)]
        [String]$AuthToken
    )

    $Base64AuthToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $UserName, $AuthToken)));

    return ("Basic {0}" `
        -f $Base64AuthToken)
}

function Find-PublishedModules
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [String]$Repository,

        [Parameter(Mandatory = $False)]
        [String]$AdoFeedBaseUrl = "https://Riki.feeds.visualstudio.com",

        [Parameter(Mandatory = $True)]
        [String]$BasicAuthToken,

        [Parameter(Mandatory = $False)]
        [String]$ModuleName
    )

    $Url = ("{0}/_apis/Packaging/Feeds/{1}/Packages" `
        -f $AdoFeedBaseUrl, $Repository)

    try
    {
        $Response = Invoke-WebRequest `
            -Uri $Url `
            -Method GET `
            -Headers @{
                Authorization = $BasicAuthToken
            } `
            -ContentType "application/json"

        if ($ModuleName)
        {
            return ($Response | Convertfrom-json).Value | Where-Object { $_.Name -eq $ModuleName }
        }
        else
        {
            ($Response | Convertfrom-json).Value
        }
    }
    catch
    {
        throw $_
    }
}

function Get-NugetVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [String]$ModuleName,

        [Parameter(Mandatory = $True)]
        [String]$ModulePath
    )

    $ModuleNuspec = Get-childItem `
        -Path $ModulePath | Where-Object { $_.Name -eq ("{0}.nuspec" -f $ModuleName) }

    Add-Type -AssemblyName System.xml.linq

    $NuspecXml = [System.Xml.Linq.xDocument]::Load($ModuleNuspec.FullName)

    Return $NuspecXml.Element("package").Element("metadata").Element("version").value
}

function Import-AutomationModuleToBlob
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext]$StorageAccountContext,

        [Parameter(Mandatory = $True)]
        [String]$ContainerName,

        [Parameter(Mandatory = $True)]
        [String]$ModulePath,

        [Parameter(Mandatory = $True)]
        [String]$ModuleName
    )

    $StorageContainer = Get-AzStorageContainer `
        -Context $StorageAccountContext `
        -Name $ContainerName `
        -ErrorAction SilentlyContinue

    if (-not $StorageContainer)
    {
        Write-Verbose ("Blob container {0} not found storage account {1}, creating new one..." `
            -f $ContainerName, $StorageAccountContext.StorageAccountName)

        try
        {
            $StorageContainer =  New-AzStorageContainer `
                -Context $StorageAccountContext `
                -Name $ContainerName `
                -ErrorAction Stop

            Write-Verbose ("Blob container {0} created in storage account {1}" `
                -f $ContainerName, $StorageAccountContext.StorageAccountName)
        }
        catch
        {
            throw ("Error occured creating blob container {0} in storage account {1} `nError: `n{2} `n{3}" `
                -f $ContainerName, $StorageAccountContext.StorageAccountName, $_.Exception, $_.ScriptStackTrace)
        }
    }

    try
    {
        $ModuleBlob = Set-AzStorageBlobContent `
            -Context $StorageAccountContext `
            -Container $ContainerName `
            -Blob $ModuleName `
            -File $ModulePath `
            -Force `
            -ErrorAction Stop | Out-String

        Write-Verbose ("Module {0} imported to storage account {1} successfully`n{2}" `
            -f $ModuleName, $StorageAccountContext.StorageAccountName, $ModuleBlob)
    }
    catch
    {
        throw ("Error occured uploading {0} in storage account {1} `nError: `n{2} `n{3}" `
            -f $ModuleName, $StorageAccountContext.StorageAccountName, $_.Exception, $_.ScriptStackTrace)
    }
}

function Update-AutomationModule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True)]
        [String]$ModuleName,

        [Parameter(Mandatory=$True)]
        [String]$ModuleUri,

        [Parameter(Mandatory=$True)]
        [String]$ResourceGroupName,

        [Parameter(Mandatory=$True)]
        [String]$AutomationAccountName,

        [Parameter(Mandatory=$False)]
        [Switch]$Sync
    )

    $NewModule = New-AzAutomationModule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $ModuleName `
        -ContentLinkUri $ModuleUri

    if ($Sync)
    {
        $Imported = $False

        while (-not $Imported)
        {
            $ImportedModule = Get-AzAutomationModule `
                -ResourceGroupName $ResourceGroupName `
                -AutomationAccountName $AutomationAccountName `
                -Name $ModuleName

            if ($ImportedModule.ProvisioningState -eq "Succeeded")
            {
                Write-Verbose ("Module {0} import was successful" `
                    -f $ModuleName)

                $Imported = $True
            }
            elseif ($ImportedModule.ProvisioningState -eq "Failed")
            {
                Throw ("Module {0} import failed" `
                    -f $ModuleName)
            }
            else
            {
                Write-Verbose ("Module {0} import in progress, status: {1}" `
                    -f $ModuleName, $ImportedModule.ProvisioningState)

                Start-Sleep -Seconds 5
            }
        }
    }
    else
    {
        if ($NewModule.ProvisioningState -eq "Creating")
        {
            Write-Verbose "Module import request was successful, creating module.."
        }
        else
        {
            throw "Error occured installing module"
        }
    }
}
