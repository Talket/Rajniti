import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/dashboard_view.dart';
import '../screens/admin/menu_management.dart';
import '../screens/admin/table_management.dart';
import '../screens/admin/reports/item_report_screen.dart';
import '../screens/captain/table_grid_screen.dart';
import '../screens/captain/order_entry_screen.dart';
import '../screens/admin/running_tables_view.dart';
import '../screens/admin/comments_master_screen.dart';
import '../screens/admin/admin_order_entry_screen.dart';
import '../screens/admin/reports/sales_report_screen.dart';
import '../screens/admin/reports/order_summary_screen.dart';

final _supabase = Supabase.instance.client;

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final session = _supabase.auth.currentSession;
    final loggedIn = session != null;
    final isLoggingIn = state.uri.toString() == '/login';

    if (!loggedIn && !isLoggingIn) return '/login';

    if (loggedIn && isLoggingIn) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();

        final role = profile['role'];
        if (role == 'admin') return '/admin';
        if (role == 'captain') return '/captain';
      } catch (e) {
        await _supabase.auth.signOut();
        return '/login';
      }
    }
    
    if (loggedIn && !isLoggingIn) {
       final currentPath = state.uri.toString();
       if (currentPath.startsWith('/admin') || currentPath.startsWith('/captain')) {
         return null; 
       }
    }

    return null; 
  },
  
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ==========================================
    // ADMIN SANDBOX
    // ==========================================
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const DashboardView(), 
        ),
        GoRoute(
          path: '/admin/menu',
          builder: (context, state) => const MenuManagementView(), 
        ),
        GoRoute(
          path: '/admin/tables',
          builder: (context, state) => const TableManagementView(), 
        ),
        GoRoute(
          path: '/admin/comments',
          builder: (context, state) => const CommentsMasterScreen(),
        ),
        GoRoute(
          path: '/admin/running',
          builder: (context, state) => const RunningTablesView(),
        ),
        GoRoute(
          path: '/admin/running/order/:tableId',
          builder: (context, state) {
            final tableId = int.tryParse(state.pathParameters['tableId'] ?? '0') ?? 0;
            final appendStr = state.uri.queryParameters['append'];
            final isAppendMode = appendStr == null || appendStr == 'true';
            
            // CRITICAL FIX: Read orderId dynamically instead of forcing it to be an int
            final orderIdStr = state.uri.queryParameters['orderId'];
            dynamic orderId;
            if (orderIdStr != null) {
              orderId = int.tryParse(orderIdStr) ?? orderIdStr;
            }

            return AdminOrderEntryScreen(
              tableId: tableId, 
              isAppendMode: isAppendMode,
              orderId: orderId, // Safely passes the UUID
            );
          },
        ),
        GoRoute(
          path: '/admin/reports/item-summary',
          builder: (context, state) => const ItemReportScreen(),
        ),
        // ADD THIS NEW ROUTE
        GoRoute(
          path: '/admin/reports/sales-summary',
          builder: (context, state) => const SalesReportScreen(),
        ),
        GoRoute(
          path: '/admin/reports/order-summary',
          builder: (context, state) => const OrderSummaryScreen(),
        ),
      ],
    ),

    // ==========================================
    // CAPTAIN SANDBOX
    // ==========================================
    GoRoute(
      path: '/captain',
      builder: (context, state) => const TableGridScreen(), 
    ),
    GoRoute(
      path: '/captain/order/:tableId',
      builder: (context, state) {
        final tableIdStr = state.pathParameters['tableId'];
        final tableId = int.tryParse(tableIdStr ?? '0') ?? 0;
        return OrderEntryScreen(tableId: tableId);
      },
    ),
    GoRoute(
      path: '/captain/active/:tableId',
      builder: (context, state) {
        final tableIdStr = state.pathParameters['tableId'];
        final tableId = int.tryParse(tableIdStr ?? '0') ?? 0;
        return OrderEntryScreen(tableId: tableId); 
      },
    ),
  ],
);