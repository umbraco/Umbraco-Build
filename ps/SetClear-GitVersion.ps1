function Set-GitVersion
{
  param (
    $uenv
  )

  if ($uenv -eq $null) { $uenv = Get-UmbracoBuildEnv }

  # parse SolutionInfo and retrieve the version string
  $filepath = "$($uenv.SolutionRoot)\src\SolutionInfo.cs"
  $text = [System.IO.File]::ReadAllText($filepath)
  $match = [System.Text.RegularExpressions.Regex]::Matches($text, "AssemblyInformationalVersion\(`"(.+)?`"\)")
  $version = $match.Groups[1].ToString()

  # clear
  $pos = $version.IndexOf(' ')
  if ($pos -gt 0) { $version = $version.Substring(0, $pos) }

  # get git version
  $githash = &git rev-parse --short HEAD

  # figure out local changes
  # does not take ?? files in account (only M,D,A...)
  $gitstatus = &git status -uno -s
  $dirty = ""
  if ($gitstatus) { $dirty = "+" }

  # update SolutionInfo with completed version string
  Replace-FileText "$($uenv.SolutionRoot)\src\SolutionInfo.cs" `
    "AssemblyInformationalVersion\(`".+`"\)" `
    "AssemblyInformationalVersion(`"$version @$githash$dirty`")"
}

function Clear-GitVersion
{
  param (
    $uenv
  )

  if ($uenv -eq $null) { $uenv = Get-UmbracoBuildEnv }

  # parse SolutionInfo and retrieve the version string
  $filepath = "$($uenv.SolutionRoot)\src\SolutionInfo.cs"
  $text = [System.IO.File]::ReadAllText($filepath)
  $match = [System.Text.RegularExpressions.Regex]::Matches($text, "AssemblyInformationalVersion\(`"(.+)?`"\)")
  $version = $match.Groups[1].ToString()

  # clear
  $pos = $version.IndexOf(' ')
  if ($pos -gt 0) { $version = $version.Substring(0, $pos) }

  # update SolutionInfo with cleared version string
  Replace-FileText "$($uenv.SolutionRoot)\src\SolutionInfo.cs" `
    "AssemblyInformationalVersion\(`".+`"\)" `
    "AssemblyInformationalVersion(`"$version`")"
}