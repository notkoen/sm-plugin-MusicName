# Copilot Instructions for MusicName SourceMod Plugin

## Repository Overview

This repository contains the **MusicName** SourceMod plugin, which automatically displays music names in chat when ambient sounds are played in Source engine games (Counter-Strike, Team Fortress 2, etc.). The plugin reads configuration files to map sound file names to human-readable song titles and announces them to players.

### Key Functionality
- **Ambient Sound Detection**: Hooks into SourceMod's ambient sound system to detect when music files are played
- **Dynamic Music Name Display**: Shows song names in chat with configurable cooldown to prevent spam
- **Multi-language Support**: Includes translation files for English, Chinese, and French
- **Player Preferences**: Individual players can toggle music name display on/off
- **Admin Commands**: Reload configurations and dump song lists without restarting the plugin
- **Map-specific Configs**: Each map can have its own music name configuration file

## Technical Environment

- **Language**: SourcePawn (SourceMod scripting language)
- **Target Platform**: SourceMod 1.12+ on Source engine games
- **Build System**: SourceKnight (modern SourceMod build tool)
- **CI/CD**: GitHub Actions with automated building and releases
- **Dependencies**: MultiColors (chat colors), UtilsHelper (utility functions)

## Project Structure

```
addons/sourcemod/
├── scripting/
│   └── MusicName.sp              # Main plugin source code
└── translations/
    └── MusicName.phrases.txt     # Multi-language translation file

.github/
├── workflows/
│   └── ci.yml                    # GitHub Actions CI/CD pipeline
└── dependabot.yml               # Dependency management

sourceknight.yaml                 # SourceKnight build configuration
```

### Runtime Configuration Structure
```
addons/sourcemod/configs/musicname/
└── <mapname>.cfg                 # Per-map configuration files
```

## Code Style & Standards

This repository follows strict SourcePawn coding standards:

### Syntax Requirements
- **ALWAYS** use `#pragma newdecls required` and `#pragma semicolon 1` at the top of .sp files
- Use tabs for indentation (4 spaces equivalent)
- Follow camelCase for local variables and function parameters
- Use PascalCase for function names and public variables
- Prefix global variables with `g_` (e.g., `g_songNames`, `g_bConfigLoaded`)

### Memory Management
- **CRITICAL**: Use `delete` for StringMaps/ArrayLists without null checking
- **NEVER** use `.Clear()` on StringMaps/ArrayLists - creates memory leaks
- Always use `delete` and create new instances instead of clearing
- Example from this codebase:
  ```sourcepawn
  // Correct way (used in OnMapEnd):
  delete g_songNames;
  delete g_fLastPlayedTime;
  g_songNames = new StringMap();
  g_fLastPlayedTime = new StringMap();
  
  // WRONG - causes memory leaks:
  g_songNames.Clear();
  ```

### Translation & Localization
- **ALWAYS** use translation files for user-facing messages
- Load translations with `LoadTranslations("MusicName.phrases");`
- Use format: `CPrintToChat(client, "%t %t", "Chat Prefix", "Message Key", args...);`
- Support multiple languages in phrases.txt format

## Build & Development Process

### Local Development Setup
1. Install SourceKnight: Follow instructions at https://github.com/srcdslab/sourceknight
2. Clone repository with dependencies:
   ```bash
   git clone <repository-url>
   cd sm-plugin-MusicName
   sourceknight build  # Downloads dependencies and compiles
   ```

### Build Commands
```bash
# Build the plugin
sourceknight build

# Clean build artifacts
sourceknight clean

# Install dependencies only
sourceknight install
```

### Dependencies Management
Dependencies are defined in `sourceknight.yaml`:
- **sourcemod**: Core SourceMod framework (version 1.13.0-git7221)
- **multicolors**: Advanced chat color support
- **utilshelper**: Common utility functions

### Testing Your Changes
1. Build the plugin: `sourceknight build`
2. Copy built .smx file to test server: `addons/sourcemod/plugins/`
3. Copy translation file: `addons/sourcemod/translations/`
4. Create test config: `addons/sourcemod/configs/musicname/<mapname>.cfg`
5. Test on a Source engine game server

## Plugin-Specific Development Patterns

### Configuration File Format
Music name configs use KeyValues format:
```
"music"
{
    "filename.mp3"     "Artist - Song Title"
    "boss_music.mp3"   "Epic Composer - Boss Battle Theme"
}
```

**IMPORTANT**: 
- File names must be lowercase
- File extensions must be included (.mp3, .wav, etc.)
- Use exact filename as heard by the ambient sound hook

### Common Code Patterns

#### Adding New Commands
```sourcepawn
// In OnPluginStart()
RegConsoleCmd("sm_newcommand", Command_NewCommand, "Description");

// Command handler
public Action Command_NewCommand(int client, int args) {
    if (!g_bConfigLoaded) {
        CPrintToChat(client, "%t %t", "Chat Prefix", "No Config");
        return Plugin_Handled;
    }
    
    // Command logic here
    return Plugin_Handled;
}
```

