This mod allows you to set generic quality filters (no specific item selected) on inserters using circuits.

When opening an inserter interface you will see a new option: "Set filters with quality signals".
![Set filters with quality signals checkbox](https://i.imgur.com/B7JXvDN.png)
Setting this option will allow the inserter to read quality signals from connected circuit networks and set its filters to match. This mod adds quality signals to the Signals tab for convenience, but you can also use the ones found in the Unsorted tab.
Comparator signals are also supported (>, <, =, ≥, ≤, ≠). For example, if you want to set the filter for qualities greater than rare, you can send both the "Rare" and "Greater than" signals. If no comparator signal is present the inserter will default to "=". If multiple comparator signals are present, the highest-value one wins.
![Comparator example](https://i.imgur.com/NtIdDZC.png)
Currently only inserters are supported, hoping to add support for other filterable machines like splitters soon.
This mod should automatically support quality tiers added by other mods.

This is a beta release, expect to run into bugs and backup your save before installing/updating.

Known Issues/Limitations:
- The vanilla circuit-controlled "Set filters" option doesn't support generic quality filters, so it is disabled while this mod's setting is active. When "Set filters with quality signals" is enabled, this mod takes control of the inserter’s filters ("Use filters" ON, "Whitelist", "Set filters" OFF).
- Removing an inserter with "Set filters with quality signals" selected, then restoring it with the Undo action does not keep its setting, you will have to reselect the option.
- If two or more comparator signals are tied for the highest value, the mod will not update filters until the tie is resolved.
