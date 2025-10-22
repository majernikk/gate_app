// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthService();
  await auth.init(); // 👈 dôležité: načítať pred runApp

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Vytvárame router pri každom builde, aby bral aktuálny stav.
    final router = GoRouter(
      // 👇 priamo zvolíme úvodnú obrazovku podľa loginu
      initialLocation: auth.isLoggedIn ? '/' : '/login',
      refreshListenable: auth, // pri login/logout sa router sám refreshne
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/',      builder: (_, __) => const HomeScreen()),
      ],
      redirect: (_, state) {
        final loggedIn = auth.isLoggedIn;
        final onLogin  = state.fullPath == '/login';

        if (!loggedIn && !onLogin) return '/login'; // zamkneme všetko okrem loginu
        if (loggedIn && onLogin)  return '/';       // prihlásený nemá vidieť login
        return null;
      },
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gate Control',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
