using System.Text.Json;
using System.Text.Json.Serialization;

namespace AMOR.AccesoOffline;

public record Evento(Guid Id, string Nombre)
{
    public override string ToString() => Nombre;
    public static readonly Evento[] Todos = [
        new(Guid.Parse("43e67bda-d19d-4c0e-a639-e85f2d62f294"), "RADEV’S · Minatitlán · 6 diciembre 2026"),
        new(Guid.Parse("3dc92160-79af-4bf7-b770-263038e88900"), "AMOR · Chiapas · 19 diciembre 2026")
    ];
    public static void Validar(Guid id)
    {
        if (!Todos.Any(e => e.Id == id)) throw new InvalidDataException("Evento no permitido.");
    }
}

public sealed record Participante
{
    public Guid RegistroId { get; init; }
    public Guid EventoId { get; init; }
    public string Nombre { get; init; } = "";
    public string Folio { get; init; } = "";
    public string Asesor { get; init; } = "";
    public string Grupo { get; init; } = "";
    public string EstadoRegistro { get; init; } = "";
    public bool ExentoPago { get; init; }
    public bool PagoValidado { get; init; }
    public bool YaIngreso { get; init; }
    public Guid? InvitacionId { get; init; }
    public string? TokenHash { get; init; }
    public string? EstadoInvitacion { get; init; }
    public string? FotoPath { get; init; }
    public string? FotoUrl { get; set; }
}
public sealed record Paquete
{
    public bool Ok { get; init; }
    public Guid PaqueteId { get; init; }
    public Guid EventoId { get; init; }
    public Guid DispositivoId { get; init; }
    public Guid UsuarioId { get; init; }
    public DateTimeOffset CreadoAt { get; init; }
    public DateTimeOffset ExpiraAt { get; init; }
    public List<Participante> Participantes { get; init; } = [];
}
public record Pendiente(Guid OperacionId, Guid PaqueteId, Guid RegistroId,
    string Token, DateTimeOffset IngresadoAt, string Estado, string Detalle);
public record ResultadoSync(Guid OperacionId, bool Ok, string Estado, string? Detalle = null);
public record RespuestaSync(bool Ok, List<ResultadoSync> Resultados);
public record ResultadoQR(string Estado, string Nombre = "", string Folio = "", string Asesor = "",
    string Grupo = "", Guid RegistroId = default, Guid InvitacionId = default, string FotoPath = "");
public record ResumenLocal(int Participantes, int Entradas, int Pendientes, int Conflictos, int Fotos,
    DateTimeOffset? Descarga, DateTimeOffset? Expira);
public record Sesion(string AccessToken, string RefreshToken, long ExpiresAt);
public record FilaAcceso(string Nombre, string Folio, string Asesor, string Grupo,
    DateTimeOffset Entrada, string Estado, string Detalle);

public static class Formato
{
    public static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        PropertyNameCaseInsensitive = true
    };
    public static string HashToken(string token) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(token))).ToLowerInvariant();
    public static bool TokenValido(string token) =>
        token.Length == 64 && token.All(Uri.IsHexDigit);
}
