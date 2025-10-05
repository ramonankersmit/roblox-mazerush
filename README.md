# Maze Rush (DFS/Prim Toggle)

## Wat is nieuw
- **Server-authoritatieve toggle** tussen `DFS` en `PRIM` via `ReplicatedStorage/State/MazeAlgorithm`.
- **LoopChance**: stel in welk percentage muren na generatie verwijderd wordt (maakt lussen, standaard 5%).
- **Lobby UI** met knoppen (DFS/PRIM + loop-kans). Client vraagt wissels aan; server valideert en zet de waardes.
- **MazeGenerator** leest runtime-waardes; valt terug op `RoundConfig` bij ontbreken.

## Snel starten
1. `rojo serve` of `rojo build --output MazeRush.rbxlx`
2. Start Studio en verbind met Rojo of open de build.
3. Druk **Play**. Tijdens PREP of in de lobby kun je rechtsboven **DFS/PRIM** kiezen.

## Bestanden
- `src/ReplicatedStorage/Modules/MazeGenerator.lua` – bevat DFS/Prim en verwerkt `State.MazeAlgorithm` en `LoopChance`.
- `src/ServerScriptService/AlgorithmService.server.lua` – valideert client-verzoeken en zet server-state.
- `src/StarterPlayer/StarterPlayerScripts/ClientUI.client.lua` – UI voor toggles, loop-kans en basis HUD.

> Tip: Je kunt ook server-only wisselen door `State.MazeAlgorithm.Value = "PRIM"` in de command bar te zetten.

## Inventory en Roblox-backpack
Maze Rush houdt de inventaris server-side bij in `InventoryService` en deelt die service via `_G.Inventory` zodat bijvoorbeeld `KeyDoorService` kan valideren of iemand een sleutel bezit. Vanaf nu spiegelt de service ook automatisch het sleutel-aantal naar de standaard Roblox-backpack: voor elke sleutel verschijnt er een `Maze Key`-tool (zonder handle) in de backpack van de speler.

De custom HUD in `ClientUI.client.lua` blijft nuttig voor bediening van Maze Rush-specifieke toggles, maar spelers kunnen nu hun sleutels beheren zoals elke andere Roblox-tool – inclusief ondersteuning voor controller/mobile dankzij de standaard backpack UI. Wanneer een sleutel wordt gebruikt of gereset, verwijdert `InventoryService` het overeenkomstige tool-item zodat de backpack altijd de serverstatus volgt.
