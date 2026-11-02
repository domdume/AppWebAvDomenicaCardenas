using System;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using System.Web;
using System.Web.Security;
using System.Web.UI.WebControls;
namespace WebAppPoliMusicV2
{
    public partial class Song : System.Web.UI.Page
    {
        private BLL.Song Service { get { return new BLL.Song(ConfigurationManager.ConnectionStrings["BDD_PoliMusicConnectionString"].ConnectionString); } }
        private int EditingId { get { return ViewState["EditingId"] == null ? 0 : (int)ViewState["EditingId"]; } set { ViewState["EditingId"] = value; } }
        protected override void OnInit(EventArgs e)
        {
            ViewStateUserKey = Session.SessionID;
            base.OnInit(e);
            if (!Request.IsAuthenticated || !(Session[Util.Constants.USER] is Entities.User))
            {
                FormsAuthentication.SignOut();
                Response.Redirect("Login.aspx", true);
            }
        }
        protected void Page_Load(object sender, EventArgs e)
        {
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
            Entities.User user = Session[Util.Constants.USER] as Entities.User;
            if (user == null) return;
            litUser.Text = user.UserName;
            if (!IsPostBack) LoadSongs();
        }
        private void LoadSongs()
        {
            try { var songs = Service.Read(); gridSongs.DataSource = songs; gridSongs.DataBind(); litCount.Text = songs.Count.ToString(); if (gridSongs.HeaderRow != null) gridSongs.HeaderRow.TableSection = TableRowSection.TableHeader; }
            catch (SqlException ex) { ShowDatabaseError(ex); }
        }
        protected string AudioUrl(object path)
        {
            try { string local = BLL.Song.NormalizePath(Convert.ToString(path)); return File.Exists(Server.MapPath(local)) ? System.Web.HttpUtility.HtmlAttributeEncode(ResolveUrl(local)) : string.Empty; }
            catch (ArgumentException) { return string.Empty; }
        }
        protected void Save_Click(object sender, EventArgs e)
        {
            try
            {
                int plays; int? count = null;
                if (txtPlays.Text.Trim().Length > 0) { if (!int.TryParse(txtPlays.Text.Trim(), out plays) || plays < 0) throw new ArgumentException("Escribe un número de reproducciones válido o deja el campo vacío."); count = plays; }
                string path = BLL.Song.NormalizePath(txtPath.Text);
                if (!File.Exists(Server.MapPath(path))) throw new ArgumentException("No se encontró el audio. Guarda el archivo en SongFiles y revisa la ruta.");
                Entities.Song song = new Entities.Song { ID = EditingId, SongName = txtName.Text, SongPath = path, Plays = count };
                if (EditingId == 0) Service.Save(song);
                else if (Service.Update(song) == 0) throw new ArgumentException("La canción ya no existe. Actualiza la biblioteca.");
                ResetEditor(); LoadSongs(); Message("Canción guardada correctamente.", false);
            }
            catch (ArgumentException ex) { Message(ex.Message, true); }
            catch (SqlException ex) { ShowDatabaseError(ex); }
        }
        protected void Songs_Command(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName != "EditSong" && e.CommandName != "DeleteSong") return;
            int id; if (!int.TryParse(Convert.ToString(e.CommandArgument), out id) || id <= 0) { Message("Selecciona una canción válida.", true); return; }
            try
            {
                if (e.CommandName == "DeleteSong")
                {
                    if (Service.Delete(id) == 0) { Message("La canción ya no existe.", true); LoadSongs(); return; }
                    if (EditingId == id) ResetEditor();
                    LoadSongs(); Message("Canción eliminada de la biblioteca.", false);
                }
                else
                {
                    Entities.Song song = Service.Read(id);
                    if (song == null) { Message("La canción ya no existe.", true); LoadSongs(); return; }
                    EditingId = id; txtName.Text = song.SongName; txtPath.Text = song.SongPath; txtPlays.Text = song.Plays.HasValue ? song.Plays.Value.ToString() : string.Empty;
                    litEditor.Text = "Editar canción"; btnSave.Text = "Guardar cambios"; btnCancel.Visible = true; txtName.Focus();
                }
            }
            catch (SqlException ex) { ShowDatabaseError(ex); }
        }
        protected void Cancel_Click(object sender, EventArgs e) { ResetEditor(); pnlMessage.Visible = false; }
        private void ResetEditor() { EditingId = 0; txtName.Text = string.Empty; txtPath.Text = "~/SongFiles/"; txtPlays.Text = string.Empty; litEditor.Text = "Añadir canción"; btnSave.Text = "Guardar canción"; btnCancel.Visible = false; }
        private void Message(string text, bool error) { pnlMessage.Visible = true; pnlMessage.CssClass = error ? "message error" : "message"; litMessage.Text = text; }
        private void ShowDatabaseError(SqlException ex)
        {
            System.Diagnostics.Trace.TraceError("Song database error: {0}", ex);
            Message(ex.Number == 547 ? "No se puede eliminar: esta canción pertenece a un álbum, artista o playlist. Retira primero esas asociaciones." : "No se pudo completar la operación. Comprueba la conexión a la base de datos e inténtalo de nuevo.", true);
        }
    }
}

