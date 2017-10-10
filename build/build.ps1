
  Write-Host "Umbraco.Build Build"

  # ################################################################
  # FIRST we need a minimal build system
  # ################################################################

  $scriptRoot = "$PSScriptRoot"

  $cache = 2
  $solutionRoot = [System.IO.Path]::GetFullPath("$scriptRoot\..")

  # create empty build.tmp and build.out
  $tmp = "$solutionRoot\build.tmp"
  $out = "$solutionRoot\build.out"
  if (test-path $tmp) { remove-item $tmp -force -recurse -errorAction SilentlyContinue > $null }
  if (test-path $out) { remove-item $out -force -recurse -errorAction SilentlyContinue > $null }
  mkdir $tmp > $null
  mkdir $out > $null

  # ensure we have temp folder for downloaded tools
  $scriptTemp = "$scriptRoot\temp"
  if (-not (test-path $scriptTemp)) { mkdir $scriptTemp > $null }

  # ensure we have NuGet
  $nuget = "$scriptTemp\nuget.exe"
  $source = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
  if ((test-path $nuget) -and ((ls $nuget).CreationTime -lt [DateTime]::Now.AddDays(-$cache)))
  {
    Remove-File $nuget
  }
  if (-not (test-path $nuget))
  {
    Write-Host "Download NuGet..."
    Invoke-WebRequest $source -OutFile $nuget
  }

  # ensure we have semver
  $semver = "$scriptTemp\Semver.dll"
  if ((test-path $semver) -and ((ls $semver).CreationTime -lt [DateTime]::Now.AddDays(-$cache)))
  {
    Remove-File $semver
  }
  if (-not (test-path $semver))
  {
    Write-Host "Download Semver..."
    &$nuget install semver -OutputDirectory $scriptTemp -Verbosity quiet
    $dir = ls "$scriptTemp\semver.*" | sort -property Name -descending | select -first 1
    $file = "$dir\lib\net452\Semver.dll"
    if (-not (test-path $file))
    {
      Write-Error "Failed to file $file"
      break
    }
    mv "$file" $semver
    Remove-Directory $dir
  }

  try
  {
    [Reflection.Assembly]::LoadFile($semver) > $null
  }
  catch
  {
    Write-Error -Exception $_.Exception -Message "Failed to load $semver"
    break
  }

  # ensure we have vswhere
  $vswhere = "$scriptTemp\vswhere.exe"
  if ((test-path $vswhere) -and ((ls $vswhere).CreationTime -lt [DateTime]::Now.AddDays(-$cache)))
  {
    Remove-File $vswhere
  }
  if (-not (test-path $vswhere))
  {
    Write-Host "Download VsWhere..."
    &$nuget install vswhere -OutputDirectory $scriptTemp -Verbosity quiet
    $dir = ls "$scriptTemp\vswhere.*" | sort -property Name -descending | select -first 1
    $file = ls -path "$dir" -name vswhere.exe -recurse
    mv "$dir\$file" $vswhere
    Remove-Directory $dir
  }

  # find visual studio
  # will not work on VSO but VSO does not need it
  $vsPath = ""
  $vsVer = ""
  $msBuild = $null
  &$vswhere | foreach {
    if ($_.StartsWith("installationPath:")) { $vsPath = $_.SubString("installationPath:".Length).Trim() }
    if ($_.StartsWith("installationVersion:")) { $vsVer = $_.SubString("installationVersion:".Length).Trim() }
  }
  if ($vsPath -ne "")
  {
    $vsVerParts = $vsVer.Split('.')
    $vsMajor = [int]::Parse($vsVerParts[0])
    $vsMinor = [int]::Parse($vsVerParts[1])
    if ($vsMajor -eq 15) {
      $msBuild = "$vsPath\MSBuild\$vsMajor.0\Bin"
    }
    elseif ($vsMajor -eq 14) {
      $msBuild = "c:\Program Files (x86)\MSBuild\$vsMajor\Bin"
    }
    else
    {
      $msBuild = $null
    }
  }

  $vs = $null
  if ($msBuild)
  {
    $vs = new-object -typeName PsObject
    $vs | add-member -memberType NoteProperty -name Path -value $vsPath
    $vs | add-member -memberType NoteProperty -name Major -value $vsMajor
    $vs | add-member -memberType NoteProperty -name Minor -value $vsMinor
    $vs | add-member -memberType NoteProperty -name MsBuild -value "$msBuild\MsBuild.exe"
  }

  # create environment object
  $uenv = new-object -typeName PsObject
  $uenv | add-member -memberType NoteProperty -name SolutionRoot -value $solutionRoot
  $uenv | add-member -memberType NoteProperty -name VisualStudio -value $vs
  $uenv | add-member -memberType NoteProperty -name NuGet -value $nuget
  $uenv | add-member -memberType NoteProperty -name VsWhere -value $vswhere

  # ################################################################
  # NOW we can actually build
  # ################################################################

  # get version
  # parse SolutionInfo and retrieve the version string
  $filepath = "$solutionRoot\src\SolutionInfo.cs"
  $text = [System.IO.File]::ReadAllText($filepath)
  $match = [System.Text.RegularExpressions.Regex]::Matches($text, "AssemblyInformationalVersion\(`"(.+)?`"\)")
  $version = $match.Groups[1]

  # semver-parse the version string
  $semver = [SemVer.SemVersion]::Parse($version)
  $release = "" + $semver.Major + "." + $semver.Minor + "." + $semver.Patch

  $uversion = new-object -typeName PsObject
  $uversion | add-member -memberType NoteProperty -name Semver -value $semver
  $uversion | add-member -memberType NoteProperty -name Release -value $release
  $uversion | add-member -memberType NoteProperty -name Comment -value $semver.PreRelease
  $uversion | add-member -memberType NoteProperty -name Build -value $semver.Build

  # build
  $buildConfiguration = "Release"
  $toolsVersion = "4.0"
  if ($uenv.VisualStudio.Major -eq 15)
  {
    $toolsVersion = "15.0"
  }

  Write-Host "Compile"
  Write-Host "Logging to $tmp\msbuild.umbraco.log"

  # beware of the weird double \\ at the end of paths
  # see http://edgylogic.com/blog/powershell-and-external-commands-done-right/
  &$uenv.VisualStudio.MsBuild "$solutionRoot\src\Umbraco.Build\Umbraco.Build.csproj" `
    /p:WarningLevel=0 `
    /p:Configuration=$buildConfiguration `
    /p:Platform=AnyCPU `
    /p:UseWPP_CopyWebApplication=True `
    /p:PipelineDependsOnBuild=False `
    /p:Verbosity=minimal `
    /t:Clean`;Rebuild `
    /tv:$toolsVersion `
    /p:UmbracoBuild=True `
    > $tmp\msbuild.umbraco.log

  if (-not $?)
  {
    Write-Host "Abort"
    break
  }

  # package nuget
  Write-Host "Pack"
  &$uenv.NuGet Pack "$solutionRoot\build\nuspec\Umbraco.Build.nuspec" `
    -Properties Solution="$solutionRoot" `
    -Version $uversion.Semver.ToString() `
    -Verbosity quiet -outputDirectory $out

  if (-not $?)
  {
    Write-Host "Abort"
    break
  }

  $hook = "$solutionRoot\build\hooks\Post-Package-NuGet.ps1"
  if (Test-Path -Path $hook)
  {
    Write-Host "Run Post-Package-NuGet hook"
    . "$hook" # define Post-Package-Nuget
    Post-Package-NuGet $uenv $uversion
  }

  if (-not $?)
  {
    Write-Host "Abort"
    break
  }

  # done
  Write-Host "Done"