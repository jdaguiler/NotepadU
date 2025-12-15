import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

import 'tasks_screen.dart';
import 'agenda_screen.dart';
import 'nuevo_anuncio_screen.dart';
import 'admin_screen.dart'; 
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> horario;
  const HomeScreen({super.key, required this.horario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _soyAdmin = false; 

  @override
  void initState() {
    super.initState();
    _verificarSiSoyAdmin(); 
  }

  void _verificarSiSoyAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['rol'] == 'admin') {
          if (mounted) setState(() => _soyAdmin = true);
        }
      } catch (e) {
        print("Error verificando admin: $e");
      }
    }
  }

  // --- FUNCIONES ---

  // 1. CORRECCIÓN WHATSAPP: Más robusta y fuerza abrir la app externa
  void _contactarPorWhatsApp(String telefono, String producto) async {
    ScaffoldMessenger.of(context).clearSnackBars(); // Limpiar mensajes viejos

    String numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Si es Bolivia (8 dígitos), agregar 591
    if (numeroLimpio.length == 8) {
      numeroLimpio = '591$numeroLimpio';
    }

    final mensaje = Uri.encodeComponent("Hola, vi tu anuncio '$producto' en la App UPDS y estoy interesado.");
    final url = Uri.parse("https://wa.me/$numeroLimpio?text=$mensaje");

    try {
      // Usamos mode: LaunchMode.externalApplication para obligar a Android a buscar WhatsApp
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
         throw 'No se pudo lanzar';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo abrir WhatsApp. Verifica que la app esté instalada."),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  void _reportarAnuncio(String docId, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reportar Publicación"),
        content: const Text("¿Este contenido es inapropiado?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance.collection('reportes').add({
                'anuncioId': docId,
                'tituloAnuncio': titulo,
                'fecha': Timestamp.now(),
                'motivo': 'Reporte de usuario',
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reporte enviado.")));
            },
            child: const Text("Reportar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _borrarMiAnuncio(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Anuncio"),
        content: const Text("¿Estás seguro? Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('anuncios').doc(docId).delete();
              
              if (mounted) {
                Navigator.pop(ctx); 
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    Navigator.pop(context); 
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Anuncio eliminado."))
                    );
                  }
                });
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- AQUÍ ESTÁ EL CAMBIO VISUAL IMPORTANTE (SAFE AREA) ---
  void _verDetalleAnuncio(Map<String, dynamic> data, String docId) {
    String imagenBase64 = data['imagenBase64'] ?? "";
    
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool esMio = currentUser != null && data['userId'] == currentUser.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Esto permite que ocupe más pantalla
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          height: MediaQuery.of(context).size.height * 0.85, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, color: Colors.grey[300])),
              const SizedBox(height: 20),

              // FOTO O ICONO
              if (imagenBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(imagenBase64), 
                    height: 200, 
                    width: double.infinity, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                  ),
                )
              else
                Center(child: Icon(IconData(data['iconoCode'] ?? 0xe88f, fontFamily: 'MaterialIcons'), size: 80, color: Colors.blue[100])),
              
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(data['titulo'] ?? 'Sin título', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  Text(data['precio'] ?? '', style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(children: [
                      const Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text("Vendedor: ${data['autor'] ?? 'Estudiante'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.email, color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Text(data['email'] ?? "Correo no visible", style: TextStyle(color: Colors.grey[700])),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Detalles:", style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(data['descripcion'] ?? '', style: const TextStyle(fontSize: 16)),
                ),
              ),
              
              const SizedBox(height: 10),

              // --- 2. ZONA SEGURA PARA BOTONES (CORRECCIÓN) ---
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10), // Un poco de aire extra abajo
                  child: Row(
                    children: [
                      // Botón Reportar
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _reportarAnuncio(docId, data['titulo']);
                        },
                        icon: const Icon(Icons.flag, color: Colors.red),
                        tooltip: "Reportar",
                      ),

                      // Botón Eliminar (Solo dueño)
                      if (esMio) 
                        IconButton(
                          onPressed: () => _borrarMiAnuncio(docId),
                          icon: const Icon(Icons.delete, color: Colors.black54),
                          tooltip: "Eliminar mi anuncio",
                        ),

                      const SizedBox(width: 10),
                      
                      // Botón WhatsApp
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                              String telefono = data['telefono'] ?? '';
                              if (telefono.isNotEmpty) _contactarPorWhatsApp(telefono, data['titulo']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: const EdgeInsets.symmetric(vertical: 12), // Botón más alto
                          ),
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text("WhatsApp", style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildMercadoTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('anuncios').orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.store_mall_directory, size: 50, color: Colors.grey), Text("El mercado está vacío.")]));
        }

        final documentos = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documentos.length,
          itemBuilder: (context, index) {
            final data = documentos[index].data() as Map<String, dynamic>;
            final docId = documentos[index].id;
            int iconCode = data['iconoCode'] ?? 0xe88f; 

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _verDetalleAnuncio(data, docId),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), color: Colors.blue[900]),
                ),
                title: Text(data['titulo'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Por: ${data['autor'] ?? 'Anónimo'}"), 
                trailing: Text(data['precio'] ?? '0 Bs', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _selectedIndex == 0 ? "Calendario" : 
            _selectedIndex == 1 ? "Mis Notas" : 
            _selectedIndex == 2 ? "Mercado" : "Mi Perfil"
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          if (_soyAdmin) 
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: "Moderación",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
            )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const AgendaScreen(),
          const TasksScreen(),
          _buildMercadoTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: "Agenda"),
          NavigationDestination(icon: Icon(Icons.note_alt), label: "Notas"),
          NavigationDestination(icon: Icon(Icons.store), label: "Mercado"),
          NavigationDestination(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
      floatingActionButton: _selectedIndex == 2 
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NuevoAnuncioScreen())),
            backgroundColor: Colors.amber,
            icon: const Icon(Icons.add_business, color: Colors.black),
            label: const Text("Vender", style: TextStyle(color: Colors.black)),
          )
        : null,
    );
  }
}