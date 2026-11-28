using System.Security.Cryptography;
using System.Text;

namespace AMOR.AccesoOffline;

public static class Proteccion
{
    private static readonly byte[] Entropia = Encoding.UTF8.GetBytes("AMOR.AccesoOffline.v2");
    public static byte[] Proteger(byte[] datos) =>
        ProtectedData.Protect(datos, Entropia, DataProtectionScope.CurrentUser);
    public static byte[] Abrir(byte[] datos) =>
        ProtectedData.Unprotect(datos, Entropia, DataProtectionScope.CurrentUser);
    public static string Proteger(string datos) =>
        Convert.ToBase64String(Proteger(Encoding.UTF8.GetBytes(datos)));
    public static string Abrir(string datos) =>
        Encoding.UTF8.GetString(Abrir(Convert.FromBase64String(datos)));
    public static void GuardarAtomico(string ruta, byte[] datos)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(ruta)!);
        var temporal = ruta + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var f = new FileStream(temporal, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                f.Write(datos);
                f.Flush(true);
            }
            File.Move(temporal, ruta, true);
        }
        finally { if (File.Exists(temporal)) File.Delete(temporal); }
    }
}
