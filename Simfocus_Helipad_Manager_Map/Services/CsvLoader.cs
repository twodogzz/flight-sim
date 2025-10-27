using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using Simfocus_Helipad_Manager_Map.Models;

namespace Simfocus_Helipad_Manager_Map.Services
{
    public static class CsvLoader
    {
        public static List<Helipad> Load(string filePath)
        {
            var helipads = new List<Helipad>();

            Console.WriteLine("📁 CsvLoader.Load() called");

            if (!File.Exists(filePath))
            {
                Console.WriteLine($"❌ File not found: {filePath}");
                return helipads;
            }

            foreach (var rawLine in File.ReadLines(filePath, Encoding.UTF8))
            {
                var line = rawLine.Trim();
                if (string.IsNullOrEmpty(line)) continue;

                var parts = SplitCsvLine(line);
                Console.WriteLine($"🔍 Parsed {parts.Count} columns: {string.Join(" | ", parts)}");

                if (parts.Count < 8)
                {
                    Console.WriteLine($"❌ Skipped line (too few columns): {line}");
                    continue;
                }

                bool okLat = double.TryParse(parts[3], NumberStyles.Float, CultureInfo.InvariantCulture, out double lat);
                bool okLon = double.TryParse(parts[4], NumberStyles.Float, CultureInfo.InvariantCulture, out double lon);
                bool okElev = double.TryParse(parts[5], NumberStyles.Float, CultureInfo.InvariantCulture, out double elev);
                bool okDecl = double.TryParse(parts[6], NumberStyles.Float, CultureInfo.InvariantCulture, out double decl);

                if (!okLat || !okLon || !okElev || !okDecl)
                {
                    Console.WriteLine($"❌ Skipped line (parse fail): {line}");
                    continue;
                }

                string tags = Unquote(parts[7]);
                string description = parts.Count > 8 ? Unquote(parts[8]) : string.Empty;

                var helipad = new Helipad
                {
                    Type = parts[0].Trim(),
                    Name = parts[1].Trim(),
                    Ident = parts[2].Trim(),
                    Latitude = lat,
                    Longitude = lon,
                    Elevation = elev,
                    MagneticDeclination = decl,
                    Tags = tags,
                    Description = description
                };

                helipads.Add(helipad);
                Console.WriteLine($"✅ Loaded helipad: {helipad.Ident} at {lat}, {lon}");
            }

            return helipads;
        }

        private static List<string> SplitCsvLine(string line)
        {
            var result = new List<string>();
            var sb = new StringBuilder();
            bool inQuotes = false;

            for (int i = 0; i < line.Length; i++)
            {
                char c = line[i];
                if (c == '"')
                {
                    if (inQuotes && i + 1 < line.Length && line[i + 1] == '"')
                    {
                        sb.Append('"');
                        i++;
                    }
                    else
                    {
                        inQuotes = !inQuotes;
                    }
                }
                else if (c == ',' && !inQuotes)
                {
                    result.Add(sb.ToString());
                    sb.Clear();
                }
                else
                {
                    sb.Append(c);
                }
            }
            result.Add(sb.ToString());
            return result;
        }

        private static string Unquote(string s)
        {
            s = s.Trim();
            if (s.Length >= 2 && s[0] == '"' && s[^1] == '"')
                s = s.Substring(1, s.Length - 2);
            return s;
        }
    }
}