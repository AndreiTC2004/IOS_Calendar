# iOS_Calendar

A native iOS calendar app built with UIKit that mirrors Apple's built-in Calendar app. It reads and writes events on the device's real calendars via EventKit, and renders them in a day-view timeline powered by [CalendarKit](https://github.com/richardtop/CalendarKit).

## Features

- Day-view timeline of events, backed by the user's actual device calendars (EventKit)
- Tap an event to view its details
- Long-press an empty slot to create a new event
- Long-press an existing event to edit it (drag to resize/move, then save)
- Automatically reloads when calendars change outside the app
- Light/dark mode aware event colors, derived from each calendar's color
- Auto-rotating news panel docked at the bottom of the calendar screen

## Requirements

- Xcode 16+
- iOS 18.2+
- Swift 5.0

## Getting Started

1. Clone the repo:
   ```bash
   git clone https://github.com/AndreiTC2004/iOS_Calendar.git
   ```
2. Open `IOS_Clandar.xcodeproj` in Xcode.
3. Let Xcode resolve the Swift Package Manager dependency ([CalendarKit](https://github.com/richardtop/CalendarKit)).
4. Build and run on a simulator or device. On first launch, grant calendar access when prompted.

## Project Structure

| File | Purpose |
|---|---|
| `AppDelegate.swift` / `SceneDelegate.swift` | App bootstrap; sets `CalendarViewController` as the root view controller. |
| `CalendarViewController.swift` | Main screen. Requests calendar access, fetches/creates/edits events through `EKEventStore`, and hosts the news panel. |
| `EKWrapper.swift` | Adapts `EKEvent` (EventKit) to CalendarKit's `EventDescriptor` protocol, including themed event colors. |
| `NewsView.swift` | Small view that displays and auto-rotates a list of news items. |

## Testing

Unit and UI test targets (`IOS_ClandarTests`, `IOS_ClandarUITests`) are set up and ready for test coverage.
