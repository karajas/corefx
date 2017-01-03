using System;
using System.Reflection;

namespace Microsoft.DotNet.Build.Tasks
{
    public partial class GenerateDepsJson
    {
        public bool IsNativeAssembly(string file, out AssemblyName result)
        {
            result = null;
            try
            {
                result = AssemblyName.GetAssemblyName(file);
            }
            catch (BadImageFormatException)
            {
                // not a PE
                return true;
            }
            return false;
        }
    }
}
