# Overzicht Maze Rush

## Algemene spelbeschrijving
- Maze Rush speelt zich af in rondes met een PREP-fase (maze bouwen en aftellen), een OVERVIEW-fase, een ACTIVE-fase van standaard 240 seconden en een END-fase waarin beloningen worden uitgedeeld en alle spelers terug naar de sky-lobby gaan.

- Tijdens PREP wordt een volledig ommuurde grid gebouwd, muren worden geanimeerd weggehaald volgens het gekozen algoritme, de uitgang wordt klaargezet, obstakels worden geplaatst en vijanden verschijnen al voordat de actieve fase start.

- Rondegegevens zoals deelname, overlevingstijd, ontsnappingen, eliminaties en unieke bezochte cellen worden per speler bijgehouden en bepalen munten, XP en eventuele unlock-beloningen.

## Maze-algoritmes en configuratie
- Het doolhof gebruikt een 20×20 grid met cellen van 16 studs, muurhoogte 24 studs en kan dynamisch overschakelen tussen een DFS-backtracker en Prim’s algoritme; de server bewaakt de keuze via ReplicatedStorage-state en een optionele loopChance voor extra lussen.

- MazeBuilder bouwt eerst een volledige muurgrid met getagde onderdelen en verwijdert muren geanimeerd op basis van het uiteindelijke patroon, zodat andere systemen cellen en muursegmenten terug kunnen vinden.

- De game kan muurhoogte tijdelijk verlagen (bv. voor de No Wall-power-up of debug-knop M), waarbij bestaande prefabs en muren worden hergeschaald.

## Thema's en sfeer
- Beschikbare thema’s (Spooky, Jungle, Frost, Glaze, Realistic, Lava, Candy, Future) definiëren materialen en transparanties voor muren/vloeren, uitgangen, primaire kleuren, muziektracks en lobby-assets.

- LightingManager leest deze themaspecificaties en past verlichting en post-processing (ColorCorrection, Bloom, SunRays, Atmosphere, DepthOfField) dynamisch toe; standaardwaarden kunnen worden hersteld.

- AudioController speelt per thema achtergrondmuziek (preload inclusief fallback-lijst) en ondersteunt close-range heartbeat-audio voor Hunters en Sentry’s met afstandsafhankelijke volumes/snelheden.

## Lobby & voorbereiding
- De sky-lobby wordt boven het doolhof geplaatst met glazen wanden, een spawnplatform en een instelbaar informatiebord (hoogte/positie aanpasbaar via attributes).

- LobbyActivityService activeert themagekoppelde activiteitenzones (Parkour, Puzzle, Minigame) met eigen prompts, beloningen en cooldowns; de server houdt bij welke zone zichtbaar en interactief is.

- LobbyService beheert ready-states, hostfunctie, themavoorvertoning en stemrondes (inclusief willekeurige thema-optie en countdowns).

## Rondemechanica & progressie
- Exploratietracking registreert elke unieke tegel die levende spelers betreden en markeert volledige dekking; ontsnappingen en eliminaties worden gelogd en tonen zich in ronde-statistieken.

- Beloningen bestaan uit deelname, overlevingsduur (met limiet), ontsnappingsbonus, volledige mazeverkenning en eliminaties; ProgressionService verwerkt coins, XP en unlocks (Exit Finder, Hunter Finder, Key Finder) op basis van drempels.

- Leaderstats houden Coins, XP en Escapes bij; reset van inventaris en power-ups gebeurt na elke ronde.

## Monsters
- Hunters patrouilleren met zichtkegel, gehoor, zoekpatronen, teamagressie en padfinding-herberekening; aanraking triggert eliminatie (met cooldown).

- Sentry’s volgen vaste routes met optionele onzichtbaarheid, gehoor en alert-sounds; attributen op het model geven chase-status door aan clients.

- Een eventmonster kan willekeurig spawnen met waarschuwingseffecten (boodschap, flicker, rumble, trailkleur), jaagt de dichtstbijzijnde speler en elimineert op aanraking of binnen radius; EventMonsterService plant spawns en synchroniseert status naar clients.

- Configuratie bepaalt aantallen, snelheden, routes en spawnkansen voor alle vijanden.

