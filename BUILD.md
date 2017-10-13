Umbraco Build
=

# Build

### Quick

In PowerShell at the repository's root,

    build/build.ps1

builds, packs the NuGet package, and copies it into `build.out`

In order to change the version, one has to manually edit `SolutionInfo.cs`.

### More

By default, the build script will try to download the latest version of components it uses (eg NuGet, Umbraco.Build, etc). One can skip this step by instructing the build script to run in local mode. Of course, the required components must be available (ie the script must have run in non-local mode once):

    build/build.ps1 -local

### VS Online

Umbraco.Build is not built continuously.

### Hooks

Hooks are extensions to the build script, that are meant to add custom operations to the build process. Hooks live in `~/build/hooks/` which is git-ignored. A typical hook would be named `HookOperation.ps1` and contain code such as:

    $global:ubuild | Add-Member -MemberType ScriptMethod HookOperation -value `
    {
      Write-Host "Execute HookOperation and do something..."
      # here, reference the build environment as $this, eg
      $ubuild.CopyFile("$($ubuild.BuildOutput)\...", "...")
    }

The build script supports the following hook(s):

* `PostPackageNuGet` - runs after the NuGet package has been created and copied to `build.out`