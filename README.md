# Sanap ERP - Frontend

Cross-platform frontend application for Sanap ERP (Mobile & Web) built with Flutter.

## Architecture & Features
- **Role-Based Dashboards**: Super Admin, Store Admin, Field Sales Manager (FSM), and Salesman.
- **Offline-First Architecture**: Local caching, SQLite/SharedPreferences session persistence, offline sales logging, and auto-sync on network reconnect.
- **Dynamic Commission Engine**: Product-level tiered commissions and multi-tier salesman referral tree.
- **Inventory & Settlements**: Stock intake, transfer workflows, reverse allocation recalls, and daily settlement verification.

## Backend Repository
The Express REST API backend is located at:
👉 **[Jayesh7210/erpbackend](https://github.com/Jayesh7210/erpbackend)**

## Getting Started

1. **Prerequisites**:
   - Flutter SDK (>=3.0.0)
   - Dart SDK
   - Android Studio / Xcode

2. **Navigate to the frontend folder**:
   ```bash
   cd frontend
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the application**:
   ```bash
   flutter run
   ```
