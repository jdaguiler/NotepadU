// Archivo: lib/data/mock_data.dart

// 1. HORARIO (Se mantiene para que el Login no falle)
final List<Map<String, dynamic>> horarioIngenieria = [
  {
    "materia": "Ecuaciones Diferenciales",
    "docente": "Ing. Saavedra",
    "aula": "B-304",
    "hora": "07:30 - 10:30",
    "dias": "Lu-Mi-Vi",
    "color": 0xFFD32F2F, 
    "tipo": "Teoría"
  },
  {
    "materia": "Programación II",
    "docente": "Ing. Jhonny Leon",
    "aula": "Lab-4",
    "hora": "10:30 - 12:30",
    "dias": "Ma-Ju",
    "color": 0xFF1976D2, 
    "tipo": "Laboratorio"
  },
  {
    "materia": "Circuitos Eléctricos",
    "docente": "Ing. Tesla",
    "aula": "Lab-Electrónica",
    "hora": "19:00 - 22:00",
    "dias": "Viernes",
    "color": 0xFFFBC02D,
    "tipo": "Práctica"
  },
];

// 2. TAREAS Y METAS (Se mantiene porque TasksScreen aún es local)
// Nota: Cuando decidamos conectar esto a Firebase, podremos borrar esta lista.
List<Map<String, dynamic>> misTareas = [
  {
    "titulo": "Presentar Canvas",
    "desc": "Imprimir el informe para la Lic. Mary Cruz",
    "fecha": "Hoy, 20:00",
    "esMeta": true,
    "completado": false,
  },
  {
    "titulo": "Comprar componentes",
    "desc": "Resistencias y leds para el viernes",
    "fecha": "Mañana",
    "esMeta": false,
    "completado": true,
  }
];

// 3. MERCADO -> BORRADO
// Ya no necesitamos 'mercadoTalentos' porque ahora leemos 
// los datos reales desde Firebase (Nube).