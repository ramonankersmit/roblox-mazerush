# Richtlijnen voor `src/`

## Scope
Deze instructies gelden voor alle scripts en modules binnen de map `src/`.

## Code stijl
- Gebruik Luau-conventies: `PascalCase` voor module- en servicenames, `camelCase` voor lokale variabelen en functies.
- Houd functies kort en doelgericht; verplaats gedeelde logica naar aparte modules.
- Voeg type-annotaties toe waar mogelijk om leesbaarheid en tooling te verbeteren.

## Documentatie in code
- Voorzie modules van een korte moduleheader die uitlegt waarvoor ze dienen.
- Gebruik inline-commentaar alleen wanneer de intentie niet direct uit de code blijkt.

## Testing
- Als er testscripts bestaan, voer ze uit na relevante wijzigingen en noteer de resultaten.
