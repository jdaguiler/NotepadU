import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  void _eliminarPublicacion(BuildContext context, String reporteId, String anuncioId) async {
    try {
      await FirebaseFirestore.instance.collection('anuncios').doc(anuncioId).delete();
      await FirebaseFirestore.instance.collection('reportes').doc(reporteId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eliminado correctamente")));
        // Si estamos en el diálogo, lo cerramos
        if (Navigator.canPop(context)) Navigator.pop(context); 
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _ignorarReporte(BuildContext context, String reporteId) async {
    await FirebaseFirestore.instance.collection('reportes').doc(reporteId).delete();
    // No cerramos el diálogo aquí para que el admin vea que desapareció, o podemos cerrarlo si preferimos
  }

  void _verDetalleReporte(BuildContext context, Map<String, dynamic> reporteData, String reporteId) async {
    final anuncioId = reporteData['anuncioId'];
    final anuncioSnap = await FirebaseFirestore.instance.collection('anuncios').doc(anuncioId).get();

    if (!context.mounted) return;

    if (!anuncioSnap.exists) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text("El anuncio ya no existe"),
        content: const Text("Parece que el usuario ya lo borró."),
        actions: [
          TextButton(onPressed: () => _ignorarReporte(context, reporteId), child: const Text("Borrar reporte"))
        ],
      ));
      return;
    }

    final anuncio = anuncioSnap.data() as Map<String, dynamic>;
    final imagenBase64 = anuncio['imagenBase64'] ?? "";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revisión"),
        content: SingleChildScrollView( // <--- ESTO EVITA EL OVERFLOW VERTICAL
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imagenBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(base64Decode(imagenBase64), height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 10),
              Text("Reporte: ${reporteData['motivo']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const Divider(),
              Text("Título: ${anuncio['titulo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Desc: ${anuncio['descripcion']}"),
              Text("Precio: ${anuncio['precio']}"),
              Text("Autor: ${anuncio['autor']}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _ignorarReporte(context, reporteId);
              Navigator.pop(ctx);
            },
            child: const Text("Ignorar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _eliminarPublicacion(context, reporteId, anuncioId),
            child: const Text("BORRAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Panel de Moderador"), backgroundColor: Colors.red[900], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reportes').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Sin reportes pendientes"));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final reporte = snapshot.data!.docs[index];
              final data = reporte.data() as Map<String, dynamic>;
              
              return Card(
                color: Colors.red[50],
                child: InkWell( // Hacemos toda la tarjeta clickeable para ver detalle
                  onTap: () => _verDetalleReporte(context, data, reporte.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(data['tituloAnuncio'] ?? 'Anuncio', style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // BOTONES DE ACCIÓN RÁPIDA (CON CORRECCIÓN DE PIXELES)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _ignorarReporte(context, reporte.id),
                              child: const Text("Ignorar", style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 5),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10)),
                              onPressed: () => _eliminarPublicacion(context, reporte.id, data['anuncioId']),
                              child: const Text("BORRAR", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        )
                      ],
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