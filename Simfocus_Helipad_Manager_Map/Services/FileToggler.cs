using System.IO;
using System;

namespace Simfocus_Helipad_Manager_Map.Services
{
    public static class FileToggler
    {
        public static bool TryToggle(string bglPath, out string resultPath, out string message)
        {
            resultPath = bglPath;
            try
            {
                if (bglPath.EndsWith(".OFF", StringComparison.OrdinalIgnoreCase))
                {
                    var newPath = Path.ChangeExtension(bglPath, ".bgl");
                    File.Move(bglPath, newPath);
                    resultPath = newPath;
                    message = $"Restored: {Path.GetFileName(newPath)}";
                    return true;
                }
                else if (bglPath.EndsWith(".bgl", StringComparison.OrdinalIgnoreCase))
                {
                    var newPath = Path.ChangeExtension(bglPath, ".OFF");
                    File.Move(bglPath, newPath);
                    resultPath = newPath;
                    message = $"Disabled: {Path.GetFileName(newPath)}";
                    return true;
                }

                message = "Unsupported file extension.";
                return false;
            }
            catch (Exception ex)
            {
                message = $"Toggle failed: {ex.Message}";
                return false;
            }
        }
    }
}