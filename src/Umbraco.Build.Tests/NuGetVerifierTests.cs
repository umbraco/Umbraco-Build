using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Umbraco.Build.Tests
{
    [TestFixture]
    public class NuGetVerifierTests
    {
        [Test]
        public void Test()
        {
            var path = Assembly.GetExecutingAssembly().Location;
            for (var i = 0; i < 5; i++)
                path = Path.GetDirectoryName(path);

            var verifier = new NuGetVerifier();
            var deps = verifier.GetNuSpecDependencies(Path.Combine(path, "UmbracoCms.Web.nuspec"));
        }
    }
}
