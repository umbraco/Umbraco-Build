
$global:ubuild | Add-Member -MemberType ScriptMethod VerifyNuGet -value `
{
  param (
    [Parameter(Mandatory=$true)]
    $nuspecs, # eg ( "UmbracoCms", "UmbracoCms.Core" )

    [Parameter(Mandatory=$true)]
    $projects # eg ( "Umbraco.Core", "Umbraco.Web" )
  )

  function Format-Dependency
  {
    param ( $d )

    $m = $d.Id + " "
    if ($d.MinInclude) { $m = $m + "[" }
    else { $m = $m + "(" }
    $m = $m + $d.MinVersion
    if ($d.MaxVersion -ne $d.MinVersion) { $m = $m + "," + $d.MaxVersion }
    if ($d.MaxInclude) { $m = $m + "]" }
    else { $m = $m + ")" }

    return $m
  }

  function Write-NuSpec
  {
    param ( $name, $deps )

    Write-Host ""
    Write-Host "$name NuSpec dependencies:"

    foreach ($d in $deps)
    {
      $m = Format-Dependency $d
      Write-Host " $m"
    }
  }

  function Write-Package
  {
    param ( $name, $pkgs )

    Write-Host ""
    Write-Host "$name packages:"

    foreach ($p in $pkgs)
    {
      Write-Host " $($p.Id) $($p.Version)"
    }
  }

  Write-Host "Verify NuGet consistency"

  $verifier = New-Object "Umbraco.Build.NuGetVerifier"

  $src = "$($this.SolutionRoot)\src"
  $pkgs = $verifier.GetProjectsPackages($src, $projects)
  if (-not $?) { Write-Host "Abort" ; break }
  #Write-Package "All" $pkgs

  $errs = $verifier.GetPackageErrors($pkgs)
  if (-not $?) { Write-Host "Abort" ; break }

  if ($errs.Length -gt 0)
  {
    Write-Host ""
  }
  foreach ($err in $errs)
  {
    Write-Host $err.Key
    foreach ($e in $err)
    {
      Write-Host " $($e.Version) required by $($e.Project)"
    }
  }
  if ($errs.Length -gt 0)
  {
    Write-Error "Found non-consolidated package dependencies"
    break
  }

  $nuerr = $false
  $nupath = "$($this.SolutionRoot)\build\NuSpecs"
  foreach ($nuspec in $nuspecs)
  {
    $deps = $verifier.GetNuSpecDependencies("$nupath\$nuspec.nuspec")
    if (-not $?) { Write-Host "Abort" ; break }
    #Write-NuSpec $nuspec $deps

    $errs = $verifier.GetNuSpecErrors($pkgs, $deps)
    if (-not $?) { Write-Host "Abort" ; break }

    if ($errs.Length -gt 0)
    {
      Write-Host ""
      Write-Host "$nuspec requires:"
      $nuerr = $true
    }
    foreach ($err in $errs)
    {
      $m = Format-Dependency $err.Dependency
      Write-Host " $m but projects require $($err.Version)"
    }
  }

  if ($nuerr)
  {
    Write-Error "Found inconsistent NuGet dependencies"
    break
  }
}