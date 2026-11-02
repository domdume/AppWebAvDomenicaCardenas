using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
namespace WebAppPoliMusicV2.BLL
{
    public class Song
    {
        private readonly DAL.Song data;
        public Song(string connectionString) { data = new DAL.Song(connectionString); }
        public List<Entities.Song> Read() { return data.Read(); }
        public Entities.Song Read(int id) { ValidateId(id); return data.Read(id); }
        public int Save(Entities.Song song) { Validate(song); return data.Save(song); }
        public int Update(Entities.Song song) { Validate(song); ValidateId(song.ID); return data.Update(song); }
        public int Delete(int id) { ValidateId(id); return data.Delete(id); }
        public static string NormalizePath(string path)
        {
            string value = (path ?? string.Empty).Trim();
            if (!Regex.IsMatch(value, @"^(?:~/|\.\./|/)?songFiles/[\w .()-]+\.(mp3|wav|ogg|m4a)$", RegexOptions.IgnoreCase))
                throw new ArgumentException("Usa una ruta local como ~/SongFiles/cancion.mp3 (MP3, WAV, OGG o M4A).");
            string file = value.Substring(value.LastIndexOf('/') + 1);
            if (file.Contains("..")) throw new ArgumentException("La ruta de audio no es válida.");
            return "~/SongFiles/" + file;
        }
        private static void Validate(Entities.Song song)
        {
            if (song == null) throw new ArgumentException("Completa los datos de la canción.");
            song.SongName = (song.SongName ?? string.Empty).Trim();
            if (song.SongName.Length == 0 || song.SongName.Length > 50) throw new ArgumentException("El nombre debe tener entre 1 y 50 caracteres.");
            song.SongPath = NormalizePath(song.SongPath);
            if (song.SongPath.Length > 255) throw new ArgumentException("La ruta no puede superar 255 caracteres.");
            if (song.Plays.HasValue && song.Plays.Value < 0) throw new ArgumentException("Las reproducciones no pueden ser negativas.");
        }
        private static void ValidateId(int id) { if (id <= 0) throw new ArgumentException("Selecciona una canción válida."); }
    }
}
