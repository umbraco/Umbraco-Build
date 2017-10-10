using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;

namespace Umbraco.Build.Tasks
{
    /*
     *  <UsingTask TaskName="Umbraco.Build.Tasks.SetAssemblySourceVersion" AssemblyFile="$(SolutionDir)..\packages\Umbraco.Build\Umbraco.Build.dll" />
     *  <Target Name="AfterBuild">
     *    <SetAssemblySourceVersion AssemblyFile="$(ProjectDir)bin\$(Configuration)\MyDll.dll" />
     *  </Target>
     */

    public class SetAssemblySourceVersion : Task
    {
        [Required]
        public string AssemblyFile { get; set; }

        public override bool Execute()
        {
            var assemblySourceVersion = new AssemblySourceVersion();
            var version = assemblySourceVersion.Set(AssemblyFile);
            Log.LogMessage(MessageImportance.Normal, $"Set source version on {AssemblyFile} to {version}.");
            return true;
        }
    }
}
