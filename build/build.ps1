
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

  # ensure we have temp folder for downloaded tools
  $scriptRoot = "$PSScriptRoot"
  $scriptTemp = "$scriptRoot\temp"
  if (-not (test-path $scriptTemp)) { mkdir $scriptTemp > $null }

  # get NuGet
  $cache = 4
  $nuget = "$scriptTemp\nuget.exe"
  if (-not $local)
  {
    $source = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    if ((test-path $nuget) -and ((ls $nuget).CreationTime -lt [DateTime]::Now.AddDays(-$cache)))
    {
      Remove-File $nuget
    }
    if (-not (test-path $nuget))
    {
      Write-Host "Download NuGet..."
      Invoke-WebRequest $source -OutFile $nuget
      if (-not $?) { Write-Host "Abort" ; break }
    }
  }
  elseif (-not (test-path $nuget))
  {
    Write-Host "Failed to locate NuGet.exe"
    break
  }

  # get the buildsystem
  $ubuildPath = [System.IO.Path]::GetFullPath("$scriptRoot\..")

  # boot the buildsystem
  . "$ubuildPath\ps\Boot.ps1"
  $ubuild.Boot($ubuildPath, $ubuildPath, @{ Local = $local; With7Zip = $false; WithNode = $false }, $true)
  if (-not $?) { Write-Host "Abort" ; break }

  # ################################################################
  # BUILD
  # ################################################################

  # build
  $buildConfiguration = "Release"
  $toolsVersion = "4.0"
  if ($ubuild.BuildEnv.VisualStudio.Major -eq 15) { $toolsVersion = "15.0" }
  $logfile = "$($ubuild.BuildTemp)\msbuild.umbraco-build.log"

  Write-Host "Compile"
  Write-Host "Logging to $logfile"

  try
  {
    $ubuild.SetGitVersion()

    # beware of the weird double \\ at the end of paths
    # see http://edgylogic.com/blog/powershell-and-external-commands-done-right/
    &$ubuild.BuildEnv.VisualStudio.MsBuild "$($ubuild.SolutionRoot)\src\Umbraco.Build\Umbraco.Build.csproj" `
      /p:WarningLevel=0 `
      /p:Configuration=$buildConfiguration `
      /p:Platform=AnyCPU `
      /p:PipelineDependsOnBuild=False `
      /p:Verbosity=minimal `
      /t:Clean`;Rebuild `
      /tv:$toolsVersion `
      /p:UmbracoBuild=True `
      > $logfile

    if (-not $?) { Write-Host "Abort" ; break }
  }
  finally
  {
    $ubuild.ClearGitVersion()
  }

  # package nuget
  Write-Host "Pack"
  &$ubuild.BuildEnv.NuGet Pack "$($ubuild.SolutionRoot)\build\nuspec\Umbraco.Build.nuspec" `
    -Properties Solution="$($ubuild.SolutionRoot)" `
    -Version $ubuild.Version.Semver.ToString() `
    -Verbosity quiet -outputDirectory "$($ubuild.BuildOutput)"

  if (-not $?) { Write-Host "Abort" ; break }

  # run hook
  $hook = "$($ubuild.SolutionRoot)\build\hooks\Post-Package-NuGet.ps1"
  if (Test-Path -Path $hook)
  {
    Write-Host "Run Post-Package-NuGet hook"
    . "$hook" # define Post-Package-Nuget
    Post-Package-NuGet
    if (-not $?) { Write-Host "Abort" ; break }
  }

  # done
  Write-Host "Done"