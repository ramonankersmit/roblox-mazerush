# Maze Rush Agent Guidelines

## Scope
Deze richtlijnen gelden voor het volledige repository, tenzij er in submappen een specifiekere `AGENTS.md` staat.

## Algemene werkwijze
- Lees altijd deze instructies voordat je wijzigingen maakt.
- Houd commitberichten beknopt en informatief.
- Voer waar mogelijk relevante tests of linting uit en rapporteer de gebruikte commando's in het eindverslag.

## Documentatie
- De `README.md` bevat het officiële overzicht van functionaliteiten. Voeg alleen informatie toe die overeenkomt met de actuele game-logica en houd de structuur met secties en opsommingstekens intact.
- Nieuwe documentatiebestanden moeten consistente Markdown-opmaak gebruiken (koppen in titelzaak, opsommingstekens met `-`, en lege regel tussen paragrafen/secties).

## Code en assets
- Roblox/Luau-code bevindt zich onder `src/`. Respecteer bestaande naamgevingsconventies en Roblox best practices (camelCase voor variabelen, PascalCase voor services/modulenamen).
- Voeg geen externe dependencies toe zonder expliciete instructie.

## Communicatie
- Beschrijf in pull requests en eindrapporten duidelijk welke onderdelen zijn gewijzigd en waarom.
- Wanneer wijzigingen niet getest kunnen worden, vermeld expliciet de reden.
