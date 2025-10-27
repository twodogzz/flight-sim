namespace Simfocus_Helipad_Manager_Map.Models
{
    public class Helipad
    {
        public string Type { get; set; } = string.Empty;           // e.g., Other, Location
        public string Name { get; set; } = string.Empty;           // e.g., Autogen Helipad HXZB3
        public string Ident { get; set; } = string.Empty;          // e.g., HXZB3
        public double Latitude { get; set; }                       // degrees
        public double Longitude { get; set; }                      // degrees
        public double Elevation { get; set; }                      // meters
        public double MagneticDeclination { get; set; }            // degrees
        public string Tags { get; set; } = string.Empty;           // e.g., "Autogen", "hospital"
        public string Description { get; set; } = string.Empty;    // optional/free text

        // Augmented fields (filled after scanning MSFS Community folder)
        public string? BglPath { get; set; }                       // matched scenery file
        public bool IsOff => BglPath != null && BglPath.EndsWith(".OFF", StringComparison.OrdinalIgnoreCase);
    }
}