# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FridgeHelper is an iOS app built with UIKit that helps users manage food items in their fridge, tracking expiry dates and sending notifications for expired items. The app uses a traditional MVC + MVVM architecture with custom observable pattern for data binding.

## Build and Development Commands

This is an Xcode project. Common development tasks:

- **Build the app**: Open `FridgeHelper.xcodeproj` in Xcode and use Cmd+B to build
- **Run the app**: Use Cmd+R in Xcode to build and run on simulator/device
- **Clean build**: Product → Clean Build Folder in Xcode

## Architecture

### Project Structure
- **Model/**: Data models (Item.swift)
- **View/**: Custom UI components (table view cells, alert views)
- **Controller/**: View controllers following MVC pattern
- **ViewModel/**: View models for data handling and business logic
- **Singleton/**: Shared services (FileMgr for file operations, DateController for date handling)

### Key Components

**Data Layer:**
- `Item.swift`: Core data model with storage conditions (室溫/冷藏/冷凍)
- `FileMgr.swift`: Singleton for file operations, image storage, and data persistence
- `ObservableObject.swift`: Custom observable pattern for data binding

**View Controllers:**
- `MainTableViewController.swift`: Primary interface with segmented control for storage conditions
- `ExpiredTableViewController.swift`: Displays expired items
- `EditViewController.swift`: Item creation/editing interface
- `TagTableViewController.swift`: Tag management

**View Models:**
- `ItemViewModel.swift`: Manages item data, filtering, and search functionality
- `TagViewModel.swift`: Handles tag-related operations
- `SortViewModel.swift`: Item sorting logic
- `SearchControlViewModel.swift`: Search functionality

### Data Flow
- Uses custom `ObservableObject<T>` for reactive data binding
- File operations handled through `FileMgr` singleton
- Items stored locally with image persistence
- Background processing for expiry notifications (Info.plist includes BGTaskSchedulerPermittedIdentifiers)

### Logging
- Custom logging function `printInfo()` in Logger.swift with timestamp, file, function, and line number information

### Key Features
- Storage condition categorization (room temperature, refrigerated, frozen)
- Expiry date tracking with notifications
- Tag-based filtering and organization
- Image storage for items
- Search and sort functionality
- Background processing for expired item notifications

## Development Notes

- App uses Chinese localization for storage conditions
- Bundle ID: `com.jefflin.FridgeHelper`
- Background modes enabled for processing expired items
- Uses UIKit with Storyboard for UI
- Custom observable pattern instead of Combine/SwiftUI