using Microsoft.Data.Sqlite;
using System.Text.Json;
using System.Text;
using System.Globalization;

namespace AMOR.AccesoOffline;

public sealed class BaseDatosLocal
{
    public static string CarpetaDatos => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AMOR", "AccesoOffline", "v2");
    public Guid EventoId { get; }
    public string Carpeta { get; }
    public string Ruta => Path.Combine(Carpeta, "acceso.db");
    public static Guid DispositivoId
    {
        get
        {
            var ruta = Path.Combine(CarpetaDatos, "dispositivo.txt");
            Directory.CreateDirectory(CarpetaDatos);
            if (!File.Exists(ruta))
            {
                using var f = new FileStream(ruta, FileMode.CreateNew, FileAccess.Write, FileShare.Read);
                using var w = new StreamWriter(f);
                w.Write(Guid.NewGuid().ToString());
            }
            return Guid.Parse(File.ReadAllText(ruta));
        }
    }
    public BaseDatosLocal(Guid eventoId, string? raiz = null)
    {
        Evento.Validar(eventoId);
        EventoId = eventoId;
        Carpeta = Path.Combine(raiz ?? CarpetaDatos, eventoId.ToString());
        Directory.CreateDirectory(Carpeta);
        using var cn = Abrir();
        using var cmd = cn.CreateCommand();
        cmd.CommandText = """
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS participantes(
                registro_id TEXT PRIMARY KEY, paquete_id TEXT NOT NULL, datos TEXT NOT NULL,
                estado TEXT NOT NULL, exento INTEGER NOT NULL, pagado INTEGER NOT NULL,
                ya_ingreso INTEGER NOT NULL, foto_local TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS invitaciones(
                invitacion_id TEXT PRIMARY KEY, registro_id TEXT NOT NULL REFERENCES participantes(registro_id),
                paquete_id TEXT NOT NULL, token_hash TEXT NOT NULL UNIQUE, estado TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS accesos(
                operacion_id TEXT PRIMARY KEY, registro_id TEXT NOT NULL UNIQUE REFERENCES participantes(registro_id),
                invitacion_id TEXT NOT NULL REFERENCES invitaciones(invitacion_id), paquete_id TEXT NOT NULL,
                token_protegido TEXT NOT NULL, ingresado_at TEXT NOT NULL,
                estado_sync TEXT NOT NULL DEFAULT 'pendiente', detalle TEXT NOT NULL DEFAULT '',
                origen TEXT NOT NULL DEFAULT 'qr');
            CREATE TABLE IF NOT EXISTS configuracion(clave TEXT PRIMARY KEY, valor TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS idx_sync ON accesos(estado_sync);
            """;
        cmd.ExecuteNonQuery();
        using var columnas = cn.CreateCommand();
        columnas.CommandText = "PRAGMA table_info(accesos)";
        bool tieneOrigen = false;
        using (var lector = columnas.ExecuteReader())
            while (lector.Read()) if (lector.GetString(1) == "origen") tieneOrigen = true;
        if (!tieneOrigen)
        {
            using var migrar = cn.CreateCommand();
            migrar.CommandText = "ALTER TABLE accesos ADD COLUMN origen TEXT NOT NULL DEFAULT 'qr'";
            migrar.ExecuteNonQuery();
        }
    }
    private SqliteConnection Abrir()
    {
        var cn = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = Ruta,
            ForeignKeys = true,
            DefaultTimeout = 5
        }.ToString());
        cn.Open();
        return cn;
    }
    private static SqliteCommand Comando(SqliteConnection cn, SqliteTransaction? tx,
        string sql, params (string, object?)[] valores)
    {
        var cmd = cn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = sql;
        foreach (var (nombre, valor) in valores) cmd.Parameters.AddWithValue(nombre, valor ?? DBNull.Value);
        return cmd;
    }
    public Paquete? PaqueteActual()
    {
        using var cn = Abrir();
        return PaqueteActual(cn, null);
    }
    private static Paquete? PaqueteActual(SqliteConnection cn, SqliteTransaction? tx)
    {
        using var cmd = Comando(cn, tx, "SELECT valor FROM configuracion WHERE clave='paquete'");
        var s = cmd.ExecuteScalar() as string;
        return s is null ? null : JsonSerializer.Deserialize<Paquete>(Proteccion.Abrir(s), Formato.Json);
    }
    public string RutaSegura(string relativa)
    {
        var raiz = Path.GetFullPath(Carpeta) + Path.DirectorySeparatorChar;
        var ruta = Path.GetFullPath(Path.Combine(Carpeta, relativa));
        if (!ruta.StartsWith(raiz, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("Ruta de fotografía inválida.");
        return ruta;
    }
    public void Importar(Paquete paquete, Guid dispositivo, IReadOnlyDictionary<Guid, string> fotos)
    {
        if (!paquete.Ok || paquete.EventoId != EventoId || paquete.DispositivoId != dispositivo ||
            paquete.PaqueteId == Guid.Empty || paquete.UsuarioId == Guid.Empty ||
            paquete.CreadoAt > DateTimeOffset.UtcNow.AddMinutes(5) ||
            paquete.ExpiraAt <= DateTimeOffset.UtcNow || paquete.ExpiraAt <= paquete.CreadoAt ||
            paquete.Participantes.Count > 10000)
            throw new InvalidDataException("El paquete no corresponde a este evento/equipo o está vencido.");
        var registros = new HashSet<Guid>();
        var invitaciones = new HashSet<Guid>();
        var hashes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var p in paquete.Participantes)
        {
            if (p.EventoId != EventoId || p.RegistroId == Guid.Empty || !registros.Add(p.RegistroId))
                throw new InvalidDataException("Paquete con inscripciones repetidas o de otro evento.");
            if (p.InvitacionId is Guid id &&
                (id == Guid.Empty || !invitaciones.Add(id) || !Formato.TokenValido(p.TokenHash ?? "") ||
                 !hashes.Add(p.TokenHash!)))
                throw new InvalidDataException("Paquete con invitaciones inválidas.");
            if (!string.IsNullOrWhiteSpace(p.FotoPath) &&
                (!fotos.TryGetValue(p.RegistroId, out var f) || !File.Exists(RutaSegura(f))))
                throw new InvalidDataException("Falta descargar una fotografía. Se conserva la descarga anterior.");
        }
        using var cn = Abrir();
        using var tx = cn.BeginTransaction(deferred: false);
        foreach (var p in paquete.Participantes)
        {
            var dato = JsonSerializer.Serialize(p with { FotoUrl = null }, Formato.Json);
            using var cmd = Comando(cn, tx, """
                INSERT INTO participantes VALUES($id,$paquete,$datos,$estado,$exento,$pago,$ingreso,$foto)
                ON CONFLICT(registro_id) DO UPDATE SET paquete_id=excluded.paquete_id,datos=excluded.datos,
                estado=excluded.estado,exento=excluded.exento,pagado=excluded.pagado,
                ya_ingreso=excluded.ya_ingreso,foto_local=excluded.foto_local
                """, ("$id", p.RegistroId.ToString()), ("$paquete", paquete.PaqueteId.ToString()),
                ("$datos", Proteccion.Proteger(dato)), ("$estado", p.EstadoRegistro), ("$exento", p.ExentoPago),
                ("$pago", p.PagoValidado), ("$ingreso", p.YaIngreso),
                ("$foto", fotos.GetValueOrDefault(p.RegistroId) ?? ""));
            cmd.ExecuteNonQuery();
            if (p.InvitacionId is Guid inv)
            {
                using var ci = Comando(cn, tx, """
                    INSERT INTO invitaciones VALUES($id,$registro,$paquete,$hash,$estado)
                    ON CONFLICT(invitacion_id) DO UPDATE SET paquete_id=excluded.paquete_id,
                    token_hash=excluded.token_hash,estado=excluded.estado
                    """, ("$id", inv.ToString()), ("$registro", p.RegistroId.ToString()),
                    ("$paquete", paquete.PaqueteId.ToString()), ("$hash", p.TokenHash),
                    ("$estado", p.EstadoInvitacion ?? "revocada"));
                ci.ExecuteNonQuery();
            }
        }
        using var meta = Comando(cn, tx, """
            INSERT INTO configuracion VALUES('paquete',$valor)
            ON CONFLICT(clave) DO UPDATE SET valor=excluded.valor
            """, ("$valor", Proteccion.Proteger(JsonSerializer.Serialize(
                paquete with { Participantes = [] }, Formato.Json))));
        meta.ExecuteNonQuery();
        tx.Commit();
    }
    public ResultadoQR Consultar(string token)
    {
        using var cn = Abrir();
        return Consultar(cn, null, token.Trim());
    }
    private static string NormalizarNombre(string texto)
    {
        var s = new StringBuilder();
        foreach (var c in texto.Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                s.Append(char.IsLetterOrDigit(c) ? char.ToUpperInvariant(c) : ' ');
        return s.ToString().Normalize(NormalizationForm.FormC);
    }
    public List<ResultadoQR> BuscarNombre(string consulta)
    {
        var palabras = NormalizarNombre(consulta).Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (palabras.Sum(p => p.Length) < 2) return [];
        using var cn = Abrir();
        var paquete = PaqueteActual(cn, null);
        if (paquete is null || DateTimeOffset.UtcNow > paquete.ExpiraAt ||
            DateTimeOffset.UtcNow < paquete.CreadoAt.AddMinutes(-5)) return [];
        using var cmd = Comando(cn, null, "SELECT registro_id,datos FROM participantes WHERE paquete_id=$paquete",
            ("$paquete", paquete.PaqueteId.ToString()));
        var ids = new List<Guid>();
        using (var lector = cmd.ExecuteReader())
            while (lector.Read())
            {
                var persona = JsonSerializer.Deserialize<Participante>(Proteccion.Abrir(lector.GetString(1)), Formato.Json)!;
                var nombre = NormalizarNombre(persona.Nombre);
                if (palabras.All(p => nombre.Contains(p, StringComparison.Ordinal))) ids.Add(Guid.Parse(lector.GetString(0)));
            }
        return ids.Select(id => ConsultarFicha(cn, null, id)).Where(f => f.RegistroId != Guid.Empty)
            .OrderBy(f => f.Nombre, StringComparer.CurrentCultureIgnoreCase).ThenBy(f => f.Folio).ToList();
    }
    public ResultadoQR ConsultarRegistro(Guid registroId)
    {
        using var cn = Abrir();
        return ConsultarFicha(cn, null, registroId);
    }
    private ResultadoQR Consultar(SqliteConnection cn, SqliteTransaction? tx, string token)
    {
        if (!Formato.TokenValido(token)) return new("qr_invalido");
        var paquete = PaqueteActual(cn, tx);
        if (paquete is null) return new("sin_descarga");
        using var cmd = Comando(cn, tx,
            "SELECT registro_id,invitacion_id FROM invitaciones WHERE token_hash=$hash AND paquete_id=$paquete LIMIT 1",
            ("$hash", Formato.HashToken(token)), ("$paquete", paquete.PaqueteId.ToString()));
        Guid registro, invitacion;
        using (var lector = cmd.ExecuteReader())
        {
            if (!lector.Read()) return new("qr_invalido");
            registro = Guid.Parse(lector.GetString(0)); invitacion = Guid.Parse(lector.GetString(1));
        }
        return ConsultarFicha(cn, tx, registro, invitacion);
    }
    private ResultadoQR ConsultarFicha(SqliteConnection cn, SqliteTransaction? tx, Guid registroId, Guid? invitacionId = null)
    {
        var paquete = PaqueteActual(cn, tx);
        if (paquete is null) return new("sin_descarga");
        if (DateTimeOffset.UtcNow > paquete.ExpiraAt) return new("paquete_vencido");
        if (DateTimeOffset.UtcNow < paquete.CreadoAt.AddMinutes(-5)) return new("revisar_reloj");
        using var cmd = Comando(cn, tx, """
            SELECT p.datos,p.estado,i.estado,p.exento,p.pagado,
            (p.ya_ingreso=1 OR EXISTS(SELECT 1 FROM accesos a WHERE a.registro_id=p.registro_id)),
            p.foto_local,i.invitacion_id
            FROM participantes p LEFT JOIN invitaciones i ON i.registro_id=p.registro_id AND i.paquete_id=p.paquete_id
            WHERE p.registro_id=$registro AND p.paquete_id=$paquete
              AND ($invitacion IS NULL OR i.invitacion_id=$invitacion) LIMIT 1
            """, ("$registro", registroId.ToString()), ("$paquete", paquete.PaqueteId.ToString()),
            ("$invitacion", invitacionId?.ToString()));
        using var r = cmd.ExecuteReader();
        if (!r.Read()) return new("qr_invalido");
        var p = JsonSerializer.Deserialize<Participante>(Proteccion.Abrir(r.GetString(0)), Formato.Json)!;
        var estado = r.GetBoolean(5) ? "ya_ingreso" :
            r.GetString(1) != "confirmado" ? "no_confirmado" :
            r.IsDBNull(7) ? "sin_invitacion" :
            r.GetString(2) is not ("activa" or "emitida") ? "revocada" :
            !(r.GetBoolean(3) || r.GetBoolean(4)) ? "sin_pago" : "autorizable";
        return new(estado, p.Nombre, p.Folio, p.Asesor, p.Grupo,
            p.RegistroId, r.IsDBNull(7) ? Guid.Empty : Guid.Parse(r.GetString(7)), r.GetString(6));
    }
    public bool Registrar(string token)
    {
        token = token.Trim();
        using var cn = Abrir();
        using var tx = cn.BeginTransaction(deferred: false);
        return GuardarAcceso(cn, tx, Consultar(cn, tx, token), token, "qr");
    }
    public bool RegistrarPorNombre(Guid registroId, Guid invitacionId, bool identidadConfirmada)
    {
        if (!identidadConfirmada || registroId == Guid.Empty || invitacionId == Guid.Empty) return false;
        using var cn = Abrir();
        using var tx = cn.BeginTransaction(deferred: false);
        var ficha = ConsultarFicha(cn, tx, registroId, invitacionId);
        if (ficha.FotoPath == "" || !File.Exists(RutaSegura(ficha.FotoPath))) return false;
        return GuardarAcceso(cn, tx, ficha, "manual:" + invitacionId, "nombre");
    }
    private bool GuardarAcceso(SqliteConnection cn, SqliteTransaction tx, ResultadoQR ficha, string token, string origen)
    {
        if (ficha.Estado != "autorizable") return false;
        var paquete = PaqueteActual(cn, tx)!;
        using var cmd = Comando(cn, tx, """
            INSERT INTO accesos(operacion_id,registro_id,invitacion_id,paquete_id,token_protegido,ingresado_at,origen)
            VALUES($op,$reg,$inv,$paq,$token,$fecha,$origen)
            """, ("$op", Guid.NewGuid().ToString()), ("$reg", ficha.RegistroId.ToString()),
            ("$inv", ficha.InvitacionId.ToString()), ("$paq", paquete.PaqueteId.ToString()),
            ("$token", Proteccion.Proteger(token)), ("$fecha", DateTimeOffset.UtcNow.ToString("O")), ("$origen", origen));
        try { cmd.ExecuteNonQuery(); tx.Commit(); return true; }
        catch (SqliteException e) when (e.SqliteErrorCode == 19) { return false; }
    }
    public List<Pendiente> Pendientes()
    {
        using var cn = Abrir();
        using var cmd = Comando(cn, null, """
            SELECT operacion_id,paquete_id,registro_id,token_protegido,ingresado_at,estado_sync,detalle,origen,invitacion_id
            FROM accesos WHERE estado_sync IN ('pendiente','conflicto') ORDER BY ingresado_at
            """);
        using var r = cmd.ExecuteReader();
        var resultado = new List<Pendiente>();
        while (r.Read()) resultado.Add(new(Guid.Parse(r.GetString(0)), Guid.Parse(r.GetString(1)),
            Guid.Parse(r.GetString(2)), Proteccion.Abrir(r.GetString(3)), DateTimeOffset.Parse(r.GetString(4)),
            r.GetString(5), r.GetString(6), r.GetString(7), Guid.Parse(r.GetString(8))));
        return resultado;
    }
    public void AplicarResultado(ResultadoSync resultado)
    {
        // Only a confirmed server response removes an entry from the pending queue.
        var estado = resultado.Estado == "ingreso_registrado" && resultado.Ok ? "sincronizado" :
            resultado.Estado == "ya_ingreso" && resultado.Ok ? "duplicado" : "conflicto";
        using var cn = Abrir();
        using var cmd = Comando(cn, null, """
            UPDATE accesos SET estado_sync=$estado,detalle=$detalle
            WHERE operacion_id=$op AND estado_sync IN ('pendiente','conflicto')
            """, ("$estado", estado), ("$detalle", resultado.Detalle ?? resultado.Estado),
            ("$op", resultado.OperacionId.ToString()));
        cmd.ExecuteNonQuery();
    }
    public ResumenLocal Resumen()
    {
        using var cn = Abrir();
        var p = PaqueteActual(cn, null);
        int Cuenta(string sql) { using var c = Comando(cn, null, sql); return Convert.ToInt32(c.ExecuteScalar()); }
        var participantes = 0; var fotos = 0;
        if (p is not null)
        {
            using var c = Comando(cn, null, "SELECT foto_local FROM participantes WHERE paquete_id=$p",
                ("$p", p.PaqueteId.ToString()));
            using var r = c.ExecuteReader();
            while (r.Read()) { participantes++; if (r.GetString(0) != "" && File.Exists(RutaSegura(r.GetString(0)))) fotos++; }
        }
        return new(participantes, Cuenta("SELECT count(*) FROM accesos"),
            Cuenta("SELECT count(*) FROM accesos WHERE estado_sync='pendiente'"),
            Cuenta("SELECT count(*) FROM accesos WHERE estado_sync='conflicto'"), fotos, p?.CreadoAt, p?.ExpiraAt);
    }
    public void Respaldar(string destino)
    {
        using var cn = Abrir();
        using var copia = new SqliteConnection($"Data Source={destino}");
        copia.Open();
        cn.BackupDatabase(copia);
    }
    public List<FilaAcceso> ListarEntradas()
    {
        using var cn = Abrir();
        using var cmd = Comando(cn, null, """
            SELECT p.datos,a.ingresado_at,a.estado_sync,a.detalle,a.origen FROM accesos a
            JOIN participantes p ON p.registro_id=a.registro_id ORDER BY a.ingresado_at DESC
            """);
        using var r = cmd.ExecuteReader();
        var filas = new List<FilaAcceso>();
        while (r.Read())
        {
            var p = JsonSerializer.Deserialize<Participante>(Proteccion.Abrir(r.GetString(0)), Formato.Json)!;
            filas.Add(new(p.Nombre, p.Folio, p.Asesor, p.Grupo,
                DateTimeOffset.Parse(r.GetString(1)).ToLocalTime(), r.GetString(2), r.GetString(3),
                r.GetString(4) == "nombre" ? "Nombre y fotografía" : "QR"));
        }
        return filas;
    }
}
