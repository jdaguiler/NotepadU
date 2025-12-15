import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Instancias de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Getter para ver si hay alguien logueado actualmente
  User? get usuarioActual => _auth.currentUser;

  // ---------------------------------------------------
  // 1. INICIAR SESIÓN (LOGIN)
  // ---------------------------------------------------
  Future<String?> login(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      // VERIFICACIÓN DE SEGURIDAD
      if (cred.user != null && !cred.user!.emailVerified) {
        // --- CAMBIO AQUÍ: Le reenviamos el correo por si se le perdió ---
        await cred.user!.sendEmailVerification(); 
        // ---------------------------------------------------------------
        
        await _auth.signOut(); // Lo sacamos
        return "Tu cuenta existe pero no está verificada. ¡Te acabamos de reenviar el correo de confirmación! Revísalo.";
      }

      return null; // Todo correcto
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return "No existe una cuenta con este correo.";
      if (e.code == 'wrong-password') return "La contraseña es incorrecta.";
      return e.message;
    }
  }

  // ---------------------------------------------------
  // 2. REGISTRARSE (CREAR CUENTA)
  // ---------------------------------------------------
  Future<String?> registrarse({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
    required String codigoEstudiante,
  }) async {
    try {
      // VALIDACIÓN 1: Solo correos UPDS
      if (!email.endsWith('@upds.edu.bo') && !email.endsWith('@upds.net.bo')) {
        return "Error: Solo se permiten correos institucionales (@upds.edu.bo)";
      }

      // Intentamos crear el usuario en Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      // VALIDACIÓN 2: Enviar correo de verificación
      if (result.user != null && !result.user!.emailVerified) {
        await result.user!.sendEmailVerification();
      }

      // Guardamos los datos extra en Firestore (Base de datos)
      await _db.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'codigo': codigoEstudiante,
        'creado_el': DateTime.now(), // Fecha de creación
        'esVerificado': false, // Inicialmente falso hasta que verifique
      });

      // Cerramos sesión para obligarlo a loguearse después de verificar
      await _auth.signOut();

      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return "Este correo ya está registrado.";
      if (e.code == 'weak-password') return "La contraseña es muy débil (usa al menos 6 caracteres).";
      return e.message ?? "Error al registrarse.";
    } catch (e) {
      return "Error inesperado: $e";
    }
  }

  // ---------------------------------------------------
  // 3. OBTENER DATOS DEL USUARIO (Para Perfil o Mercado)
  // ---------------------------------------------------
  Future<Map<String, dynamic>?> obtenerDatosUsuario() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Buscamos el documento en la colección 'users' con el ID del usuario
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error obteniendo datos: $e");
      return null;
    }
  }

  // ---------------------------------------------------
  // 4. CERRAR SESIÓN
  // ---------------------------------------------------
  Future<void> logout() async {
    await _auth.signOut();
  }
}