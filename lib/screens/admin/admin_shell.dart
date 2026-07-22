import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  // CHANGED: Set to false so the sidebar is closed by default on load
  bool _isSidebarOpen = false; 

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon!')),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.toString();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isSidebarOpen ? 250 : 0,
            child: ClipRect( 
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 250,
                maxWidth: 250, 
                child: Container(
                  color: const Color(0xFF1b1d3a), 
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Text(
                        'Rajniti Dosa',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 40),
                      
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _SidebarItem(
                              icon: Icons.dashboard,
                              title: 'Dashboard',
                              isActive: currentPath == '/admin',
                              onTap: () => context.go('/admin'),
                            ),
                            _SidebarItem(
                              icon: Icons.build,
                              title: 'Operations',
                              isActive: false,
                              onTap: () => _showComingSoon('Operations'),
                            ),
                            
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: const Icon(Icons.bar_chart, color: Colors.white70),
                                title: const Text('Reports', style: TextStyle(color: Colors.white70)),
                                iconColor: Colors.white70,
                                collapsedIconColor: Colors.white70,
                                initiallyExpanded: currentPath.contains('/admin/reports'), 
                                children: [
                                  _SidebarSubItem(
                                    title: 'Item Summary', 
                                    isActive: currentPath == '/admin/reports/item-summary',
                                    onTap: () => context.go('/admin/reports/item-summary')
                                  ),
                                  _SidebarSubItem(
                                    title: 'Sales Summary', 
                                    isActive: currentPath == '/admin/reports/sales-summary',
                                    onTap: () => context.go('/admin/reports/sales-summary')
                                  ),
                                  _SidebarSubItem(
                                    title: 'Order Summary', 
                                    isActive: currentPath == '/admin/reports/order-summary',
                                    onTap: () => context.go('/admin/reports/order-summary')
                                  ),
                                ],
                              ),
                            ),
                            
                            _SidebarItem(
                              icon: Icons.sensors,
                              title: 'Live View',
                              isActive: currentPath == '/admin/running' || currentPath.startsWith('/admin/running/order'),
                              onTap: () => context.go('/admin/running'),
                            ),

                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: const Icon(Icons.settings, color: Colors.white70),
                                title: const Text('Settings', style: TextStyle(color: Colors.white70)),
                                iconColor: Colors.white70,
                                collapsedIconColor: Colors.white70,
                                initiallyExpanded: currentPath == '/admin/menu' || currentPath == '/admin/tables' || currentPath == '/admin/comments',
                                children: [
                                  _SidebarSubItem(
                                    title: 'Menu Master', 
                                    isActive: currentPath == '/admin/menu',
                                    onTap: () => context.go('/admin/menu')
                                  ),
                                  _SidebarSubItem(
                                    title: 'Table Master', 
                                    isActive: currentPath == '/admin/tables',
                                    onTap: () => context.go('/admin/tables')
                                  ),
                                  // ADD THIS NEW SUB ITEM
                                  _SidebarSubItem(
                                    title: 'Comments Master', 
                                    isActive: currentPath == '/admin/comments',
                                    onTap: () => context.go('/admin/comments')
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(color: Colors.white24),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        onTap: () async {
                          await AuthService().logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Column(
              children: [
                // TOP BAR (Contains Hamburger and New Order Button)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // HAMBURGER MENU BUTTON
                      IconButton(
                        icon: const Icon(Icons.menu, size: 28),
                        color: const Color(0xFF1b1d3a),
                        onPressed: _toggleSidebar,
                        tooltip: 'Toggle Sidebar',
                      ),
                      const SizedBox(width: 16),
                      
                      // THE NEW ORDER BUTTON
                      ElevatedButton(
                        onPressed: () => context.go('/admin/running'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F), // Red color
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text('New Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
                
                // ACTUAL PAGE CONTENT
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.white70),
        title: Text(
          title, 
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal
          )
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SidebarSubItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarSubItem({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 56, right: 16),
        title: Text(
          title, 
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal
          )
        ),
        onTap: onTap,
      ),
    );
  }
}