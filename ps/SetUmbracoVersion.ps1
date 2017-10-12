
$global:ubuild | Add-Member -MemberType ScriptMethod SetUmbracoVersion -value `
{
  param (
    [Parameter(Mandatory=$true)]
    [string] $version
  )

  try
  {
    [Reflection.Assembly]::LoadFile($this.BuildEnv.Semver) > $null
  }
  catch
  {
    Write-Error "Failed to load $this.BuildEnv.Semver"
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
  $this.ReplaceFileText("$($this.SolutionRoot)\src\SolutionInfo.cs", `
    "AssemblyFileVersion\(`".+`"\)", `
    "AssemblyFileVersion(`"$release`")")
  $this.ReplaceFileText("$($this.SolutionRoot)\src\SolutionInfo.cs", `
    "AssemblyInformationalVersion\(`".+`"\)", `
    "AssemblyInformationalVersion(`"$semver`")")
  $year = [System.DateTime]::Now.ToString("yyyy")
  $this.ReplaceFileText("$($this.SolutionRoot)\src\SolutionInfo.cs", `
    "AssemblyCopyright\(`"Copyright © Umbraco (\d{4})`"\)", `
    "AssemblyCopyright(`"Copyright © Umbraco $year`")")

  return $semver
}
