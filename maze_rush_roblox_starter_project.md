# 🎮 Maze Rush – Game Design Document (Markdown)

## 1. Overzicht
- **Titel:** Maze Rush  
- **Genre:** Multiplayer Survival / Escape  
- **Platform:** Roblox (PC, Mobile, Console)  
- **USP:** Iedere ronde een uniek doolhof, gegenereerd met een algoritme.  
- **Spelers:** 6–12 per ronde  

---

## 2. Kernloop
1. **Lobbyfase:** spelers wachten en stemmen op het doolhoofthema.  
2. **Maze Generation:** een nieuw doolhof verschijnt live met willekeurige thema’s.  
3. **Gameplayfase:** spelers zoeken sleutels, ontwijken monsters, overwinnen obstakels en proberen de uitgang te bereiken.  
4. **Einde:** winnaars krijgen XP, coins en cosmetische beloningen.  
5. **Herhaling:** progressie gebruiken om nieuwe skins, pets en perks te ontgrendelen.  

---

## 3. Gameplay Mechanics
### Maze Generation
- **Algoritme:** Randomized Prim’s of Kruskal’s algoritme.  
- **Thema’s:** Lava Maze, Candy Maze, Spooky Maze, Cyber Maze.  
- **Variatie:** complexiteit stijgt met spelersaantal en level.  

### Obstakels
- **Parkour Rooms** – *Tower of Hell*-stijl uitdagingen.  
- **Trap Floors** – vallen open bij verkeerd moment.  
- **Moving Blocks** – vereisen timing.  

### Keys & Doors
- Sleutels openen toegang tot nieuwe zones of de hoofduitgang.  
- Soms moeten meerdere sleutels gecombineerd worden.  

### Enemies (AI)
- **Patrol Monster:** volgt vaste routes.  
- **Hunter Monster:** jaagt actief (zoals Piggy).  
- **Event Monster:** verschijnt willekeurig met effecten (*Doors*-stijl).  

### Power-ups
- **Turbo Boots** – verhoogt de loopsnelheid 5 seconden lang met 50%, geeft lichte motion blur en een vurige trail voor een spectaculair gevoel van snelheid.
- **Ghost Mode** – speler kan drie seconden door muren lopen; om balans te houden geldt een cooldown van twintig seconden.
- **Magnet Power** – trekt automatisch coins, punten en power-ups binnen een straal van tien studs naar de speler toe.
- **Time Freeze** – bevriest alle bewegende muren, traps, monsters en andere spelers voor vijf seconden, terwijl alleen de gebruiker kan bewegen.
- **Shadow Clone** – spawnt een AI-kloon die vijanden en vallen afleidt zodat de speler kan ontsnappen of herpositioneren.
- **No Wall** – verlaagt tijdelijk (drie seconden) alle binnenmuren tot twintig procent van hun hoogte, waardoor nieuwe zichtlijnen ontstaan.
- **Slow Down** – verlaagt de maximumsnelheid van alle andere spelers naar dertig procent voor een korte periode.
- **Extra Life** – geeft één extra kans; na activatie overleeft de speler een dodelijke situatie en blijft daarna twee seconden onaantastbaar.

---

## 4. Spelersrollen
- **Survivor:** probeert te ontsnappen.  
- **Monster:** jaagt op survivors (AI of speler).  

---

## 5. Progressie & Beloningen
- **Coins & XP:** verdiend per ronde.  
- **Pets:** cosmetische helpers met mini-voordelen.  
- **Cosmetics:** skins, muur-themes, trails.  
- **Titles/Badges:** prestaties (“Maze Master”, “No Damage Escape”).  
- **Daily Quests:** 3 challenges per dag.  

---

## 6. Monetization (Robux)
- VIP Pass (dubbele XP, speciale thema’s).  
- Exclusive Pets (limited edition).  
- Revive System (zoals *Doors*).  
- Cosmetics Shop (outfits, trails, skins).  

---

## 7. UI/UX Ontwerp
- **Lobby:** stemmen, shop, leaderboard.  
- **In-game:** timer, minimap, inventory, pet-UI.  

---

## 8. Technische Architectuur (Roblox Studio – Lua)
### Module-overzicht
- `RoundConfig` – instellingen voor grid, tijd, thema’s.  
- `Utils` – hulpfuncties (shuffle, opposites, neighbors).  
- `MazeGenerator` – DFS of Prim’s algoritme.  
- `MazeBuilder` – maakt fysieke muren en vloer.  

### ServerScripts
- `GameManager` – beheert rondes, events en timers.  
- `EnemySpawner` – spawnt AI-monsters.  
- `KeyDoorService` – sleutels en deuren.  

### ClientScripts
- `ClientUI` – toont status, timer, inventory.  
- `Compass` – richtingwijzer naar uitgang.  

---

## 9. Inspiratie van Populaire Roblox Games
- **Piggy** – jager-mechaniek.  
- **Doors** – spanning en willekeurige events.  
- **Tower of Hell** – parkour uitdagingen.  
- **Adopt Me!** – pets en verzamelbare cosmetica.  

---

## 10. Roadmap
**Fase 1:** Maze generator + basislobby.  
**Fase 2:** Monsters en sleutelsysteem.  
**Fase 3:** Obstakels + power-ups.  
**Fase 4:** Cosmetics en progressie.  
**Fase 5:** Monetization en nieuwe thema’s.  

---

## 11. Toekomstige uitbreidingen
- **Minimap:** top-down weergave als perk.  
- **Co-op events:** spelers openen gezamenlijk speciale deuren.  
- **Pet evolution:** combineer pets voor unieke boosts.  
- **Custom maps:** communitygemaakte layouts.  

---

## 12. Samenvatting
> Maze Rush combineert procedural generation met spanning, strategie en sociale interactie.  
> Iedere ronde is uniek, elke ontsnapping voelt verdiend — perfect voor Roblox-spelers die uitdaging en herspeelbaarheid zoeken.

