import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  
  // --- FUNCIÓN PARA CREAR O EDITAR NOTA ---
  // Si pasamos docId, es edición. Si es null, es nueva nota.
  void _mostrarDialogoNota({String? docId, String? tituloActual, String? descActual}) {
    final tituloController = TextEditingController(text: tituloActual ?? '');
    final descController = TextEditingController(text: descActual ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? "Nueva Nota" : "Editar Nota"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloController,
              decoration: const InputDecoration(
                labelText: "Título",
                hintText: "Ej: Examen de Física",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: "Detalles",
                hintText: "Estudiar temas 1, 2 y 3...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          // Botón borrar (Solo si estamos editando)
          if (docId != null)
            TextButton.icon(
              onPressed: () {
                _borrarNota(docId);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text("Borrar", style: TextStyle(color: Colors.red)),
            ),
            
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
            onPressed: () async {
              if (tituloController.text.isNotEmpty) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  try {
                    if (docId == null) {
                      // --- CREAR NUEVA ---
                      await FirebaseFirestore.instance.collection('notas').add({
                        'titulo': tituloController.text.trim(),
                        'descripcion': descController.text.trim(),
                        'fecha': Timestamp.now(),
                        'completada': false,
                        'userId': uid,
                      });
                    } else {
                      // --- ACTUALIZAR EXISTENTE ---
                      await FirebaseFirestore.instance.collection('notas').doc(docId).update({
                        'titulo': tituloController.text.trim(),
                        'descripcion': descController.text.trim(),
                        // No actualizamos la fecha para no perder el orden, o usa Timestamp.now() si quieres que suba arriba
                      });
                    }
                    // El StreamBuilder se actualizará automáticamente
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    // Mostrar error si falla
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error al guardar: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Error: Usuario no autenticado"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(docId == null ? "Guardar" : "Actualizar"),
          )
        ],
      ),
    );
  }

  void _borrarNota(String docId) {
    FirebaseFirestore.instance.collection('notas').doc(docId).delete();
  }

  void _toggleCompletada(String docId, bool estadoActual) {
    FirebaseFirestore.instance.collection('notas').doc(docId).update({
      'completada': !estadoActual,
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Inicia sesión para ver tus notas."));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoNota(), // Llama sin argumentos para crear
        backgroundColor: Colors.blue[900],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nueva Nota", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notas')
            .where('userId', isEqualTo: uid)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.hasError) return const Center(child: Text("Error cargando notas."));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 70, color: Colors.blue[100]),
                  const SizedBox(height: 20),
                  const Text("No tienes notas.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              bool completada = data['completada'] ?? false;
              String titulo = data['titulo'] ?? data['contenido'] ?? "Sin título";
              String descripcion = data['descripcion'] ?? "";

              return Dismissible(
                key: Key(doc.id),
                background: Container(color: Colors.red[400], alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (direction) => _borrarNota(doc.id),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: completada ? Colors.grey[100] : Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell( // <--- PERMITE TOCAR LA TARJETA
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      // Al tocar, abrimos el diálogo con los datos actuales para EDITAR
                      _mostrarDialogoNota(
                        docId: doc.id,
                        tituloActual: titulo,
                        descActual: descripcion
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: Checkbox(
                          value: completada,
                          onChanged: (val) => _toggleCompletada(doc.id, completada),
                          activeColor: Colors.blue[900],
                          shape: const CircleBorder(),
                        ),
                        title: Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: completada ? TextDecoration.lineThrough : null,
                            color: completada ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: descripcion.isNotEmpty ? Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                        trailing: const Icon(Icons.edit, size: 16, color: Colors.grey), // Icono lápiz sutil
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}