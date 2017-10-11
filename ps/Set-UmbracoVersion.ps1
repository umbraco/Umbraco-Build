#
# Set-UmbracoVersion
# Sets the Umbraco version
#
#   -Version <version>
#   where <version> is a Semver valid version
#   eg 1.2.3, 1.2.3-alpha, 1.2.3-alpha+456
#
function Set-UmbracoVersion
{
  param (
    [Parameter(Mandatory=$true)]
    [string]
    $version
  )

  $uenv = Get-UmbracoBuildEnv

  try
  {
    [Reflection.Assembly]::LoadFile($uenv.Semver) > $null
  }
  catch
  {
    Write-Error "Failed to load $uenv.Semver"
    break
  }

  # validate input
  $ok = [Regex]::Match($version, "^[0-9]+\.[0-9]+\.[0-9]+(\-[a-z0-9\.]+)?(\+[0-9]+)?$")
  if (-not $ok.Success)
  {
    Write-Error "Invalid version $version"
    break
  }

  # parse input
  try
  {
    $semver = [SemVer.SemVersion]::Parse($version)
  }
  catch
  {
    Write-Error "Invalid version $version"
    break
  }

  #
  $release = "" + $semver.Major + "." + $semver.Minor + "." + $semver.Patch

  # edit files and set the proper versions and dates
  Write-Host "Update SolutionInfo.cs"
  Replace-FileText "$($uenv.SolutionRoot)\src\SolutionInfo.cs" `
    "AssemblyFileVersion\(`".+`"\)" `
    "AssemblyFileVersion(`"$release`")"
  Replace-FileText "$($uenv.SolutionRoot)\src\SolutionInfo.cs" `
    "AssemblyInformationalVersion\(`".+`"\)" `
    "AssemblyInformationalVersion(`"$semver`")"
  $year = [System.DateTime]::Now.ToString("yyyy")
  Replace-FileText "$($uenv.SolutionRoot)\src\SolutionInfo.cs" `
    "AssemblyCopyright\(`"Copyright © Umbraco (\d{4})`"\)" `
    "AssemblyCopyright(`"Copyright © Umbraco $year`")"

  return $semver
}
