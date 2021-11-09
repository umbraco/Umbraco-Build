Umbraco Build
=

# About

The Umbraco.Build package is the foundation of all Umbraco products builds.

Or, at least, that's the goal - it's currently work-in-progress.

### Tasks

Umbraco.Build registers the following common tasks:

* `GetUmbracoVersion` - returns the semver version of the product
* `SetUmbracoVersion` - sets the semver version of the product
* `SetBuildVersion` - adds build version infos to the product version
* `ClearBuildVersion` - removes the build version infos from the product version
* `VerifyNuGet` - verifies NuGet packages consistency

### Usage

Products using Umbraco.Build need to:

(to be completed)

### Versioning

The build script respects the version that has been set with `SetUmbracoVersion` and shows in the `SolutionInfo.cs` file, eg `1.2.3` or `1.2.3-alpha.3`. This version appears in the `AssemblyInformationVersion` assembly attribute, which shows as *Product Version* in the dll properties in Windows Explorer.

The build script complements the attribute with the following elements:

* Build number - for branches that are not "release branches" - appends the build number
* Git hash - appends `@a4f89c47` or `@a4f89c47+` where `a4f89c47` is the Git hash of the commit that is built, and the `+` signs indicates local changes

Therefore, Windows Explorer could show `1.2.3 @a4f89c47`.

Build number is appended as follows:

* 1.2.3 = 1.2.3-aleph.*buildNumber*
* 1.2.3-beta = 1.2.3-beta.0.*buildNumber*
* 1.2.3-beta.3 = 1.2.3-beta.3.*buildNumber*

Semver-wise, this means that each continuous build of a pre-release version comes *after* that version, ie -alpha.0.20171012.0001 > -alpha, and so we should upgrade the alpha/beta number at the moment we release it.

Example of a versions sequence:

    1.0.0                           release of 1.0.0
    1.0.1-aleph.20171011.0001       continuous build of 1.0.1
    1.0.1-aleph.20171011.0002       continuous build of 1.0.1
    1.0.1-aleph.20171012.0001       continuous build of 1.0.1
    1.0.1                           release of 1.0.1
    1.0.1-alpha.0.20071013.0001     continuous build of -alpha.0
    1.0.1-alpha.0.20071014.0001     continuous build of -alpha.0
    1.0.1-alpha.0.20071014.0002     continuous build of -alpha.0
    1.0.1-alpha.1                   release of 1.0.1-alpha.1
    1.0.1-alpha.1.20071015.0001     continuous build of -alpha.1
    etc

Also examples of Git hashes!

### Attributes

AssemblyVersion 8.0.0
  = used by CLR compatibility - change only with major breaking changes
AssemblyFileVersion 8.1.2.5557
  = SemVer base version + build number
AssemblyInformationalVersion 8.1.2-alpha.12.5557
  = SemVer / NuGet version, optional -alpha.12, optional .5557 (build)
  not using +5557 because for SemVer it's info only, no comparison
The build number is an Int32 - cannot use 20170919231025
should it be a count? number of secs since? since first build of that version?

## Releasing

To release new versions, GitHub actions are used. In the `.github/workflows/release.yml` workflow you can see and configure the steps.

1. Make sure to update `SolutionInfo.cs` with the version you want to release
2. The release is triggered by pushing a new tag to the repository with the version number in the format `v0.2.17` - this should be the same version number you put in `SolutionInfo.cs` prefixed with a `v`
3. The release workflow will run and push the latest version to MyGet

