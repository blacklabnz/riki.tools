<#
.SYNOPSIS
    Sign a JWT (JSON Web Token).
.DESCRIPTION
    Creates signed JWT given a signing certificate and claims in JSON.
.NOTES
    This function takes signing certificates and the payload to sign as parameters.
    Once signature is signed it will attach it to header and payload data to form the Jwt token
    General format of Jwt Token: {Header}.{Payload}.{Signature}
    Sample Payload:
    {
        "iss":  "test-530@testprojneil.iam.gserviceaccount.com",
        "scope":  "https://www.googleapis.com/auth/spreadsheets",
        "aud":  "https://www.googleapis.com/oauth2/v4/token",
        "exp":  1567562215.186064,
        "iat":  1567558675.186064
    }
.EXAMPLE
    New-RikiJwt `
        -PayloadJson $JwtpayloadJson `
        -Cert $SigningCert
    Note: exp and iat epoch time stamp needs to be generated on the fly.
    Singing cert can be import using this line of code:
    $CertObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$Path\*.pfx", 'PasswordofPfx',[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
#>
function New-RikiJwt
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Header = '{"alg":"RS256","typ":"JWT"}',

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string]$PayloadJson,

        [Parameter(Mandatory=$true)]
		[System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningCert
    )

    Write-Verbose ("Payload to sign: {0}" `
        -f $PayloadJson)

    Write-Verbose ("Signing certificate: {0}" `
        -f $SigningCert.Subject)

    # Validating that the parameter is actually JSON - if not, generate breaking error
    try
    {
        $PayloadJson | ConvertFrom-Json `
            -ErrorAction Stop | Out-Null
    }
    catch
    {
        throw ("The supplied JWT payload is not JSON: {0}" `
            -f $payloadJson)
    }

    $EncodedHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Header)) `
        -replace '\+','-' `
        -replace '/','_' `
        -replace '='

    $EncodedPayload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($PayloadJson)) `
        -replace '\+','-' `
        -replace '/','_' `
        -replace '='

    # JWT header and the payload
    $Jwt = ("{0}.{1}" `
        -f $EncodedHeader, $EncodedPayload )

    $Rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider

    # Requiring the private key to be present; else cannot sign!
    if (-not $SigningCert.Privatekey)
    {
        throw ("Private key not found in certificate with Thumbprint:{0}, cannot sign jwt" `
            -f $SigningCert.Thumbprint)
    }
    else
    {
        $Rsa.ImportParameters($SigningCert.Privatekey.ExportParameters($true))

        try
        {
            $Signature = [Convert]::ToBase64String($Rsa.SignData([System.Text.Encoding]::UTF8.GetBytes($Jwt), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) `
                -replace '\+','-' `
                -replace '/','_' `
                -replace '='
        }
        catch
        {
            throw ("Signing with SHA256 and Pkcs1 padding failed using private key in certificat with Thumbprint {0}" `
                -f $SigningCert.Thumbprint)
        }
    }

    $JwtToken = ("{0}.{1}" `
        -f $Jwt, $Signature)

    return $JwtToken
}

Export-ModuleMember `
    -Function New-RikiJwt