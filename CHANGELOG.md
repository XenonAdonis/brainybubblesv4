# Changelog

## v0.2.0 - 2025-08-12
### Added
- Settings screen with persistent options (SharedPreferences).
- Background music toggle using audioplayers (looping, lifecycle-aware).
- Safe fallback when music asset missing.

### Changed
- Spawn system ramps from fast to normal; can be tuned via Settings.

### Fixed
- Stability when audio asset is not present (won't crash).

