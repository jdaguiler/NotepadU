import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true; // Variable para alternar entre Login y Registro

  // Controladores de texto
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  
  // Extra para registro
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _codigoController = TextEditingController(); // Código de estudiante

  @override
  void initState() {
    super.initState();
    // Limpiar campos cuando se inicializa el LoginScreen (útil después de logout)
    _emailController.clear();
    _passController.clear();
    _nombreController.clear();
    _telefonoController.clear();
    _codigoController.clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _isLoading = true);
    String? error;

    if (_isLogin) {
      // --- LOGIN ---
      error = await _authService.login(
        _emailController.text.trim(),
        _passController.text.trim(),
      );
      
      // Si no hubo error en Login, el StreamBuilder en main.dart manejará la navegación automáticamente
      // Firebase Auth actualiza el estado y el StreamBuilder detectará el cambio
      if (error == null) {
        // IMPORTANTE: Verificar que realmente hay un usuario autenticado
        // Esto asegura que el login fue exitoso antes de resetear el estado
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && mounted) {
          // Limpiar campos después de login exitoso
          _emailController.clear();
          _passController.clear();
          // Reseteamos el estado de carga
          setState(() => _isLoading = false);
          // El StreamBuilder en main.dart detectará el cambio automáticamente
          // y mostrará el HomeScreen. No necesitamos navegación manual aquí.
        } else if (mounted) {
          // Si por alguna razón no hay usuario, mostrar error
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error: No se pudo completar el inicio de sesión"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Salir temprano para evitar resetear _isLoading de nuevo
      }

    } else {
      // --- REGISTRO ---
      error = await _authService.registrarse(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
        codigoEstudiante: _codigoController.text.trim(),
      );

      // Si el registro fue exitoso (error == null), mostramos DIÁLOGO DE VERIFICACIÓN
      if (error == null) {
        setState(() => _isLoading = false); // Dejamos de cargar
        
        showDialog(
          context: context,
          barrierDismissible: false, // Obliga a leer
          builder: (ctx) => AlertDialog(
            title: const Text("¡Casi listo!"),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread, size: 50, color: Colors.amber),
                SizedBox(height: 15),
                Text("Te hemos enviado un enlace de confirmación a tu correo institucional.\n\nPor favor, revísalo y haz clic en el enlace para activar tu cuenta."),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Cierra diálogo
                  setState(() => _isLogin = true); // Cambia a modo Login
                },
                child: const Text("Entendido, ir al Login"),
              )
            ],
          ),
        );
        return; // Cortamos aquí para que no intente navegar al Home
      }
    }

    setState(() => _isLoading = false);

    // Manejo de errores (Si falló login o registro)
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: SingleChildScrollView( // Para que no tape el teclado
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                _isLogin ? "BIENVENIDO UPDS" : "CREAR CUENTA",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // --- FORMULARIO ---
              
              if (!_isLogin) ...[
                // Campos solo para Registro
                _buildTextField(_nombreController, "Nombre Completo", Icons.person),
                const SizedBox(height: 15),
                _buildTextField(_telefonoController, "Celular (Para ventas)", Icons.phone),
                const SizedBox(height: 15),
                _buildTextField(_codigoController, "Código Estudiante", Icons.badge),
                const SizedBox(height: 15),
              ],

              _buildTextField(_emailController, "Correo Institucional", Icons.email),
              const SizedBox(height: 15),
              _buildTextField(_passController, "Contraseña", Icons.lock, isObscure: true),
              
              const SizedBox(height: 30),

              // BOTÓN DE ACCIÓN
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          _isLogin ? "INGRESAR" : "REGISTRARME",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              // CAMBIAR MODO (LOGIN <-> REGISTRO)
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? "¿No tienes cuenta? Regístrate aquí" : "¿Ya tienes cuenta? Ingresa aquí",
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue[900]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}