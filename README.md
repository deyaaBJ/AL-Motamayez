# Motamayez

**Motamayez** is a desktop Point of Sale and store management system built with **Flutter** and **Dart**, designed primarily for **Windows** and powered by a local **SQLite** database.

The project aims to provide a practical, fast, and reliable solution for managing daily store operations from one place without depending on a permanent internet connection.

## Overview

Motamayez covers the core needs of a retail store or supermarket, including:

- Product and inventory management
- Barcode support for products and units
- Batch and expiry date tracking
- POS sales workflow
- Cash, credit, and partial payment handling
- Customer accounts and debt tracking
- Supplier and purchase invoice management
- Expense tracking
- Financial and sales reports
- PDF export
- Store, tax, currency, and printer settings
- User roles and access control
- Local backup support
- Automatic archiving of old invoices

## Core Features

### Product and Inventory Management

The system allows adding, editing, and managing products with support for:

- Product pricing
- Cost price
- Quantity tracking
- Multiple selling units
- Barcode assignment
- Low stock awareness

### Batch and Expiry Tracking

Motamayez tracks real purchase batches, not just total stock. Each batch can include:

- Remaining quantity
- Cost price
- Production date
- Expiry date
- Linked supplier

This is especially useful for stores that handle food, medicine, or any expiry-sensitive products.

### POS and Sales

The application includes a dedicated POS interface for fast invoice creation and selling operations, with support for:

- Cash sales
- Credit sales
- Partial payments
- Customer-linked invoices
- Profit calculation per invoice
- Thermal receipt printing

### Customers and Debt Management

The system helps track customer balances and payment activity, including:

- Outstanding debt
- Paid amounts
- Remaining balances
- Payment allocation across invoices

### Suppliers and Purchases

Motamayez also includes supplier and purchasing workflows, allowing you to:

- Add and manage suppliers
- Create purchase invoices
- Record supplier payments
- Track supplier balances
- Return batches to suppliers

### Reports and PDF Export

The application provides reporting tools for:

- Sales
- Profit
- Financial movement
- Purchase activity
- Debt and balance summaries

Reports can be exported to **PDF** for sharing, printing, or archiving.

### Users and Permissions

The app includes authentication and role-based access. Current roles in the project include:

- `admin`
- `cashier`
- `tax`

This helps separate responsibilities and control access inside the system.

### Activation and Backup

The project includes a built-in device activation flow and local data protection features such as:

- Device-linked activation validation
- Local activation data storage
- Backup creation on app close
- Backup retention management

## Tech Stack

- **Flutter**
- **Dart**
- **Provider** for state management
- **SQLite**
- `sqflite`
- `sqflite_common_ffi`
- `pdf`
- `fl_chart`
- `shared_preferences`
- `http`
- `window_manager`
- `esc_pos_utils_plus`

## Project Structure

The main project code is organized under `lib/`:

- `screens`  
  Main application screens such as products, POS, customers, reports, settings, suppliers, and purchases.

- `providers`  
  State management and business logic.

- `db`  
  Database initialization, schema creation, and migrations.

- `models`  
  Data models used across the app.

- `services`  
  Supporting services such as activation, encryption, backup, and printing.

- `widgets`  
  Reusable UI components.

## Database

The project uses a local **SQLite** database, and the schema is managed programmatically through [`lib/db/db_helper.dart`](/e:/Motamayez/motamayez/lib/db/db_helper.dart).

Some of the main tables include:

- `products`
- `product_units`
- `product_batches`
- `sales`
- `sale_items`
- `sales_archive`
- `customers`
- `transactions`
- `suppliers`
- `purchase_invoices`
- `purchase_items`
- `expenses`
- `settings`
- `users`

## Running the Project

### Requirements

- Flutter SDK
- Dart SDK
- Windows environment for the desktop build

### Install dependencies

```bash
flutter pub get
```

### Run the application

```bash
flutter run -d windows
```

### Build a Windows release

```bash
flutter build windows
```

## Notes

- The application is designed to work locally with an on-device database.
- Some features depend on Windows-specific behavior such as printing or device fingerprinting.
- The app includes an activation check before showing the login screen.
- A backup process is triggered when the app closes.
- Old invoices can be archived automatically to keep the main sales tables lighter and faster.

## Project Goal

The goal of **Motamayez** is to provide a practical store management system that helps with:

- Faster sales operations
- Better stock control
- Customer and supplier balance tracking
- Better financial organization
- Reduced manual work and daily errors

## Status

The project is under active development and is being expanded to support real store workflows with a focus on usability, speed, and stable local operation.
