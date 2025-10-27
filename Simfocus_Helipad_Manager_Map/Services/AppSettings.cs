using System.IO;
using System.Text.Json;

namespace Simfocus_Helipad_Manager_Map.Services
{
    public static class AppSettings
    {
        private static readonly string SettingsPath =
            Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.ApplicationData),
                         "Simfocus_Helipad_Manager_Map", "settings.json");

        public static string? CommunityFolder { get; set; }

        public static void Load()
        {
            if (!File.Exists(SettingsPath)) return;
            var json = File.ReadAllText(SettingsPath);
            var dto = JsonSerializer.Deserialize<SettingsDto>(json);
            CommunityFolder = dto?.CommunityFolder;
        }

        public static void Save()
        {
            var dir = Path.GetDirectoryName(SettingsPath)!;
            Directory.CreateDirectory(dir);
            var dto = new SettingsDto { CommunityFolder = CommunityFolder };
            var json = JsonSerializer.Serialize(dto, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsPath, json);
        }

        private class SettingsDto { public string? CommunityFolder { get; set; } }
    }
}