
$global:ubuild | Add-Member -MemberType ScriptMethod SetGitVersion -value `
{
  # parse SolutionInfo and retrieve the version string
  $filepath = "$($this.SolutionRoot)\src\SolutionInfo.cs"
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
  $this.ReplaceFileText("$($this.SolutionRoot)\src\SolutionInfo.cs", `
    "AssemblyInformationalVersion\(`".+`"\)", `
    "AssemblyInformationalVersion(`"$version @$githash$dirty`")")
}

$global:ubuild | Add-Member -MemberType ScriptMethod ClearGitVersion -value `
{
  # parse SolutionInfo and retrieve the version string
  $filepath = "$($this.SolutionRoot)\src\SolutionInfo.cs"
  $text = [System.IO.File]::ReadAllText($filepath)
  $match = [System.Text.RegularExpressions.Regex]::Matches($text, "AssemblyInformationalVersion\(`"(.+)?`"\)")
  $version = $match.Groups[1].ToString()

  # clear
  $pos = $version.IndexOf(' ')
  if ($pos -gt 0) { $version = $version.Substring(0, $pos) }

  # update SolutionInfo with cleared version string
  $this.ReplaceFileText("$($this.SolutionRoot)\src\SolutionInfo.cs", `
    "AssemblyInformationalVersion\(`".+`"\)", `
    "AssemblyInformationalVersion(`"$version`")")
}