## Obstakels & omgeving
- Standaard obstakels omvatten bewegende platforms en valdeuren met spawnregels (geen start/exit, minimale afstand, optionele vaste cellen) en parameters zoals beweging, pauzes en transparanties.

- ObstacleSpawner zorgt dat prefabs aanwezig zijn, kiest cellen, zet attributen en activeert scripts voor elk model; fallbackmeldingen waarschuwen voor ontbrekende assets.

- MazeBuilder’s animatie zorgt dat muren met naamgeving (W_x_y_dir) verwijderd worden volgens het gegenereerde raster, waardoor paden ontstaan.

## Power-ups
- Beschikbare power-ups: Turbo Boots (snelheid & trail), Ghost Mode (door muren lopen met cooldown), Magnet Power (zuigt pickups aan), Time Freeze (bevriest vijanden en andere spelers, forcefield-bol), Shadow Clone (maakt lokmodel), No Wall (verlaagt muren tijdelijk), Slow Down (vertraagt anderen) en Extra Life (revive + kortdurende onkwetsbaarheid).

- PowerUpService spawnt per ronde meerdere exemplaren per type op cel-anchors, koppelt proximity-prompts, synchroniseert effectstatussen en reset spelers bij rondewissel.

- Eliminaties worden eerst door PowerUps.TryPreventElimination onderschept (vooral Extra Life); GameManager raadpleegt deze hook voordat het een speler uitschakelt.

## Sleutels, inventaris & gadgets
- InventoryService beheert server-side aantallen sleutels en finder-unlocks, spiegelt deze naar de standaard Roblox-backpack met ondropbare tools (Maze Key, Exit/Hunter/Key Finder), synchroniseert naar clients en reset bij ronde-einde.

- KeyDoorService spawnt sleutelmodellen en Finder-pickups volgens rondeconfiguratie, voorziet ze van prompts om inventory-methodes aan te roepen en bouwt de uitgangsdeur + barrières; zodra voldoende sleutels gebruikt zijn, opent de deur en vuurt een event.

- ProgressionService controleert coins/XP tegen unlock-drempels en roept InventoryProvider aan voor GrantExit/Hunter/KeyFinder, zodat permanente gadgets beschikbaar komen.

## UI & hulpmiddelen
- De hoofd-HUD toont ronde-status, actieve/uitgeschakelde spelers, eventmonsterstatus en waarschuwingen voor sentry-onzichtbaarheid of eventwaarschuwingen; eliminaties worden gemeld met een overlay.

- Finder-knoppen geven spelers paden naar uitgang, dichtstbijzijnde hunter of sleutel via pathfinding-trails en afstandstekst zolang de corresponderende gadget geactiveerd is.

- De Exit Finder heeft bovendien een aparte kompas-UI die hoekafwijking naar de uitgang toont, en meldt wanneer geen exit beschikbaar is.

- VisitedTrail projecteert tegels in de maze wanneer de speler cellen bezoekt, afgestemd op het huidige thema, en stopt/cleart bij statewissels.

- In de maze wordt de camera automatisch op first-person gezet (behalve in de lobby of bij dood), met herstel van oorspronkelijke zoominstellingen; lobby-spelers houden een ruime zoomafstand.

- De debug-M-sneltoets laat spelers muurhoogte toggelen voor testdoeleinden via een RemoteEvent.

## Audio, licht & effecten
- AudioController regelt themamuziek (met preload en fade), heartbeat-waarschuwingen voor nabije vijanden en past volumes/snelheden aan op basis van afstand tot het gevaar.

- EnemyEffects bouwt chase-geluiden voor vijanden, genereert trails/glow-effecten en kan cameratrillingen starten tijdens eventmonster-warnings via RemoteEvent payloads.

- EventMonsterService stuurt Warn/Start/Stop payloads (boodschap, lichtkleur, rumble-intensiteit, trailkleur) naar clients zodat UI en effecten synchroon lopen.

## Event & themaservices
- Het lobbybord en lobby-preview reageren op ThemeValue-updates; LobbyService onderhoudt een lijst van beschikbare thema-opties en vult State/LobbyThemeOptions voor clientvisualisatie.

- EventMonsterStatus, volgende spawn-delay en waarschuwingen worden via State-values en RemoteEvents gedeeld voor UI’s zoals het scoreboard.

## Testing
- ⚠️ Niet uitgevoerd (read-only analyse).
