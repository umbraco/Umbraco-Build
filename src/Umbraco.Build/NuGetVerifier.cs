using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Xml;
using System.Xml.Serialization;
using NuGet.Versioning;

namespace Umbraco.Build
{
    public class NuGetVerifier : ExportedObject
    {
        // reads a nuspec file and returns its dependencies
        // filename is the full or relative path to nuspec
        public Dependency[] GetNuSpecDependencies(string filename)
        {
            NuSpec nuspec;
            var serializer = new XmlSerializer(typeof(NuSpec));
            using (var reader = new IgnoreNsXmlTextReader(new StreamReader(filename)))
            {
                nuspec = (NuSpec) serializer.Deserialize(reader);
            }
            var groups = nuspec.Metadata.Groups;

            var deps = new List<Dependency>();
            foreach (var group in groups)
            {
                var nudeps = group.Dependencies;
           
                foreach (var nudep in nudeps)
                {
                    var dep = new Dependency { Id = nudep.Id };

                    var parts = nudep.Version.Split(',');
                    if (parts.Length == 1)
                    {
                        dep.MinInclude = parts[0].StartsWith("[");
                        dep.MaxInclude = parts[0].EndsWith("]");

                        if (!NuGetVersion.TryParse(parts[0].Substring(1, parts[0].Length - 2).Trim(), out var version)) continue;
                        dep.MinVersion = dep.MaxVersion = version;
                    }
                    else
                    {
                        if (!NuGetVersion.TryParse(parts[0].Substring(1).Trim(), out var version)) continue;
                        dep.MinVersion = version;
                        if (!NuGetVersion.TryParse(parts[1].Substring(0, parts[1].Length - 1).Trim(), out version)) continue;
                        dep.MaxVersion = version;
                        dep.MinInclude = parts[0].StartsWith("[");
                        dep.MaxInclude = parts[1].EndsWith("]");
                    }

                    deps.Add(dep);
                }
            }
            
            return deps.ToArray();
        }

        // read projects and returns their (distinct) packages
        // projects are assumed to be in <root>/<project>
        public Package[] GetProjectsPackages(string root, string[] projects)
        {
            var l = new List<Package>();
            foreach (var project in projects)
            {
                var path = Path.Combine(root, project);
                var packageConfig = Path.Combine(path, "packages.config");
                if (File.Exists(packageConfig))
                    ReadPackagesConfig(packageConfig, l);
                var csprojs = Directory.GetFiles(path, "*.csproj");
                foreach (var csproj in csprojs)
                    ReadCsProj(csproj, l);
            }
            IEnumerable<Package> p = l.OrderBy(x => x.Id);
            p = DistinctBy(p, x => x.Id + ":::" + x.Version + ":::" + x.Codition ?? string.Empty +":::");
            return p.ToArray();
        }

        // look for packages existing in projects with different versions
        // returns package id -> package versions
        public IGrouping<string, Package>[] GetPackageErrors(Package[] pkgs)
        {

            var conditions = pkgs.GroupBy(x => x.Codition);
            
            var conditionLess = pkgs.Where(x => x.Codition is null).ToArray();

            IGrouping<string, Package>[] result = null;
            
            foreach (var condition in conditions)
            {
                var temp = condition.Key is null ? condition : condition.Concat(conditionLess);

                var supResult =
                        temp
                        .GroupBy(x =>  x.Id)
                    .Where(x => x.Count() > 1)
                    .ToArray();


                    result = result is null ? supResult : result.Concat(supResult).ToArray();
            }

            return result;

        }

        // look for nuspec dependencies that don't match packages
        // returns dependency, package version
        public NuGetError[] GetNuSpecErrors(Package[] pkgs, Dependency[] deps)
        {
            var xpkgs = pkgs.ToDictionary(x => x.Id + ":::" + x.Codition, x => x.Version);
            return deps.Select(dep =>
            {
                if (!xpkgs.TryGetValue(dep.Id, out var packageVersion)) return null;

                // ok if dep min is included, and matches package version
                // would be weird to not include, and it must match
                var ok = dep.MinInclude && packageVersion == dep.MinVersion;

                return ok ? null : new NuGetError { Dependency = dep, Version = packageVersion };
            })
            .Where(x => x != null)
            .ToArray();
        }

        // reads a package.config file and append packages to the list
        private static void ReadPackagesConfig(string filename, List<Package> packages)
        {
            //Console.WriteLine("read " + filename);

            PackagesConfigPackages pkgs;
            var serializer = new XmlSerializer(typeof(PackagesConfigPackages));
            using (var reader = new IgnoreNsXmlTextReader(new StreamReader(filename)))
            {
                pkgs = (PackagesConfigPackages) serializer.Deserialize(reader);
            }
            foreach (var p in pkgs.Packages)
            {
                if (!NuGetVersion.TryParse(p.Version, out var version)) continue;
                packages.Add(new Package { Id = p.Id, Version = version, Project = GetDirectoryName(filename) });
            }
        }

