using System.Drawing;

namespace AMOR.AccesoOffline;

public sealed class BuscarParticipantesForm : Form
{
    private readonly BaseDatosLocal local;
    private readonly TextBox nombre = new()
    {
        Name = "BusquedaNombre",
        Dock = DockStyle.Fill,
        PlaceholderText = "Nombre completo o apellidos"
    };
    private readonly Button buscar = new() { Name = "BuscarNombre", Text = "Buscar", AutoSize = true };
    private readonly Button revisar = new()
    {
        Name = "RevisarPersona",
        Text = "Revisar persona seleccionada",
        AutoSize = true,
        Enabled = false
    };
    private readonly Label resultado = new()
    {
        Name = "ResultadoBusqueda",
        Dock = DockStyle.Top,
        Height = 50,
        Text = "Busca por nombre y apellidos. Verifica folio, asesor y grupo si hay personas con el mismo nombre."
    };
    private readonly DataGridView filas = new()
    {
        Name = "CoincidenciasNombre",
        Dock = DockStyle.Fill,
        ReadOnly = true,
        AllowUserToAddRows = false,
        AllowUserToDeleteRows = false,
        AllowUserToResizeRows = false,
        AutoGenerateColumns = false,
        MultiSelect = false,
        SelectionMode = DataGridViewSelectionMode.FullRowSelect,
        RowHeadersVisible = false,
        AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
        AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.DisplayedCells,
        ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.AutoSize,
        DefaultCellStyle = new DataGridViewCellStyle { WrapMode = DataGridViewTriState.True, Padding = new Padding(2) }
    };
    private bool buscando;
    public ResultadoQR? Seleccion { get; private set; }

    public BuscarParticipantesForm(BaseDatosLocal datos, string evento)
    {
        local = datos;
        Text = "Buscar participante · " + evento;
        Size = new Size(1100, 600); MinimumSize = new Size(860, 480);
        StartPosition = FormStartPosition.CenterParent;
        Font = new Font("Segoe UI", 11); BackColor = Color.FromArgb(255, 246, 250);
        AutoScaleMode = AutoScaleMode.Dpi;
        foreach (var (campo, titulo, peso) in new[] {
            ("Nombre", "Nombre completo", 30), ("Folio", "Folio", 25),
            ("Asesor", "Asesor", 12), ("Grupo", "Grupo", 12), ("Estado", "Situación", 21) })
            filas.Columns.Add(new DataGridViewTextBoxColumn
            {
                DataPropertyName = campo,
                HeaderText = titulo,
                FillWeight = peso,
                SortMode = DataGridViewColumnSortMode.NotSortable
            });
        filas.Columns[1].DefaultCellStyle = new DataGridViewCellStyle { Font = new Font("Consolas", 9), WrapMode = DataGridViewTriState.True };
        filas.CellFormatting += (_, e) =>
        {
            if (e.ColumnIndex == 1 && e.Value is string folio)
            {
                var separador = folio.IndexOf('-');
                if (separador >= 0 && folio.Length > 20)
                { e.Value = folio[..(separador + 1)] + "\n" + folio[(separador + 1)..]; e.FormattingApplied = true; }
                return;
            }
            if (e.ColumnIndex != 4 || e.Value is not string valor) return;
            e.Value = valor switch
            {
                "autorizable" => "Puede revisarse",
                "ya_ingreso" => "Ya ingresó",
                "sin_pago" => "Sin pago validado",
                "revocada" => "QR revocado",
                "no_confirmado" => "Sin confirmar",
                "sin_invitacion" => "Sin QR emitido",
                _ => "No autorizable"
            };
            e.FormattingApplied = true;
        };
        var cabecera = new TableLayoutPanel { Dock = DockStyle.Top, Height = 96, Padding = new Padding(12), ColumnCount = 2 };
        cabecera.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        cabecera.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        cabecera.Controls.Add(nombre, 0, 0); cabecera.Controls.Add(buscar, 1, 0);
        var ayuda = new Label
        {
            Text = "Puedes escribir los apellidos primero. La búsqueda no distingue acentos ni mayúsculas.",
            AutoSize = true,
            Margin = new Padding(0, 8, 0, 0)
        };
        cabecera.Controls.Add(ayuda, 0, 1); cabecera.SetColumnSpan(ayuda, 2);
        var contenido = new Panel { Dock = DockStyle.Fill, Padding = new Padding(12) };
        contenido.Controls.Add(filas); contenido.Controls.Add(resultado);
        var pie = new FlowLayoutPanel { Dock = DockStyle.Bottom, Height = 58, Padding = new Padding(12), FlowDirection = FlowDirection.RightToLeft };
        var cancelar = new Button { Text = "Cancelar", AutoSize = true, DialogResult = DialogResult.Cancel };
        pie.Controls.Add(cancelar); pie.Controls.Add(revisar);
        Controls.Add(contenido); Controls.Add(cabecera); Controls.Add(pie);
        AcceptButton = buscar; CancelButton = cancelar;
        buscar.Click += async (_, _) => await Buscar();
        filas.SelectionChanged += (_, _) => revisar.Enabled = !buscando && filas.SelectedRows.Count == 1;
        revisar.Click += (_, _) =>
        {
            if (buscando || filas.SelectedRows.Count != 1 || filas.SelectedRows[0].DataBoundItem is not ResultadoQR persona) return;
            Seleccion = persona; DialogResult = DialogResult.OK; Close();
        };
        filas.CellDoubleClick += (_, e) => { if (e.RowIndex >= 0) revisar.PerformClick(); };
        FormClosing += (_, e) => { if (buscando) e.Cancel = true; };
        Shown += (_, _) => nombre.Focus();
    }
    private async Task Buscar()
    {
        if (buscando) return;
        Seleccion = null; revisar.Enabled = false; filas.DataSource = null;
        var consulta = nombre.Text.Trim();
        if (consulta.Count(char.IsLetterOrDigit) < 2)
        { resultado.Text = "Escribe al menos dos letras del nombre o de los apellidos."; return; }
        var resumen = local.Resumen();
        if (resumen.Descarga is null || resumen.Expira <= DateTimeOffset.UtcNow)
        { resultado.Text = "Primero descarga o actualiza los datos de este evento con internet."; return; }
        buscando = true; buscar.Enabled = false; nombre.Enabled = false;
        resultado.Text = "Buscando en los datos guardados en esta laptop…";
        try
        {
            var coincidencias = await Task.Run(() => local.BuscarNombre(consulta));
            filas.DataSource = coincidencias;
            filas.ClearSelection(); revisar.Enabled = false;
            resultado.Text = coincidencias.Count == 0 ? "No hay coincidencias en la última descarga de este evento." :
                $"{coincidencias.Count} coincidencia(s). Selecciona a la persona correcta; después revisarás su fotografía.";
        }
        catch { resultado.Text = "No se pudo leer la búsqueda local. No se autorizó ninguna entrada."; }
        finally { buscando = false; buscar.Enabled = true; nombre.Enabled = true; nombre.Focus(); }
    }
}
