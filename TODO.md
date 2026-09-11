# Repackage Pro Tools ToDo
1. The whole Xcode/Xcode Command Line Tools checking in the script is due to a Claude hallucination, I'm pretty sure mkbom is fully built into base macOS, need to check and fix. -- DONE
2. The Script currently assumes that it is working with a recent installer .dmg and offers to remove components that may not be in older installers. It will largely list those components but show them as 0 size. The script will not fail if the component is not there and the user still says to remove it, which is good behavior for later using a list of things to automatically remove, but the UI needs to make clear the component is really not there to remove in any specific .dmg.
3. Need to think about handle older installers that were Pre Avid Link or maybe put a limit on the oldest versions supported.
4. Needs testing with more older .dmg.
5. Save the user's choices to the remove item questions to a text (or JSON?) file and put along side the output .pkg file.
6. Allow the script to take that file as input and either drive the whole script or change the defaults of the options shown to the user--that needs some thought. 
7. Lots could be done to clean up the script/make it prettier/more modular but let see if it's of any use first.
8. Make a script that cleans up current Pro Tools installs, offering to remove the same things as here, but stuff that has already been installed on the Mac.

