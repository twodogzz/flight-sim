using GMap.NET.WindowsPresentation;
using Simfocus_Helipad_Manager_Map.Models;
using Simfocus_Helipad_Manager_Map.Services;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Simfocus_Helipad_Manager_Map.Controls
{
    public partial class HelipadInfoPanel : UserControl
    {
        private Helipad _helipad;
        private GMapMarker _marker;

        public HelipadInfoPanel()
        {
            InitializeComponent();
        }

        public void LoadHelipad(Helipad h, GMapMarker marker)
        {
            _helipad = h;
            _marker = marker;

            IdentText.Text = $"Ident: {h.Ident}";
            NameText.Text = $"Name: {h.Name}";
            PathText.Text = string.IsNullOrEmpty(h.BglPath) ? "No BGL match" : h.BglPath;
            ToggleButton.IsEnabled = !string.IsNullOrEmpty(h.BglPath);

            ToggleButton.Click += (s, e) =>
            {
                if (FileToggler.TryToggle(h.BglPath, out var newPath, out var message))
                {
                    h.BglPath = newPath;
                    PathText.Text = newPath;
                    MessageBox.Show(message);

                    if (_marker?.Shape is Ellipse ellipse)
                    {
                        ellipse.Fill = string.IsNullOrEmpty(h.BglPath) ? Brushes.Red : Brushes.Green;
                    }
                }
                else
                {
                    MessageBox.Show(message);
                }
            };
        }
    }
}