import 'dart:convert'; // Para convertir la foto a texto
import 'dart:io';      // Para manejar el archivo de la foto
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // Librería de cámara/galería
import '../services/auth_service.dart';

class NuevoAnuncioScreen extends StatefulWidget {
  const NuevoAnuncioScreen({super.key});

  @override
  State<NuevoAnuncioScreen> createState() => _NuevoAnuncioScreenState();
}

class _NuevoAnuncioScreenState extends State<NuevoAnuncioScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores de texto
  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  final _precioController = TextEditingController();
  
  bool _isLoading = false;
  String _categoria = "Tutoría";
  
  // --- VARIABLES PARA LA FOTO (NO LAS QUITAMOS) ---
  File? _imagenSeleccionada;
  String? _imagenBase64; 

  final Map<String, int> _categorias = {
    "Tutoría": 0xf0925,
    "Tecnología": 0xe324,
    "Libros": 0xe398,
    "Comida": 0xe532,
    "Varios": 0xe88f,
  };

  // --- FUNCIÓN PARA SELECCIONAR FOTO ---
  Future<void> _seleccionarFoto() async {
    final picker = ImagePicker();
    // Calidad 40 para que no sea muy pesada y entre rápido a la BD
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

    if (pickedFile != null) {
      setState(() {
        _imagenSeleccionada = File(pickedFile.path);
      });
      
      // Convertimos la imagen a texto para guardarla
      List<int> imageBytes = await _imagenSeleccionada!.readAsBytes();
      _imagenBase64 = base64Encode(imageBytes);
    }
  }

  // --- FUNCIÓN PARA GUARDAR TODO ---
  void _publicarAnuncio() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Verificar que hay un usuario autenticado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: No se puede identificar el usuario. Por favor, inicia sesión nuevamente."),
            backgroundColor: Colors.red,
          )
        );
        return;
      }

      // 2. Obtenemos datos del usuario (Nombre, Teléfono, EMAIL)
      final userData = await AuthService().obtenerDatosUsuario();
      
      if (userData == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: No se pudo obtener los datos del usuario. Por favor, verifica tu perfil."),
            backgroundColor: Colors.red,
          )
        );
        return;
      }

      // 2. Guardamos en Firebase (FUSIÓN DE TODO)
      await FirebaseFirestore.instance.collection('anuncios').add({
        'titulo': _tituloController.text.trim(),
        'descripcion': _descController.text.trim(),
        'precio': "${_precioController.text.trim()} Bs",
        'categoria': _categoria,
        'iconoCode': _categorias[_categoria],
        
        // Datos del Vendedor
        'autor': userData['nombre'] ?? 'Estudiante UPDS',
        'telefono': userData['telefono'] ?? '',
        'email': userData['email'] ?? currentUser.email ?? 'Correo oculto', // <--- AQUÍ ESTÁ EL EMAIL NUEVO
        'userId': currentUser.uid,
        
        'fecha': Timestamp.now(),
        
        // Foto del Producto
        'imagenBase64': _imagenBase64 ?? "", // <--- AQUÍ ESTÁ LA FOTO (NO SE QUITÓ)
      });

      if (!mounted) return;
      
      // 3. Éxito
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Anuncio publicado con éxito!")));
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Anuncio"), 
        backgroundColor: Colors.blue[900], 
        foregroundColor: Colors.white
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- ZONA DE LA FOTO (VISUAL) ---
              GestureDetector(
                onTap: _seleccionarFoto,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _imagenSeleccionada != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imagenSeleccionada!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                            Text("Toca para agregar foto (Opcional)", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // --- CAMPOS DE TEXTO ---
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: "Título", border: OutlineInputBorder(), prefixIcon: Icon(Icons.label)),
                validator: (val) => val!.isEmpty ? "Falta título" : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                items: _categorias.keys.map((String key) {
                  return DropdownMenuItem(value: key, child: Text(key));
                }).toList(),
                onChanged: (val) => setState(() => _categoria = val!),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _precioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Precio (Bs)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                validator: (val) => val!.isEmpty ? "Falta precio" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Descripción", border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                validator: (val) => val!.isEmpty ? "Falta descripción" : null,
              ),
              const SizedBox(height: 30),

              // --- BOTÓN PUBLICAR ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _publicarAnuncio,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("PUBLICAR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}