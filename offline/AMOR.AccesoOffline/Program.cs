namespace AMOR.AccesoOffline;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        using var instancia = new Mutex(true, "Local\\AMOR.AccesoOffline.v2", out var nueva);
        if (!nueva)
        {
            MessageBox.Show("El control de acceso ya está abierto en esta sesión de Windows.");
            return;
        }
        try
        {
            using var api = new ApiCliente();
            Application.Run(new Form1(api));
        }
        catch (Exception)
        {
            MessageBox.Show("No se pudo abrir el programa. Revisa que esté extraída la carpeta completa y que tu cuenta de Windows tenga acceso a sus datos locales.",
                "AMOR · Acceso Offline", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
