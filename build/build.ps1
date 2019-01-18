
  param (
    # run local, don't download, assume everything is ready
    [Parameter(Mandatory=$false)]
    [Alias("l")]
    [Alias("loc")]
    [switch] $local = $false
  )

  # ################################################################
  # BOOTSTRAP
  # ################################################################

  # create and boot the buildsystem
  $error.Clear()
  $ubuild = &"$PSScriptRoot\..\ps\Boot.ps1"
  $ubuild.Boot($PSScriptRoot,
    @{ Local = $local; With7Zip = $false; WithNode = $false },
    @{ IsUmbracoBuild = $true })
  if ($ubuild.OnError()) { return }

  Write-Host "Umbraco.Build Build"
  Write-Host "Umbraco.Build v$($ubuild.BuildVersion)"

  # ################################################################
  # BUILD
  # ################################################################

  # configure
  $ubuild.ReleaseBranches = @( "master" )

  # build
  $buildConfiguration = "Release"
  $logfile = "$($ubuild.BuildTemp)\msbuild.umbraco-build.log"

  # restore NuGet
  Write-Host "Restore NuGet"
  Write-Host "Logging to $($ubuild.BuildTemp)\nuget.restore.log"
  &$ubuild.BuildEnv.NuGet restore "$($ubuild.SolutionRoot)\src\Umbraco.Build.sln" > "$($ubuild.BuildTemp)\nuget.restore.log"
  if (-not $?) { throw "Failed to restore NuGet packages." }

  try
  {
    $ubuild.SetBuildVersion()
    if ($ubuild.OnError()) { return }

    # beware of the weird double \\ at the end of paths
    # see http://edgylogic.com/blog/powershell-and-external-commands-done-right/
    Write-Host "Compile"
    Write-Host "Logging to $logfile"
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
  if ($ubuild.OnError()) { return }

  # package nuget
  Write-Host "Pack"
  &$ubuild.BuildEnv.NuGet Pack "$($ubuild.SolutionRoot)\build\nuspec\Umbraco.Build.nuspec" `
    -Properties Solution="$($ubuild.SolutionRoot)" `
    -Version $ubuild.Version.Semver.ToString() `
    -Verbosity detailed -outputDirectory "$($ubuild.BuildOutput)" > "$($ubuild.BuildTemp)\nupack.log"

  if (-not $?) { throw "Failed to pack NuGet." }

  # run hook
  if ($ubuild.HasMethod("PostPackageNuGet"))
  {
    Write-Host "Run PostPackageNuGet hook"
    $ubuild.PostPackageNuGet()
    if ($ubuild.OnError()) { return }
  }

  # done
  Write-Host "Done"