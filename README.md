
# MusicName

This plugin prints the names of music played in chat based on a config file.

> [!NOTE]
> The [`main`](https://github.com/notkoen/sm-plugin-MusicName) branch contains the code for a non-clientprefs version that doesn't store client settings.

## Config Formatting

The plugin reads configs in the format below under `/sourcemod/configs/musicname/<mapname>.cfg`. For sample configs, you can refer to my other [Music-Names](https://github.com/notkoen/music-names) repository.

> [!CAUTION]
> File extensions must be **included** *(such as `.mp3`)* for music to be detected and displayed

> [!CAUTION]
> File names must be **lowercase**

```yaml
"music"
{
    "filename.mp3" "Artist - Title"
    "level1_boss.mp3" "Pendulum - The Tempest (Live at Brixton Academy)"
    "level2_boss.mp3" "Pendulum - Slam"
}
```