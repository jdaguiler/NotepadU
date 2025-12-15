import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodleService {
  
  static const String _storageKey = 'user_moodle_url';

  // 1. GUARDAR URL
  static Future<void> guardarUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, url);
  }

  // 2. OBTENER URL
  static Future<String?> obtenerUrlGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  // 3. OBTENER EVENTOS (Con corrección robusta de fecha)
  static Future<List<Map<String, dynamic>>> obtenerEventosUPDS() async {
    try {
      final urlUsuario = await obtenerUrlGuardada();

      if (urlUsuario == null || urlUsuario.isEmpty) {
        return []; 
      }

      print("Descargando calendario desde: $urlUsuario");
      final response = await http.get(Uri.parse(urlUsuario));

      if (response.statusCode == 200) {
        // Decodificamos el archivo
        final ical = ICalendar.fromString(response.body);
        List<Map<String, dynamic>> listaEventos = [];

        if (ical.data.isNotEmpty) {
          for (var evento in ical.data) {
            if (evento['type'] == 'VEVENT') {
              
              // --- CORRECCIÓN AQUÍ ---
              // Pasamos el dato crudo (dynamic) para analizarlo bien
              DateTime fechaEvento = _limpiarFecha(evento['dtstart']);
              // -----------------------

              listaEventos.add({
                'titulo': evento['summary'] ?? 'Actividad UPDS',
                'desc': evento['description'] ?? '',
                'fecha': fechaEvento,
                'tipo': 'UPDS',
                'esMoodle': true,
              });
            }
          }
        }
        return listaEventos;
      }
      return [];
    } catch (e) {
      print("Error leyendo Moodle: $e");
      return [];
    }
  }

  // 4. FUNCIÓN TRADUCTORA BLINDADA
  static DateTime _limpiarFecha(dynamic rawDate) {
    if (rawDate == null) return DateTime.now();

    try {
      String fechaStr = "";

      // CASO A: Es un Mapa (Ej: {'dt': '2025...', 'tzid': 'America/La_Paz'})
      if (rawDate is Map) {
        fechaStr = rawDate['dt']?.toString() ?? "";
      } 
      // CASO B: Es un String directo
      else {
        fechaStr = rawDate.toString();
      }

      // LIMPIEZA: Si viene con basura tipo "DTSTART:2025..." o "TZID=...:2025..."
      // Nos quedamos con lo que esté después de los dos puntos
      if (fechaStr.contains(':')) {
        fechaStr = fechaStr.split(':').last;
      }

      // Quitamos cualquier cosa que no sea número o la letra T (limpieza final)
      fechaStr = fechaStr.replaceAll(RegExp(r'[^0-9T]'), '');

      // PARSEO MANUAL (Formato iCal estándar: AAAAMMDDTHHMMSS)
      if (fechaStr.length >= 8) {
        String year = fechaStr.substring(0, 4);
        String month = fechaStr.substring(4, 6);
        String day = fechaStr.substring(6, 8);
        
        int h = 0, m = 0, s = 0;

        // Si tiene hora (T)
        if (fechaStr.contains('T') && fechaStr.length >= 13) {
           int tIndex = fechaStr.indexOf('T');
           // Verificamos que haya caracteres suficientes post-T
           if (fechaStr.length >= tIndex + 5) {
             h = int.tryParse(fechaStr.substring(tIndex + 1, tIndex + 3)) ?? 0;
             m = int.tryParse(fechaStr.substring(tIndex + 3, tIndex + 5)) ?? 0;
           }
        }

        return DateTime(
          int.parse(year), 
          int.parse(month), 
          int.parse(day), 
          h, m, s
        );
      }
      
      // Si no pudimos parsear, devuelve hoy (pero imprime el error para saber)
      print("No se pudo entender la fecha: $rawDate");
      return DateTime.now(); 

    } catch (e) {
      print("CRASH FECHA parseando '$rawDate': $e");
      return DateTime.now();
    }
  }
}