# returns a string containing the hash of $file
$global:ubuild | Add-Member -MemberType ScriptMethod GetFileHash -value `
{
  param ( $file )

  try 
  {
    $crypto = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider
    $stream = [System.IO.File]::OpenRead($file)
    $hash = $crypto.ComputeHash($stream)
    $text = ""
    $hash | ForEach-Object `
    {
      $text = $text + $_.ToString("x2")
    }
    return $text
  }
  finally
  {
    if ($stream)
    {
      $stream.Dispose()
    }
    $crypto.Dispose()
  }
}

# returns the full path if $file is relative to $pwd
$global:ubuild | Add-Member -MemberType ScriptMethod GetFullPath -value `
{
  param ( $file )

  $path = [System.IO.Path]::Combine($pwd, $file)
  $path = [System.IO.Path]::GetFullPath($path)
  return $path
}

# removes a directory, doesn't complain if it does not exist
$global:ubuild | Add-Member -MemberType ScriptMethod RemoveDirectory -value `
{
  param ( $dir )

  Remove-Item $dir -force -recurse -errorAction SilentlyContinue > $null
}

# removes a file, doesn't complain if it does not exist
$global:ubuild | Add-Member -MemberType ScriptMethod RemoveFile -value `
{
  param ( $file )

  Remove-Item $file -force -errorAction SilentlyContinue > $null
}

# copies a file, creates target dir if needed
$global:ubuild | Add-Member -MemberType ScriptMethod CopyFile -value `
{
  param ( $source, $target )

  $ignore = new-item -itemType file -path $target -force
  Copy-Item -force $source $target
}

# copies files to a directory
$global:ubuild | Add-Member -MemberType ScriptMethod CopyFiles -value `
{
  param ( $source, $select, $target, $filter )

  $files = Get-ChildItem -r "$source\$select"
  $files | Foreach-Object {
    $relative = $_.FullName.SubString($source.Length+1)
    $_ | add-member -memberType NoteProperty -name RelativeName -value $relative
  }
  if ($filter -ne $null) {
    $files = $files | Where-Object $filter 
  }
  $files |
    Foreach-Object {
      if ($_.PsIsContainer) {
        $ignore = new-item -itemType directory -path "$target\$($_.RelativeName)" -force
      }
      else {
        $this.CopyFile($_.FullName, "$target\$($_.RelativeName)")
      }
    }
}

# regex-replaces content in a file
$global:ubuild | Add-Member -MemberType ScriptMethod ReplaceFileText -value `
{
  param ( $filename, $source, $replacement )

  $filepath = $this.GetFullPath($filename)
  $text = [System.IO.File]::ReadAllText($filepath)
  $text = [System.Text.RegularExpressions.Regex]::Replace($text, $source, $replacement)
  $utf8bom = New-Object System.Text.UTF8Encoding $true
  [System.IO.File]::WriteAllText($filepath, $text, $utf8bom)
}

# VS online export env variable
$global:ubuild | Add-Member -MemberType ScriptMethod SetEnv -value `
{
  param ( $name, $value )
  [Environment]::SetEnvironmentVariable($name, $value)

  # set environment variable for VSO
  # https://github.com/Microsoft/vsts-tasks/issues/375
  # https://github.com/Microsoft/vsts-tasks/blob/master/docs/authoring/commands.md
  Write-Host ("##vso[task.setvariable variable=$name;]$($value)")
}

# temp store file under file.temp-build
$global:ubuild | Add-Member -MemberType ScriptMethod TempStoreFile -value `
{
  param ( $path )
  $name = [System.IO.Path]::GetFileName($path)

  if (Test-Path "$path")
  {
    if (Test-Path "$path.temp-build")
    {
      Write-Host "Found already existing $name.temp-build"
      Write-Host "(will be restored after build)"
    }
    else
    {
      Write-Host "Save existing $name as $name.temp-build"
      Write-Host "(will be restored after build)"
      Move-Item "$path" "$path.temp-build"
    }
  }
}

# restores a file that was temp stored under file.temp-build
$global:ubuild | Add-Member -MemberType ScriptMethod TempRestoreFile -value `
{
  param ( $path )
  $name = [System.IO.Path]::GetFileName($path)

  if (Test-Path "$path.temp-build")
  {
    Write-Host "Restoring existing $name"
    $this.RemoveFile("$path")
    Move-Item "$path.temp-build" "$path"
  }
}

# clears an environment variable
$global:ubuild | Add-Member -MemberType ScriptMethod ClearEnvVar -value `
{
  param ( $var )
  $value = [Environment]::GetEnvironmentVariable($var)
  if (Test-Path "env:$var") { Remove-Item "env:$var" }
  return $value
}

# sets an environment variable
$global:ubuild | Add-Member -MemberType ScriptMethod SetEnvVar -value `
{
  param ( $var, $value )
  if ($value)
  {
    [Environment]::SetEnvironmentVariable($var, $value)
  }
  else
  {
    if (Test-Path "env:$var") { rm "env:$var" }
  }
}

# looks for a method
$global:ubuild | Add-Member -MemberType ScriptMethod HasMethod -value `
{
  param ( $name )
  return $this.PSObject.Methods.Name -match $name
}

# unrolls errors
$global:ubuild | Add-Member -MemberType ScriptMethod WriteException -value `
{
  param ( $e )

  Write-Host "Exception!"
  while ($e -ne $null)
  {
    $ii = $e.ErrorRecord.InvocationInfo
    Write-Host "$($e.GetType().Name): $($e.Message)"
    if ($ii -ne $null)
    {
      Write-Host "## $($ii.ScriptName) $($ii.ScriptLineNumber):$($ii.OffsetInLine)"
      Write-Host "   $($ii.Line.Trim())"
    }
    Write-Host " "
    $e = $e.InnerException
  }
}