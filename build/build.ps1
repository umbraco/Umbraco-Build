
  param (
    # run local - don't download, assume everything is ready
    [Parameter(Mandatory=$false)]
    [switch] $local = $false
  )

  Write-Host "Umbraco.Build Build"

  # ################################################################
  # BOOTSTRAP
  # ################################################################

  $scriptRoot = "$PSScriptRoot"
  $solutionRoot = [System.IO.Path]::GetFullPath("$scriptRoot\..")

  # ensure we have empty build.tmp and build.out folders
  $buildTemp = "$solutionRoot\build.tmp"
  $buildOutput = "$solutionRoot\build.out"
  if (test-path $buildTemp) { remove-item $buildTemp -force -recurse -errorAction SilentlyContinue > $null }
  if (test-path $buildOutput) { remove-item $buildOutput -force -recurse -errorAction SilentlyContinue > $null }
  mkdir $buildTemp > $null
  mkdir $buildOutput > $null

  # ensure we have temp folder for downloaded tools
  $scriptTemp = "$scriptRoot\temp"
  if (-not (test-path $scriptTemp)) { mkdir $scriptTemp > $null }

  # cache downloads for 4 days
  $cache = 4

  # ensure we have NuGet
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

  # ################################################################
  # GET THE BUILD SYSTEM
  # ################################################################

  $ubuild = "$scriptRoot\.."

  # source build system scripts
  . "$ubuild\ps\Utilities.ps1"
  . "$ubuild\ps\Get-VisualStudio.ps1"
  . "$ubuild\ps\Get-UmbracoBuildEnv.ps1"
  . "$ubuild\ps\Set-UmbracoVersion.ps1"
  . "$ubuild\ps\Get-UmbracoVersion.ps1"
  . "$ubuild\ps\SetClear-GitVersion.ps1"

  # ################################################################
  # BUILD
  # ################################################################

  $uenv = Get-UmbracoBuildEnv -no7zip -noNode -local:$local
  if (-not $?) { Write-Host "Abort" ; break }
  $uversion = Get-UmbracoVersion
  if (-not $?) { Write-Host "Abort" ; break }

  # build
  $buildConfiguration = "Release"
  $toolsVersion = "4.0"
  if ($uenv.VisualStudio.Major -eq 15) { $toolsVersion = "15.0" }
  $logfile = "$buildTemp\msbuild.umbraco-build.log"

  Write-Host "Compile"
  Write-Host "Logging to $logfile"

  try
  {
    Set-GitVersion

    # beware of the weird double \\ at the end of paths
    # see http://edgylogic.com/blog/powershell-and-external-commands-done-right/
    &$uenv.VisualStudio.MsBuild "$solutionRoot\src\Umbraco.Build\Umbraco.Build.csproj" `
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
    Clear-GitVersion
  }

  # package nuget
  Write-Host "Pack"
  &$uenv.NuGet Pack "$solutionRoot\build\nuspec\Umbraco.Build.nuspec" `
    -Properties Solution="$solutionRoot" `
    -Version $uversion.Semver.ToString() `
    -Verbosity quiet -outputDirectory $buildOutput

  if (-not $?) { Write-Host "Abort" ; break }

  # run hook
  $hook = "$solutionRoot\build\hooks\Post-Package-NuGet.ps1"
  if (Test-Path -Path $hook)
  {
    Write-Host "Run Post-Package-NuGet hook"
    . "$hook" # define Post-Package-Nuget
    Post-Package-NuGet $uenv $uversion
    if (-not $?) { Write-Host "Abort" ; break }
  }

  # done
  Write-Host "Done"