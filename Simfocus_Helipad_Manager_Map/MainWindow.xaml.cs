using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using Simfocus_Helipad_Manager_Map.Models;
using Simfocus_Helipad_Manager_Map.Services;

namespace Simfocus_Helipad_Manager_Map
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            Loaded += MainWindow_Loaded;
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            var config = LoadUserConfig();
            if (config == null)
            {
                StatusText.Text = "No saved config found.";
                return;
            }

            if (!File.Exists(config.CsvPath) || !Directory.Exists(config.CommunityFolder))
            {
                StatusText.Text = "Saved paths are invalid.";
                return;
            }

            try
            {
                var helipads = CsvLoader.Load(config.CsvPath);
                var bglIndex = BglIndexer.Index(config.CommunityFolder);
                BglMatcher.Match(helipads, bglIndex);

                PlotHelipadsOnMap(helipads);

                int matched = helipads.Count(h => !string.IsNullOrEmpty(h.BglPath));
                StatusText.Text = $"Loaded {helipads.Count} helipads — {matched} matched to BGLs.";
            }
            catch (Exception ex)
            {
                StatusText.Text = $"Error loading data: {ex.Message}";
            }
        }

        private UserConfig LoadUserConfig()
        {
            const string path = "userconfig.json";
            if (!File.Exists(path)) return null;

            try
            {
                var json = File.ReadAllText(path);
                return JsonSerializer.Deserialize<UserConfig>(json);
            }
            catch
            {
                return null;
            }
        }

        private class UserConfig
        {
            public string CsvPath { get; set; }
            public string CommunityFolder { get; set; }
        }

        // Your existing event handlers:
        private void LoadCsv_Click(object sender, RoutedEventArgs e)
        {
            // Your CSV load logic here
        }

        private void SelectCommunity_Click(object sender, RoutedEventArgs e)
        {
            // Your folder selection logic here
        }

        private void IndexBgls_Click(object sender, RoutedEventArgs e)
        {
            // Your BGL indexing logic here
        }
    }
}