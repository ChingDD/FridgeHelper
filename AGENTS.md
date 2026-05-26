# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Development Commands

### Building and Running
- Use Xcode to build and run the project: Open `FridgeHelper.xcodeproj` in Xcode
- Target device: iOS (portrait orientation only)
- No package dependencies - uses only native iOS frameworks

### Testing
- No automated test suite present - testing done through Xcode simulator and device testing

## Architecture Overview

### High-Level Structure
FridgeHelper is an iOS app for managing food items in a refrigerator with expiration tracking and notifications.

**Core Architecture Pattern**: MVVM (Model-View-ViewModel) with repository-based local persistence and CloudKit sync

### Key Components

**Models**:
- `Item` (Item.swift): Core data model representing food items with properties like name, quantity, expiry date, storage condition, memo, tag, and image
- Storage conditions: 室溫 (room temperature), 冷藏 (refrigerated), 冷凍 (frozen)

**ViewModels** (business logic):
- `MainViewModel`: Manages item CRUD operations, filtering, sorting, local list cache, expired item state, and table update events
- `TagViewModel`: Handles tag creation and filtering
- `EditViewModel`: Builds new or edited `Item` values and validates edit form state
- `SortMethod`: Defines sorting options (by date, quantity, or no explicit sort)

**Views/Controllers**:
- `MainTableViewController`: Primary interface showing items in table format with filtering/search
- `EditViewController`: Item creation/editing interface  
- `ExpiredTableViewController`: Shows items nearing expiration
- `TagTableViewController`: Tag management interface

**Data Layer**:
- `SwiftDataItemRepository`: Handles local SwiftData persistence for items and UserDefaults-backed tags
- `CompositeRepository`: Owner-device write-through repository. Reads from SwiftData and writes item changes to local SwiftData first, then CloudKit in the background
- `CloudRepository`: Handles CloudKit item CRUD for private and shared zones
- `SyncCoordinator`: Applies CloudKit changes to local SwiftData after app launch, remote notifications, or accepted shares
- `DateController` singleton: Date formatting utilities
- SwiftData is the local source of truth for persisted items

### Key Features
- **Expiration Tracking**: Items within 3 days of expiry are flagged as "expired"
- **Push Notifications**: Background notifications for expiring items
- **Filtering System**: By storage condition, tags, search keywords
- **Image Support**: Items can have associated photos stored as JPEG data
- **Sorting Options**: By date (near to far, far to near) and quantity (high to low, low to high)

### Data Flow
1. `SwiftDataItemRepository.fetch()` loads items from SwiftData sorted by `timeStamp` descending, so newly created items remain at the top after reloads
2. `MainViewModel` keeps an in-memory `savedItems` cache and derives `displayedItems`, `expiredItems`, and `expiredCount` from it
3. ViewControllers subscribe to `MainViewModel` publishers and `tableUpdateEvent` for UI updates
4. Item add/update/delete flows update `MainViewModel` cache first, persist through the repository, then emit table update events
5. `MainTableViewController.viewWillAppear` refreshes view state such as tag menu, expired count, and selection only. It does not trigger CloudKit sync or refetch items
6. CloudKit sync is triggered by app launch, remote notifications, accepted shares, or an explicit `MainViewModel.syncFromCloudIfNeeded()` call. After sync, `.cloudKitDataDidChange` causes `MainViewModel` to reload local SwiftData

### Current Item Flow

**Add / Edit / Delete**:
1. `MainViewModel` updates the local `savedItems` cache first
2. The repository writes the change to SwiftData
3. `MainViewModel` emits a table update event
4. `MainTableViewController` renders from `displayedItems`

**MainTableViewController.viewWillAppear**:
1. Refreshes tag menu, expired count, and selection state only
2. Does not call `syncCloudToLocal()`
3. Does not refetch items when returning from add/edit screens

**CloudKit Changes**:
1. `AppDelegate`, `SceneDelegate`, or remote notification handling triggers `syncCloudToLocal()`
2. After sync finishes, `.cloudKitDataDidChange` is posted
3. `MainViewModel` receives the notification and calls `loadItems()`
4. `SwiftDataItemRepository.fetch()` returns items sorted by `timeStamp` descending
5. `MainViewModel.updateDerivedState()` updates `displayedItems`

### Background Processing
- Uses `BackgroundTasks` framework for checking expired items
- App delegate handles notification authorization and delivery
- Bundle ID: `com.jefflin.FridgeHelper` with background task identifier: `com.jefflin.FridgeHelper.checkExpired`

### UI Patterns
- Uses Storyboard-based UI with programmatic customization
- Custom table view cells for item display
- Swipe actions for item deletion
- Menu-based filtering and sorting controls
- Search controller integration in navigation bar
