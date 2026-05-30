# garmin-tfl

A Garmin watch App with TfL integration that displays the next bus times at stops within a 100m of where you are.

# Side Loading

Whilst this app is in development and not available on the Garmin Store, it is only possible to Side Load it, to do this you'll need to:

1. Register for a TfL API Account - https://api-portal.tfl.gov.uk/signup
2. Create TfL API Keys
3. Download and Install VS Code - https://code.visualstudio.com/
4. Add the Monkey C extension for VS Code - https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c
5. Follow these instructions taken from: https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/

The Monkey C extension provides a wizard to help developers side load an application. The wizard will create an executable (PRG) of the selected project. Here's how to use it:

    Plug your device into your computer

    Use Ctrl + Shift + P (Command + Shift + P on the Mac) to summon the command palette

    In the command palette type "Build for Device" and select Monkey C: Build for Device

    Select the product you wish to build for. If you are unable to choose a device for which to build (the menu appears empty), it means that there are no valid devices configured for your project. See Editing the Supported Products for instructions.

    Choose a directory for the output and click Select Folder

    In your file manager, go to the directory selected in step 4

    Copy the generated PRG files to your device's GARMIN/APPS directory

<a target="_blank" href="https://icons8.com/icon/4ot4n9HeBZOA/double-decker-bus">Double Decker Bus</a> icon by <a target="_blank" href="https://icons8.com">Icons8</a>
