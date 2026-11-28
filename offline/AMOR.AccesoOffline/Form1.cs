using System.Drawing;
using System.IO.Compression;

namespace AMOR.AccesoOffline;

public sealed class Form1 : Form
{
    private readonly ApiCliente api;
    private readonly string? raiz;
    private BaseDatosLocal local;
    private readonly Guid dispositivo;
    private readonly Color rosa = Color.FromArgb(163, 52, 96);
    private readonly ComboBox eventos = new() { Name = "Eventos", DropDownStyle = ComboBoxStyle.DropDownList, Width = 395 };
    private readonly TextBox txtQR = new()
    {
        Name = "CodigoQR",
        Dock = DockStyle.Fill,
        Font = new Font("Segoe UI", 18),
        PlaceholderText = "Coloca el cursor aquí y escanea con el lector USB"
    };
    private readonly Label estado = new()
    {
        Name = "EstadoAcceso",
        Dock = DockStyle.Fill,
        TextAlign = ContentAlignment.MiddleCenter,
        Font = new Font("Segoe UI", 15, FontStyle.Bold),
        Text = "ESPERANDO LECTURA DEL QR"
    };
    private readonly Label datos = new()
    {
        Dock = DockStyle.Fill,
        Font = new Font("Segoe UI", 14),
        Padding = new Padding(20),
        Text = "Nombre: —\n\nFolio: —\n\nAsesor: —\n\nGrupo: —"
    };
    private readonly Label resumen = new() { Name = "Resumen", AutoSize = false, Dock = DockStyle.Top, Height = 76, Padding = new Padding(15, 8, 10, 0) };
    private readonly Label actividad = new() { Dock = DockStyle.Bottom, Height = 38, Padding = new Padding(15, 6, 10, 4), Text = "Modo offline: las entradas se guardan en esta laptop." };
    private readonly PictureBox foto = new() { Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.Zoom, BackColor = Color.FromArgb(248, 231, 239) };
    private readonly Button autorizar = new()
    {
        Name = "Autorizar",
        Text = "AUTORIZAR ENTRADA",
        Dock = DockStyle.Fill,
        Height = 60,
        Enabled = false,
        Font = new Font("Segoe UI", 17, FontStyle.Bold)
    };
    private readonly FlowLayoutPanel herramientas = new() { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(12), WrapContents = true };
    private readonly Button cancelar = new() { Text = "Cancelar operación", AutoSize = true, Visible = false };
    private CancellationTokenSource? operacion;
    private string tokenActual = "";
    public Form1(ApiCliente cliente, string? carpeta = null, Guid? equipo = null)
    {
        api = cliente; raiz = carpeta; dispositivo = equipo ?? BaseDatosLocal.DispositivoId;
        local = new(Evento.Todos[0].Id, raiz);
        Text = "AMOR 2026 · Control de Acceso Offline · 2.0.0";
        Size = new Size(1180, 800); MinimumSize = new Size(940, 680);
        StartPosition = FormStartPosition.CenterScreen; BackColor = Color.FromArgb(255, 246, 250);
        Font = new Font("Segoe UI", 11); AutoScaleMode = AutoScaleMode.Dpi;
        var titulo = new Label
        {
            Text = "JOYERÍA AMOR DE LOS DOS · ACCESO SIN INTERNET",
            Dock = DockStyle.Top,
            Height = 64,
            TextAlign = ContentAlignment.MiddleCenter,
            BackColor = rosa,
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 20, FontStyle.Bold)
        };
        eventos.DataSource = Evento.Todos;
        eventos.SelectedIndexChanged += (_, _) => CambiarEvento();
        herramientas.Controls.Add(eventos);
        AgregarBoton("Conectar cuenta", Conectar);
        AgregarBoton("Descargar datos y fotos", Descargar);
        AgregarBoton("Sincronizar entradas", Sincronizar);
        AgregarBoton("Ver entradas", VerEntradas);
        AgregarBoton("Respaldar", Respaldar);
        cancelar.Click += (_, _) => operacion?.Cancel();
        herramientas.Controls.Add(cancelar);
        var panel = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(20), ColumnCount = 2, RowCount = 4 };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 65));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 82));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));
        panel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 74));
        var campo = new Panel { Dock = DockStyle.Fill };
        var indicacion = new Label
        {
            Text = "ESCANEA EL QR CON EL LECTOR USB",
            Dock = DockStyle.Top,
            Height = 26,
            ForeColor = rosa,
            Font = new Font("Segoe UI", 11, FontStyle.Bold)
        };
        txtQR.Dock = DockStyle.Bottom; txtQR.AccessibleName = "Código QR de la invitación";
        campo.Controls.Add(txtQR); campo.Controls.Add(indicacion);
        panel.Controls.Add(campo, 0, 0); panel.SetColumnSpan(campo, 2);
        panel.Controls.Add(estado, 0, 1); panel.SetColumnSpan(estado, 2);
        var fichaPanel = new Panel { Name = "DatosParticipante", Dock = DockStyle.Fill, AutoScroll = true };
        datos.AutoSize = true; datos.Dock = DockStyle.Top;
        fichaPanel.Resize += (_, _) => datos.MaximumSize =
            new Size(Math.Max(200, fichaPanel.ClientSize.Width - SystemInformation.VerticalScrollBarWidth), 0);
        fichaPanel.Controls.Add(datos);
        panel.Controls.Add(foto, 0, 2); panel.Controls.Add(fichaPanel, 1, 2);
        panel.Controls.Add(autorizar, 0, 3); panel.SetColumnSpan(autorizar, 2);
        autorizar.BackColor = rosa; autorizar.ForeColor = Color.White; autorizar.FlatStyle = FlatStyle.Flat;
        Controls.Add(panel); Controls.Add(resumen); Controls.Add(herramientas); Controls.Add(titulo); Controls.Add(actividad);
        txtQR.KeyDown += (_, e) =>
        {
            if (e.KeyCode == Keys.Enter)
            {
                e.SuppressKeyPress = true; var lectura = txtQR.Text.Trim(); txtQR.Clear();
                if (lectura.Length > 0) Leer(lectura);
            }
        };
        autorizar.Click += (_, _) => Autorizar();
        Shown += (_, _) =>
        {
            var disponible = Screen.FromControl(this).WorkingArea;
            if (Width > disponible.Width || Height > disponible.Height) WindowState = FormWindowState.Maximized;
            txtQR.Focus();
        };
        FormClosing += (_, e) => { if (operacion is not null) { e.Cancel = true; operacion.Cancel(); actividad.Text = "Terminando la operación antes de cerrar…"; } };
        FormClosed += (_, _) => foto.Image?.Dispose();
        ActualizarResumen();
    }
    private void AgregarBoton(string texto, Action accion)
    {
        var b = new Button { Text = texto, AutoSize = true, Padding = new Padding(6), ForeColor = rosa };
        b.Click += (_, _) => accion(); herramientas.Controls.Add(b);
    }
    private void CambiarEvento()
    {
        if (eventos.SelectedItem is not Evento e) return;
        local = new(e.Id, raiz); Limpiar(); ActualizarResumen();
    }
    private void Limpiar()
    {
        tokenActual = ""; autorizar.Enabled = false; txtQR.Clear();
        datos.Text = "Nombre: —\n\nFolio: —\n\nAsesor: —\n\nGrupo: —";
        var anterior = foto.Image; foto.Image = null; anterior?.Dispose();
        estado.Text = "ESPERANDO LECTURA DEL QR"; estado.ForeColor = rosa;
    }
    private void ActualizarResumen()
    {
        var r = local.Resumen();
        resumen.Text = $"Participantes descargados: {r.Participantes}   |   Fotos: {r.Fotos}   |   Entradas locales: {r.Entradas}   |   Pendientes: {r.Pendientes}   |   Por revisar: {r.Conflictos}\n" +
            (r.Descarga is null ? "Aún no hay una descarga para este evento. Conecta tu cuenta y descarga con internet." :
            $"Datos del {r.Descarga.Value.ToLocalTime():dd/MM/yyyy HH:mm}. Actualízalos antes de abrir el acceso. Válidos hasta {r.Expira!.Value.ToLocalTime():dd/MM/yyyy HH:mm}.");
    }
    private void Leer(string token)
    {
        Limpiar();
        try
        {
            var ficha = local.Consultar(token);
            datos.Text = $"Nombre: {ficha.Nombre}\n\nFolio: {ficha.Folio}\n\nAsesor: {ficha.Asesor}\n\nGrupo: {ficha.Grupo}";
            estado.Text = ficha.Estado switch
            {
                "autorizable" => "ACCESO AUTORIZABLE · VERIFICA LA FOTOGRAFÍA",
                "ya_ingreso" => "ESTA PERSONA YA INGRESÓ",
                "sin_pago" => "SIN PAGO VALIDADO",
                "revocada" => "INVITACIÓN REVOCADA",
                "no_confirmado" => "REGISTRO NO CONFIRMADO",
                "sin_descarga" => "PRIMERO DESCARGA LOS DATOS DE ESTE EVENTO",
                "paquete_vencido" => "DESCARGA VENCIDA · ACTUALIZA EL EVENTO",
                "revisar_reloj" => "REVISA LA FECHA Y HORA DE LA LAPTOP",
                _ => "QR NO RECONOCIDO EN ESTE EVENTO"
            };
            estado.ForeColor = ficha.Estado == "autorizable" ? Color.DarkGreen : Color.DarkRed;
            if (ficha.FotoPath != "" && File.Exists(local.RutaSegura(ficha.FotoPath)))
            {
                using var stream = new MemoryStream(Proteccion.Abrir(File.ReadAllBytes(local.RutaSegura(ficha.FotoPath))));
                using var imagen = System.Drawing.Image.FromStream(stream);
                foto.Image = new Bitmap(imagen);
            }
            tokenActual = token.Trim();
            autorizar.Enabled = ficha.Estado == "autorizable" && operacion is null;
        }
        catch
        {
            estado.Text = "NO SE PUDO LEER LA FICHA LOCAL. NO SE AUTORIZÓ LA ENTRADA.";
            estado.ForeColor = Color.DarkRed; autorizar.Enabled = false; tokenActual = "";
        }
        txtQR.Focus();
    }
    private void Autorizar()
    {
        if (!autorizar.Enabled || tokenActual == "") return;
        autorizar.Enabled = false;
        try
        {
            var ok = local.Registrar(tokenActual);
            estado.Text = ok ? "ENTRADA GUARDADA EN ESTA LAPTOP" : "ENTRADA NO AUTORIZADA O YA REGISTRADA";
            estado.ForeColor = ok ? Color.DarkGreen : Color.DarkRed;
            tokenActual = ""; ActualizarResumen();
        }
        catch { estado.Text = "NO SE GUARDÓ LA ENTRADA. VUELVE A ESCANEAR."; estado.ForeColor = Color.DarkRed; }
        txtQR.Focus();
    }
    private async void Ejecutar(Func<CancellationToken, Task> trabajo)
    {
        if (operacion is not null) return;
        using var cts = new CancellationTokenSource(); operacion = cts; Limpiar();
        foreach (Control c in herramientas.Controls) c.Enabled = false;
        cancelar.Visible = true; cancelar.Enabled = true; txtQR.Enabled = false;
        try { await trabajo(cts.Token); }
        catch (OperationCanceledException) { actividad.Text = "Operación cancelada. Las entradas y la última descarga completa se conservan."; }
        catch (Exception e)
        {
            actividad.Text = "La operación no se completó; tus entradas locales se conservan.";
            var mensaje = e is HttpRequestException ? "No se pudo conectar. Revisa internet e inténtalo de nuevo." : e.Message;
            MessageBox.Show(this, mensaje, "AMOR · Acceso Offline", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        finally
        {
            operacion = null; foreach (Control c in herramientas.Controls) c.Enabled = true;
            cancelar.Visible = false; txtQR.Enabled = true; ActualizarResumen(); txtQR.Focus();
        }
    }
    private void Conectar()
    {
        using var dialogo = new Form
        {
            Text = "Conectar cuenta de AMOR",
            Size = new Size(430, 260),
            StartPosition = FormStartPosition.CenterParent,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false,
            MinimizeBox = false
        };
        var usuario = new TextBox { PlaceholderText = "Usuario o correo", Dock = DockStyle.Top };
        var password = new TextBox { PlaceholderText = "Contraseña", UseSystemPasswordChar = true, Dock = DockStyle.Top };
        var aceptar = new Button { Text = "Conectar", Dock = DockStyle.Bottom, DialogResult = DialogResult.OK };
        var layout = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, Padding = new Padding(20) };
        layout.Controls.Add(new Label { Text = "Usa una cuenta con acceso activo al evento.", AutoSize = true });
        usuario.Width = 350; password.Width = 350; layout.Controls.Add(usuario); layout.Controls.Add(password);
        dialogo.Controls.Add(layout); dialogo.Controls.Add(aceptar); dialogo.AcceptButton = aceptar;
        if (dialogo.ShowDialog(this) != DialogResult.OK) return;
        var nombre = usuario.Text; var clave = password.Text; password.Clear();
        Ejecutar(async ct => { await api.IniciarSesion(nombre, clave, local.EventoId, ct); actividad.Text = "Cuenta conectada. Ya puedes descargar o sincronizar."; });
    }
    private void Descargar() => Ejecutar(async ct =>
    {
        await api.Descargar(local, dispositivo, new Progress<string>(s => actividad.Text = s), ct);
        actividad.Text = "DESCARGA COMPLETA. Puedes operar este evento sin internet.";
    });
    private void Sincronizar() => Ejecutar(async ct =>
    {
        await api.Sincronizar(local, dispositivo, new Progress<string>(s => actividad.Text = s), ct);
        var r = local.Resumen(); actividad.Text = r.Pendientes + r.Conflictos == 0 ?
            "TODAS LAS ENTRADAS ESTÁN SINCRONIZADAS." :
            "Quedan entradas por revisar. Abre «Ver entradas» para consultar el resultado.";
    });
    private void VerEntradas()
    {
        using var f = new Form { Text = "Entradas del evento seleccionado", Size = new Size(1050, 550), StartPosition = FormStartPosition.CenterParent };
        f.Controls.Add(new DataGridView
        {
            Dock = DockStyle.Fill,
            ReadOnly = true,
            AllowUserToAddRows = false,
            AllowUserToDeleteRows = false,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
            DataSource = local.ListarEntradas()
        });
        f.ShowDialog(this);
    }
    private void Respaldar()
    {
        using var dialogo = new SaveFileDialog { Filter = "Respaldo AMOR (*.zip)|*.zip", FileName = $"AMOR_{local.EventoId}_{DateTime.Now:yyyyMMdd_HHmm}.zip" };
        if (dialogo.ShowDialog(this) != DialogResult.OK) return;
        var temporal = Path.Combine(Path.GetTempPath(), "AMOR-" + Guid.NewGuid() + ".db");
        var archivoTemporal = Path.Combine(Path.GetDirectoryName(dialogo.FileName)!, "AMOR-" + Guid.NewGuid() + ".tmp");
        try
        {
            local.Respaldar(temporal);
            using (var zip = ZipFile.Open(archivoTemporal, ZipArchiveMode.Create))
            {
                zip.CreateEntryFromFile(temporal, "acceso.db");
                foreach (var archivo in Directory.EnumerateFiles(local.Carpeta, "*.bin", SearchOption.AllDirectories))
                    zip.CreateEntryFromFile(archivo, Path.GetRelativePath(local.Carpeta, archivo).Replace('\\', '/'));
                using var info = new StreamWriter(zip.CreateEntry("EQUIPO_Y_EVENTO.txt").Open());
                info.WriteLine($"Equipo: {dispositivo}\nEvento: {local.EventoId}\nCifrado para la misma cuenta de Windows. No incluye contraseña ni sesión.");
            }
            File.Move(archivoTemporal, dialogo.FileName, true);
            actividad.Text = "Respaldo guardado. Está cifrado para esta cuenta de Windows; consérvalo en un lugar seguro.";
        }
        catch { MessageBox.Show(this, "No se pudo completar el respaldo. El archivo elegido debe ser nuevo y la unidad debe tener espacio."); }
        finally
        {
            if (File.Exists(temporal)) File.Delete(temporal);
            if (File.Exists(archivoTemporal)) File.Delete(archivoTemporal);
        }
    }
}
