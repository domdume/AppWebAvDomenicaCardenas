namespace WebAppPoliMusicV2.Entities
{
    public class Song
    {
        public int ID { get; set; }
        public string SongName { get; set; }
        public string SongPath { get; set; }
        public int? Plays { get; set; }
    }
}
