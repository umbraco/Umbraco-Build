
# register global $ubuild
$global:ubuild = @{ }

# register Initialize
$global:ubuild | Add-Member -MemberType ScriptMethod Boot -value `
{
  param (
    [Parameter(Mandatory=$true)]
    [string] $ubuildPath,

    [Parameter(Mandatory=$true)]
    [string] $solutionRoot,

    [Parameter(Mandatory=$false)]
    $uenvOptions,

    [Parameter(Mandatory=$false)]
    [switch] $isUmbracoBuild
  )

  if ($isUmbracoBuild)
  {
    $this.BuildPath = $ubuildPath
  }
  else
  {
    $this.BuildPath = $ubuildPath
    $this.BuildVersion = [System.IO.Path]::GetFileName($ubuildPath).Substring("Umbraco.Build.".Length)

    # load the lib
    Add-Type -Path "$($this.BuildPath)\lib\Umbraco.Build.dll"
    if (-not $?) { Write-Host "Abort" ; break }
  }

  # source the scripts
  &"$($this.BuildPath)\ps\GetUmbracoBuildEnv.ps1"
  if (-not $?) { Write-Host "Abort" ; break }
  &"$($this.BuildPath)\ps\GetUmbracoVersion.ps1"
  if (-not $?) { Write-Host "Abort" ; break }
  &"$($this.BuildPath)\ps\SetUmbracoVersion.ps1"
  if (-not $?) { Write-Host "Abort" ; break }
  &"$($this.BuildPath)\ps\SetClearBuildVersion.ps1"
  if (-not $?) { Write-Host "Abort" ; break }
  &"$($this.BuildPath)\ps\VerifyNuGet.ps1"
  if (-not $?) { Write-Host "Abort" ; break }
  &"$($this.BuildPath)\ps\Utilities.ps1"
  if (-not $?) { Write-Host "Abort" ; break }

  # ensure we have empty build.tmp and build.out folders
  $buildTemp = "$solutionRoot\build.tmp"
  $buildOutput = "$solutionRoot\build.out"
  if (test-path $buildTemp) { remove-item $buildTemp -force -recurse -errorAction SilentlyContinue > $null }
  if (test-path $buildOutput) { remove-item $buildOutput -force -recurse -errorAction SilentlyContinue > $null }
  mkdir $buildTemp > $null
  mkdir $buildOutput > $null

  $this.BuildTemp = $buildTemp
  $this.BuildOutput = $buildOutput
  $this.SolutionRoot = $solutionRoot
  $this.BuildNumber = $env:BUILD_NUMBER

  # initialize the build environment
  $this.BuildEnv = $this.GetUmbracoBuildEnv($uenvOptions, $scriptTemp)
  if (-not $?) { Write-Host "Abort" ; break }

  # initialize the version
  $this.Version = $this.GetUmbracoVersion()
  if (-not $?) { Write-Host "Abort" ; break }

  # source the hools
  $hooks = $this.GetFullPath("$solutionRoot\build\hooks")
  if ([System.IO.Directory]::Exists($hooks))
  {
    ls "$hooks\*.ps1" | ForEach-Object {
      &"$_"
    }
  }
}