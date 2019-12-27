<#
.SYNOPSIS
    Function to generate google access token
.DESCRIPTION
    This function uses a signed jwt token to request google access token
.NOTES
    The function can be disected in the following steps:
    1. generate a signed Jwt token

    Sample Jwt payload:
    {
        "iss":  "test-530@testprojneil.iam.gserviceaccount.com",
        "scope":  "https://www.googleapis.com/auth/spreadsheets",
        "aud":  "https://www.googleapis.com/oauth2/v4/token",
        "exp":  1567552971.6133082,
        "iat":  1567549431.6133082
    }
    note: exp and iat epoch time stamp needs to be generate on the fly
    The New-RikiJwt will use the singed Jwt as part of the paylaod to request a access tokne to google api.

    2. Request access token
    The request needs a payload with type of 'application/x-www-form-urlencoded' enclosing the signed Jwt token.
    Sample payload:
    $RequestBody = @{
            grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
            assertion = $SingedJwt
    }
.EXAMPLE
    New-GoogleAccessToken `
        -GoogleServiceAccountName "test-530@testprojneil.iam.gserviceaccount.com" `
        -Scope "https://www.googleapis.com/auth/spreadsheets" `
        -SigningCert $CertObject
    note:
    To get the Signing cert you need to generate and downlaod the private key of the service account in Google api console.
    Once the *.key file is downlaoded, a cert file needs to be generated using the private key.
    Then a *.pfx file needs be generated bundling the *.crt and *.key file.
    Reason being pfx is need to sign the Jwt in this context.
    Use this line of code to create the certificate object:
    $CertObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$Path\*.pfx", 'PasswordofPfx',[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
#>

function New-GoogleAccessToken
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$True)]
        [string]$GoogleServiceAccountName,

        [Parameter(Mandatory=$True)]
        [string]$Scope,

        [Parameter(Mandatory=$False)]
        [string]$GoogleOAuthEndpoint = 'https://www.googleapis.com/oauth2/v4/token',

        [Parameter(Mandatory=$True)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningCert
    )

    $Iat = (New-TimeSpan `
        -Start (Get-Date "01/01/1970") `
        -End (Get-Date).ToUniversalTime()).TotalSeconds

    $Exp = $Iat + (New-TimeSpan `
        -Minutes 59).TotalSeconds

    $JwtpayloadJson = [Ordered]@{
        iss = $GoogleServiceAccountName
        scope = $Scope
        aud = $GoogleOAuthEndpoint
        exp = $Exp
        iat = $Iat
    } | ConvertTo-Json

    $SingedJwt = New-RikiJwt `
        -PayloadJson $JwtpayloadJson `
        -SigningCert $SigningCert

    $RequestBody = @{
        grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
        assertion = $SingedJwt
    }

    try
    {
        $AccessToken = ((Invoke-WebRequest `
            -Uri $GoogleOAuthEndpoint `
            -Method Post `
            -Body $RequestBody `
            -ContentType 'application/x-www-form-urlencoded' `
            -UseBasicParsing).content | ConvertFrom-Json).Access_Token
    }
    catch
    {
        throw $_
    }

    return $AccessToken
}