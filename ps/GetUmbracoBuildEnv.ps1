
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
      if (-not $?) { Write-Host "Abort" ; break }
    }
  }
  elseif (-not (test-path $nuget))
  {
    Write-Host "Failed to locate NuGet.exe"
    break
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
        if (-not $?) { Write-Host "Abort" ; break }
        $dir = ls "$scriptTemp\7-Zip.CommandLine.*" | sort -property Name -descending | select -first 1
        $file = ls -path "$dir" -name 7za.exe -recurse
        mv "$dir\$file" $sevenZip
        $this.RemoveDirectory($dir)
      }
    }
    elseif (-not (test-path $sevenZip))
    {
      Write-Host "Failed to locate 7za.exe"
      break
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
        if (-not $?) { Write-Host "Abort" ; break }
        $dir = ls "$scriptTemp\vswhere.*" | sort -property Name -descending | select -first 1
        $file = ls -path "$dir" -name vswhere.exe -recurse
        mv "$dir\$file" $vswhere
        $this.RemoveDirectory($dir)
      }
    }
    elseif (-not (test-path $vswhere))
    {
      Write-Host "Failed to locate VsWhere.exe"
      break
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
          Write-Error "Failed to file $file"
          break
        }
        mv "$file" $semver
        $this.RemoveDirectory($dir)
      }
    }
    elseif (-not (test-path $semver))
    {
      Write-Host "Failed to locate Semver.dll"
      break
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
        if (-not $?) { Write-Host "Abort" ; break }
        &$sevenZip x "$scriptTemp\node-v6.9.1-win-x86.7z" -o"$scriptTemp" -aos > $nul
        $this.RemoveFile("$scriptTemp\node-v6.9.1-win-x86.7z")
      }
    }
    elseif (-not (test-path $node))
    {
      Write-Host "Failed to locate Node"
      break
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

    if ($msBuild)
    {
      $vs = @{
        Path = $vsPath
        Major = $vsMajor
        Minor = $vsMinor
        MsBuild = "$msBuild\MsBuild.exe"
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
