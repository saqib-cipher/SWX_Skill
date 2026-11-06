<#
.SYNOPSIS
    Sketchware & DayGreen SWB Archive Creation and Extraction Tool
.DESCRIPTION
    Packs a Sketchware project into a standard encrypted .swb (ZIP) backup archive,
    or unpacks an .swb archive for inspection and restoration.
.PARAMETER Action
    "pack" to create .swb, "unpack" to extract .swb
.PARAMETER ScId
    Project ID (e.g. 601) when packing from standard .sketchware directory
.PARAMETER SwbPath
    Path to the .swb file (output for pack, input for unpack)
.PARAMETER WorkspaceRoot
    Path to .sketchware root directory (defaults to current dir or environment)
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("pack", "unpack")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$ScId,

    [Parameter(Mandatory = $true)]
    [string]$SwbPath,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputDir
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$KeyBytes = $Utf8NoBom.GetBytes("sketchwaresecure")

function Encrypt-SketchwareData([byte[]]$bytes) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 128
    $aes.BlockSize = 128
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key = $KeyBytes
    $aes.IV = $KeyBytes
    $enc = $aes.CreateEncryptor()
    return $enc.TransformFinalBlock($bytes, 0, $bytes.Length)
}

function Decrypt-SketchwareData([byte[]]$bytes) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 128
    $aes.BlockSize = 128
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key = $KeyBytes
    $aes.IV = $KeyBytes
    $dec = $aes.CreateDecryptor()
    return $dec.TransformFinalBlock($bytes, 0, $bytes.Length)
}

if ($Action -eq "pack") {
    if (-not $ScId -and -not (Test-Path $WorkspaceRoot)) {
        Write-Error "Either -ScId or valid -WorkspaceRoot must be provided to pack an SWB archive."
        exit 1
    }

    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("swb_pack_" + [System.Guid]::NewGuid().ToString("N"))
    [System.IO.Directory]::CreateDirectory($TempDir) | Out-Null

    try {
        $DataSrc = if ($WorkspaceRoot) { Join-Path $WorkspaceRoot "data/$ScId" } else { "data/$ScId" }
        $MyscSrc = if ($WorkspaceRoot) { Join-Path $WorkspaceRoot "mysc/list/$ScId/project" } else { "mysc/list/$ScId/project" }
        $ResSrc  = if ($WorkspaceRoot) { Join-Path $WorkspaceRoot "resources" } else { "resources" }

        # 1. Project metadata at root
        $DestProj = Join-Path $TempDir "project"
        if (Test-Path $MyscSrc) {
            Copy-Item $MyscSrc $DestProj
        } elseif (Test-Path (Join-Path $DataSrc "project")) {
            Copy-Item (Join-Path $DataSrc "project") $DestProj
        } else {
            # Minimal project file
            $minJson = @{
                sc_id = if ($ScId) { $ScId } else { "601" }
                my_ws_name = "ExportedApp"
                my_app_name = "ExportedApp"
                my_sc_pkg_name = "com.exported.app"
                my_sc_ver_code = "1"
                my_sc_ver_name = "1.0"
                proj_type = 1
            } | ConvertTo-Json -Compress
            $encBytes = Encrypt-SketchwareData ($Utf8NoBom.GetBytes($minJson))
            [System.IO.File]::WriteAllBytes($DestProj, $encBytes)
        }

        # 2. Copy data directory
        $DestData = Join-Path $TempDir "data"
        if (Test-Path $DataSrc) {
            Copy-Item $DataSrc $DestData -Recurse -Force
        } else {
            [System.IO.Directory]::CreateDirectory($DestData) | Out-Null
        }

        # 3. Copy project resources if available
        $DestRes = Join-Path $TempDir "resources"
        [System.IO.Directory]::CreateDirectory($DestRes) | Out-Null
        foreach ($sub in @("images", "sounds", "fonts", "icons")) {
            $subPath = Join-Path $DestRes $sub
            [System.IO.Directory]::CreateDirectory($subPath) | Out-Null
            $srcSub = Join-Path $ResSrc "$sub/$ScId"
            if (Test-Path $srcSub) {
                Copy-Item "$srcSub/*" $subPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            if ($sub -ne "icons") {
                [System.IO.File]::WriteAllBytes((Join-Path $subPath ".nomedia"), @())
            }
        }

        # 4. Create ZIP (.swb)
        if (Test-Path $SwbPath) {
            Remove-Item $SwbPath -Force
        }
        $parent = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($SwbPath))
        if (-not (Test-Path $parent)) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }

        [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $SwbPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        Write-Host "Successfully packed SWB archive: $SwbPath"
    } finally {
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} elseif ($Action -eq "unpack") {
    if (-not (Test-Path $SwbPath)) {
        Write-Error "SWB file does not exist: $SwbPath"
        exit 1
    }

    $TargetDir = if ($OutputDir) { $OutputDir } else {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($SwbPath)
        Join-Path ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($SwbPath))) ($base + "_unpacked")
    }

    if (-not (Test-Path $TargetDir)) {
        [System.IO.Directory]::CreateDirectory($TargetDir) | Out-Null
    }

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($SwbPath, $TargetDir)
    } catch {
        # Fallback if overwrite is needed
        $archive = [System.IO.Compression.ZipFile]::OpenRead($SwbPath)
        foreach ($entry in $archive.Entries) {
            $destPath = [System.IO.Path]::Combine($TargetDir, $entry.FullName)
            $destDir = [System.IO.Path]::GetDirectoryName($destPath)
            if (-not [string]::IsNullOrEmpty($destDir) -and -not (Test-Path $destDir)) {
                [System.IO.Directory]::CreateDirectory($destDir) | Out-Null
            }
            if (-not [string]::IsNullOrEmpty($entry.Name)) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
            }
        }
        $archive.Dispose()
    }
    Write-Host "Successfully extracted SWB archive to: $TargetDir"

    # Quick inspection of project metadata
    $projFile = Join-Path $TargetDir "project"
    if (Test-Path $projFile) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($projFile)
            $decrypted = Decrypt-SketchwareData $bytes
            $json = $Utf8NoBom.GetString($decrypted)
            Write-Host "`nProject Metadata:"
            Write-Host $json
        } catch {
            Write-Warning "Could not decrypt project metadata: $_"
        }
    }
}
