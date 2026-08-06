# EEG Viewer relocated

The Python EEG Viewer is now an independent project:

- repository: <https://github.com/xxlukexx/eeg-viewer>
- canonical local checkout: `F:/codex/te-pipeline/repos/eeg-viewer`
- Version 1 tag: `v1.0.0`

The implementation has no runtime dependency on `eeg_tools`. Its original
development commit remains in this repository's history as `d82f3dd`, while
active development, tests, documentation, and benchmark results now belong to
the standalone repository.

Ignored `.venv` and generated `results` files may remain in this directory on
machines that ran the original benchmark. They are historical local runtime
state, not the active source tree.
