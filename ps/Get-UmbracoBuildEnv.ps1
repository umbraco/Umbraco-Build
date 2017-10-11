#
# Get-UmbracoBuildEnv
# Gets the Umbraco build environment
# Downloads tools if necessary
#
function Get-UmbracoBuildEnv
{
  param (
    # run local - don't download, assume everything is ready
    [Parameter(Mandatory=$false)]
    [switch] $local = $false,

    # disable what we don't need
    [Parameter(Mandatory=$false)]
    [switch] $no7zip = $false,
    [Parameter(Mandatory=$false)]
    [switch] $noNode = $false
  )

  # cache for 4 days
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
  
  # ensure we have 7-Zip
  $sevenZip = "$scriptTemp\7za.exe"
  if (-not $no7zip)
  {
    if (-not $local)
    {
      if ((test-path $sevenZip) -and ((ls $sevenZip).CreationTime -lt [DateTime]::Now.AddDays(-$cache)))
      {
        Remove-File $sevenZip
      }
      if (-not (test-path $sevenZip))
      {
        Write-Host "Download 7-Zip..."
        &$nuget install 7-Zip.CommandLine -OutputDirectory $scriptTemp -Verbosity quiet
        if (-not $?) { Write-Host "Abort" ; break }
        $dir = ls "$scriptTemp\7-Zip.CommandLine.*" | sort -property Name -descending | select -first 1
        $file = ls -path "$dir" -name 7za.exe -recurse
        mv "$dir\$file" $sevenZip
        Remove-Directory $dir
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
  if (-not $local)
  {
    if ((test-path $vswhere) -and ((ls $vswhere).CreationTime -lt [DateTime]::Now.AddDays(-$cache)))
    {
      Remove-File $vswhere
    }
    if (-not (test-path $vswhere))
    {
      Write-Host "Download VsWhere..."
      &$nuget install vswhere -OutputDirectory $scriptTemp -Verbosity quiet
      if (-not $?) { Write-Host "Abort" ; break }
      $dir = ls "$scriptTemp\vswhere.*" | sort -property Name -descending | select -first 1
      $file = ls -path "$dir" -name vswhere.exe -recurse
      mv "$dir\$file" $vswhere
      Remove-Directory $dir
    }
  }
  elseif (-not (test-path $vswhere))
  {
    Write-Host "Failed to locate VsWhere.exe"
    break
  }


  # ensure we have semver
  $semver = "$scriptTemp\Semver.dll"
  if (-not $local)
  {
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
  
  # ensure we have node
  $node = "$scriptTemp\node-v6.9.1-win-x86"
  if (-not $noNode)
  {
    if (-not $local)
    {
      $source = "http://nodejs.org/dist/v6.9.1/node-v6.9.1-win-x86.7z"
      if (-not (test-path $node))
      {
        Write-Host "Download Node..."
        Invoke-WebRequest $source -OutFile "$scriptTemp\node-v6.9.1-win-x86.7z"
        if (-not $?) { Write-Host "Abort" ; break }
        &$sevenZip x "$scriptTemp\node-v6.9.1-win-x86.7z" -o"$scriptTemp" -aos > $nul
        Remove-File "$scriptTemp\node-v6.9.1-win-x86.7z"    
      }
    }
    elseif (-not (test-path $node))
    {
      Write-Host "Failed to locate Node"
      break
    }
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
  
  $solutionRoot = [System.IO.Path]::GetFullPath("$scriptRoot\..")
  
  $uenv = new-object -typeName PsObject
  $uenv | add-member -memberType NoteProperty -name SolutionRoot -value $solutionRoot
  $uenv | add-member -memberType NoteProperty -name VisualStudio -value $vs
  $uenv | add-member -memberType NoteProperty -name NuGet -value $nuget
  $uenv | add-member -memberType NoteProperty -name Zip -value $sevenZip
  $uenv | add-member -memberType NoteProperty -name VsWhere -value $vswhere
  $uenv | add-member -memberType NoteProperty -name Semver -value $semver
  $uenv | add-member -memberType NoteProperty -name NodePath -value $node
  $uenv | add-member -memberType NoteProperty -name Local -value $local
  
  return $uenv
}
