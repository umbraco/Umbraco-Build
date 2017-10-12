# returns a string containing the hash of $file
$global:ubuild | Add-Member -MemberType ScriptMethod GetFileHash -value `
{
  param ($file)

  try 
  {
    $crypto = new-object System.Security.Cryptography.SHA1CryptoServiceProvider
    $stream = [System.IO.File]::OpenRead($file)
    $hash = $crypto.ComputeHash($stream)
    $text = ""
    $hash | foreach `
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
  param ($file)

  $path = [System.IO.Path]::Combine($pwd, $file)
  $path = [System.IO.Path]::GetFullPath($path)
  return $path
}

# removes a directory, doesn't complain if it does not exist
$global:ubuild | Add-Member -MemberType ScriptMethod RemoveDirectory -value `
{
  param ($dir)

  remove-item $dir -force -recurse -errorAction SilentlyContinue > $null
}

# removes a file, doesn't complain if it does not exist
$global:ubuild | Add-Member -MemberType ScriptMethod RemoveFile -value `
{
  param ($file)

  remove-item $file -force -errorAction SilentlyContinue > $null
}

# copies a file, creates target dir if needed
$global:ubuild | Add-Member -MemberType ScriptMethod CopyFile -value `
{
  param ($source, $target)

  $ignore = new-item -itemType file -path $target -force
  cp -force $source $target
}

# copies files to a directory
$global:ubuild | Add-Member -MemberType ScriptMethod CopyFiles -value `
{
  param ($source, $select, $target, $filter)

  $files = ls -r "$source\$select"
  $files | foreach {
    $relative = $_.FullName.SubString($source.Length+1)
    $_ | add-member -memberType NoteProperty -name RelativeName -value $relative
  }
  if ($filter -ne $null) {
    $files = $files | where $filter 
  }
  $files |
    foreach {
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
  param ($filename, $source, $replacement)

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