# AutodocZhukovTest

A production-style iOS test project focused on **clean architecture**, **responsive UX**, and **real-world edge cases**.

This app displays a news feed from the Autodoc API with pagination, detail navigation, image optimization, offline support, and adaptive layouts for iPhone/iPad.

---

## Why This Project Stands Out

- **Modern iOS stack**: UIKit + MVVM + Combine + async/await
- **Scalable architecture**: Coordinator-based navigation, dependency composition, protocol-driven services
- **Performance-first implementation**: image downsampling, prefetch/preheat, in-memory + disk caching
- **Robust UX in poor network conditions**: offline banners, cached startup content, retry flows
- **Adaptive UI**: polished behavior on iPhone portrait/landscape and iPad 2-column layouts
- **No third-party dependencies**: only Apple frameworks

---

## Implemented Features

### Core Product Flow

- Splash screen with initial data warm-up
- News list screen with compositional layout and diffable data source
- News detail screen with full content and image
- Navigation flow coordinated via `AppCoordinator`

### Networking & Data

- API integration with page-based endpoint:
  - `GET /api/news/{page}/{pageSize}`
- Flexible date decoding for mixed backend date formats
- Domain mapping from DTOs to app models
- Error handling for network/response/decoding failures

### Pagination & Loading Experience

- Infinite scroll with threshold-based next-page loading
- Background prefetch of the upcoming page
- Pull-to-refresh for top-of-list refresh
- Completion footer when all available news are loaded

### Offline & Reliability

- Disk cache for first page (fast subsequent launches)
- Network status monitoring (`NWPathMonitor`)
- Offline UI states:
  - full-screen network error when no content is available
  - inline network banner when cached content is shown
- Recovery path after network returns

### Image Pipeline

- `ImageLoader` implemented as an `actor` for safe concurrency
- Request deduplication for concurrent image consumers
- Prioritized loading (`display` vs `background`)
- On-the-fly downsampling via ImageIO to reduce memory pressure
- Image preheating on splash and during list scrolling
- Shimmer placeholder for smoother perceived loading

### Read State Persistence

- “Read” status badge in list cells
- Mark-as-read on detail open
- Persistent storage of read IDs across app launches

### Layout & Device Adaptation

- iPhone portrait: single-column feed
- iPhone landscape: two columns
- iPad: two-column layout with consistent row sizing
- Scroll indicator customization and clean spacing system

---

## Technical Highlights

- **Architecture**
  - MVVM + Combine state publishing
  - Coordinator pattern for app flow orchestration
  - Composition root for dependency injection
  - Protocol abstractions for testability and modularity

- **Concurrency**
  - Extensive use of Swift Concurrency (`Task`, `async/await`)
  - Actor isolation for shared mutable image-loading state
  - MainActor-bound UI updates and safe cross-thread handoffs

- **UI Engineering**
  - Compositional layout + diffable snapshots
  - Snapshot reconfiguration for lightweight UI state updates
  - Smooth transitions between loading, content, and error states

---

## Project Structure

```text
AutodocZhukovTest/
├─ App/                  # AppCoordinator + dependency wiring
├─ Features/
│  ├─ Splash/            # Splash screen and startup flow
│  ├─ NewsList/          # Feed UI, layout, pagination, preheat
│  └─ NewsDetail/        # News detail screen
├─ Networking/           # API client, date decoding
├─ Services/             # Images, cache, network monitor, read store
├─ Models/               # Domain entities
└─ Views/                # Shared UI components (e.g., shimmer)
```

---

## Build & Run

1. Open `AutodocZhukovTest.xcodeproj` in Xcode.
2. Select a simulator/device.
3. Build & run (`⌘R`).

---

## What This Demonstrates to Employers

This project demonstrates practical iOS engineering skills expected in product teams:

- building maintainable app architecture, not just screens
- shipping responsive, resilient UX under real network constraints
- writing concurrency-safe code with performance considerations
- delivering a polished feature set aligned with technical requirements

If you are looking for an iOS developer who can combine **code quality**, **user-focused thinking**, and **execution speed**, this project reflects that approach.

