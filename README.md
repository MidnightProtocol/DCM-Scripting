# SCRIPTING IN CREATIVE MODE

Hello Creators, Ryan Petrie (aka bob42) here. I lead the core tech team here at Midnight Society, and our team has been developing the scripting system powering DEADROP Creator Modes in Snapshot VII. Today I want to introduce you to that scripting system and help you prepare to script your own game modes within DEADROP.

What you see in Snapshot VII may look like the custom game mode feature you’ve seen in other games, with menus to change game rules and parameters. But that’s just the tip of the iceberg. For each game mode, there is a backing script that controls the flow and logic of the game. And from the ground up, we’ve designed it to be used by you—the DEADROP community—to make whatever game mode you can imagine.

## Designed for Creators
When we were planning Snapshot VII, we picked several game modes that we should implement to prove out the scripting system and to drive its feature set. At no point were we focused on just delivering game modes; they were always a means to an end. What we’re really delivering is the capability built into DEADROP to make any game that can be dreamed up with DEADROP’s systems. When scripting, you’ll have access to the core systems that make up the Vertical Extraction Shooter: movement, weapons, damage, respawns, tuning, teams, and more. We’ve also implemented systems just for Creator Modes, like HUD control and messaging, scoreboards, and game rounds, with more features to come.

To illustrate the power that comes from this, look to the variety of game modes shipped in this snapshot. All the Creator Modes built into Snapshot VII are implemented entirely in script. There is no code in the DEADROP codebase that even mentions Capture the Flag or Team Deathmatch, for example. The scoring rules, loadouts on spawn, team assignment, detecting when a flag is captured, the HUD messages – all of that logic is written in script.

## Technical Details
We use Lua (specifically Luau, a hardened and battle-tested variant of Lua) as our scripting backend. Lua is a popular choice for scripting languages, and resources for learning Lua are readily available. Script code executes on the server, which authoritatively controls all game logic.

We’ve built an API (a set of objects, functions and data) on top of Lua to expose functionality to scripts, in two layers. The lower layer is the direct access to our C++ engine and game code, where function calls in the script directly execute native code. The higher layer is written in Lua and implements utilities or higher-level functionality, like health regeneration or outfit management.


Game scripts are authored locally on your computer. When they’re ready to be tested, they’re uploaded to our backend via the Upload Script button in the Creative tab of the lobby menu. From there, our game servers pull down the script when a game instance of that Refiner Code is created and matchmade into. Game scripts only run on the game servers, but we’re developing tools to make inspecting and debugging your script possible. We’ll have more information on that later.


The other half of the equation is the Tunable Configuration. You can set up custom tunables for your own script, just like the Snapshot VII DCMs have now. Parameters like health amount, number of rounds, game length, and scoring are all set up via a configurable JSON file that instructs the UI what to show. Whatever selections users make from those parameters are then passed on to the script. So each script can actually seed dozens of modes, all tuned with the parameters you define.

## An Example
The following is an excerpt from the Free For All mode in Snapshot VII. It sets up three loadouts, inserts them into a common table, and uses that table to grant each player one of the three loadouts on respawn, rotating through each in turn.

```-- Define the data for the three loadouts.
local Loadouts = {}

local LoadoutOne = {}
local LoadoutTwo = {}
local LoudoutThree = {}

table.insert(Loadouts, LoadoutOne)
table.insert(Loadouts, LoadoutTwo)
table.insert(Loadouts, LoudoutThree)

local Armor = { Helmet = "HeavyHelmet", Chest = "HeavyChestArmor"}
local Grenades = {"FragGrenade", "SmokeGrenade"}

local AssaultRifle = {Weapon = "AssaultRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "3xReflex-1"}}
local HeavyPistol = {Weapon = "HeavyPistol", Parts={"BarrelIV", "GripIV", "BlueLaser", "4xPTS-1"}}
local SMG = {Weapon = "SMG", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}
local DMR = {Weapon = "DMR", Parts={"BarrelIV", "GripIV", "StockIV", "4xPTS-1"}}
local Sniper = {Weapon = "SniperRifle", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser", "8xPTS-2"}}
local PumpShotgun = {Weapon = "PumpShotgun", Parts={"BarrelIV", "GripIV", "StockIV", "BlueLaser"}}

LoadoutOne.PrimaryWeapon = AssaultRifle
LoadoutOne.SecondaryWeapon = HeavyPistol
LoadoutOne.Grenades = Grenades
LoadoutOne.Armor = Armor

LoadoutTwo.PrimaryWeapon = SMG
LoadoutTwo.SecondaryWeapon = DMR
LoadoutTwo.Grenades = Grenades
LoadoutTwo.Armor = Armor

LoudoutThree.PrimaryWeapon = Sniper
LoudoutThree.SecondaryWeapon = PumpShotgun
LoudoutThree.Grenades = Grenades
LoudoutThree.Armor = Armor

-- Utility function to give the player a loadout.
function AwardNextLoadout(Player, Loadout)
	Player:GetEquipment():AddItem("LargeBackpack")
	
	Inventory.GrantWeapon(Player, Loadout.PrimaryWeapon, true, true)
	Inventory.GrantWeapon(Player, Loadout.SecondaryWeapon, true, false)
	
	Player:GetEquipment():AddItem(Loadout.Armor.Helmet)
	Player:GetEquipment():AddItem(Loadout.Armor.Chest)

	for i = 1, #Loadout.Grenades do
		Player:GetEquipment():AddItem(Loadout.Grenades[i])
	end
end

-- Set up the hook on respawn to fill the player’s inventory.
GameMode.OnRespawn:Connect(function(Player)
	Player:GetBackpack():ClearInventory()
	Player:GetEquipment():ClearInventory()

	local LoadoutIndex = LoadOutTracker[Player] % #Loadouts + 1
	AwardNextLoadout(Player, Loadouts[LoadoutIndex])
	LoadOutTracker[Player] = LoadOutTracker[Player] + 1
end)
```
All of the Lua scripts that run the DCMs in Snapshot VII are available to you to peruse.

## What Can I Do Now?
Get familiar with Lua. Look for online tutorials. There are even online IDEs and interpreters, so you can start learning and using the language in your browser.
Look over the DEADROP Creator Mode source code. It’s all there for you to see. As you examine the code, you’ll start understanding how game modes are made, what is possible in script, and how it’s done.
Plan your Creator Mode. Looking over the source code will get your creative juices flowing as you learn what tools are available to you. Write down your ideas, or if you’re ambitious, you can start to stitch together some Lua code.
Look out for more. We’re working hard to get the information and tools in your hands as soon as we can!
