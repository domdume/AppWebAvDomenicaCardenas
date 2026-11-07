using System;
using System.Web;
using System.Web.Security;
using System.Web.UI;
namespace WebAppPoliMusicV3
{
    public partial class SiteMaster : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            var user = Session[EntityLayer.PoliMusicV3.Util.Constants.USER] as EntityLayer.PoliMusicV3.User;
            if (!Request.IsAuthenticated || user == null) { FormsAuthentication.SignOut(); Response.Redirect("~/Login", true); return; }
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
            litUser.Text = user.UserName;
            bool songs = Request.AppRelativeCurrentExecutionFilePath.IndexOf("Song", StringComparison.OrdinalIgnoreCase) >= 0;
            var active = songs ? navSongs : navHome;
            active.Attributes["class"] = "nav-item selected";
            active.Attributes["aria-current"] = "page";
        }
    }
}
