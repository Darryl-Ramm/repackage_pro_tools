# Paths
### Items to offer to remove, and their paths in the unpacked installer.

This document was built by inspecting the unpacked installer and
Pro Tools.app bundle on installed systyems, and was an input to
Claude to build the script, and Claude helped update it.

1. **Avid Link / Application Manager**
* `${EXPAND_DIR}/Pro Tools Application.pkg/Scripts/AvidLink_Installer.pkg`
* `${EXPAND_DIR}/Pro Tools AppMan.pkg`

2. **Pro Tools Sketch**
* `${PAYLOAD_EXTRACT_DIR}/Applications/Pro Tools.app/Contents/PlugIns/System Plug-Ins/Pro Tools Sketch.aaxplugin`
* *(Plus clearing the staging artifacts like `/tmp/Go_Sketch/`)*

3. **SoundFlow Integration**
* `${EXPAND_DIR}/Pro Tools Application.pkg/Scripts/SoundFlowProTools.pkg`

4. **Splice Integration**
* `${EXPAND_DIR}/Pro Tools Application.pkg/Scripts/SpliceProTools.pkg`

5. **Melodyne / Celemony**
* `${EXPAND_DIR}/Pro Tools Application.pkg/Scripts/Melodyne.pkg`

6. **Pro Tools Demo Sessions**
* `/tmp/Demo_Session` (packaged temp asset)

7. **Avid Video Engine**
* `${PAYLOAD_EXTRACT_DIR}/Applications/Pro Tools.app/Contents/Frameworks/Video Engine/`
* *(Leaving `/Users/Shared/AvidVideoEngine` alone per instruction)*

### New items to add:

1. **PACE/iLok License Manager Installer**
* `/tmp/PACE/LicenseSupport.pkg`
* *(remove the PACE directory and everything in it)*

1. **Video Test Patterns**
* `/Applications/Pro Tools.app/Contents/SharedSupport/Factory Content/Video Test Patterns/`

1. **Tutorial Sessions**
* `/Applications/Pro Tools.app/Contents/SharedSupport/Factory Content/Tutorials/`

1. **HTML Help**
* `/Applications/Pro Tools.app/Contents/PTHelp/`

1. **PDF Manuals**
* `/Applications/Pro Tools.app/Contents/SharedSupport/Documentation/`
* *(Removing these prevents Pro Tools every recopying them to /Users/Shared on each startup)*

## Things that would be implemented easily but don't make a lot of sense, and we won't do for now

1. **Core Plugins**
* `/Applications/Pro Tools.app/Contents/Plugins/Core Plug-Ins/`
* *(Would step thought each .aaxplugin file there)*

1 **Systems Plugins**
* `/Applications/Pro Tools.app/Contents/Plugins/System Plug-Ins/`
* *(Would step thought each .aaxplugin file there)*
