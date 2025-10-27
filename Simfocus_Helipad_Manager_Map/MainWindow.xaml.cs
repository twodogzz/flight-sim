using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using GMap.NET;
using GMap.NET.MapProviders;
using GMap.NET.WindowsPresentation;
using Simfocus_Helipad_Manager_Map.Models;
using Simfocus_Helipad_Manager_Map.Services;

namespace Simfocus_Helipad_Manager_Map
{
    public partial class MainWindow : Window
    {
        private List<Helipad> _helipads = new();
        private DispatcherTimer _debounceTimer;

        public MainWindow()
        {
            InitializeComponent();
            AppSettings.Load();

            // Initialize GMap.NET
            MapControl.MapProvider = GMapProviders.OpenStreetMap;
            MapControl.Position = new PointLatLng(-27.4698, 153.0251); // Brisbane
            MapControl.ShowCenter = false;

            // Setup debounce timer
            _debounceTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromMilliseconds(400)
            };
            _debounceTimer.Tick += (s, e) =>
            {
                _debounceTimer.Stop();
                PlotHelipadsOnMap();
            };

            // Hook into zoom & pan events
            MapControl.OnMapZoomChanged += () => RestartDebounce();
            MapControl.OnMapDrag += () => RestartDebounce();
        }

        private void RestartDebounce()
        {
            _debounceTimer.Stop();
            _debounceTimer.Start();
        }

        // --- Menu: Load CSV ---
        private void LoadCsv_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFileDialog
            {
                Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
            };

            if (dialog.ShowDialog() == true)
            {
                _helipads = CsvLoader.Load(dialog.FileName);
                MessageBox.Show($"Loaded {_helipads.Count} helipads.");

                if (!string.IsNullOrEmpty(AppSettings.CommunityFolder))
                {
                    var identMap = BglIndex.BuildIdentMap(AppSettings.CommunityFolder);
                    BglIndex.AttachMatchesToHelipads(_helipads, identMap);

                    int matched = _helipads.Count(h => !string.IsNullOrEmpty(h.BglPath));
                    MessageBox.Show($"Matched {matched} helipads to BGL files.");
                }

                PlotHelipadsOnMap();
            }
        }

        // --- Menu: Select Community Folder ---
        private void SelectCommunity_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFileDialog
            {
                CheckFileExists = false,
                CheckPathExists = true,
                FileName = "Select this folder"
            };

            if (dialog.ShowDialog() == true)
            {
                var folder = System.IO.Path.GetDirectoryName(dialog.FileName);
                if (!string.IsNullOrEmpty(folder))
                {
                    AppSettings.CommunityFolder = folder;
                    AppSettings.Save();
                    MessageBox.Show($"Community folder set:\n{folder}");
                }
            }
        }

        // --- Menu: Index BGLs ---
        private void IndexBgls_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(AppSettings.CommunityFolder))
            {
                MessageBox.Show("Set the Community folder first.");
                return;
            }

            var identMap = BglIndex.BuildIdentMap(AppSettings.CommunityFolder);
            BglIndex.AttachMatchesToHelipads(_helipads, identMap);

            int matched = _helipads.Count(h => !string.IsNullOrEmpty(h.BglPath));
            MessageBox.Show($"Indexed {identMap.Count} BGLs. Matched {matched} helipads.");

            PlotHelipadsOnMap();
        }

        // --- Plot helipads with clustering + viewport filtering ---
        private void PlotHelipadsOnMap()
        {
            MapControl.Markers.Clear();
            if (_helipads == null || _helipads.Count == 0) return;

            // Get current viewport bounds
            var rect = MapControl.ViewArea;
            if (rect.IsEmpty) return;

            var visibleHelipads = _helipads.Where(h =>
                h.Latitude <= rect.Top &&
                h.Latitude >= rect.Bottom &&
                h.Longitude >= rect.Left &&
                h.Longitude <= rect.Right).ToList();

            if (visibleHelipads.Count == 0) return;

            // Grid size based on zoom
            double gridSizeDeg;
            if (MapControl.Zoom < 5) gridSizeDeg = 5.0;
            else if (MapControl.Zoom < 8) gridSizeDeg = 1.0;
            else if (MapControl.Zoom < 12) gridSizeDeg = 0.2;
            else gridSizeDeg = 0.05;

            var clusters = new Dictionary<(int, int), List<Helipad>>();

            foreach (var h in visibleHelipads)
            {
                int cellX = (int)(h.Longitude / gridSizeDeg);
                int cellY = (int)(h.Latitude / gridSizeDeg);
                var key = (cellX, cellY);

                if (!clusters.ContainsKey(key))
                    clusters[key] = new List<Helipad>();

                clusters[key].Add(h);
            }

            foreach (var cluster in clusters.Values)
            {
                if (cluster.Count == 1)
                {
                    var h = cluster[0];
                    var marker = new GMapMarker(new PointLatLng(h.Latitude, h.Longitude))
                    {
                        Shape = new Ellipse
                        {
                            Width = 8,
                            Height = 8,
                            Stroke = Brushes.Black,
                            StrokeThickness = 1,
                            Fill = string.IsNullOrEmpty(h.BglPath) ? Brushes.Red : Brushes.Green
                        },
                        Tag = h
                    };

                    marker.Shape.MouseLeftButtonUp += (s, e) =>
                    {
                        if (!string.IsNullOrEmpty(h.BglPath))
                        {
                            if (FileToggler.TryToggle(h.BglPath, out var newPath, out var message))
                            {
                                h.BglPath = newPath;
                                MessageBox.Show(message);
                                PlotHelipadsOnMap();
                            }
                            else
                            {
                                MessageBox.Show(message);
                            }
                        }
                    };

                    MapControl.Markers.Add(marker);
                }
                else
                {
                    double avgLat = cluster.Average(h => h.Latitude);
                    double avgLon = cluster.Average(h => h.Longitude);

                    var marker = new GMapMarker(new PointLatLng(avgLat, avgLon))
                    {
                        Shape = new Border
                        {
                            Width = 28,
                            Height = 28,
                            CornerRadius = new CornerRadius(14),
                            Background = Brushes.Blue,
                            BorderBrush = Brushes.White,
                            BorderThickness = new Thickness(2),
                            Child = new TextBlock
                            {
                                Text = cluster.Count.ToString(),
                                Foreground = Brushes.White,
                                FontWeight = FontWeights.Bold,
                                HorizontalAlignment = HorizontalAlignment.Center,
                                VerticalAlignment = VerticalAlignment.Center,
                                TextAlignment = TextAlignment.Center
                            }
                        },
                        Tag = cluster
                    };

                    MapControl.Markers.Add(marker);
                }
            }
        }
    }
}