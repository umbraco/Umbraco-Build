
  param (
    # run local - don't download, assume everything is ready
    [Parameter(Mandatory=$false)]
    [Alias("l")]
    [switch] $local = $false
  )

  Write-Host "Umbraco.Build Build"

  # ################################################################
  # BOOTSTRAP
  # ################################################################

  # ensure we have temp folder for downloads
  $scriptRoot = "$PSScriptRoot"
  $scriptTemp = "$scriptRoot\temp"
  if (-not (test-path $scriptTemp)) { mkdir $scriptTemp > $null }

  # get the buildsystem
  $ubuildPath = [System.IO.Path]::GetFullPath("$scriptRoot\..")

  # boot the buildsystem
  # this creates $global:ubuild
  &"$ubuildPath\ps\Boot.ps1"
  $ubuild.Boot($ubuildPath, $ubuildPath, `
    @{ Local = $local; With7Zip = $false; WithNode = $false }, `
    @{ IsUmbracoBuild = $true })
  if (-not $?) { throw "Failed to boot the build system." }
  Write-Host "Umbraco.Build v$($ubuild.BuildVersion)"

  # ################################################################
  # BUILD
  # ################################################################

  # configure
  $ubuild.ReleaseBranches = @( "master" )

  # build
  $buildConfiguration = "Release"
  $logfile = "$($ubuild.BuildTemp)\msbuild.umbraco-build.log"

  Write-Host "Compile"
  Write-Host "Logging to $logfile"

  try
  {
    $ubuild.SetBuildVersion()

    # beware of the weird double \\ at the end of paths
    # see http://edgylogic.com/blog/powershell-and-external-commands-done-right/
    &$ubuild.BuildEnv.VisualStudio.MsBuild "$($ubuild.SolutionRoot)\src\Umbraco.Build\Umbraco.Build.csproj" `
      /p:WarningLevel=0 `
      /p:Configuration=$buildConfiguration `
      /p:Platform=AnyCPU `
      /p:PipelineDependsOnBuild=False `
      /p:Verbosity=minimal `
      /t:Clean`;Rebuild `
      /tv:"$($ubuild.BuildEnv.VisualStudio.ToolsVersion)" `
      /p:UmbracoBuild=True `
      > $logfile

    if (-not $?) { throw "Failed to compile." }
  }
  finally
  {
    $ubuild.ClearBuildVersion()
  }

  # package nuget
  Write-Host "Pack"
  &$ubuild.BuildEnv.NuGet Pack "$($ubuild.SolutionRoot)\build\nuspec\Umbraco.Build.nuspec" `
    -Properties Solution="$($ubuild.SolutionRoot)" `
    -Version $ubuild.Version.Semver.ToString() `
    -Verbosity quiet -outputDirectory "$($ubuild.BuildOutput)"

  if (-not $?) { throw "Failed to pack NuGet." }

  # run hook
  if ($ubuild.HasMethod("PostPackageNuGet"))
  {
    Write-Host "Run PostPackageNuGet hook"
    $ubuild.PostPackageNuGet()
    if (-not $?) { throw "Failed to run hook." }
  }

  # done
  Write-Host "Done"