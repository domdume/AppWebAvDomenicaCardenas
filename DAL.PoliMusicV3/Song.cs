using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
namespace DAL.PoliMusicV3
{
    public class Song
    {
        private readonly string connectionString;
        public Song(string connectionString) { this.connectionString = connectionString; }
        public List<EntityLayer.PoliMusicV3.Song> Read() { return Query(null); }
        public EntityLayer.PoliMusicV3.Song Read(int id) { List<EntityLayer.PoliMusicV3.Song> rows = Query(id); return rows.Count == 0 ? null : rows[0]; }
        private List<EntityLayer.PoliMusicV3.Song> Query(int? id)
        {
            List<EntityLayer.PoliMusicV3.Song> songs = new List<EntityLayer.PoliMusicV3.Song>();
            using (SqlConnection con = new SqlConnection(connectionString))
            using (SqlCommand cmd = new SqlCommand("SELECT ID_SONG, SONG_NAME, SONG_PATH, PLAYS FROM dbo.TBL_SONG" + (id.HasValue ? " WHERE ID_SONG=@ID" : " ORDER BY SONG_NAME, ID_SONG"), con))
            {
                if (id.HasValue) cmd.Parameters.Add("@ID", SqlDbType.Int).Value = id.Value;
                con.Open();
                using (SqlDataReader r = cmd.ExecuteReader())
                    while (r.Read()) songs.Add(new EntityLayer.PoliMusicV3.Song { ID = r.GetInt32(0), SongName = r.GetString(1), SongPath = r.GetString(2), Plays = r.IsDBNull(3) ? (int?)null : r.GetInt32(3) });
            }
            return songs;
        }
        public int Save(EntityLayer.PoliMusicV3.Song song) { return Write(song, false); }
        public int Update(EntityLayer.PoliMusicV3.Song song) { return Write(song, true); }
        private int Write(EntityLayer.PoliMusicV3.Song song, bool update)
        {
            string sql = update ? "UPDATE dbo.TBL_SONG SET SONG_NAME=@NAME, SONG_PATH=@PATH, PLAYS=@PLAYS WHERE ID_SONG=@ID" : "INSERT INTO dbo.TBL_SONG (SONG_NAME, SONG_PATH, PLAYS) VALUES (@NAME,@PATH,@PLAYS); SELECT CAST(SCOPE_IDENTITY() AS int);";
            using (SqlConnection con = new SqlConnection(connectionString))
            using (SqlCommand cmd = new SqlCommand(sql, con))
            {
                cmd.Parameters.Add("@NAME", SqlDbType.VarChar, 50).Value = song.SongName;
                cmd.Parameters.Add("@PATH", SqlDbType.VarChar, 255).Value = song.SongPath;
                cmd.Parameters.Add("@PLAYS", SqlDbType.Int).Value = song.Plays.HasValue ? (object)song.Plays.Value : DBNull.Value;
                if (update) cmd.Parameters.Add("@ID", SqlDbType.Int).Value = song.ID;
                con.Open();
                return update ? cmd.ExecuteNonQuery() : (int)cmd.ExecuteScalar();
            }
        }
        public int Delete(int id)
        {
            // Foreign keys protect songs used in albums or playlists.
            using (SqlConnection con = new SqlConnection(connectionString))
            using (SqlCommand cmd = new SqlCommand("DELETE FROM dbo.TBL_SONG WHERE ID_SONG=@ID", con))
            {
                cmd.Parameters.Add("@ID", SqlDbType.Int).Value = id;
                con.Open();
                return cmd.ExecuteNonQuery();
            }
        }
    }
}
