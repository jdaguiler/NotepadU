import 'dart:async';
import '../data/mock_data.dart';

class UPDSScraper {
  // Simula conexión al servidor UPDS
  static Future<List<Map<String, dynamic>>> obtenerHorario(String codigo, String password) async {
    await Future.delayed(const Duration(seconds: 2)); // Espera 2 segundos
    
    // Devolvemos el horario importado de mock_data
    return horarioIngenieria; 
  }
}