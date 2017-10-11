using System;
using System.IO;
using System.Reflection;

namespace Umbraco.Build
{
    // PowerShell can have a hard time locating and loading assemblies

    internal static class AssemblyResolver
    {
        private static string _path;
        private static readonly object Locker = new object();

        public static void EnsureInitialized()
        {
            lock (Locker)
            {
                if (_path != null) return;
                _path = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

                AppDomain.CurrentDomain.AssemblyResolve += (sender, args) =>
                {
                    var debug = Environment.GetEnvironmentVariable("UMBRACO_BUILD_DEBUG") == "1";
                    var pos = args.Name.IndexOf(',');
                    var name = pos > 0 ? args.Name.Substring(0, pos) : args.Name;
                    var assemblyPath = Path.Combine(_path, name + ".dll");
                    var exists = File.Exists(assemblyPath);
                    if (debug)
                        Console.WriteLine("Resolve{0} {1}.", exists ? "+" : "-", args.Name);
                    return exists
                        ? Assembly.LoadFrom(assemblyPath)
                        : null;
                };
            }
        }
    }
}
