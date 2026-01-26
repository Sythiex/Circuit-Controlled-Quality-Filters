# Circuit-Controlled Quality Filters

### This mod allows you to set generic quality filters (no specific item selected) on inserters using circuits.

## TLDR how to use:
1. Open an inserter
2. Enable **"Set filters with quality signals"**
3. Send quality + (optional) comparator signals on the connected circuit network.

## longer boring description:

When opening an inserter interface you will see a new option: "Set filters with quality signals".
![Set filters with quality signals checkbox](https://i.imgur.com/B7JXvDN.png)

Setting this option will allow the inserter to read quality signals from connected circuit networks and set its filters to match. This mod adds quality signals to the Signals tab for convenience, but you can also use the ones found in the Unsorted tab.

Comparator signals are also supported (>, <, =, ≥, ≤, ≠). For example, if you want to set the filter for qualities greater than rare, you can send both the "Rare" and "Greater than" signals. If no comparator signal is present the inserter will default to "=". If multiple comparator signals are present, the highest-value one wins.
![Comparator example](https://i.imgur.com/NtIdDZC.png)

## Other Notes
- This mod should automatically support qualities added by other mods.
- Currently only inserters are supported, looking to add support for other generic quality filterables like splitters soon.
- ***This is a beta release, expect to run into bugs and backup your save before installing/updating.***

## Known Issues/Limitations:
- The vanilla circuit-controlled "Set filters" option doesn't support generic quality filters, so it is disabled while this mod's setting is active. When "Set filters with quality signals" is enabled, this mod takes control of the inserter’s filters ("Use filters" ON, "Whitelist", "Set filters" OFF).
- Removing an inserter with "Set filters with quality signals" enabled then restoring it with the Undo action does not keep its setting.
- If two or more comparator signals are tied for the highest value, the mod will not update filters until the tie is resolved.
