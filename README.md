# ⚜️ Legacy Admin Mobile Application
[![Flutter](https://img.shields.io/badge/Flutter-3.10.3-blue?style=for-the-badge&logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0.0-teal?style=for-the-badge&logo=dart)](https://dart.dev/)
[![Shorebird](https://img.shields.io/badge/Shorebird-OTA_Code_Push-orange?style=for-the-badge)](https://shorebird.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FCM-yellow?style=for-the-badge&logo=firebase)](https://firebase.google.com/)

A premium, feature-rich administrative mobile portal built for **Legacy Store** (luxury watches & timepieces brand). Serving as the mobile frontend of a customized **Enterprise Resource Planning (ERP)** system, this native **Flutter** application provides administrators, managers, and partners with full-spectrum control over the store catalog, real-time multi-warehouse inventory, orders, marketing campaigns, cashier POS, expense ledgers, and live business analytics directly from their iOS and Android devices.

The system enforces strict **Role-Based Access Control (RBAC)**, dynamically adjusting the navigation menus, dashboard statistics, and operational screens based on the logged-in administrator's permissions (Owner, Stock Manager, Cashier, Financial Auditor) fetched from the backend.

---

## ✨ Application Feature Modules

*   **📊 Live ERP Dashboard & Task Manager:** Real-time metrics of daily sales, orders count, and partner commissions. Includes a local-first offline task manager with priority setting and remote server synchronization.
*   **🔐 Dynamic Role-Based Permissions (RBAC):** Screens, actions, and API requests dynamically restrict themselves based on the user's role. Stock Managers only see inventory-related screens, Cashiers are redirected to the POS module, and Financial Auditors have sole access to treasury and payout approvals.
*   **📦 Inventory & Multi-Warehouse Tracking:** Check variant stock levels, request stock transfers between warehouses, manage product procurement batches, and receive automatic alerts for low stock levels.
*   **🧾 Order Management & Mobile POS:** Inspect customer purchases, update fulfillment statuses (Pending, Shipped, Delivered, Cancelled), generate official PDF invoices locally, and process offline showroom sales with the Mobile POS wizard.
*   **💰 Financial Control & Auditing:** Audit orders for accurate COGS (Cost of Goods Sold), approve partner payouts, document operational store expenses, track treasury liquidity, and perform month-end financial closures.
*   **🎯 Promotions & Marketing Hub:** Create and control coupons, configure Flash Sales, bundle products for discounts, run Buy One Get One (BOGO) campaigns, and monitor active affiliate marketers.
*   **💬 CRM, Support & Reviews:** Respond to customer inquiry forms, moderate reviews before displaying them on the storefront, and check restock requests for high-end watch variants.
*   **🔔 Live Push Notifications:** Automated push notifications powered by Firebase Cloud Messaging (FCM) alerting admins instantly of new orders, critical inventory drops, or pending payout requests.

---

## 🛠️ Technology Stack & Architecture

### Core Architecture & Cloud Services
*   **Design Pattern:** Feature-driven modular architecture. Each feature contains its screen UI, providers/controllers, and data models to ensure high maintainability and scalability.
*   **Database Backend:** Connects to a serverless **Neon PostgreSQL** database through the Next.js secure REST API endpoints.
*   **State Management:** `provider` (version `^6.1.5+1`) for clean state promotion and reactive UI updates.
*   **Secure Offline Caching:**
    *   `shared_preferences` for non-sensitive local storage (e.g. task manager caching).
    *   `flutter_secure_storage` for storing encrypted access tokens, passwords, and server cookies.
*   **Push Notifications:** **Firebase Cloud Messaging (FCM)** using `firebase_messaging` & `flutter_local_notifications` for background and foreground alerts.
*   **Instant Updates (OTA):** **Shorebird Code Push** integration to publish hot-fixes, UI improvements, and critical updates directly to active user devices without App Store/Play Store review delays.
*   **Payment & Financial Integration:** Interacts with the **Paymob Gateway** records for order auditing, refund confirmations, and transaction verifications.
*   **Networking:** Custom `http` wrapper with built-in connection interceptors, timeout handling, and automatic authorization headers inject.

### Key Packages & UI Enhancements
*   `google_fonts` (using *Playfair Display* for brand elegance & *Inter* for administrative clarity).
*   `fl_chart` for highly configurable, premium visual charts representing financial analytics.
*   `pdf` & `printing` for on-device PDF rendering, wireless printing, and file sharing.
*   `shimmer` for premium shimmer loading animations.
*   `arabic_reshaper` for clean Right-to-Left (RTL) Arabic text rendering in PDF layouts.

---

## 📁 Project Directory Structure

```text
lib/
├── core/
│   ├── config/       # API base URLs, timeouts, and route definitions (e.g. api_config.dart)
│   ├── constants/    # Theme styling tokens, brand assets, and local configurations
│   ├── network/      # API communication wrapper and error interceptors
│   ├── services/     # System-level features (Notification helper, PDF generator, Print service)
│   ├── theme/        # Light/Dark luxury theme configurations
│   └── widgets/      # Shared reusable UI elements (buttons, inputs, status badges)
│
├── features/         # Modular business domains
│   ├── auth/         # Login interface, session validation, and auto-login logic
│   ├── dashboard/    # Primary analytics hub and administrative Todo tasks
│   ├── finance/      # Treasury levels, operational expenses, and partner payouts
│   ├── home/         # Persistent bottom navigation shell and app drawer
│   ├── marketing/    # Coupon, flash sales, bundles, and affiliate settings
│   ├── more/         # CRM lists, review moderation, and customer inquiry support
│   ├── notifications/# Alerts history and templates
│   ├── operations/   # Suppliers, shipping zones, and invoices list
│   ├── orders/       # Order tracking, details page, and mobile POS checkout
│   ├── products/     # Product grid, creation form, variant generator, and image uploads
│   ├── reports/      # Sales graphs, COGS analysis, and data reports
│   ├── settings/     # App configurations and system notifications templates
│   └── storefront/   # Categories hierarchy, brand lists, and merchandising assets
│
└── main.dart         # Entry point (Splash screen dispatcher, MultiProvider initialization)
```

---

## 🚀 Setting Up & Getting Started

### 📋 Prerequisites
Ensure you have the following installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `^3.10.3`)
*   [Dart SDK](https://dart.dev/get-started) (version `^3.0.0`)
*   Android Studio & Android SDK (for Android builds)
*   Xcode (version `^14.0` or higher, macOS required for iOS builds)

### ⚙️ Local Configuration

1.  **Configure API Connection:**
    Open [lib/core/config/api_config.dart](file:///e:/Dev/web/LegaCy/admin-app/lib/core/config/api_config.dart).
    *   By default, it connects to the production deployment: `https://www.legecy.store`.
    *   For local testing, uncomment the local IP address option matching your machine's network IP (e.g. `http://192.168.x.x:8080` or `http://10.0.2.2:8080` for Android emulator).

2.  **Add Firebase Credentials:**
    Create project credentials in your Firebase Console and place them in the following paths:
    *   **Android:** `admin-app/android/app/google-services.json`
    *   **iOS:** `admin-app/ios/Runner/GoogleService-Info.plist`

3.  **Install Dependencies:**
    Run this command in the `admin-app` directory:
    ```bash
    flutter pub get
    ```

4.  **Run Development Mode:**
    Ensure you have an active emulator or physical device connected, then run:
    ```bash
    flutter run
    ```

---

## 📦 Building for Production

### Android Release
*   **Generate direct APK:**
    ```bash
    flutter build apk --release
    ```
*   **Generate Google Play App Bundle (.aab):**
    ```bash
    flutter build appbundle --release
    ```

### iOS Release (macOS required)
*   **Generate iOS App Bundle:**
    ```bash
    flutter build ipa --release
    ```

---

## 🦅 Shorebird Over-The-Air (OTA) Code Push

This application is fully integrated with **Shorebird** for immediate hot-patching. This allows the development team to push bug-fixes and UI refinements instantly to active users without passing through App Store or Google Play Store reviews.

*   **Configuration file:** [shorebird.yaml](file:///e:/Dev/web/LegaCy/admin-app/shorebird.yaml)
*   **Diagnostic check:** Verify your Shorebird configuration:
    ```bash
    shorebird doctor
    ```
*   **Release a new base version:**
    ```bash
    shorebird release android
    # or
    shorebird release ios
    ```
*   **Deploy an instant patch to live devices:**
    ```bash
    shorebird patch android
    # or
    shorebird patch ios
    ```

*Note: Base releases must be created using `shorebird release` rather than `flutter build` for patches to apply successfully.*
