//using System;
//using System.IO;
//using System.Linq;
//using System.Reflection;
//using LibGit2Sharp;
//using Mono.Cecil;
//using Vestris.ResourceLib;

namespace Umbraco.Build
{
    // keeping this around for info - does not work
    //
    // requires NuGet for
    // - LibGit2Sharp
    // - Mono.Cecil
    // - System.ValueTuple
    // - Vestris.ResourceLib (maybe)

    /*
    public class AssemblySourceVersion
    {
        public AssemblySourceVersion()
        {
            AssemblyResolver.EnsureInitialized();
        }

        public string Set(string filename)
        {
            // get git version
            var gitPath = Path.GetDirectoryName(Path.GetFullPath(Path.IsPathRooted(filename) ? filename : Path.Combine(Directory.GetCurrentDirectory(), filename)));
            (var version, var hasLocalChanges) = GetGitVersion(gitPath);

            if (version == null)
                return string.Empty;

            var versionString = version + (hasLocalChanges ? "+" : "");

            // get assembly and module
            var assembly = AssemblyDefinition.ReadAssembly(filename);
            var module = assembly.MainModule;

            // get existing attributes, if any
            var attributeTypeName = typeof(AssemblyInformationalVersionAttribute).FullName;
            var existingAttributes = assembly.CustomAttributes.Where(x => x.AttributeType.FullName == attributeTypeName).ToList();
            var existingAttribute = existingAttributes.FirstOrDefault();
            foreach (var existing in existingAttributes)
                assembly.CustomAttributes.Remove(existing);

            var existingVersion = existingAttribute?.ConstructorArguments[0].Value.ToString().Trim();
            if (existingVersion != null)
            {
                var pos = existingVersion.IndexOf(' ');
                if (pos > 0) existingVersion = existingVersion.Substring(0, pos - 1);
            }

            var newVersion = existingVersion
                             + (existingVersion == null ? "" : " ")
                             + versionString;

            // create and add the new attribute
            var ctor = typeof(AssemblyInformationalVersionAttribute).GetConstructor(new[] { typeof(string) });
            var attribute = new CustomAttribute(module.Import(ctor));
            attribute.ConstructorArguments.Add(new CustomAttributeArgument(module.TypeSystem.String, newVersion));
            assembly.CustomAttributes.Add(attribute);

            // write the assembly
            assembly.Write(filename);

            // still, not enough, 'cos it's not modifying the unmanaged
            // PE VERSIONINFO resource ... so need to do it here
            //
            // closet would be ResourceLib which cannot deal with stings
            // in product version (wtf?!) => give up for now
            using (var info = new ResourceInfo())
            {
                info.Load(filename);
                var resourceId = new ResourceId(Kernel32.ResourceTypes.RT_VERSION);
                var versionResource = info.Resources[resourceId];

            }


            return versionString;
        }

        private static (string, bool) GetGitVersion(string path)
        {
            while (path != null && !Directory.EnumerateDirectories(path, ".git").Any())
                path = Path.GetDirectoryName(path);

            if (path == null)
            {
                var debug = Environment.GetEnvironmentVariable("UMBRACO_BUILD_DEBUG") == "1";
                if (debug) Console.WriteLine("Could not locate .git directory.");
                return (null, false);
            }

            try
            {
                using (var repository = new Repository(path))
                {
                    var commit = repository.Head.Tip;
                    var version = commit.Sha.Substring(0, 8);
                    var status = repository.RetrieveStatus();
                    var hasLocalChanges = status.Added.Any() || status.Missing.Any() || status.Modified.Any()
                                          || status.Removed.Any() || status.RenamedInIndex.Any() || status.RenamedInWorkDir.Any()
                                          || status.Staged.Any();

                    return (version, hasLocalChanges);
                }
            }
            catch (RepositoryNotFoundException)
            {
                var debug = Environment.GetEnvironmentVariable("UMBRACO_BUILD_DEBUG") == "1";
                if (debug) Console.WriteLine("RepositoryNotFoundException.");
                return (null, false);
            }
        }
    }
    */
}
