import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importante para verificar sesión
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'data/mock_data.dart'; // Para pasar el horario por defecto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('es_ES', null); // Para calendario en español
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agenda UPDS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // GESTIÓN DE SESIÓN PERSISTENTE:
      // StreamBuilder escucha si el usuario entra o sale.
      // Firebase Auth persiste automáticamente la sesión, así que cuando el usuario
      // cierre y vuelva a abrir la app, el StreamBuilder detectará el usuario guardado.
      // IMPORTANTE: No usar Navigator en logout/login, dejar que este StreamBuilder
      // maneje toda la navegación automáticamente.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Mientras verifica el estado de autenticación inicial, mostrar un indicador de carga
          // Solo mostrar loading en el estado inicial, no en cambios subsecuentes
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // 1. Si hay usuario autenticado (sesión persistente), vamos directo al HOME
          final user = snapshot.data;
          if (user != null) {
            return HomeScreen(horario: horarioIngenieria);
          }
          
          // 2. Si no hay usuario, vamos al LOGIN
          return const LoginScreen();
        },
      ),
    );
  }
}