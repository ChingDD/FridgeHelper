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
FridgeHelper is an iOS app for managing food items in a refrigerator with expiration tracking and notifications.

**Core Architecture Pattern**: MVVM (Model-View-ViewModel) with Singleton data management

### Key Components

**Models**:
- `Item` (Item.swift): Core data model representing food items with properties like name, quantity, expiry date, storage condition, memo, tag, and image
- Storage conditions: 室溫 (room temperature), 冷藏 (refrigerated), 冷凍 (frozen)

**ViewModels** (business logic):
- `ItemViewModel`: Manages item CRUD operations, filtering, sorting, and data persistence
- `TagViewModel`: Handles tag creation and filtering
- `SortViewModel`: Manages sorting options (by date, quantity)
- Search and segmentation control ViewModels

**Views/Controllers**:
- `MainTableViewController`: Primary interface showing items in table format with filtering/search
- `EditViewController`: Item creation/editing interface  
- `ExpiredTableViewController`: Shows items nearing expiration
- `TagTableViewController`: Tag management interface

**Data Layer**:
- `FileMgr` singleton: Handles JSON serialization/deserialization for items and tags to Documents directory
- `DateController` singleton: Date formatting utilities
- Uses iOS Documents directory for local storage (no CoreData/SQLite)

### Key Features
- **Expiration Tracking**: Items within 3 days of expiry are flagged as "expired"
- **Push Notifications**: Background notifications for expiring items
- **Filtering System**: By storage condition, tags, search keywords
- **Image Support**: Items can have associated photos stored as JPEG data
- **Sorting Options**: By date (near to far, far to near) and quantity (high to low, low to high)

### Data Flow
1. `FileMgr` loads items from Documents directory JSON files
2. `ItemViewModel` manages in-memory item arrays with Observable pattern
3. ViewControllers bind to ViewModel observables for reactive UI updates
4. Changes trigger automatic persistence via `FileMgr`

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