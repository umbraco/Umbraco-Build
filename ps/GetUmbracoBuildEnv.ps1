
$global:ubuild | Add-Member -MemberType ScriptMethod GetUmbracoBuildEnv -value `
{
  param (
    [Parameter(Mandatory=$true)]
    $uenvOptions,

    [Parameter(Mandatory=$true)]
    [string] $scriptTemp
  )

  function Merge-Options
  {
    param ( $merge, $options )
    $keys = $options.GetEnumerator() | ForEach-Object { $_.Key }
    foreach ($key in $keys)
    {
      if ($merge.ContainsKey($key)) { $options[$key] = $merge[$key] }
    }
    return $options
  }

  # options
  $options = Merge-Options $uenvOptions @{
    Local = $false
    Cache = 4 # days
    With7Zip = $true
    WithVs = $true
    WithSemver = $true
    WithNode = $true
  }

  # ensure we have NuGet - not an option really
  $nuget = "$scriptTemp\nuget.exe"
  if (-not $options.Local)
  {
    $source = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    if ((test-path $nuget) -and ((ls $nuget).CreationTime -lt [DateTime]::Now.AddDays(-$options.Cache)))
    {
      $this.RemoveFile($nuget)
    }
    if (-not (test-path $nuget))
    {
      Write-Host "Download NuGet..."
      Invoke-WebRequest $source -OutFile $nuget
      if (-not $?) { throw "Failed to download NuGet." }
    }
  }
  elseif (-not (test-path $nuget))
  {
    throw "Failed to locate NuGet.exe."
  }

  # ensure we have 7-Zip
  $sevenZip = "$scriptTemp\7za.exe"
  if ($options.With7Zip)
  {
    if (-not $options.Local)
    {
      if ((test-path $sevenZip) -and ((ls $sevenZip).CreationTime -lt [DateTime]::Now.AddDays(-$options.Cache)))
      {
        $this.RemoveFile($sevenZip)
      }
      if (-not (test-path $sevenZip))
      {
        Write-Host "Download 7-Zip..."
        &$nuget install 7-Zip.CommandLine -OutputDirectory $scriptTemp -Verbosity quiet
        if (-not $?) { throw "Failed to download 7-Zip." }
        $dir = ls "$scriptTemp\7-Zip.CommandLine.*" | sort -property Name -descending | select -first 1
        # selecting the first 1 because now there is 7za.exe and x64/7za.exe
        # we could be more clever and detect whether we are x86 or x64
        $file = ls -path "$dir" -name 7za.exe -recurse | select -first 1
        mv "$dir\$file" $sevenZip
        $this.RemoveDirectory($dir)
      }
    }
    elseif (-not (test-path $sevenZip))
    {
      throw "Failed to locate 7za.exe."
    }
  }

  # ensure we have vswhere
  $vswhere = "$scriptTemp\vswhere.exe"
  if ($options.WithVs)
  {
    if (-not $options.Local)
    {
      if ((test-path $vswhere) -and ((ls $vswhere).CreationTime -lt [DateTime]::Now.AddDays(-$options.Cache)))
      {
        $this.RemoveFile($vswhere)
      }
      if (-not (test-path $vswhere))
      {
        Write-Host "Download VsWhere..."
        &$nuget install vswhere -OutputDirectory $scriptTemp -Verbosity quiet
        if (-not $?) { throw "Failed to download VsWhere." }
        $dir = ls "$scriptTemp\vswhere.*" | sort -property Name -descending | select -first 1
        $file = ls -path "$dir" -name vswhere.exe -recurse
        mv "$dir\$file" $vswhere
        $this.RemoveDirectory($dir)
      }
    }
    elseif (-not (test-path $vswhere))
    {
      throw "Failed to locate VsWhere.exe."
    }
  }

  # ensure we have semver
  $semver = "$scriptTemp\Semver.dll"
  if ($options.WithSemver)
  {
    if (-not $options.Local)
    {
      if ((test-path $semver) -and ((ls $semver).CreationTime -lt [DateTime]::Now.AddDays(-$options.Cache)))
      {
        $this.RemoveFile($semver)
      }
      if (-not (test-path $semver))
      {
        Write-Host "Download Semver..."
        &$nuget install semver -OutputDirectory $scriptTemp -Verbosity quiet
        $dir = ls "$scriptTemp\semver.*" | sort -property Name -descending | select -first 1
        $file = "$dir\lib\net452\Semver.dll"
        if (-not (test-path $file))
        {
          throw "Failed to locate $file"
        }
        mv "$file" $semver
        $this.RemoveDirectory($dir)
      }
    }
    elseif (-not (test-path $semver))
    {
      throw "Failed to locate $semver"
    }

    try
    {
      [Reflection.Assembly]::LoadFile($semver) > $null
    }
    catch
    {
      throw "Failed to load $semver"
    }
  }

  # ensure we have node
  $node = "$scriptTemp\node-v6.9.1-win-x86"
  if ($options.WithNode)
  {
    if (-not $options.Local)
    {
      $source = "http://nodejs.org/dist/v6.9.1/node-v6.9.1-win-x86.7z"
      if (-not (test-path $node))
      {
        Write-Host "Download Node..."
        Invoke-WebRequest $source -OutFile "$scriptTemp\node-v6.9.1-win-x86.7z"
        if (-not $?) { throw "Failed to download Node." }
        &$sevenZip x "$scriptTemp\node-v6.9.1-win-x86.7z" -o"$scriptTemp" -aos > $nul
        $this.RemoveFile("$scriptTemp\node-v6.9.1-win-x86.7z")
      }
    }
    elseif (-not (test-path $node))
    {
      throw "Failed to locate Node."
    }
  }

  # find visual studio
  # will not work on VS Online but VS Online does not need it
  $vs = $null
  if ($options.WithVs)
  {
    $vsPath = ""
    $vsVer = ""
    $msBuild = $null

    &$vswhere | ForEach-Object {
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

    if ($msBuild)
    {
      $toolsVersion = "4.0"
      if ($vsMajor -eq 15) { $toolsVersion = "15.0" }

      $vs = @{
        Path = $vsPath
        Major = $vsMajor
        Minor = $vsMinor
        MsBuild = "$msBuild\MsBuild.exe"
        ToolsVersion = $toolsVersion
      }
    }
  }

  $uenv = @{
    Options = $options
    Nuget = $nuget
  }

  if ($options.With7Zip) { $uenv.Zip = $sevenZip }
  if ($options.WithVs) { $uenv.VisualStudio = $vs ; $uenv.VsWhere = $vswhere }
  if ($options.WithSemver) { $uenv.Semver = $semver }
  if ($options.WithNode) { $uenv.NodePath = $node }

  return $uenv
}
