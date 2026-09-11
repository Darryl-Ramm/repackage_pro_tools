# repackage_pro_tools for macOS
[![Latest Release](https://img.shields.io/github/v/release/Darryl-Ramm/repackage_pro_tools?include_prereleases&sort=semver)](https://github.com/Darryl-Ramm/repacakge_pro_tools/releases/latest)

A shell script that repackages a stripped down Avid Pro Tools .pkg installer. The script allows the user to select what components to remove, starting from the Pro Tools installer that Avid distribute in .dmg disk images. Users can package their own reduced feature installers and avoid problems or just wasted effort manually uninstalling the bundled bloatware, especially Avid Link. The intention is to show this is possible, and allow uses to use these modified installers on their own or their organization's Mac computers to help solve problems and make use of Pro Tools easier. Nobody should redistribute modified packages outside of that. 

`repackage_pro_tools.sh` currently allows the user to choose to remove any of the following items

* Avid Link [~129MB]
* SoundFlow [~361MB]
* Splice [~22MB]
* Melodyne [~96MB]
* Sketch [~1.1GB]
* Avid Video Engine [~2.8GB]
* Pro Tools Demo Sessions [~455MB]
* PACE/iLok License Manager [~115M]
* Video Test Patterns? [~95MB]
* Tutorial Sessions? [~75MB]
* HTML Help? [~267MB]
* PDF Manuals? [~165MB]

The sizes here are the size of the items removed from the installer .pkg, these components will often consume more space when actually installed. Some of these take around double the space on disk. For example the PDF manuals and Video Test patterns are stored inside the Pro Tools.app package and  copied from there to /Users/Shared when Pro Tools starts, it's unnecessary overhead adding to startup time but also doubles the space required on disk. Here we just remove those items from within the Pro Tools.app bundle within the installer .pkg so the files just don't exist there, and are never copied to /User/Shared

`repackage_pro_tools.sh` can be run on an Intel based Mac or an Apple Silicon based Mac and the resulting .pkg file can be run on both Intel and Apple Silicon based Macs.

Avid distribute Pro Tools macOS installers as disk .dmg image containing multiple .pkg package images. Besides the Pro Tools .pkg installer there are additional .pkg installers in the .dmg image, such as the Avid HD Driver and Pro Tools Audio Bridge. And of these additional .pkg installers found in the .dmg file are copied to the output directory (default is the same directory the .dmg) alongside the new reduced Pro Tools .pkg file. 

Other items in the installer .pkg like the Avid Link (including vestiges of App Manager) and PACE/iLok License manager are shipped as .pkg installers within the main Pro Tools .pkg installer. By removing those sub-packages they no longer run during a Pro Tools install.

A big win here for many users will be just removing Avid Link. Many users don't want that installed and it reinstalling itself every time Pro Tools is installed is a pain. We simply remove the Avid Link .pkg inside the Pro Tools installer .pkg so it never runs.

Here removing the PACE/iLok license manger means you need to have that installed separately, and most Pro Tools users likely already have that installed and often have a later version that the version included inside any Pro Tools installer they are going to run.  Nothing here reduces the requirements to have, or tries to technically bypass in any way the Pro Tools and any third party license authorizations, it's just reducing what is in an installer package. 
    
This was developed and primarily tested against the Pro_Tools_2026.4.1_Mac.dmg

## Unsigned Package

`repackage_pro_tools.sh` is intended for personal use and internal sharing within a user's organization, not public redistribution.

This tool produces an unsigned .pkg by expanding the package content, deleting components and re-flattening the package, this discards the cryptographic .pkg signing. The new .pkg will no longer be signed by Avid, however a user can still run that unsigned package.  macOS requires admin credentials to install any .pkg regardless of signing, that remains unchanged. 

The repackaged .pkg on the machine it was created on does not have any quarantine restrictions applied like it would be if that same unsigned packaged had been downloaded say with a Web browser. That download would normally apply a quarantine to the file and when the unsigned .pkg is run Gatekeeper would issue a warning that Apple cannot check for malicious software (because it's not signed).

If a repackaged .pkg is moved to a different computer within an organization via Web browser downloads, email attachments, or AirDrop macOS the file will be quarantined and Gatekeeper invoked when it's run so the user will see an "Apple cannot check for malicious content" warning. If you see that you can still run the .pkg from the command line in Terminal.app using the macOS installer command.
e.g. 
```
sudo installer -pkg Pro_Tools_Install_26.4.1_Clean.pkg -target /
```

When copying modified .pkg files within your organization you can avoid the gatekeeper warning by moving files on removable media like a USB thumb drive, copying files off a file server, or using the wget command line utility to download from a intranet web server. 

## Download and Installation
Download the latest release script and make it executable:

```
curl -sL -O https://github.com/Darryl-Ramm/repackage_pro_tools/releases/latest/download/repackage_pro_tools.sh
```
```
chmod +x repackage_pro_tools.sh
```
## Usage
Run the script against a Pro Tools installer .dmg. For example: 

```
./repackage_pro_tools.sh Pro_Tools_26.4.1_Mac.dmg
```
Follow the prompts and answer the y/n questions about what packages should be removed from the installer .pkg the script will build.

By degault the script will leave a new .pkg installer, in this example named Pro_Tools_Install_26.4.1_Clean.pkg. 

For more usage information and command line options use `repackage_pro_tools.sh -h`

## Issues

* Using a modified Pro Tools installer may break software or cause compatibility problems, including problems that may not be immediately obvious.
    * If that is suspected you can do a full install of Pro Tools using the unmodified .dmg made over the current Pro Tools install.
* Removing components may not remove all mention of or appearance of that component within Pro Tools.
    * For example removing SoundFlow or Splice will still leave their corresponding panels in the Clip Area of the Pro Tools Edit Window. But those can be hidden in the UI.
* This is certainly not endorsed by Avid.
* Avid Support might refuse to provide support if a modified installer is used. So maybe don't mention that :-) and just test by doing an install from a full installer .dmg. 
* The installer script that runs on a modified installer .pkg package does not know that items have been removed from the pacakge and will state the original size required to do the full install.
* This was developed and primarily tested against the Pro_Tools_2026.4.1_Mac.dmg. It may not work as reliably with past or future versions.
* `repackage_pro_tools.sh` does not replace the modified Pro Tools .pkg file back into a .dmg disk image. Again the intent is not for users to redistribute anything.
* Using this may cause problems, may not install things properly that Pro Tools relies on in ways not expected, 

----

Avid and Pro Tools are trademarks or registered trademarks of Avid Technology, Inc. or its subsidiaries in the United States and/or other countries. Avid and Pro Tools are used here only to clearly identify the product.
