using System.Collections.Generic;
using System.IO;
using Simfocus_Helipad_Manager_Map.Models;

namespace Simfocus_Helipad_Manager_Map.Services
{
    public static class BglIndex
    {
        public static Dictionary<string, string> BuildIdentMap(string communityFolder)
        {
            var map = new Dictionary<string, string>(System.StringComparer.OrdinalIgnoreCase);

            foreach (var file in Directory.EnumerateFiles(communityFolder, "*.bgl", SearchOption.AllDirectories))
            {
                var ident = ExtractIdentFromFilename(file);
                if (!string.IsNullOrEmpty(ident) && !map.ContainsKey(ident))
                {
                    map[ident] = file;
                }
            }

            foreach (var file in Directory.EnumerateFiles(communityFolder, "*.OFF", SearchOption.AllDirectories))
            {
                var ident = ExtractIdentFromFilename(file);
                if (!string.IsNullOrEmpty(ident) && !map.ContainsKey(ident))
                {
                    map[ident] = file;
                }
            }

            return map;
        }

        private static string? ExtractIdentFromFilename(string path)
        {
            var name = Path.GetFileNameWithoutExtension(path);
            if (string.IsNullOrEmpty(name)) return null;

            var parts = name.Split('_');
            if (parts.Length < 2) return null;

            return parts[^1]; // last token after underscore
        }

        // 👇 This is the AttachMatchesToHelipads method
        public static void AttachMatchesToHelipads(
            List<Helipad> helipads,
            Dictionary<string, string> identMap)
        {
            foreach (var h in helipads)
            {
                if (identMap.TryGetValue(h.Ident, out var path))
                {
                    h.BglPath = path;
                }
            }
        }
    }
}