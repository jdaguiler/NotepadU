import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; 

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _cerrarSesion(BuildContext context) async {
    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro de que deseas cerrar sesión?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      // Cerrar sesión en Firebase Auth
      // IMPORTANTE: NO usar Navigator aquí. El StreamBuilder en main.dart
      // detectará automáticamente el cambio de estado (signOut) y mostrará
      // el LoginScreen automáticamente. Esto evita problemas de navegación
      // y asegura que el estado se maneje correctamente.
      await FirebaseAuth.instance.signOut();
      
      // El StreamBuilder en main.dart se encargará de navegar al LoginScreen
      // automáticamente cuando detecte que no hay usuario autenticado.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // Quitamos el AppBar si ya tienes uno en el 'home' principal,
      // o lo dejamos si esta pantalla se abre sola.
      // appBar: AppBar(title: const Text("Mi Perfil")), 
      
      // --- CORRECCIÓN PRINCIPAL: SingleChildScrollView ---
      body: SingleChildScrollView(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Damos una altura mínima mientras carga para que no se vea vacío
              return const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Variables por defecto
            String nombre = "Estudiante";
            String email = user?.email ?? "No disponible";
            String telefono = "No registrado";
            String codigo = "No registrado";
            bool verificado = false;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              nombre = data['nombre'] ?? nombre;
              email = data['email'] ?? email;
              telefono = data['telefono'] ?? telefono;
              codigo = data['codigo'] ?? codigo;
              verificado = data['esVerificado'] ?? false;
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Espacio superior para que no quede pegado al techo (safe area)
                  SafeArea(child: const SizedBox(height: 20)),
                  
                  // --- AVATAR ---
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 60, // Un poco más grande
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.person, size: 70, color: Colors.white),
                      ),
                      if (verificado)
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.check_circle, color: Colors.green, size: 30),
                        )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- NOMBRE ---
                  Text(
                    nombre,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // --- TARJETA DE DATOS ---
                  Card(
                    elevation: 2, // Un poco menos de sombra para que sea más limpio
                    color: Colors.grey[50], // Un fondo gris muy clarito
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email_outlined, color: Colors.blue),
                            title: const Text("Correo Institucional", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            subtitle: Text(email, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                            dense: true,
                          ),
                          const Divider(indent: 20, endIndent: 20),
                          ListTile(
                            leading: const Icon(Icons.phone_android_outlined, color: Colors.green),
                            title: const Text("Teléfono", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            subtitle: Text(telefono, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                            dense: true,
                          ),
                          const Divider(indent: 20, endIndent: 20),
                          ListTile(
                            leading: const Icon(Icons.badge_outlined, color: Colors.orange),
                            title: const Text("Código Estudiante", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            subtitle: Text(codigo, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- ESPACIO FINAL ANTES DEL BOTÓN ---
                  // Usamos SizedBox en lugar de Spacer porque estamos en un ScrollView
                  const SizedBox(height: 40),

                  // --- BOTÓN CERRAR SESIÓN ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cerrarSesion(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text("Cerrar Sesión"),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- FOOTER ---
                  Column(
                    children: [
                       Text(
                        "NotepadU",
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Versión 1.0.0",
                         style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Desarrollado por Devops SRL",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      // Espacio extra abajo para que no quede pegado al borde inferior del celular
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}