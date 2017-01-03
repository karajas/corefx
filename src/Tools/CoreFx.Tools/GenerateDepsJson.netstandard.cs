using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Text.RegularExpressions;
using Microsoft.Build.Framework;

namespace Microsoft.DotNet.Build.Tasks
{ 
    public partial class GenerateDepsJson: BuildTask
    {
        public bool IsNativeAssembly(string file, out AssemblyName result)
        {
            result = null;
            try
            {
                using (
                    FileStream assemblyStream = new FileStream(file, FileMode.Open, FileAccess.Read,
                        FileShare.Delete | FileShare.Read))
                using (PEReader peReader = new PEReader(assemblyStream, PEStreamOptions.LeaveOpen))
                {
                    if (peReader.HasMetadata)
                    {
                        MetadataReader reader = peReader.GetMetadataReader();
                        if (reader.IsAssembly)
                        {
                            AssemblyDefinition assemblyDef = reader.GetAssemblyDefinition();

                            result = new AssemblyName();
                            result.Name = reader.GetString(assemblyDef.Name);
                            result.CultureName = reader.GetString(assemblyDef.Culture);
                            result.Version = assemblyDef.Version;

                            if (!assemblyDef.PublicKey.IsNil)
                            {
                                result.SetPublicKey(reader.GetBlobBytes(assemblyDef.PublicKey));
                            }
                        }
                    }
                    else
                    {
                        //Native
                        return true;
                    }
                }
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
