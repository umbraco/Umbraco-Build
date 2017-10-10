using System;
using System.IO;
using System.Linq;
using System.Reflection;
using LibGit2Sharp;
using Mono.Cecil;
using Umbraco.Build.Attributes;

namespace Umbraco.Build
{
    public class AssemblySourceVersion
    {
        public string Get(string filename)
        {
            var asmPath = Path.GetFullPath(Path.IsPathRooted(filename) ? filename : Path.Combine(Directory.GetCurrentDirectory(), filename));
            var asm = Assembly.ReflectionOnlyLoadFrom(asmPath);
            var attributeTypeName = typeof(AssemblySourceVersionAttribute).FullName;
            var attrs = asm.GetCustomAttributesData().Where(x => x.AttributeType.FullName == attributeTypeName).ToArray();
            if (attrs.Length > 1)
                throw new Exception("panic: multiple AssemblySourceVersionAttribute attributes.");
            if (attrs.Length == 0) return "00000000";

            var version = (string) attrs[0].ConstructorArguments[0].Value;
            var hasLocalChanges = (bool) attrs[0].ConstructorArguments[1].Value;
            return new AssemblySourceVersionAttribute(version, hasLocalChanges).ToString();
        }

        public string Set(string filename)
        {
            // get git version
            var gitPath = Path.GetDirectoryName(Path.GetFullPath(Path.IsPathRooted(filename) ? filename : Path.Combine(Directory.GetCurrentDirectory(), filename)));
            (var version, var hasLocalChanges) = GetGitVersion(gitPath);

            // get assembly and module
            var assembly = AssemblyDefinition.ReadAssembly(filename);
            var module = assembly.MainModule;

            // remove existing attributes, if any
            var attributeTypeName = typeof(AssemblySourceVersionAttribute).FullName;
            var existingAttributes = assembly.CustomAttributes.Where(x => x.AttributeType.FullName == attributeTypeName).ToList();
            foreach (var existingAttribute in existingAttributes)
                assembly.CustomAttributes.Remove(existingAttribute);

            // create and add the new attribute
            var ctor = typeof(AssemblySourceVersionAttribute).GetConstructor(new[] { typeof(string), typeof(bool) });
            var attribute = new CustomAttribute(module.Import(ctor));
            attribute.ConstructorArguments.Add(new CustomAttributeArgument(module.TypeSystem.String, version));
            attribute.ConstructorArguments.Add(new CustomAttributeArgument(module.TypeSystem.Boolean, hasLocalChanges));
            assembly.CustomAttributes.Add(attribute);

            // write the assembly
            assembly.Write(filename);

            return new AssemblySourceVersionAttribute(version, hasLocalChanges).ToString();
        }

        private static (string, bool) GetGitVersion(string path)
        {
            while (path != null && !Directory.EnumerateDirectories(path, ".git").Any())
                path = Path.GetDirectoryName(path);

            if (path == null)
                return ("00000000", false);

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
                return ("00000000", false);
            }
        }
    }
}
