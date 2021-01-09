Param(
    [switch] $Release,
    [string] $SigningCertThumbprint,
    [string] $TimestampServer
)

$ErrorActionPreference = 'Stop'

# Options
$configuration = 'Release'
$artifactsDir = Join-Path (Resolve-Path .) 'artifacts'
$packagesDir = Join-Path $artifactsDir 'Packages'

# Detection
. $PSScriptRoot\build\Get-DetectedCiVersion.ps1
$versionInfo = Get-DetectedCiVersion -Release:$Release
Update-CiServerBuildName $versionInfo.ProductVersion
Write-Host "Building using version $($versionInfo.ProductVersion)"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$visualStudioInstallation = & $vswhere -latest -version [16,] -requires Microsoft.Component.MSBuild -products * -property installationPath
if (!$visualStudioInstallation) { throw 'Cannot find installation of Visual Studio 2019 or newer.' }
$msbuild = Join-Path $visualStudioInstallation 'MSBuild\Current\Bin\MSBuild.exe'

$msbuildArgs = @(
    '/p:PackageOutputPath=' + $packagesDir
    '/p:RepositoryCommit=' + $versionInfo.CommitHash
    '/p:Version=' + $versionInfo.ProductVersion
    '/p:PackageVersion=' + $versionInfo.PackageVersion
    '/p:FileVersion=' + $versionInfo.FileVersion
    '/p:Configuration=' + $configuration
    '/v:minimal'
)

# Build
& $msbuild /t:build /restore @msbuildArgs
if ($LastExitCode) { exit 1 }

if ($SigningCertThumbprint) {
    . build\SignTool.ps1
    SignTool $SigningCertThumbprint $TimestampServer (
        Get-ChildItem src\Techsola.InstantReplay\bin\$configuration -Recurse -Include Techsola.InstantReplay.dll)
}

# Pack
Remove-Item -Recurse -Force $packagesDir -ErrorAction Ignore

& $msbuild src\Techsola.InstantReplay /t:pack /p:NoBuild=true @msbuildArgs
if ($LastExitCode) { exit 1 }

if ($SigningCertThumbprint) {
    # Waiting for 'dotnet sign' to become available (https://github.com/NuGet/Home/issues/7939)
    $nuget = 'tools\nuget.exe'
    if (-not (Test-Path $nuget)) {
        New-Item -ItemType Directory -Force -Path tools
        Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile $nuget
    }

     # Workaround for https://github.com/NuGet/Home/issues/10446
    foreach ($extension in 'nupkg', 'snupkg') {
        & $nuget sign $packagesDir\*.$extension -CertificateFingerprint $SigningCertThumbprint -Timestamper $TimestampServer
    }
}
