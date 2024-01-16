# Scripting in Deadrop Creative Mode
-----
## Initial Setup

To get started with DEADROP's DCM Scripting, ensure you have the following requirements set up on your system:

1. **Visual Studio Code**: This is the primary and recommended IDE used for development. Download and install it from [here](https://code.visualstudio.com/).

2. **Enable 'Allow Breakpoints Everywhere'**: 
    - Open Visual Studio Code.
    - Go to `Settings`.
    - Search for `Debug: Allow Breakpoints Everywhere` and enable this setting.

3. **LUAU Language Server Extension**: 
    - This extension provides enhanced language support for Luau.
    - Install it from the Visual Studio Marketplace: [Luau Language Server](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp).

4. **Midnight Luau Debugger Extension**: 
    - Required for debugging DCM Luau scripts in Visual Studio Code.
    - Install it from the Visual Studio Marketplace: [Midnight Luau Debugger](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp).
-----
## Creating Your First Project

Follow these steps to set up your first project with DEADROP's DCM Scripting:

1. **Create an Empty Folder**: 
    - Choose a location on your computer for your project.

2. **Create Required Folders**: 
    - Open the newly created folder.
    - Inside, create a folder named `.vscode`.
    - Also, create folders named `UserModes` and `UserModules`.

3. **Set Up launch.json File**: 
    - In the `.vscode` folder, create a new file named `launch.json`.
    - Leave this file empty for now. 
    
    
   <sub> **Note**: If you are unable to change the file extension, you may need to adjust your system settings to show file extensions.</sub>

4. **Open the Project in Visual Studio Code**: 
    - Open Visual Studio Code.
    - Navigate to `File > Open Folder` and select your project folder.

5. **Configure launch.json for Debugging**: 
    - With your project open in Visual Studio Code, navigate to the `launch.json` file.
    - Add the following Midnight Luau Debugger default configuration:

    ```json
    {
        "configurations": [
            {
                "type": "msld",
                "request": "attach",
                "name": "Midnight Debug",
                "host": "127.0.0.1",
                "port": 21110,
                "sourceRoot": "${workspaceFolder}",
                "map": "Canyon"
            }
        ]
    }
    ```

    - Change the `map` value to `"Canyon"` as required for your setup.


-----
## Making your Mode

Creating a basic game mode in DEADROP's DCM Scripting involves a few simple steps:

1. **Prepare the UserModes Folder**:
    - Ensure you have previously created a `UserModes` folder as instructed in the [Creating Your First Project](##creating-your-first-project) section.

2. **Create the MyUserMode.luau File**:
    - Inside the `UserModes` folder, create a new file named `MyUserMode.luau`.

3. **Add the Simple Mode Script**:
    - Open the `MyUserMode.luau` file in Visual Studio Code.
    - Copy and paste the following Lua script as an example of a simple game mode:

    ```lua
    local GameMode = Moon.GameMode.First()
    GameMode.AutomaticRespawn = true

    local Players = {}

    GameMode.OnLogin:Connect(function(Player)
        print("Someone joined!")
        table.insert(Players, Player)
    end)

    MS.Utility.SetTimer(function()
        print("Ending the match after 20 seconds, everyone's a winner!")
        GameMode:EndMatch(Players)
    end, 20)

    print("Our mode ran!")
    ```

    - This script sets up a basic game mode where all players are winners after 20 seconds.

4. **Explore More Examples**:
    - For more advanced examples, visit the [DCM Scripting Code Snippets](https://github.com/MidnightProtocol/DCM-Scripting/tree/main/Code-Snippets) on GitHub.

-----


## Testing your Mode

### Single Player Testing
(See also: [Multiplayer Testing](#multiplayer-testing))

Follow these steps to test your script in a single-player environment:

1. **Open Client and Choose a Test Map**:
    - Launch the client and select a test map of your choice.

2. **Connect the Debugger**:
    - Ensure the debugger is set up and connected as per the earlier setup instructions.

3. **Select the Script for Restart**:
    - In Visual Studio Code, choose the script you want to test.

4. **Identify and Fix Issues**:
    - If you encounter any issues, refer to the [Debugging In-Depth](#debugging-in-depth) section for guidance.

5. **Edit and Restart the Script**:
    - Make necessary changes to your script.
    - Restart the script to apply your changes.

6. **Verify the Script Functionality**:
    - Observe the script in action and ensure it's working as expected.

For a visual walkthrough of these steps, watch our [YouTube Tutorial](https://www.youtube.com/watch?v=6l9bt5KYEhw).

### Multiplayer Testing
Details for multiplayer testing will be provided in future guides.

### Additional Resources
- [Debugging In-Depth](#debugging-in-depth): A comprehensive guide to debugging your scripts.

-----

## Publishing Your Mode

Once you've tested and finalized your game mode, you can publish it for others to use. Follow these steps:

1. **Publish the Script**:
    - Ensure your script is complete and functioning as intended.
    - Publish your script following the standard procedure in your development environment.

2. **Share the Refiner Code**:
    - Upon publishing, you will receive a Refiner Code associated with your script.
    - This code is a unique 9-digit identifier, formatted with dashes after every 3 numbers (e.g., `123-456-789`).
    - Share this code with others so they can easily access your game mode.

For a visual guide on how to publish and share your game mode, watch our [YouTube Tutorial](https://www.youtube.com/watch?v=EGW4c8_Q9gQ).

-----
## Some Extra Detail on Selected Topics

### Example Modes and Modules
- **Debugger Attachment**: When you attach your debugger to the Deadrop client, `ExampleModes` and `Modules` folders are automatically populated or refreshed.
- **Reference and Usage**: The contents of these folders are for reference and use. Modes and modules provided may range from fully functional to works in progress.
- **Modification Note**: Any changes made to these modes and modules will be ignored as they are part of the provided environment.

### Port Forwarding & Local Multiplayer Testing
- To test your modes locally with multiple players, refer to our [Advanced Topic Guide](#).

### Matchmaking with a Refiner Code
- **Publishing Modes**: Upon publishing a mode, a refiner key is generated.
- **Player Requirements**: Published modes require a minimum player count (currently 4) to start. All players must be matched into the same refiner key.

### MSLD Features
- For a comprehensive understanding of the MSLD debugger, check out the [In-Depth MSLD Debugger Guide](#).

### Map Names In The Launch.json
- **Map Selection**: The map name in `launch.json` determines the map that loads when you restart or select a new script.
- **Changing Maps**: To change the map, you must disconnect and reconnect your debugger.
- **Valid Map Names** (as of version 7.5):
    - `Canyon`
    - `Proving Ground 2`
    - `Proving Ground 3`
