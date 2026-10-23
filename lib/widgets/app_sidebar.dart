import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/ai_assistant_screen.dart';
import '../screens/create_project_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/auth_screen.dart';

class AppSidebar extends StatelessWidget {
  final String userEmail;
  final int currentIndex;

  const AppSidebar({
    Key? key,
    required this.userEmail,
    required this.currentIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String userName = userEmail.split('@')[0];
    if (userName.isNotEmpty) {
      userName = userName[0].toUpperCase() + userName.substring(1);
    }

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF161E2E),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        children: [
          // User Info Header
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6),
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF1E293B),
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Navigation Links
          _buildNavItem(
            context,
            0,
            'Dashboard / Home',
            Icons.home_outlined,
            Icons.home,
            DashboardScreen(userEmail: userEmail),
          ),
          _buildNavItem(
            context,
            1,
            'My Projects',
            Icons.folder_outlined,
            Icons.folder,
            ProjectsScreen(userEmail: userEmail),
          ),
          _buildNavItem(
            context,
            2,
            'AI Assistant',
            Icons.auto_awesome_outlined,
            Icons.auto_awesome,
            AiAssistantScreen(userEmail: userEmail),
          ),
          _buildNavItem(
            context,
            3,
            'Create Project',
            Icons.add_circle_outline,
            Icons.add_circle,
            CreateProjectScreen(userEmail: userEmail),
          ),

          const Spacer(),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),

          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: Colors.white70,
              size: 20,
            ),
            title: const Text(
              'Profile Settings',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userEmail: userEmail),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.redAccent,
              size: 20,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    String title,
    IconData icon,
    IconData activeIcon,
    Widget targetScreen,
  ) {
    bool isSelected = currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: isSelected
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.25),
                  const Color(0xFF1D4ED8).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.5),
                width: 1,
              ),
            )
          : null,
      child: ListTile(
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: isSelected
            ? null
            : () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => targetScreen),
                );
              },
      ),
    );
  }
}
