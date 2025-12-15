import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Base de datos manual
import '../services/moodle_service.dart'; // Servicio de Moodle
import 'package:firebase_auth/firebase_auth.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // Configuración del Calendario
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Aquí guardaremos las tareas que vienen de Moodle
  List<Map<String, dynamic>> _eventosMoodle = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _cargarMoodle(); // Cargamos Moodle al iniciar la pantalla
  }

  // --- 1. LÓGICA DE MOODLE (AUTOMÁTICA) ---
  
  Future<void> _cargarMoodle() async {
    // Llamamos al servicio que busca el link guardado en el celular
    final eventos = await MoodleService.obtenerEventosUPDS();
    if (mounted) {
      setState(() {
        _eventosMoodle = eventos;
      });
    }
  }

  // Muestra el cuadro para pegar el link .ics
  void _mostrarConfiguracion() {
    final txtController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Vincular Moodle UPDS"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ve a Moodle -> Calendario -> Exportar. Copia la URL del calendario (.ics) y pégala aquí para ver TUS tareas.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: txtController,
              decoration: const InputDecoration(
                labelText: "Pegar URL aquí",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: "https://moodle.upds.edu.bo/..."
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (txtController.text.isNotEmpty) {
                // 1. Guardamos el link en la memoria del celular
                await MoodleService.guardarUrl(txtController.text.trim());
                if (context.mounted) Navigator.pop(context);
                
                // 2. Recargamos la agenda para ver los cambios
                _cargarMoodle();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("¡Moodle sincronizado correctamente!")),
                  );
                }
              }
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  // --- 2. LÓGICA DE FIREBASE (MANUAL) - CORREGIDA ---
  // --- 2. LÓGICA DE FIREBASE (MANUAL) - CON PRIVACIDAD ---
  void _agregarEventoManual() {
    final tituloController = TextEditingController();
    String tipoSeleccionado = 'Tarea';
    
    // Usamos una variable temporal para la fecha del nuevo evento
    DateTime fechaEvento = _selectedDay ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // StatefulBuilder permite actualizar la fecha dentro del diálogo
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Nuevo Evento Personal"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(
                    labelText: "Título (Ej: Estudiar Java)",
                    icon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: tipoSeleccionado,
                  items: ['Clase', 'Examen', 'Tarea', 'Proyecto']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => setStateDialog(() => tipoSeleccionado = val!),
                  decoration: const InputDecoration(
                    labelText: "Tipo",
                    icon: Icon(Icons.category),
                  ),
                ),
                const SizedBox(height: 15),
                // --- SELECCIONAR FECHA ---
                InkWell(
                  onTap: () async {
                    final fechaElegida = await showDatePicker(
                      context: context,
                      initialDate: fechaEvento,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (fechaElegida != null) {
                      setStateDialog(() {
                        fechaEvento = fechaElegida;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Fecha del evento",
                      icon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      "${fechaEvento.day}/${fechaEvento.month}/${fechaEvento.year}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar")),
              
              // --- AQUÍ ESTÁ EL CAMBIO IMPORTANTE ---
              ElevatedButton(
                onPressed: () {
                  if (tituloController.text.isNotEmpty) {
                    
                    // 1. OBTENEMOS EL ID DEL USUARIO ACTUAL
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    
                    if (uid == null) return; // Seguridad: Si no hay usuario, no guardamos nada

                    // 2. GUARDAMOS CON LA ETIQUETA 'userId'
                    FirebaseFirestore.instance.collection('agenda').add({
                      'titulo': tituloController.text,
                      'tipo': tipoSeleccionado,
                      // Guardamos la fecha elegida
                      'fecha': Timestamp.fromDate(fechaEvento),
                      // Guardamos el ID del dueño para que sea privado
                      'userId': uid, 
                    });
                    
                    Navigator.pop(context);
                  }
                },
                child: const Text("Guardar"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // 1. OBTENEMOS EL ID DEL USUARIO ACTUAL (Para privacidad)
    final user = FirebaseAuth.instance.currentUser;
    // Si por error es nulo, usamos un string vacío para que no traiga nada
    final uid = user?.uid ?? ""; 

    // Usamos StreamBuilder para escuchar Firebase en tiempo real
    return StreamBuilder<QuerySnapshot>(
      // --- CAMBIO CLAVE: FILTRAMOS POR 'userId' ---
      stream: FirebaseFirestore.instance
          .collection('agenda')
          .where('userId', isEqualTo: uid) // <--- Solo trae MIS eventos
          .snapshots(),
      
      builder: (context, snapshot) {
        
        // --- 3. FUSIÓN DE DATOS (FIREBASE + MOODLE) ---
        
        // Mapa maestro donde juntaremos todo por fecha
        Map<DateTime, List<dynamic>> eventosDelCalendario = {};

        // A) Procesar datos de Firebase (Manuales)
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Protección contra fechas nulas
            if (data['fecha'] == null) continue; 
            DateTime fecha;
            try {
               fecha = (data['fecha'] as Timestamp).toDate();
            } catch (e) { continue; }

            DateTime fechaKey = DateTime.utc(fecha.year, fecha.month, fecha.day);
            
            if (eventosDelCalendario[fechaKey] == null) {
              eventosDelCalendario[fechaKey] = [];
            }
            eventosDelCalendario[fechaKey]!.add(data);
          }
        }

        // B) Procesar datos de Moodle (Automáticos)
        // Moodle sigue igual porque se guarda localmente en el celular
        for (var eventoMoodle in _eventosMoodle) {
            DateTime fecha = eventoMoodle['fecha'];
            DateTime fechaKey = DateTime.utc(fecha.year, fecha.month, fecha.day);

            if (eventosDelCalendario[fechaKey] == null) {
              eventosDelCalendario[fechaKey] = [];
            }
            eventosDelCalendario[fechaKey]!.add(eventoMoodle);
        }

        // Función para que el calendario sepa qué pintar
        List<dynamic> getEventosDelDia(DateTime dia) {
           DateTime fechaKey = DateTime.utc(dia.year, dia.month, dia.day);
           return eventosDelCalendario[fechaKey] ?? [];
        }

        // --- 4. INTERFAZ GRÁFICA (Igual que antes) ---
        
        return Scaffold(
          body: Column(
            children: [
              // Botón para configurar Moodle
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: ElevatedButton.icon(
                  onPressed: _mostrarConfiguracion,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text("Vincular mi Moodle UPDS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue[900],
                    elevation: 1,
                  ),
                ),
              ),

              // Calendario
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                
                // Carga los puntos naranjas (mezcla de Firebase filtrado + Moodle)
                eventLoader: getEventosDelDia,

                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Colors.blue[900], shape: BoxShape.circle),
                  markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              ),

              const Divider(),

              // Lista de Tareas del día seleccionado
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: getEventosDelDia(_selectedDay!).map((evento) {
                    
                    // Verificamos si es de Moodle para pintarlo diferente
                    bool esDeMoodle = evento['esMoodle'] == true;

                    return Card(
                      // Color diferente si viene de la Universidad
                      color: esDeMoodle ? Colors.orange[50] : Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          esDeMoodle ? Icons.school : Icons.edit_calendar, 
                          color: esDeMoodle ? Colors.orange[900] : Colors.blue[900],
                        ),
                        title: Text(
                          evento['titulo'], 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(
                          esDeMoodle ? "Plataforma UPDS" : "Evento Personal: ${evento['tipo']}"
                        ),
                        trailing: esDeMoodle 
                          ? const Icon(Icons.cloud_done, size: 16, color: Colors.grey)
                          : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          
          // Botón Flotante para agregar tareas manuales (Firebase)
          floatingActionButton: FloatingActionButton(
            onPressed: _agregarEventoManual,
            backgroundColor: Colors.blue[900],
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}