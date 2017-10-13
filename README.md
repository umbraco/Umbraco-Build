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