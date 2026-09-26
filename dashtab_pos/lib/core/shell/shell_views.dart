import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_widgets.dart';
import 'views/audit_view.dart';
import 'views/customers_view.dart';
import 'views/dashboard_view.dart';
import 'views/inventory_view.dart';
import 'views/kitchen_view.dart';
import 'views/menu_view.dart';
import 'views/orders_view.dart';
import 'views/pos_view.dart';
import 'views/reports_view.dart';
import 'views/settings_view.dart';
import 'views/shift_view.dart';
import 'views/staff_view.dart';
import 'views/suppliers_view.dart';
import 'views/tables_view.dart';

/// Top-level view registry hosted inside [HomeShell].
class ShellViews {
  static Widget build(BuildContext context, String key) {
    switch (key) {
      case 'dashboard':
        return const DashboardView();
      case 'pos':
        // NOT const: the POS must rebuild when the shell does (cart-drawer
        // flag, live store changes) — a const instance is canonicalized and
        // its element skips the rebuild entirely, which froze the mobile
        // cart drawer shut.
        return PosView();
      case 'orders':
        return const OrdersView();
      case 'tables':
        return const TablesView();
      case 'kitchen':
        return const KitchenView();
      case 'menu':
        return const MenuView();
      case 'inventory':
        return const InventoryView();
      case 'suppliers':
        return const SuppliersView();
      case 'customers':
        return const CustomersView();
      case 'staff':
        return const StaffView();
      case 'shift':
        return const ShiftView();
      case 'audit':
        return const AuditView();
      case 'reports':
        return const ReportsView();
      case 'settings':
        return const SettingsView();
      default:
        // Every registered view is handled above; a bad key means a
        // navigation bug, so fail loudly rather than showing a stub.
        return const EmptyState(
          icon: AppIcons.info,
          title: 'View not found',
          message: 'This screen does not exist. Please restart the app.',
        );
    }
  }
}
