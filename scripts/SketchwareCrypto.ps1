<#
.SYNOPSIS
    Sketchware & DayGreen AES-128-CBC Project File Encryptor / Decryptor
.DESCRIPTION
    Decrypts or encrypts Sketchware core project data files (project, file, logic, view, resource, library)
    using AES-128-CBC with key/IV "sketchwaresecure".
.PARAMETER Action
    "decrypt" or "encrypt"
.PARAMETER InputPath
    Path to the source file
.PARAMETER OutputPath
    Path to write the result
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("decrypt", "encrypt")]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$KeyString = "sketchwaresecure"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$KeyBytes = $Utf8NoBom.GetBytes($KeyString)

$Aes = [System.Security.Cryptography.Aes]::Create()
$Aes.KeySize = 128
$Aes.BlockSize = 128
$Aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
$Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$Aes.Key = $KeyBytes
$Aes.IV = $KeyBytes

if (-not (Test-Path $InputPath)) {
    Write-Error "Input file does not exist: $InputPath"
    exit 1
}

if ($Action -eq "decrypt") {
    $EncryptedBytes = [System.IO.File]::ReadAllBytes($InputPath)
    if ($EncryptedBytes.Length -eq 0) {
        Write-Output ""
        exit 0
    }

    try {
        $Decryptor = $Aes.CreateDecryptor()
        $DecryptedBytes = $Decryptor.TransformFinalBlock($EncryptedBytes, 0, $EncryptedBytes.Length)

        if ($OutputPath) {
            [System.IO.File]::WriteAllBytes($OutputPath, $DecryptedBytes)
            Write-Host "Successfully decrypted '$InputPath' to '$OutputPath'"
        } else {
            $DecryptedText = $Utf8NoBom.GetString($DecryptedBytes)
            Write-Output $DecryptedText
        }
    } catch {
        # Check if already plaintext
        try {
            $PlainBytes = [System.IO.File]::ReadAllBytes($InputPath)
            $PlainText = $Utf8NoBom.GetString($PlainBytes)
            if ($PlainText.Trim().StartsWith("{") -or $PlainText.Trim().StartsWith("[") -or $PlainText.Trim().StartsWith("@")) {
                Write-Host "File appears to already be plaintext."
                if ($OutputPath) {
                    [System.IO.File]::WriteAllBytes($OutputPath, $PlainBytes)
                } else {
                    Write-Output $PlainText
                }
                exit 0
            }
        } catch {}
        Write-Error "Decryption failed: $_"
        exit 1
    }
} elseif ($Action -eq "encrypt") {
    $PlainBytes = [System.IO.File]::ReadAllBytes($InputPath)

    try {
        $Encryptor = $Aes.CreateEncryptor()
        $EncryptedBytes = $Encryptor.TransformFinalBlock($PlainBytes, 0, $PlainBytes.Length)

        $Target = if ($OutputPath) { $OutputPath } else { $InputPath }
        [System.IO.File]::WriteAllBytes($Target, $EncryptedBytes)
        Write-Host "Successfully encrypted '$InputPath' to '$Target'"
    } catch {
        Write-Error "Encryption failed: $_"
        exit 1
    }
}
