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
    sealed class Progreso : IProgress<string> { public void Report(string s) { } }
    sealed class ServidorSimulado(Paquete paquete) : HttpMessageHandler
    {
        public Paquete Paquete = paquete;
        public bool PerderRespuesta;
        public int Entradas, Reintentos;
        readonly Dictionary<Guid, ResultadoSync> registro = [];
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var path = request.RequestUri!.AbsolutePath;
            if (path.Contains("/storage/"))
            {
                using var bitmap = new SKBitmap(10, 12); bitmap.Erase(SKColors.Pink);
                using var image = SKImage.FromBitmap(bitmap); using var data = image.Encode(SKEncodedImageFormat.Webp, 90);
                return new(HttpStatusCode.OK) { Content = new ByteArrayContent(data.ToArray()) };
            }
            if (path.Contains("iniciar-sesion") || path.Contains("/auth/"))
                return Json(new { access_token = "token-ficticio", refresh_token = "refresh-ficticio", expires_in = 3600 });
            Check(request.Headers.Authorization?.Parameter == "token-ficticio", "solicitud usa sesion del operador");
            using var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync(ct));
            if (body.RootElement.GetProperty("accion").GetString() == "descargar") return Json(Paquete);
            var filas = new List<ResultadoSync>();
            foreach (var entrada in body.RootElement.GetProperty("accesos").EnumerateArray())
            {
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
