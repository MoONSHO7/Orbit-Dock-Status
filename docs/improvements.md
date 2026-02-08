# Orbit_Status Improvements

## Goal
Improve `Orbit_Status` based on codebase analysis and modern addon standards.

## Key Missing Feature: LibDataBroker (LDB) Support

**Current Status:**
The project memory indicates that `Widgets/LDB.lua` utilizes LibDataBroker (LDB) integration, but this file is missing from the codebase. The `Widgets/` directory contains specific widgets (Performance, CombatTimer, Gold, etc.) but no generic LDB handler.

**Recommendation:**
Implement `Widgets/LDB.lua` to provide full support for LibDataBroker. This is crucial for:

1.  **Ecosystem Compatibility:**
    - LDB allows any LDB-compliant addon (e.g., Raider.IO, DBM, WeakAuras, TomTom) to display data in `Orbit_Status` without requiring custom widgets for each.
    - This instantly expands the functionality of the dock to hundreds of external addons.

2.  **Architectural Efficiency:**
    - Instead of maintaining individual widgets for every possible metric, `Orbit_Status` can rely on the LDB ecosystem for data providers.
    - The `WidgetManager` should be updated to dynamically create widgets from registered LDB data objects.

**Implementation Steps:**
1.  Create `Widgets/LDB.lua`.
2.  Use `LibStub("LibDataBroker-1.1")` to iterate over registered data objects.
3.  For each data object, create a `BaseWidget` instance (or similar structure compatible with `WidgetManager`).
4.  Listen for LDB callbacks (`OnTooltipShow`, `OnClick`, `OnEnter`, `OnLeave`) and map them to the widget's event handlers.
5.  Register these dynamic widgets with `WidgetManager` so they can be docked/undocked like native widgets.

This single feature will significantly enhance the utility and flexibility of `Orbit_Status`, making it a true replacement for other broker displays (like Titan Panel or ChocolateBar).
