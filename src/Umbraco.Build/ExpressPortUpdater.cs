using System.Globalization;
using System.IO;
using System.Xml;

namespace Umbraco.Build
{
    public class ExpressPortUpdater : ExportedObject
    {
        public void Update(string path, string release)
        {
            var xmlDocument = new XmlDocument();
            var fullPath = Path.GetFullPath(path);
            xmlDocument.Load(fullPath);
            int.TryParse(release.Replace(".", ""), out int result);
            while (result < 1024)
                result *= 10;
            var xmlNode1 = xmlDocument.GetElementsByTagName("IISUrl").Item(0);
            if (xmlNode1 != null)
                xmlNode1.InnerText = "http://localhost:" + result;
            var xmlNode2 = xmlDocument.GetElementsByTagName("DevelopmentServerPort").Item(0);
            if (xmlNode2 != null)
                xmlNode2.InnerText = result.ToString(CultureInfo.InvariantCulture);
            xmlDocument.Save(fullPath);
        }
    }
}