#### Safe StringMap Operations
```sourcepawn
// Getting values with fallback
char buffer[256];
if (!g_songNames.GetString(key, buffer, sizeof(buffer))) {
    // Handle missing key
    return;
}

// Setting values
g_songNames.SetString(key, value);

// Iterating through StringMap
StringMapSnapshot snap = g_songNames.Snapshot();
int len = snap.Length;
for (int i = 0; i < len; i++) {
    snap.GetKey(i, key, sizeof(key));
    g_songNames.GetString(key, value, sizeof(value));
    // Process key/value pair
}
delete snap; // Don't forget to delete the snapshot
```

#### Translation Usage
```sourcepawn
// Simple message
CPrintToChat(client, "%t %t", "Chat Prefix", "Message Key");

// Message with formatting
CPrintToChat(client, "%t %t", "Chat Prefix", "Now Playing", songName);

// For new translations, add to MusicName.phrases.txt:
"New Message Key"
{
    "#format"   "{1:s}"  // If using parameters
    
    "en"        "English text here {green}{1}"
    "fr"        "French text here {green}{1}"
    "zho"       "Traditional Chinese text here {green}{1}"
    "chi"       "Simplified Chinese text here {green}{1}"
}
```

## Performance Considerations

### Critical Performance Rules
- **Ambient Sound Hook**: This runs on EVERY ambient sound in the game - optimize heavily
- **Cooldown System**: Prevent spam by checking timestamps before announcements
- **String Operations**: Minimize string operations in frequently called functions
- **Map Changes**: Clean up StringMaps properly to prevent memory leaks

### Optimization Examples from Codebase
```sourcepawn
// Check cooldown before expensive operations
if (g_fLastPlayedTime.GetValue(sFileName, lastPlayed) && 
    (currentTime - lastPlayed) < g_fCooldownTime) {
    return Plugin_Continue;
}

// Cache file name conversion
char sFileName[PLATFORM_MAX_PATH];
GetFileFromPath(sample, sFileName, sizeof(sFileName));
StringToLowerCase(sFileName); // Only convert once
```

## Common Issues & Troubleshooting

### Build Issues
- **Missing dependencies**: Run `sourceknight install` first
- **Compilation errors**: Check for missing includes or syntax errors
- **Version conflicts**: Ensure SourceMod version matches sourceknight.yaml

### Runtime Issues
- **Config not loading**: Check file path `/sourcemod/configs/musicname/<mapname>.cfg`
- **Songs not detected**: Ensure filenames are lowercase and include extensions
- **Translation missing**: Verify `LoadTranslations("MusicName.phrases");` is called

### Memory Leaks
- **StringMap persistence**: Use delete/recreate pattern, never `.Clear()`
- **Snapshots**: Always delete StringMapSnapshot objects after use
- **Map changes**: Clean up in OnMapEnd() event

## Contributing Guidelines

### Before Making Changes
1. Understand the ambient sound hook system - it's performance-critical
2. Test with actual Source engine games, not just compilation
3. Ensure changes work across different maps and game modes
4. Consider impact on server performance (this runs frequently)

### Pull Request Checklist
- [ ] Code follows SourcePawn style guidelines
- [ ] No memory leaks (proper delete usage)
- [ ] Translation support maintained
- [ ] Performance impact considered
- [ ] Tested on actual game server
- [ ] Build passes CI/CD pipeline

### Semantic Versioning
- **MAJOR**: Breaking changes to plugin API or config format
- **MINOR**: New features, new translations, new commands
- **PATCH**: Bug fixes, performance improvements, minor tweaks

## Advanced Development Topics

### Extending Language Support
1. Add new language codes to each phrase in `MusicName.phrases.txt`
2. Follow existing format and color coding patterns
3. Test with game clients set to that language

### Custom Sound Detection
The ambient sound hook can be extended for other sound types:
```sourcepawn
public Action Hook_AmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, 
    float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay) {
    // Check volume (mappers use volume 0 to stop music)
    if (volume == 0.0) return Plugin_Continue;
    
    // Extract filename and normalize
    char sFileName[PLATFORM_MAX_PATH];
    GetFileFromPath(sample, sFileName, sizeof(sFileName));
    StringToLowerCase(sFileName);
    
    // Your custom detection logic here
    
    return Plugin_Continue;
}
```

### Configuration System Extension
To support additional config formats or features:
1. Modify `LoadConfig()` function
2. Update config documentation in README.md
3. Maintain backward compatibility with existing configs
4. Add validation for new config parameters

This repository represents a well-structured, production-ready SourceMod plugin with proper build automation, internationalization, and performance optimization. When making changes, prioritize code clarity, performance, and maintainability.