using System;

namespace Umbraco.Build.Attributes
{
    [AttributeUsage(AttributeTargets.Assembly /*, AllowMultiple = false, Inherited = false*/)]
    public class AssemblySourceVersionAttribute : Attribute
    {
        public AssemblySourceVersionAttribute(string version, bool hasLocalChanges)
        {
            Version = version.TrimEnd('+');
            HasLocalChanges = hasLocalChanges;
        }

        public string Version { get; }
        public bool HasLocalChanges { get; }

        public override string ToString()
        {
            return HasLocalChanges ? Version + "+" : Version;
        }
    }
}
