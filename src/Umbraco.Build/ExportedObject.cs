namespace Umbraco.Build
{
    public abstract class ExportedObject
    {
        protected ExportedObject()
        {
            AssemblyResolver.EnsureInitialized();
        }
    }
}
