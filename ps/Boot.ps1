
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

    # .IsUmbracoBuild
    #     indicates whether we are building Umbraco.Build
    #     as .BuildPath and .BuildVersion are obviously different
    # .Keep
    #     do not clear the tmp and out directories
    [Parameter(Mandatory=$false)]
    $switches
  )

  if ($switches)
  {
    $isUmbracoBuild = $switches.IsUmbracoBuild
    $keepBuildDirs = $switches.KeepBuildDirs
  }

  if ($isUmbracoBuild)
  {
    $this.BuildPath = $ubuildPath
    $this.BuildVersion = "? (building)"
  }
  else
  {
    $this.BuildPath = $ubuildPath
    $this.BuildVersion = [System.IO.Path]::GetFileName($ubuildPath).Substring("Umbraco.Build.".Length)

    # load the lib
    Add-Type -Path "$($this.BuildPath)\lib\Umbraco.Build.dll"
    if (-not $?) { throw "Failed to load Umbraco.Build.dll." }
  }

  $scripts = (
    "GetUmbracoBuildEnv",
    "GetUmbracoVersion",
    "SetUmbracoVersion",
    "SetClearBuildVersion",
    "VerifyNuGet",
    "Utilities"
  )

  # source the scripts
  foreach ($script in $scripts) {
    &"$($this.BuildPath)\ps\$script.ps1"
    if (-not $?) { throw "Failed to source $script.ps1" }
  }

  # ensure we have empty build.tmp and build.out folders
  $buildTemp = "$solutionRoot\build.tmp"
  $buildOutput = "$solutionRoot\build.out"
  if ($keepBuildDirs)
  {
    if (-not (test-path $buildTemp)) { mkdir $buildTemp > $null }
    if (-not (test-path $buildOutput)) { mkdir $buildOutput > $null }
  }
  else
  {
    if (test-path $buildTemp) { remove-item $buildTemp -force -recurse -errorAction SilentlyContinue > $null }
    if (test-path $buildOutput) { remove-item $buildOutput -force -recurse -errorAction SilentlyContinue > $null }
    mkdir $buildTemp > $null
    mkdir $buildOutput > $null
  }

  $this.BuildTemp = $buildTemp
  $this.BuildOutput = $buildOutput
  $this.SolutionRoot = $solutionRoot
  $this.BuildNumber = $env:BUILD_BUILDNUMBER

  # initialize the build environment
  $this.BuildEnv = $this.GetUmbracoBuildEnv($uenvOptions, $scriptTemp)
  if (-not $?) { throw "Failed to get a build environment." }

  # initialize the version
  $this.Version = $this.GetUmbracoVersion()
  if (-not $?) { throw "Failed to get Umbraco version." }

  # source the hooks
  $hooks = $this.GetFullPath("$solutionRoot\build\hooks")
  if ([System.IO.Directory]::Exists($hooks))
  {
    ls "$hooks\*.ps1" | ForEach-Object {
      &"$_"
    }
  }
}