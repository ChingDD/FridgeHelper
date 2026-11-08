# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Running
- Use Xcode to build and run the project: Open `FridgeHelper.xcodeproj` in Xcode
- Target device: iOS (portrait orientation only)
- No package dependencies - uses only native iOS frameworks

### Testing
- No automated test suite present - testing done through Xcode simulator and device testing

## Architecture Overview

### High-Level Structure
FridgeHelper is an iOS app for managing food items in one or more refrigerators, with expiration tracking, notifications, CloudKit sync and per-fridge sharing.

**Core Architecture Pattern**: MVVM with repository-based local persistence (SwiftData) and CloudKit sync. **Multi-fridge**: one fridge = one CloudKit record zone.

### Key Components

**Models**:
- `Item`: Food item (name, number, unit, expiry date, `storeLocation`, memo, tag, image, `fridgeID`, `zoneOwnerName`, `updatedByName`). `timeStamp` string is the identity (also the CKRecord name).
- `Fridge` (`@Model`, local only, not synced): `fridgeID` = `"<ownerName>|<zoneName>"` (stringified zoneID), name, `plan`, `tags`, `locations`, `createdAt`, `listsUpdatedAt` (last local change of tags/locations). Own zones always use `CKCurrentUserDefaultName` as ownerName (`Fridge.normalizedOwnerName`). `Fridge.zoneID(from:)` restores a zoneID from a fridgeID. `SelectedFridgeStore` remembers the last selected fridge
- `FridgePlan` (`free` / `familyLifetime`): central limits (owned fridges, items per fridge, invited members). Provided via `FridgePlanProviding` (currently `FreeFridgePlanProvider`; StoreKit planned). Plan follows the fridge Owner; members trust `FridgeMetadata.plan` synced from the zone

**ViewModels**:
- `MainViewModel`: One instance **per selected fridge** (rebuilt on every selection). Item CRUD, filtering/sorting/search, in-memory `savedItems` cache, derived `displayedItems` / `expiredItems` / `expiredCount` / `savedItemCount`, capacity gate `addItemRejection` (synchronous on purpose)
- `StringListViewModel`: User-defined lists (tags, locations) + selected filter value. Persists through `StringListStore`; `FridgeStringListStore` writes `Fridge.tags/locations` and calls `onChange` to push `FridgeMetadata` to the cloud
- `FridgeViewModel`: Fridge list for the selection screen (reloads on `.cloudKitDataDidChange`)
- `ParticipantsViewModel`: Share participants for the selected fridge
- `EditViewModel`: Builds new/edited `Item` values and validates form state
- `SortMethod` (in MainViewModel.swift): sort options

**Views/Controllers**:
- `LunchingViewController`: Launch animation, then switches the window root to `FridgeSelectionViewController`. On selection it saves `SelectedFridgeStore.fridgeID` and calls `MainTabBarFactory.make`
- `FridgeSelectionViewController`: Home screen listing local `Fridge`s
- `MainTabBarFactory` (**composition root**): Per selected fridge builds `SwiftDataItemRepository` → `CloudRepository` → `CompositeRepository`, both `StringListViewModel`s, `MainViewModel` (with `syncFromCloud` closure → `AppDelegate.syncCloudToLocal()`), and a `ShareManager` bound to that fridge. Returns a `MainTabBarController`
- `MainTabBarController`: Hides system tab bar, uses custom floating glass bar (3 tabs: Fridge / Scan / Participants)
- `FridgeViewController`: Dashboard (expiry banner, location/tag filters, card list, FAB). Calls `MainViewModel` for add/update/delete
- `ItemFormViewController`: Add/edit item form (replaces old EditViewController)
- `ExpiryAlertsViewController`: Expiry alerts sheet (replaces old ExpiredTableViewController)
- `ManageListViewController`: Generic add/delete screen for tags and locations
- `ParticipantsViewController`: Member list; invite/remove via `UICloudSharingController`
- `ScanViewController`: Skeleton only, scanning not implemented
- UI is built programmatically (custom components in `View/Components`, styling in `Theme`), no longer storyboard-based except the launch screen

**Data Layer**:
- `SwiftDataStack`: Owns the `ModelContainer`. Created once in `AppDelegate` (`sharedStack`)
- `SwiftDataItemRepository` (`ItemRepositoryProtocol`): Local SwiftData CRUD; `fetch(fridgeID:)` sorted by `timeStamp` descending; `count(fridgeID:)`
- `CompositeRepository`: Write-through. Reads local only; add/update/delete write SwiftData first, then CloudKit in the background (best-effort, failures only logged). Update is **single-flight per item** with dirty-flag merging; delete waits for in-flight upload and clears dirty to avoid resurrecting records
- `CloudRepository`: CloudKit item CRUD. `route(for:)` picks `privateDB` / `sharedDB` and zone from `Item.fridgeID`. `fetch(fridgeID:)` / `count` intentionally return empty (local only)
- `SyncCoordinator`: Cloud → local one-way sync using change tokens (per database and per zone, keys from `SyncTokenKey`). Covers all private zones + shared DB. `ensureFridge` rebuilds a `Fridge` from a record's zoneID (new device / reinstall); applies `FridgeMetadata` (plan only for others' fridges; lists by last-writer-wins on `listsUpdatedAt`). Does not handle user CRUD
- `FridgeMigrator`: Idempotent check run at launch; creates the Default fridge (zone `ShareZone`, system default lists) if it does not exist. No legacy-data migration (app is unreleased)
- `DateController` singleton: Date formatting

