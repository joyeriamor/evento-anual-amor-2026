using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using SkiaSharp;

namespace AMOR.AccesoOffline;

public sealed class ApiCliente : IDisposable
{
    public const string ProyectoUrl = "https://rkjlqxxmxbiciuhtpnpf.supabase.co";
    private readonly HttpClient http;
    private readonly HttpClient fotos;
    private readonly string key;
    private readonly string sesionPath;
    private Sesion? sesion;
    public ApiCliente(string? clave = null, HttpMessageHandler? transporte = null, string? carpeta = null)
    {
        key = clave ?? File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "clave-publica.txt")).Trim();
        if (!key.StartsWith("sb_publishable_", StringComparison.Ordinal))
            throw new InvalidDataException("La conexión requiere una clave pública, nunca una clave secreta.");
        http = transporte is null ? new HttpClient() : new HttpClient(transporte, false);
        http.Timeout = TimeSpan.FromMinutes(3);
        http.MaxResponseContentBufferSize = 32 * 1024 * 1024;
        fotos = transporte is null ? new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) :
            new HttpClient(transporte, false);
        fotos.Timeout = TimeSpan.FromMinutes(2);
        sesionPath = Path.Combine(carpeta ?? BaseDatosLocal.CarpetaDatos, "sesion.bin");
        if (File.Exists(sesionPath))
        {
            try
            {
                sesion = JsonSerializer.Deserialize<Sesion>(
                Proteccion.Abrir(File.ReadAllBytes(sesionPath)), Formato.Json);
            }
            catch (Exception e) when (e is System.Security.Cryptography.CryptographicException or JsonException or IOException)
            { sesion = null; }
        }
    }
    public bool Conectado => sesion is not null;
    public void CerrarSesion()
    {
        sesion = null;
        if (File.Exists(sesionPath)) File.Delete(sesionPath);
    }
    private async Task<JsonDocument> Enviar(string ruta, object datos, string? token, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, ProyectoUrl + ruta);
        request.Headers.Add("apikey", key);
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        request.Content = JsonContent.Create(datos, options: Formato.Json);
        using var response = await http.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            if (response.StatusCode == HttpStatusCode.Unauthorized)
                throw new UnauthorizedAccessException("Inicia sesión de nuevo. Las entradas locales se conservan.");
            if (response.StatusCode == HttpStatusCode.NotFound)
                throw new InvalidOperationException("Falta publicar el módulo offline en el servidor.");
            if (response.StatusCode == HttpStatusCode.Forbidden)
                throw new InvalidOperationException("La cuenta no tiene permiso activo para este evento.");
            throw new InvalidOperationException("El servidor no confirmó la operación. Revisa la conexión y vuelve a intentar. Tus entradas se conservan.");
        }
        return JsonDocument.Parse(await response.Content.ReadAsByteArrayAsync(ct));
    }
    private void GuardarSesion(JsonElement root)
    {
        var access = root.GetProperty("access_token").GetString()!;
        var refresh = root.GetProperty("refresh_token").GetString()!;
        // This untrusted expiration is only for refresh scheduling, never authorization.
        var expires = DateTimeOffset.UtcNow.AddMinutes(40).ToUnixTimeSeconds();
        if (root.TryGetProperty("expires_in", out var exp)) expires = DateTimeOffset.UtcNow.ToUnixTimeSeconds() + exp.GetInt64();
        sesion = new(access, refresh, expires);
        Proteccion.GuardarAtomico(sesionPath, Proteccion.Proteger(JsonSerializer.SerializeToUtf8Bytes(sesion, Formato.Json)));
    }
    public async Task IniciarSesion(string usuario, string password, Guid evento, CancellationToken ct)
    {
        Evento.Validar(evento);
        if (string.IsNullOrWhiteSpace(usuario) || password.Length == 0)
            throw new InvalidOperationException("Escribe tu usuario y contraseña.");
        using var respuesta = usuario.Contains('@')
            ? await Enviar("/auth/v1/token?grant_type=password", new { email = usuario.Trim(), password }, null, ct)
            : await Enviar("/functions/v1/iniciar-sesion-usuario",
                new { usuario = usuario.Trim(), password, evento_id = evento }, null, ct);
        GuardarSesion(respuesta.RootElement);
    }
    private async Task Refrescar(CancellationToken ct)
    {
        if (sesion is null) throw new UnauthorizedAccessException("Conecta tu cuenta para descargar o sincronizar.");
        using var r = await Enviar("/auth/v1/token?grant_type=refresh_token",
            new { refresh_token = sesion.RefreshToken }, null, ct);
        GuardarSesion(r.RootElement);
    }
    private async Task<T> Operar<T>(object datos, CancellationToken ct)
    {
        if (sesion is null) throw new UnauthorizedAccessException("Conecta tu cuenta para descargar o sincronizar.");
        if (sesion.ExpiresAt < DateTimeOffset.UtcNow.AddMinutes(2).ToUnixTimeSeconds()) await Refrescar(ct);
        JsonDocument respuesta;
        try { respuesta = await Enviar("/functions/v1/acceso-offline", datos, sesion!.AccessToken, ct); }
        catch (UnauthorizedAccessException)
        {
            await Refrescar(ct);
            respuesta = await Enviar("/functions/v1/acceso-offline", datos, sesion!.AccessToken, ct);
        }
        using (respuesta)
            return respuesta.RootElement.Deserialize<T>(Formato.Json) ?? throw new InvalidDataException("Respuesta incompleta.");
    }
    public async Task Descargar(BaseDatosLocal local, Guid dispositivo, IProgress<string> progreso, CancellationToken ct)
    {
        progreso.Report("Preparando la lista del evento…");
        var p = await Operar<Paquete>(new { accion = "descargar", evento_id = local.EventoId, dispositivo_id = dispositivo }, ct);
        if (!p.Ok || p.EventoId != local.EventoId || p.DispositivoId != dispositivo || p.PaqueteId == Guid.Empty ||
            p.Participantes is null || p.Participantes.Count > 10000)
            throw new InvalidDataException("El servidor devolvió otro evento o equipo.");
        var relativa = Path.Combine("paquetes", p.PaqueteId.ToString());
        var carpeta = local.RutaSegura(relativa);
        if (Directory.Exists(carpeta)) throw new InvalidDataException("Identificador de descarga repetido.");
        Directory.CreateDirectory(carpeta);
        var rutas = new System.Collections.Concurrent.ConcurrentDictionary<Guid, string>();
        var conFoto = p.Participantes.Where(f => !string.IsNullOrWhiteSpace(f.FotoPath)).ToArray();
        var terminadas = 0; var activado = false;
        try
        {
            await Parallel.ForEachAsync(conFoto, new ParallelOptions { MaxDegreeOfParallelism = 4, CancellationToken = ct },
                async (fila, token) =>
                {
                    if (!Uri.TryCreate(fila.FotoUrl, UriKind.Absolute, out var uri) ||
                        uri.Scheme != "https" || uri.Host != new Uri(ProyectoUrl).Host ||
                        !uri.AbsolutePath.StartsWith("/storage/v1/object/sign/", StringComparison.Ordinal))
                        throw new InvalidDataException("URL de fotografía no autorizada.");
                    using var respuesta = await fotos.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, token);
                    respuesta.EnsureSuccessStatusCode();
                    if (respuesta.Content.Headers.ContentLength > 10 * 1024 * 1024)
                        throw new InvalidDataException("Una fotografía excede el tamaño permitido.");
                    await using var entrada = await respuesta.Content.ReadAsStreamAsync(token);
                    using var bytes = new MemoryStream();
                    var buffer = new byte[16384]; int leidos;
                    while ((leidos = await entrada.ReadAsync(buffer, token)) > 0)
                    {
                        if (bytes.Length + leidos > 10 * 1024 * 1024) throw new InvalidDataException("Fotografía demasiado grande.");
                        bytes.Write(buffer, 0, leidos);
                    }
                    using var encoded = SKData.CreateCopy(bytes.ToArray());
                    using var codec = SKCodec.Create(encoded);
                    if (codec is null || (long)codec.Info.Width * codec.Info.Height > 24_000_000)
                        throw new InvalidDataException("Dimensiones de fotografía no permitidas.");
                    using var bitmap = SKBitmap.Decode(codec) ?? throw new InvalidDataException("Fotografía no reconocida.");
                    using var orientada = Orientar(bitmap, codec.EncodedOrigin);
                    using var image = SKImage.FromBitmap(orientada);
                    using var jpeg = image.Encode(SKEncodedImageFormat.Jpeg, 85);
                    var archivo = Path.Combine(relativa, fila.RegistroId + ".bin");
                    Proteccion.GuardarAtomico(local.RutaSegura(archivo), Proteccion.Proteger(jpeg.ToArray()));
                    if (!rutas.TryAdd(fila.RegistroId, archivo)) throw new InvalidDataException("Fotografía duplicada.");
                    progreso.Report($"Fotografías: {Interlocked.Increment(ref terminadas)} de {conFoto.Length}");
                });
            ct.ThrowIfCancellationRequested();
            local.Importar(p, dispositivo, rutas);
            activado = true;
            progreso.Report($"Descarga completa: {p.Participantes.Count} participantes y {terminadas} fotografías.");
        }
        finally { if (!activado && Directory.Exists(carpeta)) Directory.Delete(carpeta, true); }
    }
    public async Task Sincronizar(BaseDatosLocal local, Guid dispositivo, IProgress<string> progreso, CancellationToken ct)
    {
        var pendientes = local.Pendientes();
        var terminadas = 0;
        foreach (var grupo in pendientes.GroupBy(p => p.PaqueteId))
            foreach (var lote in grupo.Chunk(25))
            {
                ct.ThrowIfCancellationRequested();
                var r = await Operar<RespuestaSync>(new
                {
                    accion = "sincronizar",
                    evento_id = local.EventoId,
                    dispositivo_id = dispositivo,
                    paquete_id = grupo.Key,
                    accesos = lote.Select(a => new { a.OperacionId, a.Token, a.IngresadoAt }).ToArray()
                }, ct);
                var ids = lote.Select(p => p.OperacionId).ToHashSet();
                if (!r.Ok || r.Resultados is null || r.Resultados.Count != lote.Length ||
                    r.Resultados.Select(x => x.OperacionId).Distinct().Count() != lote.Length ||
                    r.Resultados.Any(x => !ids.Contains(x.OperacionId)))
                    throw new InvalidDataException("No se confirmó el lote completo. Las entradas se conservan para reintentar.");
                foreach (var fila in r.Resultados) local.AplicarResultado(fila);
                terminadas += lote.Length;
                progreso.Report($"Entradas procesadas: {terminadas} de {pendientes.Count}");
            }
    }
    public void Dispose() { http.Dispose(); fotos.Dispose(); }
    private static SKBitmap Orientar(SKBitmap original, SKEncodedOrigin origen)
    {
        var swap = (int)origen >= 5;
        var w = original.Width; var h = original.Height;
        var salida = new SKBitmap(swap ? h : w, swap ? w : h);
        using var canvas = new SKCanvas(salida);
        canvas.Clear(SKColors.White);
        var m = SKMatrix.Identity;
        switch (origen)
        {
            case SKEncodedOrigin.TopRight: m.ScaleX = -1; m.TransX = w; break;
            case SKEncodedOrigin.BottomRight: m.ScaleX = -1; m.ScaleY = -1; m.TransX = w; m.TransY = h; break;
            case SKEncodedOrigin.BottomLeft: m.ScaleY = -1; m.TransY = h; break;
            case SKEncodedOrigin.LeftTop: m.ScaleX = 0; m.ScaleY = 0; m.SkewX = 1; m.SkewY = 1; break;
            case SKEncodedOrigin.RightTop: m.ScaleX = 0; m.ScaleY = 0; m.SkewX = -1; m.SkewY = 1; m.TransX = h; break;
            case SKEncodedOrigin.RightBottom: m.ScaleX = 0; m.ScaleY = 0; m.SkewX = -1; m.SkewY = -1; m.TransX = h; m.TransY = w; break;
            case SKEncodedOrigin.LeftBottom: m.ScaleX = 0; m.ScaleY = 0; m.SkewX = 1; m.SkewY = -1; m.TransY = w; break;
        }
        canvas.SetMatrix(m);
        canvas.DrawBitmap(original, 0, 0);
        return salida;
    }
}
