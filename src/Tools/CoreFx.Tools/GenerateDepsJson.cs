using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.Build.Framework;

namespace Microsoft.DotNet.Build.Tasks
{
    public partial class GenerateDepsJson : BuildTask
    {
        [Required]
        public string DepsJsonPath { get; set; }

        public override bool Execute()
        {
            List<string> filesInDir = Directory.EnumerateFiles(Path.GetDirectoryName(DepsJsonPath)).ToList();

            List<AssemblyName> assemblyNames = new List<AssemblyName>();
            foreach (string file in filesInDir)
            {
                AssemblyName result;
                if (IsNativeAssembly(file, out result)) continue;
                assemblyNames.Add(result);
            }

            string contents = "";

            using (StreamReader streamReader = new StreamReader(new FileStream(DepsJsonPath, FileMode.Open)))
            {
                contents = streamReader.ReadToEnd();
            }

            foreach (var temp in assemblyNames)
            {
                string value = temp.Name + "/";
                var matchString = temp.Name + @"\/\d.\d.\d+";
                MatchCollection matchCollection = Regex.Matches(contents, matchString);
                if (matchCollection.Count > 0)
                {
                    foreach (Match match in matchCollection)
                    {
                        contents = contents.Replace(match.Value,
                            temp.Name + "/" + temp.Version.Major + "." + temp.Version.Minor + "." + temp.Version.Build);
                    }
                }
                else
                {
                    string toFind = "\".NETCoreApp,Version=v1.0/win7-x64\": {";
                    string thingToAdd =
                        $"\r\n\"{temp.Name}/{temp.Version.Major}.{temp.Version.Minor}.{temp.Version.Build}\": {{\"runtime\": {{\r\n          \"lib/netstandard1.3/{temp.Name}.dll\": {{}}\r\n      }} }},";

                    contents = contents.Replace(toFind, toFind + thingToAdd);

                    toFind = "\"libraries\": {";
                    thingToAdd =
                        $"\r\n    \"{temp.Name}/{temp.Version.Major}.{temp.Version.Minor}.{temp.Version.Build}\": {{\r\n      \"type\": \"package\",\r\n      \"serviceable\": true,\r\n      \"sha512\": \"\"}},";
                    contents = contents.Replace(toFind, toFind + thingToAdd);

                }
            }

            using (StreamWriter sw = new StreamWriter(new FileStream(DepsJsonPath, FileMode.Truncate)))
            {
                sw.Write(contents);
            }

            return !Log.HasLoggedErrors;
        }
    }
}
