# repackage_pro_tools
[![Latest Release](https://img.shields.io/github/v/release/Darryl-Ramm/repackage_pro_tools?include_prereleases&sort=semver)](https://github.com/Darryl-Ramm/repacakge_pro_tools/releases/latest)
Repackage your own Avid Pro Tools isntallers to avoid installing all the bloatware/crapware

Add -w wait option to susepct repacakgin until ready or a ... -p pack option to repack an modified tree???

This is not encouraged by or endorsed by Avid.

The installer script that runs on a modified installer .pkg package does not know it was modified and will state the original size required to do the install.

The Pro Tools macOS installer is distributed as a disk .dmg image containing multiple .pkg package images. The .dmg contains three actual installers.

Install .pkg - The actual Pro Tools software. This alsi includwes mutluple .pkg sub-pacakges
HD Driver.pkg - The installer for the .kext drivers for Avid Pro Tools HD Native and HDX hardware interfaces. You only need to install these if you have a HD Natice or HDX Inerface and are usign that with Pro Tools Ultimate or with a different DAW via CoreAudio.

Install .pkg includes mutluple .pkg sub-pacakges within it. It's relatively simpel to just remove those sub0packages so they can't ever run.

The /Applications/Pro Tools.app application bundle in the .pkg installer is a large pece of software and includes components that are easilly rmovable.

Pro Tools.app/Contents/Plugins/Core Plugins

These are the core Pro tools AAX plugins distributed with Pro Tools, all other plugins require using separate installers. When Pro Tools starts up it checks in these core plugins are installed in /Library/Application Support/Avid/Audio/Plug-Ins and if not Pro Tools copies these embedded plugins in its app bundle to that plugin directory. Thats a handy way of resetting the core plugins at any times, you just delete them from the plugin folder and restart Pro Tools. Although generally stable there very occasionally can be a problem where one of eh core plugins cause a problem and you need to remove it fromt eh plguign folder, but then every time you restart Pro Tools it gets put back. The solution there has been for a long time to jsut delete the pluging bundle from Pro Tools.app/Contents/Plugins/Core Plugins. Expanding that back to the .pkg installer we could simply remove any core .aaxplugin fromt he app package in the isntaller and Pro Tools will work fine, it just won't have accve to that plugin. 

Plugin isntallers typically do more than just place a .aaxplugin file in the plugin folder, they may place prefereces/settings, say in the users Documents folder or elsewhre, keep state in ~/Library etc. That is tyupically small, and ther eare no sample based virtual isntuamt libraryes diestibved int eh Pro tools installer, so no large sample based libraies anywhere that we need to uninstall. Well except for Pro Tools .... which we will discuss below.


Somebody wanting to distribiete differet plugin exeecutables pacaktged within a Pro Tools installer

Pro Tools.app/Contents/Plugins/SystemPlugins

The script

This does not reinstall the Install Pro Tools*.pkg file back into a .dmg disk image. The .dmg are handy for file downloading or distribution but nobody should be redistributing these modified installers.

Using this may cause problems, may not install thigns properly that Pro Tools relies on in ways not expected, 

however if three are problems running the a full Avid installer

Avid and Pro Tools are trademarks or registered trademarks of Avid Technology, Inc. or its subsidiaries in the United States and/or other countries.
