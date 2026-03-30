# The satellite (connection-aware) feature

This document explains how **satellite connectivity** works in this app: what it means, how to see it and test it during development (including the **launch argument** for local testing), and how it is implemented in terms of **connectivity** and **location** only.

## What “satellite” means in this app

- **good** — Unconstrained network. The app shows **"Status: Good data"**; full map and forecast, rain map loaded.
- **low** — Network is **ultra-constrained** (e.g. `NWPath.isUltraConstrained` is true). The app shows **"Status: Low data"**; reduced experience (e.g. no rain map).
- **none** — No network (path not satisfied). The app shows "Status: No data"; minimal weather (no hourly) and no rain map.

The status bar shows a single line: **Status: Good data** / **Status: Low data** / **Status: No data**, aligned with map and forecast visibility.

## How to see it in the demo (development and testing)

1. **On a real device** — Use a network that the system reports as ultra-constrained (e.g. certain cellular or satellite links when `NWPath.isUltraConstrained` is true). Open the app; the status bar should show "Status: Low data". On **iOS 26.4+** (recommended for Spark satellite), weather HTTPS uses **`allowsUltraConstrainedNetworkAccess`** on the shared **`URLSessionConfiguration`** in **`NetworkURLSessionHTTPClient`** (in addition to entitlements).
2. **Testing locally without special hardware — launch argument:** Use the **`-SimulateConstrainedPath`** launch argument so the app always uses a fixed connectivity value. In Xcode: **Edit Scheme → Run → Arguments → Arguments Passed On Launch**, add two arguments:
   - **`-SimulateConstrainedPath`**
   - **`low`** (or **`none`** or **`good`**)
   Run the app. With **`low`** you’ll see "Low data mode", and the rain map will show a placeholder. Use **`none`** to simulate no connection, or **`good`** to force good. This is the recommended way to test satellite UI and behaviour on any device or simulator.
3. **Behaviour** — When connectivity is **good**, the rain map (radar) is loaded; when **low** or **none**, the rain map section shows a placeholder. When **none**, the app fetches minimal weather. So the app both shows the satellite state and acts on it.

**Location:** Weather and RainViewer radar use the **device location** from Core Location. There is no fallback location; if location is unavailable, the app shows "No location found".

## How it’s implemented (connectivity and location only)

### 1. Connection strength — `Connectivity.swift`

- **`Connectivity`** is an enum: **good**, **low**, **none**.
- **`Connectivity(networkPath: NWPath)`** initializer:
  - If the launch argument **`-SimulateConstrainedPath good|low|none`** is set, it **returns that value** (for testing without real constrained hardware).
  - Else if `networkPath.status != .satisfied`, returns **.none**.
  - Else if `networkPath.isUltraConstrained` is true, returns **.low**.
  - Otherwise returns **.good**.

So **low** is driven by **ultra-constrained path** in production, or by **`-SimulateConstrainedPath low`** in development/testing.

### 2. Observing connectivity — `NetworkPathService.swift` and `ViewModel.swift`

- **NetworkPathService** uses **NWPathMonitor** and notifies observers via **networkPathDidUpdate(with path: NWPath)**.
- **WeatherViewModel** (in ViewModel.swift) conforms to **NetworkPathServiceObserver**, holds **connectivity**, and in **networkPathDidUpdate(with:)** sets **connectivity = Connectivity(networkPath: path)**. The UI (SwiftUI) reacts because the ViewModel is **@Observable**.

### 3. Status bar — `ContentView.swift` and `Connectivity+Display.swift`

- **Connectivity+Display** adds **description** ("Status: Good data", "Status: Low data", or "Status: No data"). The status bar in **ContentView** shows **viewModel.connectivity.description** only (single line).

### 4. Adapting behaviour — `ViewModel.swift` and `ContentView.swift`

- **WeatherViewModel:** When **connectivity == .none** the app fetches minimal weather (no hourly); otherwise full weather.
- **ContentView:** The rain map (**StormMapView**) is only shown when **viewModel.connectivity == .good**; when **.low** or **.none**, a placeholder is shown.

### 5. Location — `LocationService.swift`

- **Core Location** supplies the device location; **reverse geocoding** gives the place name. **Open-Meteo** and **RainViewer** use this location for weather and radar.

## Summary

| Concept | In this app |
|--------|----------------|
| **What triggers Low data mode** | Connectivity is **low** (`NWPath.isUltraConstrained` or **`-SimulateConstrainedPath low`**). |
| **Where it’s computed** | `Connectivity.swift`: `Connectivity(networkPath:)` (including launch argument). |
| **Where it’s observed** | `NetworkPathService.swift`: NWPathMonitor → networkPathDidUpdate(with:). |
| **Where it’s stored** | WeatherViewModel: **connectivity** updated in networkPathDidUpdate(with:). |
| **Where it’s shown** | ContentView: status bar shows connectivity.description (Status: Good/Low/No data). |
| **Where it’s used for behaviour** | WeatherViewModel: minimal vs full weather when .none; ContentView: rain map (StormMapView) only when .good. |
| **Location** | LocationService: device location for weather and radar; no fallback. |
| **Traffic on satellite** | `Satellite-Data.entitlements`: carrier-constrained keys + App ID capability (see **Building an app**). |

For the exact code, see **Connectivity.swift**, **Connectivity+Display.swift**, **NetworkPathService.swift**, **ViewModel.swift** (WeatherViewModel), **ContentView.swift**, **StormMapView.swift**, and **LocationService.swift**.

---

## Building an app with satellite (connection-aware) behaviour

If you want to add similar behaviour to your own app:

1. **Observe the network path** — Use **NWPathMonitor** and the default path. Read **`path.isUltraConstrained`** for a “low” (e.g. satellite or constrained) state; `path.status != .satisfied` for none; otherwise good. See **NetworkPathService.swift** and **Connectivity.swift**.
2. **Declare ultra-constrained access (HTTPS on satellite)** — In your app target’s **entitlements**: **`com.apple.developer.networking.carrier-constrained.appcategory`** (string array; values from [Apple’s entitlement docs](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.networking.carrier-constrained.appcategory)) and **`com.apple.developer.networking.carrier-constrained.app-optimized`** = **`true`**. Example plist: **`SparkSatelliteWeather/Satellite-Data.entitlements`**. Enable the matching capability on the **App ID** in Apple Developer. [Overview](https://developer.apple.com/documentation/BundleResources/Configuring-your-app-for-ultra-constrained-networks).

3. **Single connectivity value** — Map the path to one enum (e.g. good / low / none). Your ViewModel (or equivalent) holds this and updates it when the path changes. Expose a human-readable description for the status bar (e.g. “Status: Good/Low/No data”).
4. **Testing without real hardware** — Support a launch argument (e.g. **`-SimulateConstrainedPath good|low|none`**) so the app uses a fixed connectivity value. See **Connectivity.swift** and the README. This lets you test the UI and behaviour on any device or simulator.
5. **Gate heavy or optional features** — In this app, the rain map is only shown when connectivity is **.good**. You can hide or downgrade bandwidth-heavy features when **.low** or **.none**.
6. **Optional: minimal data when none** — When connectivity is **.none**, fetch only essential data (e.g. current + daily, no hourly) to avoid failing requests.
7. **Location** — Use Core Location and reverse geocoding as usual; no change needed for satellite behaviour beyond using the same location for your APIs.

**Android (if you also ship an Android app):** Google uses **manifest metadata**, not these entitlements. See **SparkSatelliteWeather-Android** **`docs/SATELLITE.md`** and [Develop for constrained satellite networks](https://developer.android.com/develop/connectivity/satellite/constrained-networks).