**CloudKit Layer** (`Data/CloudKit`):
- `ZoneManager` (`ZoneManaging`): `ensureZoneExists(_:)` for own zones only. `defaultZoneName = "ShareZone"`; later fridges use `Fridge_<UUID>`
- `ShareManager` (`SharingRepositoryProtocol`): One per fridge; fetches/creates the zone-wide `CKShare`, stops sharing. Only the fridge Owner can invite or stop sharing
- `FridgeMetadataRepository` / `FridgeMetadataRecordMapper`: Writes the fridge's own record into its zone (plan, lists, `listsUpdatedAt`). Owner writes full metadata; members write list fields only and never create the record. Skips the write when the cloud copy is already up to date
- `ItemRecordMapper`: Item ↔ CKRecord
- `SubscriptionManager` (`Subscribable`): Silent-push subscriptions (private zone + shared DB), registered from `AppDelegate`

### Key Features
- **Expiration Tracking**: Items within 3 days of expiry are flagged (`expiryDate.timeIntervalSinceNow <= 259200`)
- **Local Notifications**: 3-days-before and expiry-day notifications scheduled in `AppDelegate`
- **Filtering**: By storage location, tag, search keyword; sorting by date/quantity
- **Multi-fridge + Plans**: Per-fridge item capacity via `FridgePlan`
- **iCloud Sync**: Across devices on the same Apple ID
- **Shared Fridge**: Zone-wide `CKShare` per fridge; participants read/write via shared DB
- **Real-time Updates**: Silent push → sync, with a notification showing who changed what

### Data Flow

**Launch (fresh install and normal launch are the same path)**:
1. `AppDelegate.didFinishLaunching` creates `SwiftDataStack`, then synchronously runs `FridgeMigrator.ensureDefaultFridge()` (ensures the Default fridge exists) so a fridge always exists
2. Background Task: `syncCloudToLocal()` → `pushOwnedFridgeMetadata()` → `planAllItemsExpirationNotification()`. In parallel: notification authorization, `registerForRemoteNotifications`, zone + subscription setup
3. `syncCloudToLocal()` is serialized via `syncTask` (one sync at a time); fresh install has no token so it is a full fetch (restores data for the same Apple ID). It posts `.cloudKitDataDidChange` when done
4. After the animation, `FridgeSelectionViewController` shows local fridges; selecting one runs `MainTabBarFactory.make`, creating a fresh `MainViewModel` that calls `loadItems()` (`fetch(fridgeID:)`)

**Item Add / Update / Delete**:
1. `FridgeViewController` → `MainViewModel` (`addItem` / `updateItem` / `updateQuantity` / `removeItem`)
2. `MainViewModel` updates `savedItems` first so UI reflects immediately
3. `CompositeRepository` writes SwiftData, then CloudKit in the background
4. `MainViewModel` reschedules/removes notifications and calls `updateDerivedState()`
5. `addItem` first checks `addItemRejection` (capacity); update/delete never check capacity

**String lists (tags / locations)**:
1. `ManageListViewController` → `StringListViewModel.add` / `remove(at:)`
2. `FridgeStringListStore.save` writes `Fridge.tags/locations`, updates `listsUpdatedAt`, saves context, calls `onChange`
3. `onChange` → `FridgeMetadataRepository.upsert(for:)` uploads to the cloud
4. Removing a value clears `selected` if it was the active filter; items already using it keep their string
5. Other devices apply it in `SyncCoordinator.applyLists` (cloud newer, or local still default), then `.cloudKitDataDidChange` → `reloadFromStore()`

**Silent Push → Sync**:
1. A change on any device delivers a silent push; `AppDelegate.didReceiveRemoteNotification` calls `syncCloudToLocal(shouldNotifyChanges: true)`
2. `SyncCoordinator.fetchChanges()` applies cloud changes to SwiftData, a user notification shows who changed what
3. `.cloudKitDataDidChange` makes `FridgeViewModel`, `MainViewModel` (`loadItems()`) and `StringListViewModel` reload from local data

**Sharing Flow**:
1. Owner opens the Participants tab; `ShareManager` (bound to the selected fridge) fetches or creates the zone-wide `CKShare`; `UICloudSharingController` handles invite/remove
2. Participant accepts: `SceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:)` calls `container.accept(_:)` then `syncCloudToLocal()`; `ensureFridge` creates the shared fridge locally

### Background Processing
- Bundle ID: `com.jefflin.FridgeHelper`, background task identifier: `com.jefflin.FridgeHelper.checkExpired`
- `AppDelegate` handles notification authorization/delivery and remote notifications

### Other Docs in Repo
`CloudKitSyncFlow.md`, `FridgeBusinessAndTechnicalDesign.md`, `pushUpdateToCloud.md`, `ENHANCEMENTS.md`, `release_tickets.md` hold design notes. Prefer the code when they disagree.
