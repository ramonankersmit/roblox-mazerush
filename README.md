# Maze Rush (DFS/Prim Toggle)

## Wat is nieuw
- **Server-authoritatieve toggle** tussen `DFS` en `PRIM` via `ReplicatedStorage/State/MazeAlgorithm`.
- **Lobby UI** met knoppen (DFS/PRIM). Client vraagt wissel aan; server valideert en zet de StringValue.
- **MazeGenerator** leest runtime-waarde; valt terug op `RoundConfig.MazeAlgorithm` bij ontbreken.

## Snel starten
1. `rojo serve` of `rojo build --output MazeRush.rbxlx`
2. Start Studio en verbind met Rojo of open de build.
3. Druk **Play**. Tijdens PREP of in de lobby kun je rechtsboven **DFS/PRIM** kiezen.

## Bestanden
- `src/ReplicatedStorage/Modules/MazeGenerator.lua` – bevat DFS én Prim en leest `State.MazeAlgorithm`.
- `src/ServerScriptService/AlgorithmService.server.lua` – valideert client-verzoeken en zet server-state.
- `src/StarterPlayer/StarterPlayerScripts/ClientUI.client.lua` – UI voor toggle en basis HUD.

> Tip: Je kunt ook server-only wisselen door `State.MazeAlgorithm.Value = "PRIM"` in de command bar te zetten.
