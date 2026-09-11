# repackage_pro_tools for macOS
[![Latest Release](https://img.shields.io/github/v/release/Darryl-Ramm/repackage_pro_tools?include_prereleases&sort=semver)](https://github.com/Darryl-Ramm/repacakge_pro_tools/releases/latest)

Repackage your own stripped down Avid Pro Tools .pkg installer by selecting what bloatware to remove from the official Pro Tools installer that Avid distribute as .dmg images. The intent here is to allow users to package their own reduced feature installers and avoid problems with all the bundled bloatware, especially Avid Link. The intention is users use these modified installers on their own or their organization's Mac computers. Nobody should redistribute a modified packages outside of that. 

repackage_pro_tools currently allows the user to choose to remove any of the following items

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

The sizes here are the size of the items removed from the installer .pkg, these components will actually consume more space when actually installed. Some of these take around double the space on disk. For example the PDF manuals and Video Test patterns are stored inside the Pro Tools.app package and  copied from there to /Users/Shared when Pro Tools starts, it's unnecessary overhead adding to startup time but also doubles the space required on disk. Here we just remove those items from within the Pro Tools.app bundle within the installer .pkg so the files just don't exist there, and are never copied to /User/Shared

This tool can be run on an Intel based Mac or an Apple Silicon based Mac and the resulting .pkg file can be run on both Intel and Apple Silicon based Macs.

The Pro Tools macOS installer is distributed as a disk .dmg image containing multiple .pkg package images. Besides the Pro Tools .pkg installer thasre are addional .pkg files, such as the Avid HD Driver and Pro Tools Audio Bridge. And og these addional .pkg isntallers found int the .dmg file are copied to the output directory (default is the same directory the .dmg is in) aling side teh new reduced Pro Tools .pkg file. 

Other items in the installer .pkg like the Avid Link (including vestiges of App Manager) and PACE/iLok License manager are shipped as .pkg installers withing the main Pro Tools .pkg installer. By just removing those sub- pacakges they no longer get to run during a Pro Tools install.

A big win here for many users will be just removing Avid Link. Many users don't want that installed and it reinstalling itself every time a Pro Tools installer is run, becomes a pain in the ass. We simply remove the Avid Link .pkg inside the Pro Tools installer .pkg so it never runs.

Here removing the PACE/iLok license manger just means you need to have that installed separately, and most Pro Tools users likely already hae that isntalle and often have a later version that the version included inside any Pro Tools installer they are going to run. 

Nothing here reduces the requirements to have, or tries to technically bypass in any way the Pro Tools and any third party license authorizations, it's just reducing what is in an installer package. 
    
This was developed and primarily tested against the Pro_Tools_2026.4.1_Mac.dmg

## Unsigned Package

repackage_pro_tools.shis intended for personal, local use and internal sharing within your own organization, not public redistribution.

This tool produces an unsigned .pkg by expanding the package content, deleting components and re-flattening the package, this discards the cryptographic .pkg signing. The new .pkg will no longer be signed by Avid, however a user can still run that unsigned package.  macOS requires admin credentials to install any .pkg regardless of signing, that remains unchanged. 

The repackaged .pkg on the machine it was created on does not have any quarantine restrictions applied like it would be if that same unsigned packaged had been downloaded say with a Web browser. That download would normally apply a quarantine to the file and when the unsigned .pkg is run Gatekeeper would issue a warning that Apple cannot check for malicious software (because it's not signed).

If a repackaged .pkg is moved to a different computer within an organization via Web browser downloads, email attachments, or AirDrop macOS the file will be quarantiend and Gatekeeper invoked when it's run witht hat "Apple cannot check for malicios content" warning, if you see that, right-click the .pkg and choose Open rather than double-clicking; you will be prompted for admin credentials from there. Alternatively, sudo installer -pkg <path-to-pkg> -target / from Terminal installs without going through that dialog. 

When copying modified .pkg files within your organization you can avoid the gatekeeper warning by moving files on removable media like a USB thumb drive, copying files off a file server, or using the wget command line utility to download from a intranet web server. 

## Xcode/Xcode Command Line Utilities mkbom Dependency



repackage_pro_tools.sh removes  components in two possible  ways, it either removes entire pacakges in the Pro Tools main isntaller package, Like Avid Link or it removes sets of files or whole directories from within the installer. Fot the later we have to rebuild the .pkg BOM (Bill of Materials), before repacakign the isntaller. This requires the mkbom (/usr/bin/mkbom) 

If Xcode or the Xcode command line utilties is not installed on

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
Follow the prompts and answer the y/n questions about what [packages should be removed from the installer .pkg the script will build.

By degault the script will leave a new a, in this case named Pro_Tools_Install_26.4.1_Clean.pkg. It also copies the Avid HD Driver and

To see more usage information and command line options use `repackage_pro_tools.sh -h`

## Issues

* This was developed and primarily tested against the Pro_Tools_2026.4.1_Mac.dmg. It may now work as reliably with past of future.
* The installer script that runs on a modified installer .pkg package does not know the package had items removed  and will state the original size required to do the full install.
* Removing components here may not remove all mention of or appearahce of that component within Pro Tools. For example removing  SoundFlow or Splice will still leave their correstponging panels in the Clip Area fof the Pro Tools Edit Window. But those can be hidden in the UI. 

using these modfeid installers may break software or cause compatibity provlsems, including problems that may not be immedatly obvioys. If that is suspected you can test by doing a full install of Pro Tools using the unmodified .dmg made over your current Pro Tools install.

* This is certainly not endorsed by Avid. Avid Support might refuse to provide support if a modified installer is used. So maybe don't mention that :-) and just test by doing an install from a fill installer .dmg if there is a problem.
* This does not replace the modified Pro Tools*.pkg file back into a .dmg disk image. Again the intent for users  to redistribute anything.
* Using this may cause problems, may not install things properly that Pro Tools relies on in ways not expected, 

however if three are problems running the a full Avid installer

----

Avid and Pro Tools are trademarks or registered trademarks of Avid Technology, Inc. or its subsidiaries in the United States and/or other countries. Avid and Pro Tools are used here only to clearly identify the product.