        // reads a project file and append PackageReference packages to the list
        private static void ReadCsProj(string filename, List<Package> packages)
        {
            //Console.WriteLine("read " + filename);

            CsProjProject proj;
            var serializer = new XmlSerializer(typeof(CsProjProject));
            using (var reader = new IgnoreNsXmlTextReader(new StreamReader(filename)))
            {
                proj = (CsProjProject) serializer.Deserialize(reader);
            }

            foreach (var itemGroup in proj.ItemGroups)
            {
                if (itemGroup.Packages != null)
                    foreach (var package in itemGroup.Packages)
                    {
                        var sversion = package.VersionE ?? package.VersionA;
                        if (!NuGetVersion.TryParse(sversion, out var version)) continue;
                        packages.Add(new Package { Id = package.Id, Version = version, Project = GetDirectoryName(filename), Codition = itemGroup.Condition});
                    }
            }
        }

        private static string GetDirectoryName(string filename)
        {
            return Path.GetFileName(Path.GetDirectoryName(filename));
        }

        private static IEnumerable<TSource> DistinctBy<TSource, TKey>(/*this*/ IEnumerable<TSource> source, Func<TSource, TKey> keySelector)
        {
            var knownKeys = new HashSet<TKey>();
            foreach (var element in source)
            {
                if (knownKeys.Add(keySelector(element)))
                {
                    yield return element;
                }
            }
        }

        private class IgnoreNsXmlTextReader : XmlTextReader
        {
            public IgnoreNsXmlTextReader(TextReader reader)
                : base(reader)
            { }

            public override string NamespaceURI => string.Empty;
        }

        public class NuGetError
        {
            public Dependency Dependency { get; set; }
            public NuGetVersion Version { get; set; }
        }

        public class Dependency
        {
            public string Id { get; set; }
            public NuGetVersion MinVersion { get; set; }
            public NuGetVersion MaxVersion { get; set; }
            public bool MinInclude { get; set; }
            public bool MaxInclude { get; set; }
        }

        public class Package
        {
            public string Id { get; set; }
            public NuGetVersion Version { get; set; }
            public string Project { get; set; }

            public string Codition{ get; set; }
        }

        [XmlType(AnonymousType = true /*, Namespace = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"*/)]
        [XmlRoot(/*Namespace = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd",*/ IsNullable = false, ElementName = "package")]
        public class NuSpec
        {
            [XmlElement("metadata")]
            public NuSpecMetadata Metadata { get; set; }
        }

        [XmlType(AnonymousType = true, /*Namespace = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd",*/ TypeName = "metadata")]
        public class NuSpecMetadata
        {
            [XmlArray("dependencies")]
            [XmlArrayItem("group", IsNullable = false)]
            public NuSpecDependencyGroup[] Groups { get; set; }
           
        }

        [XmlType(AnonymousType = true, /*Namespace = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd",*/ TypeName = "group")]
        public class NuSpecDependencyGroup
        {
            [XmlElement("dependency")]
            public NuSpecDependency[] Dependencies { get; set; }
            
            [XmlAttribute(AttributeName = "targetFramework")]
            public string TargetFramework { get; set; }
        }
        
        [XmlType(AnonymousType = true, /*Namespace = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd",*/ TypeName = "dependency")]
        public class NuSpecDependency
        {
            [XmlAttribute(AttributeName = "id")]
            public string Id { get; set; }

            [XmlAttribute(AttributeName = "version")]
            public string Version { get; set; }
        }

        [XmlType(AnonymousType = true)]
        [XmlRoot(Namespace = "", IsNullable = false, ElementName = "packages")]
        public class PackagesConfigPackages
        {
            [XmlElement("package")]
            public PackagesConfigPackage[] Packages { get; set; }
        }

        [XmlType(AnonymousType = true, TypeName = "package")]
        public class PackagesConfigPackage
        {
            [XmlAttribute(AttributeName = "id")]
            public string Id { get; set; }

            [XmlAttribute(AttributeName = "version")]
            public string Version { get; set; }
        }

        [XmlType(AnonymousType = true)]
        [XmlRoot(Namespace = "", IsNullable = false, ElementName = "Project")]
        public class CsProjProject
        {
            [XmlElement("ItemGroup")]
            public CsProjItemGroup[] ItemGroups { get; set; }
        }

        [XmlType(AnonymousType = true, TypeName = "ItemGroup")]
        public class CsProjItemGroup
        {
            [XmlElement("PackageReference")]
            public CsProjPackageReference[] Packages { get; set; }
            
            [XmlAttribute(AttributeName = "Condition")]
            public string Condition { get; set; }

        }

        [XmlType(AnonymousType = true, TypeName = "PackageReference")]
        public class CsProjPackageReference
        {
            [XmlAttribute(AttributeName = "Include")]
            public string Id { get; set; }

            [XmlAttribute(AttributeName = "Version")]
            public string VersionA { get; set; }

            [XmlElement("Version")]
            public string VersionE { get; set; }
        }
    }


}