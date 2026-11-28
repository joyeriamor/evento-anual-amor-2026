using AMOR.AccesoOffline;
using Microsoft.Data.Sqlite;
using System.Net;
using System.Text;
using System.Text.Json;
using SkiaSharp;
using System.Windows.Forms;

static class Program
{
    static int checks;
    static readonly Guid E = Evento.Todos[0].Id, C = Evento.Todos[1].Id, D = Guid.NewGuid();
    static readonly string Token = new('a', 64);
    static void Check(bool value, string nombre)
    { if (!value) throw new Exception("FALLÓ: " + nombre); checks++; Console.WriteLine("OK " + nombre); }
    static void Rechaza(Action action, string nombre)
    { try { action(); } catch { checks++; Console.WriteLine("OK " + nombre); return; } throw new Exception("No rechazó: " + nombre); }
    static Participante Fila(string token, string estado = "confirmado", string inv = "emitida", bool pago = true, bool previo = false) => new()
    {
        RegistroId = Guid.NewGuid(),
        EventoId = E,
        Nombre = "PERSONA FICTICIA " + checks,
        Folio = "DEMO-" + Guid.NewGuid(),
        Asesor = "ASESOR FICTICIO",
        Grupo = "VENDEDORA",
        EstadoRegistro = estado,
        PagoValidado = pago,
        YaIngreso = previo,
        InvitacionId = Guid.NewGuid(),
        TokenHash = Formato.HashToken(token),
        EstadoInvitacion = inv
    };
    static Paquete Paq(params Participante[] filas) => new()
    {
        Ok = true,
        PaqueteId = Guid.NewGuid(),
        EventoId = E,
        DispositivoId = D,
        UsuarioId = Guid.NewGuid(),
        CreadoAt = DateTimeOffset.UtcNow.AddMinutes(-1),
        ExpiraAt = DateTimeOffset.UtcNow.AddDays(1),
        Participantes = filas.ToList()
    };
    [STAThread]
    static int Main()
    {
        var root = Path.Combine(Path.GetTempPath(), "AMOR-PRUEBAS-" + Guid.NewGuid());
        Directory.CreateDirectory(root);
        try
        {
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            var local = new BaseDatosLocal(E, root);
            Check(local.Consultar(Token).Estado == "sin_descarga", "sin descarga no autoriza");
            var p1 = Fila(Token); var p2 = Fila(new('b', 64), "pendiente");
            var p3 = Fila(new('c', 64), inv: "revocada"); var p4 = Fila(new('d', 64), pago: false);
            var p5 = Fila(new('e', 64), previo: true); var p6 = Fila(new('f', 64)) with { ExentoPago = true, PagoValidado = false };
            var p = Paq(p1, p2, p3, p4, p5, p6);
            local.Importar(p, D, new Dictionary<Guid, string>());
            Check(local.Resumen().Participantes == 6, "descarga completa local");
            Check(local.Consultar(Token).Estado == "autorizable", "pago validado");
            Check(local.Consultar(new('b', 64)).Estado == "no_confirmado", "no confirmado rechazado");
            Check(local.Consultar(new('c', 64)).Estado == "revocada", "QR revocado rechazado");
            Check(local.Consultar(new('d', 64)).Estado == "sin_pago", "sin pago rechazado");
            Check(local.Consultar(new('e', 64)).Estado == "ya_ingreso", "entrada previa servidor");
            Check(local.Consultar(new('f', 64)).Estado == "autorizable", "cortesia valida");
            Check(local.Consultar("incorrecto").Estado == "qr_invalido", "formato incorrecto");
            Check(new BaseDatosLocal(C, root).Consultar(Token).Estado == "sin_descarga", "eventos separados");
            Rechaza(() => local.Importar(p with { EventoId = C }, D, new Dictionary<Guid, string>()), "rechaza paquete de otro evento");
            Rechaza(() => local.Importar(p, Guid.NewGuid(), new Dictionary<Guid, string>()), "rechaza equipo ajeno");
            Rechaza(() => local.Importar(p with { ExpiraAt = DateTimeOffset.UtcNow.AddHours(-1) }, D, new Dictionary<Guid, string>()), "rechaza descarga vencida");
            Rechaza(() => local.Importar(p with { Participantes = [p1, p1] }, D, new Dictionary<Guid, string>()), "rechaza registros duplicados en descarga");
            Rechaza(() => local.RutaSegura("../../fuera.bin"), "impide salir de carpeta del evento");
            Check(local.Resumen().Participantes == 6, "descarga fallida conserva anterior");
            var results = Task.WhenAll(Task.Run(() => local.Registrar(Token)), Task.Run(() => local.Registrar(Token))).GetAwaiter().GetResult();
            Check(results.Count(x => x) == 1, "dos lecturas concurrentes producen una entrada");
            Check(local.Consultar(Token).Estado == "ya_ingreso", "impide segundo ingreso");
            Check(!local.Registrar(new('d', 64)), "no guarda entrada sin pago");
            local = new BaseDatosLocal(E, root);
            Check(local.Pendientes().Count == 1, "pendiente sobrevive cierre y reapertura");
            Check(local.Pendientes()[0].Token == Token, "QR protegido recuperable solo localmente");
            using (var cn = new SqliteConnection("Data Source=" + local.Ruta))
            {
                cn.Open(); using var cmd = cn.CreateCommand(); cmd.CommandText = "select token_protegido from accesos limit 1";
                Check(!((string)cmd.ExecuteScalar()!).Contains(Token), "QR no esta en texto plano");
            }
            var op = local.Pendientes()[0].OperacionId;
            local.AplicarResultado(new(op, false, "ya_ingreso"));
            Check(local.Pendientes().Count == 1 && local.Resumen().Conflictos == 1, "respuesta negativa no descarta entrada");
            local.AplicarResultado(new(op, true, "ingreso_registrado"));
            Check(local.Pendientes().Count == 0, "confirmacion servidor resuelve pendiente");
            Check(local.Resumen().Entradas == 1, "sincronizar no borra historial local");
            var backup = Path.Combine(root, "respaldo.db"); local.Respaldar(backup);
            using (var cn = new SqliteConnection("Data Source=" + backup))
            { cn.Open(); using var cmd = cn.CreateCommand(); cmd.CommandText = "select count(*) from accesos"; Check(Convert.ToInt32(cmd.ExecuteScalar()) == 1, "respaldo consistente incluye entradas"); }
            Check(local.Registrar(new('f', 64)), "otra entrada pendiente antes de actualizar descarga");
            var pendienteAnterior = local.Pendientes().Single();
            local.Importar(Paq(p1 with { InvitacionId = Guid.NewGuid(), TokenHash = Formato.HashToken(new('1', 64)) }), D, new Dictionary<Guid, string>());
            Check(local.Consultar(Token).Estado == "qr_invalido", "descarga nueva invalida QR anterior");
            Check(local.Resumen().Entradas == 2, "descarga nueva conserva entradas");
            Check(local.Pendientes().Single().OperacionId == pendienteAnterior.OperacionId &&
                local.Pendientes().Single().PaqueteId == pendienteAnterior.PaqueteId, "descarga nueva conserva el paquete de cada pendiente");
            TestApi(Path.Combine(root, "api"));
            TestUI(Path.Combine(root, "ui"));
            TestNombres(Path.Combine(root, "nombres"));
            TestApiNombre(Path.Combine(root, "api-nombre"));
            TestMigracionNombre(Path.Combine(root, "migracion-nombre"));
            TestBusquedaUI(Path.Combine(root, "busqueda-ui"));
            Console.WriteLine("APROBADO: " + checks + " comprobaciones Windows con SQLite, cifrado, imágenes e interfaz reales; Auth y red simulados.");
            return 0;
        }
        catch (Exception e) { Console.Error.WriteLine(e); return 1; }
        finally
        {
            SqliteConnection.ClearAllPools();
            try { Directory.Delete(root, true); } catch { }
        }
    }
    static void TestApi(string root)
    {
        var p = Fila(Token) with
        {
            FotoPath = E + "/foto.webp",
            FotoUrl = ApiCliente.ProyectoUrl + "/storage/v1/object/sign/fotos-promotoras/foto.webp?token=prueba"
        };
        using var mock = new ServidorSimulado(Paq(p));
        using var api = new ApiCliente("sb_publishable_prueba", mock, root);
        var local = new BaseDatosLocal(E, root);
        var progreso = new Progreso();
        api.IniciarSesion("ensayo", "password-ficticia", E, CancellationToken.None).GetAwaiter().GetResult();
        api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult();
        Check(local.Resumen().Fotos == 1, "descarga y cifra foto WebP");
        var ficha = local.Consultar(Token);
        using (var image = System.Drawing.Image.FromStream(new MemoryStream(Proteccion.Abrir(File.ReadAllBytes(local.RutaSegura(ficha.FotoPath))))))
            Check(image.Width == 10 && image.Height == 12, "foto offline legible sin URL firmada");
        Check(local.Registrar(Token), "entrada offline tras descarga");
        mock.PerderRespuesta = true;
        Rechaza(() => api.Sincronizar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult(), "corte de red conserva pendiente");
        Check(local.Pendientes().Count == 1, "sin confirmacion sigue pendiente");
        api.Sincronizar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult();
        Check(local.Pendientes().Count == 0, "reintento de sincronizacion");
        Check(mock.Entradas == 1 && mock.Reintentos == 1, "respuesta perdida no duplica entrada");
        using (var grande = new SKBitmap(4896, 6528))
        {
            grande.Erase(SKColors.Pink);
            using var imagen = SKImage.FromBitmap(grande);
            using var jpeg = imagen.Encode(SKEncodedImageFormat.Jpeg, 85);
            mock.Foto = jpeg.ToArray();
        }
        mock.Paquete = mock.Paquete with { PaqueteId = Guid.NewGuid(), Participantes = [p] };
        api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult();
        using (var imagen = System.Drawing.Image.FromStream(new MemoryStream(
            Proteccion.Abrir(File.ReadAllBytes(local.RutaSegura(local.Consultar(Token).FotoPath))))))
            Check(imagen.Height > imagen.Width && Math.Max(imagen.Width, imagen.Height) <= 2048,
                "foto JPEG de 32 MP se descarga y reduce antes de guardar");
        Check(local.Resumen().Entradas == 1, "reducir foto conserva la entrada existente");
        mock.Foto = mock.Foto![..^2]; // JPEG with all image data but no closing EOI marker.
        mock.Paquete = mock.Paquete with { PaqueteId = Guid.NewGuid() };
        api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult();
        using (var imagen = SKBitmap.Decode(Proteccion.Abrir(File.ReadAllBytes(
            local.RutaSegura(local.Consultar(Token).FotoPath)))))
            Check(imagen is not null && imagen.GetPixel(imagen.Width / 2, imagen.Height - 1).Red > 150,
                "JPEG sin marcador final conserva los pixeles visibles");
        var previo = local.PaqueteActual()!.PaqueteId;
        mock.Foto = [0xff, 0xd8, 0xff, 0xe1, 0, 0];
        mock.Paquete = mock.Paquete with { PaqueteId = Guid.NewGuid() };
        Rechaza(() => api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult(),
            "archivo JPEG ilegible no activa una descarga");
        Check(local.PaqueteActual()!.PaqueteId == previo, "imagen ilegible conserva la descarga valida");
        mock.Paquete = mock.Paquete with { PaqueteId = Guid.NewGuid(), Participantes = [p with { FotoUrl = "https://ajeno.example/foto.png" }] };
        Rechaza(() => api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult(), "rechaza fotografia de servidor ajeno");
        Check(local.Resumen().Participantes == 1 && local.Resumen().Entradas == 1, "fallo de fotos conserva descarga y entradas");
        mock.Paquete = mock.Paquete with { EventoId = C };
        Rechaza(() => api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult(), "rechaza respuesta con evento cruzado");
        api.CerrarSesion();
        Check(!File.Exists(Path.Combine(root, "sesion.bin")), "cerrar sesion borra credencial local");
        Rechaza(() => new ApiCliente("sb_secret_no_permitida", mock, root), "no acepta claves secretas");
    }
    static void TestUI(string root)
    {
        var persona = Fila(Token) with { FotoPath = E + "/fotografia-ficticia.jpg" };
        using var mock = new ServidorSimulado(Paq(persona));
        using var api = new ApiCliente("sb_publishable_prueba", mock, root);
        var local = new BaseDatosLocal(E, root);
        using (var avatar = new System.Drawing.Bitmap(200, 240))
        {
            using (var g = System.Drawing.Graphics.FromImage(avatar))
            {
                g.Clear(System.Drawing.Color.MistyRose);
                g.FillEllipse(System.Drawing.Brushes.RosyBrown, 65, 25, 70, 80);
                g.FillEllipse(System.Drawing.Brushes.RosyBrown, 35, 110, 130, 140);
            }
            using var stream = new MemoryStream();
            avatar.Save(stream, System.Drawing.Imaging.ImageFormat.Jpeg);
            File.WriteAllBytes(local.RutaSegura("foto-prueba.bin"), Proteccion.Proteger(stream.ToArray()));
        }
        local.Importar(mock.Paquete, D, new Dictionary<Guid, string> { { persona.RegistroId, "foto-prueba.bin" } });
        using var form = new Form1(api, root, D);
        form.Show(); Application.DoEvents();
        var input = (TextBox)form.Controls.Find("CodigoQR", true).Single();
        var button = (Button)form.Controls.Find("Autorizar", true).Single();
        input.Text = Token;
        var args = new KeyEventArgs(Keys.Enter);
        typeof(Control).GetMethod("OnKeyDown", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!
            .Invoke(input, [args]);
        Application.DoEvents();
        Check(button.Enabled, "interfaz habilita autorizacion real");
        var captura = Environment.GetEnvironmentVariable("AMOR_PREVIEW_PATH");
        if (!string.IsNullOrEmpty(captura))
        {
            using var bitmap = new System.Drawing.Bitmap(form.Width, form.Height);
            form.DrawToBitmap(bitmap, new System.Drawing.Rectangle(0, 0, form.Width, form.Height));
            bitmap.Save(captura, System.Drawing.Imaging.ImageFormat.Png);
        }
        form.Size = new System.Drawing.Size(970, 720); Application.DoEvents();
        Check(form.RectangleToScreen(form.ClientRectangle).Contains(button.RectangleToScreen(button.ClientRectangle)),
            "boton de entrada accesible en pantalla de laptop");
        var panelDatos = (Panel)form.Controls.Find("DatosParticipante", true).Single();
        Check(panelDatos.DisplayRectangle.Height >= panelDatos.Controls[0].Height,
            "ficha completa disponible en ventana reducida");
        button.PerformClick(); Application.DoEvents();
        Check(local.Resumen().Entradas == 1 && !button.Enabled, "boton guarda entrada y se deshabilita");
        var eventos = (ComboBox)form.Controls.Find("Eventos", true).Single();
        eventos.SelectedIndex = 1; Application.DoEvents();
        Check(!button.Enabled, "cambiar evento limpia autorizacion anterior");
        form.Close();
    }
    static Dictionary<Guid, string> Fotos(BaseDatosLocal local, params Participante[] personas)
    {
        using var avatar = new SKBitmap(60, 80); avatar.Erase(SKColors.LightPink);
        using (var canvas = new SKCanvas(avatar))
        {
            using var pintura = new SKPaint { Color = SKColors.DarkMagenta, IsAntialias = true };
            canvas.DrawCircle(30, 22, 12, pintura);
            canvas.DrawRoundRect(new SKRect(10, 40, 50, 78), 10, 10, pintura);
        }
        using var imagen = SKImage.FromBitmap(avatar); using var jpeg = imagen.Encode(SKEncodedImageFormat.Jpeg, 85);
        File.WriteAllBytes(local.RutaSegura("foto-nombre.bin"), Proteccion.Proteger(jpeg.ToArray()));
        return personas.Where(p => p.FotoPath is not null).ToDictionary(p => p.RegistroId, _ => "foto-nombre.bin");
    }
    static void TestNombres(string root)
    {
        var local = new BaseDatosLocal(E, root);
        Check(local.BuscarNombre("ANA").Count == 0, "sin descarga no hay resultados por nombre");
        var a = Fila(Token) with { Nombre = "Ana María González Hernández", FotoPath = "foto" };
        var b = Fila(new('b', 64)) with { Nombre = a.Nombre, FotoPath = "foto", Grupo = "GRUPO DOS" };
        var otras = new[] { Fila(new('c', 64), pago: false), Fila(new('d', 64), inv: "revocada"),
            Fila(new('e', 64), estado: "pendiente"), Fila(new('f', 64), previo: true),
            Fila(new('1', 64)) with { InvitacionId = null, TokenHash = null },
            Fila(new('2', 64)) with { ExentoPago = true, PagoValidado = false } }
            .Select((p, i) => p with { Nombre = "María Luisa Pérez Sánchez " + i, FotoPath = "foto" }).ToArray();
        var sinFoto = Fila(new('3', 64)) with { Nombre = "Persona sin fotografía" };
        var todos = new[] { a, b, sinFoto }.Concat(otras).ToArray();
        local.Importar(Paq(todos), D, Fotos(local, todos));
        Check(local.BuscarNombre("ANA MARIA GONZALEZ HERNANDEZ").Count == 2, "busca nombre completo sin acentos");
        Check(local.BuscarNombre("hernández ana").Count == 2, "apellidos primero y varios homonimos");
        Check(local.BuscarNombre("Sánchez Pérez").Count == 6, "busca por ambos apellidos en distinto orden");
        Check(local.BuscarNombre("  Ana   Mari\u0301a  ").Count == 2, "espacios y acentos Unicode equivalentes");
        Check(local.BuscarNombre("inexistente").Count == 0, "nombre sin coincidencias");
        Check(local.BuscarNombre("%_").Count == 0, "comodines no exponen toda la descarga");
        Check(new BaseDatosLocal(C, root).BuscarNombre("Ana").Count == 0, "busqueda no cruza eventos");
        Check(!local.RegistrarPorNombre(a.RegistroId, a.InvitacionId!.Value, false), "sin confirmar identidad no hay ingreso manual");
        Check(!local.RegistrarPorNombre(a.RegistroId, b.InvitacionId!.Value, true), "invitacion ajena no autoriza a otra persona");
        Check(!local.RegistrarPorNombre(sinFoto.RegistroId, sinFoto.InvitacionId!.Value, true), "sin fotografia no autoriza por nombre");
        foreach (var p in otras.Take(5))
            Check(!local.RegistrarPorNombre(p.RegistroId, p.InvitacionId ?? Guid.Empty, true), "pago, estado, entrada o QR pendiente impiden acceso manual");
        var concurrentes = Task.WhenAll(Task.Run(() => local.Registrar(Token)),
            Task.Run(() => local.RegistrarPorNombre(a.RegistroId, a.InvitacionId!.Value, true))).GetAwaiter().GetResult();
        Check(concurrentes.Count(x => x) == 1, "QR y nombre simultaneos producen un solo ingreso");
        Check(local.BuscarNombre("hernandez").Single(f => f.RegistroId == a.RegistroId).Estado == "ya_ingreso", "busqueda muestra entrada previa");
        Check(local.RegistrarPorNombre(b.RegistroId, b.InvitacionId!.Value, true), "autoriza homonimo seleccionado por folio y foto");
        Check(!local.Registrar(new('b', 64)), "QR no duplica una entrada por nombre");
        var pendiente = new BaseDatosLocal(E, root).Pendientes().Single(p => p.RegistroId == b.RegistroId);
        Check(pendiente.Origen == "nombre" && pendiente.InvitacionId == b.InvitacionId, "entrada manual persiste con invitacion y metodo");
        Check(local.ListarEntradas().Single(f => f.Folio == b.Folio).Metodo == "Nombre y fotografía", "historial distingue ingreso por nombre");
        Check(local.RegistrarPorNombre(otras[5].RegistroId, otras[5].InvitacionId!.Value, true), "cortesia valida admite acceso por nombre");
        local.Importar(Paq(sinFoto), D, new Dictionary<Guid, string>());
        Check(local.BuscarNombre("ANA").Count == 0, "busqueda excluye personas de descargas anteriores");
        Check(!local.RegistrarPorNombre(b.RegistroId, b.InvitacionId!.Value, true), "seleccion antigua no autoriza tras actualizar descarga");
    }
    static void TestApiNombre(string root)
    {
        var p = Fila(Token) with { Nombre = "Persona ficticia por nombre", FotoPath = "foto.webp",
            FotoUrl = ApiCliente.ProyectoUrl + "/storage/v1/object/sign/fotos-promotoras/foto.webp?token=prueba" };
        using var mock = new ServidorSimulado(Paq(p)); using var api = new ApiCliente("sb_publishable_prueba", mock, root);
        var local = new BaseDatosLocal(E, root); var progreso = new Progreso();
        api.IniciarSesion("ensayo", "password-ficticia", E, CancellationToken.None).GetAwaiter().GetResult();
        api.Descargar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult();
        Check(local.RegistrarPorNombre(p.RegistroId, p.InvitacionId!.Value, true), "entrada manual antes de sincronizar");
        mock.ManualNoPublicado = true;
        Rechaza(() => api.Sincronizar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult(), "modulo manual sin publicar conserva pendiente");
        Check(local.Pendientes().Count == 1, "no pierde entrada si falta el servicio manual");
        mock.ManualNoPublicado = false; mock.PerderRespuesta = true;
        Rechaza(() => api.Sincronizar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult(), "respuesta manual perdida conserva entrada");
        api.Sincronizar(local, D, progreso, CancellationToken.None).GetAwaiter().GetResult();
        Check(local.Pendientes().Count == 0 && mock.Entradas == 1 && mock.Reintentos == 1, "reintento manual sincroniza una sola entrada");
    }
    static void TestMigracionNombre(string root)
    {
        var local = new BaseDatosLocal(E, root); var p = Fila(Token);
        local.Importar(Paq(p), D, new Dictionary<Guid, string>()); local.Registrar(Token);
        var id = local.Pendientes().Single().OperacionId;
        using (var cn = new SqliteConnection("Data Source=" + local.Ruta))
        { cn.Open(); using var cmd = cn.CreateCommand(); cmd.CommandText = "ALTER TABLE accesos DROP COLUMN origen"; cmd.ExecuteNonQuery(); }
        var anterior = new BaseDatosLocal(E, root).Pendientes().Single();
        Check(anterior.OperacionId == id && anterior.Token == Token && anterior.Origen == "qr",
            "actualizar base 2.1 conserva pendiente QR y su identificador");
    }
    static void Esperar(Func<bool> condicion)
    {
        var tiempo = System.Diagnostics.Stopwatch.StartNew();
        while (!condicion() && tiempo.Elapsed < TimeSpan.FromSeconds(15))
        { Application.DoEvents(); Thread.Sleep(10); }
        if (!condicion()) throw new Exception("No termino la operacion de interfaz");
    }
    static void TestBusquedaUI(string root)
    {
        var a = Fila(Token) with { Nombre = "Ana María González Hernández", FotoPath = "foto" };
        var b = Fila(new('b', 64)) with { Nombre = a.Nombre, FotoPath = "foto" };
        var local = new BaseDatosLocal(E, root); local.Importar(Paq(a, b), D, Fotos(local, a, b));
        using (var busqueda = new BuscarParticipantesForm(local, "Evento ficticio"))
        {
            busqueda.Show(); Application.DoEvents();
            var texto = (TextBox)busqueda.Controls.Find("BusquedaNombre", true).Single();
            var boton = (Button)busqueda.Controls.Find("BuscarNombre", true).Single();
            var grid = (DataGridView)busqueda.Controls.Find("CoincidenciasNombre", true).Single();
            var revisar = (Button)busqueda.Controls.Find("RevisarPersona", true).Single();
            texto.Text = "hernandez ana"; boton.PerformClick(); Esperar(() => boton.Enabled);
            Check(grid.Rows.Count == 2, "interfaz busca ambos apellidos sin internet");
            Check(grid.SelectedRows.Count == 0 && !revisar.Enabled, "homonimos requieren seleccion explicita");
            var capturaBusqueda = Environment.GetEnvironmentVariable("AMOR_PREVIEW_BUSQUEDA");
            if (!string.IsNullOrEmpty(capturaBusqueda))
            { using var imagen = new System.Drawing.Bitmap(busqueda.Width, busqueda.Height); busqueda.DrawToBitmap(imagen, new System.Drawing.Rectangle(0, 0, busqueda.Width, busqueda.Height)); imagen.Save(capturaBusqueda); }
            var esperado = ((ResultadoQR)grid.Rows[1].DataBoundItem!).Folio;
            grid.Rows[1].Selected = true; Application.DoEvents(); revisar.PerformClick();
            Check(busqueda.Seleccion?.Folio == esperado,
                "revisa exactamente el folio seleccionado");
        }
        using var mock = new ServidorSimulado(Paq(a, b)); using var api = new ApiCliente("sb_publishable_prueba", mock, root);
        using var form = new Form1(api, root, D); form.Show(); Application.DoEvents();
        form.RevisarPorNombre(a.RegistroId); Application.DoEvents();
        var autorizar = (Button)form.Controls.Find("Autorizar", true).Single();
        var confirmar = (CheckBox)form.Controls.Find("ConfirmarIdentidad", true).Single();
        Check(!autorizar.Enabled && confirmar.Visible && !confirmar.Checked, "nombre no autoriza antes de cotejar fotografia");
        confirmar.Checked = true; Application.DoEvents(); Check(autorizar.Enabled, "confirmacion de fotografia habilita acceso manual");
        form.Size = new System.Drawing.Size(970, 720); Application.DoEvents();
        var fotografia = (PictureBox)form.Controls.Find("Fotografia", true).Single();
        Check(fotografia.Height >= 120 && form.RectangleToScreen(form.ClientRectangle).Contains(autorizar.RectangleToScreen(autorizar.ClientRectangle)),
            "foto y boton manual utilizables en pantalla de laptop");
        var captura = Environment.GetEnvironmentVariable("AMOR_PREVIEW_NOMBRE");
        if (!string.IsNullOrEmpty(captura))
        { using var imagen = new System.Drawing.Bitmap(form.Width, form.Height); form.DrawToBitmap(imagen, new System.Drawing.Rectangle(0, 0, form.Width, form.Height)); imagen.Save(captura); }
        autorizar.PerformClick(); Application.DoEvents();
        Check(local.Resumen().Entradas == 1 && !autorizar.Enabled, "boton real registra entrada por nombre una vez");
        Check(form.Controls.Find("PanelCodigoQR", true).Single().Visible && form.Controls.Find("CodigoQR", true).Single().CanFocus,
            "tras ingreso manual vuelve a quedar listo el lector QR");
        form.RevisarPorNombre(b.RegistroId); confirmar.Checked = true;
        ((ComboBox)form.Controls.Find("Eventos", true).Single()).SelectedIndex = 1; Application.DoEvents();
        Check(!autorizar.Enabled && !confirmar.Visible && !confirmar.Checked, "cambiar evento borra identidad y seleccion manual");
        form.Close();
    }
    sealed class Progreso : IProgress<string> { public void Report(string s) { } }
    sealed class ServidorSimulado(Paquete paquete) : HttpMessageHandler
    {
        public Paquete Paquete = paquete;
        public bool PerderRespuesta;
        public bool ManualNoPublicado;
        public byte[]? Foto;
        public int Entradas, Reintentos;
        readonly Dictionary<Guid, ResultadoSync> registro = [];
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var path = request.RequestUri!.AbsolutePath;
            if (path.Contains("/storage/"))
            {
                if (Foto is not null) return new(HttpStatusCode.OK) { Content = new ByteArrayContent(Foto) };
                using var bitmap = new SKBitmap(10, 12); bitmap.Erase(SKColors.Pink);
                using var image = SKImage.FromBitmap(bitmap); using var data = image.Encode(SKEncodedImageFormat.Webp, 90);
                return new(HttpStatusCode.OK) { Content = new ByteArrayContent(data.ToArray()) };
            }
            if (path.EndsWith("/acceso-offline-manual") && ManualNoPublicado)
                return new(HttpStatusCode.NotFound);
            if (path.Contains("iniciar-sesion") || path.Contains("/auth/"))
                return Json(new { access_token = "token-ficticio", refresh_token = "refresh-ficticio", expires_in = 3600 });
            Check(request.Headers.Authorization?.Parameter == "token-ficticio", "solicitud usa sesion del operador");
            using var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync(ct));
            if (body.RootElement.GetProperty("accion").GetString() == "descargar") return Json(Paquete);
            var filas = new List<ResultadoSync>();
            foreach (var entrada in body.RootElement.GetProperty("accesos").EnumerateArray())
            {
                if (path.EndsWith("/acceso-offline-manual"))
                {
                    Check(entrada.GetProperty("identidad_confirmada").GetBoolean() &&
                        entrada.GetProperty("registro_id").GetGuid() != Guid.Empty &&
                        entrada.GetProperty("invitacion_id").GetGuid() != Guid.Empty && !entrada.TryGetProperty("token", out _),
                        "envio manual usa identidad e invitacion sin inventar un QR");
                }
                var op = entrada.GetProperty("operacion_id").GetGuid();
                if (!registro.TryGetValue(op, out var previo))
                { previo = new(op, true, "ingreso_registrado"); registro.Add(op, previo); Entradas++; }
                else Reintentos++;
                filas.Add(previo);
            }
            if (PerderRespuesta) { PerderRespuesta = false; throw new HttpRequestException("Corte ficticio despues de guardar"); }
            return Json(new RespuestaSync(true, filas));
        }
        static HttpResponseMessage Json(object data) => new(HttpStatusCode.OK)
        { Content = new StringContent(JsonSerializer.Serialize(data, Formato.Json), Encoding.UTF8, "application/json") };
    }
}
