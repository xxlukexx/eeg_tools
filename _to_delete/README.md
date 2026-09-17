# Retired standalone artifact detectors

These functions predate `eegAR_Detect` and duplicate detector implementations now exposed through that single entry point. They are retained temporarily for migration and audit, but new code must call `eegAR_Detect`.

The folder remains visible to recursive MATLAB path setup so existing callers do not fail immediately. Remove these files only after legacy callers have migrated and compatibility tests show that no active analysis depends on them.

Moved here:

- `eegAR_Alpha.m`
- `eegAR_EOGStat.m`
- `eegAR_Flat.m`
- `eegAR_MinMax.m`
- `eegAR_Range.m`
