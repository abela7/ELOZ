import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/tasks/presentation/screens/tasks_screen.dart';
import '../features/tasks/presentation/screens/add_task_screen.dart';
import '../features/tasks/presentation/screens/edit_task_screen.dart';
import '../data/models/task.dart';
import '../features/habits/presentation/screens/habits_screen.dart';
import '../features/finance/presentation/screens/finances_screen.dart';
import '../features/mbt/presentation/screens/mood_screen.dart';
import '../features/sleep/presentation/screens/sleep_screen.dart';
import '../features/stats/presentation/screens/stats_screen.dart';
import '../features/more/presentation/screens/more_screen.dart';

/// Root scaffold with bottom navigation
class RootScaffold extends StatefulWidget {
  final Widget child;
  final String currentLocation;

  const RootScaffold({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _getCurrentIndex(String location) {
    if (location.startsWith('/home') || location == '/') return 0;
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/habits')) return 2;
    if (location.startsWith('/finance')) return 3;
    if (location.startsWith('/mood')) return 6;
    if (location.startsWith('/sleep')) return 4;
    if (location.startsWith('/stats')) return 5;
    if (location.startsWith('/more')) return 6;
    return 0;
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/tasks');
        break;
      case 2:
        context.go('/habits');
        break;
      case 3:
        context.go('/finance');
        break;
      case 4:
        context.go('/sleep');
        break;
      case 5:
        context.go('/stats');
        break;
      case 6:
        context.go('/more');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(widget.currentLocation);
    final isOnHomeTab = currentIndex == 0;

    return PopScope(
      canPop: isOnHomeTab,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isOnHomeTab) return;
        context.go('/home');
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_rounded),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_rounded),
              label: 'Habits',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Finance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bedtime_rounded),
              label: 'Sleep',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Stats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

/// Global navigator key for notifications
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// App Router Configuration
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return RootScaffold(
          currentLocation: state.uri.toString(),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/tasks',
          name: 'tasks',
          builder: (context, state) => const TasksScreen(),
          routes: [
            GoRoute(
              path: 'add',
              name: 'add-task',
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) => const AddTaskScreen(),
            ),
            GoRoute(
              path: 'edit',
              name: 'edit-task',
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) {
                final task = state.extra as Task;
                return EditTaskScreen(task: task);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/habits',
          name: 'habits',
          builder: (context, state) => const HabitsScreen(),
        ),
        GoRoute(
          path: '/finance',
          name: 'finance',
          builder: (context, state) => const FinancesScreen(),
        ),
        GoRoute(
          path: '/mood',
          name: 'mood',
          builder: (context, state) => const MoodScreen(),
        ),
        GoRoute(
          path: '/sleep',
          name: 'sleep',
          builder: (context, state) => const SleepScreen(),
        ),
        GoRoute(
          path: '/stats',
          name: 'stats',
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: '/more',
          name: 'more',
          builder: (context, state) => const MoreScreen(),
        ),
      ],
    ),
  ],
);
