// utils/exerciseCatalog.ts
// Fuente única de ejercicios predefinidos para catálogo/selector/reemplazos.

export const predefinedExercises: Array<{ ejercicio: string; musculo: string }> = [
  // Pectoral
  { ejercicio: 'Press banca', musculo: 'Pectoral' },
  { ejercicio: 'Press plano mancuernas', musculo: 'Pectoral' },
  { ejercicio: 'Press banca inclinado', musculo: 'Pectoral' },
  { ejercicio: 'Press inclinado mancuernas', musculo: 'Pectoral' },
  { ejercicio: 'Aperturas mancuernas', musculo: 'Pectoral' },
  { ejercicio: 'Press inclinado mancuernas Smith', musculo: 'Pectoral' },
  { ejercicio: 'Peck-Deck (Mariposa)', musculo: 'Pectoral' },

  // Hombros
  { ejercicio: 'Press militar', musculo: 'Hombros' },
  { ejercicio: 'Press militar mancuernas', musculo: 'Hombros' },
  { ejercicio: 'Extensión hombros polea', musculo: 'Hombros' },
  { ejercicio: 'Elevaciones laterales', musculo: 'Hombros' },
  { ejercicio: 'Elevaciones frontales', musculo: 'Hombros' },
  { ejercicio: 'Press inclinado mancuernas Smith', musculo: 'Hombros' },
  { ejercicio: 'Deltoides posterior', musculo: 'Hombros' },

  // Tríceps
  { ejercicio: 'Tríceps Katana', musculo: 'Tríceps' },
  { ejercicio: 'Extensión tríceps cable', musculo: 'Tríceps' },
  { ejercicio: 'Extensión tríceps mancuerna', musculo: 'Tríceps' },
  { ejercicio: 'Fondos paralelas', musculo: 'Tríceps' },
  { ejercicio: 'Fondos paralelas lastre', musculo: 'Tríceps' },
  { ejercicio: 'Press cerrado', musculo: 'Tríceps' },
  { ejercicio: 'Extensión tríceps polea', musculo: 'Tríceps' },
  { ejercicio: 'Triceps sentado', musculo: 'Tríceps' },

  // Bíceps
  { ejercicio: 'Curl bíceps mancuerna', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps barra', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps cable', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps martillo', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps concentrado', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps predicador', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps spider', musculo: 'Bíceps' },

  // Espalda
  { ejercicio: 'Remo barra', musculo: 'Espalda' },
  { ejercicio: 'Remo mancuernas', musculo: 'Espalda' },
  { ejercicio: 'Remo polea', musculo: 'Espalda' },
  { ejercicio: 'Remo T', musculo: 'Espalda' },
  { ejercicio: 'Jalón al pecho', musculo: 'Espalda' },
  { ejercicio: 'Dominadas', musculo: 'Espalda' },
  { ejercicio: 'Dominadas lastre', musculo: 'Espalda' },

  // Cuádriceps
  { ejercicio: 'Sentadillas', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas mancuernas', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas frontales', musculo: 'Cuádriceps' },
  { ejercicio: 'Prensa de piernas', musculo: 'Cuádriceps' },
  { ejercicio: 'Extensión piernas', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas búlgaras', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas búlgaras mancuernas', musculo: 'Cuádriceps' },

  // Femoral
  { ejercicio: 'Curl femoral acostado', musculo: 'Femoral' },
  { ejercicio: 'Curl femoral sentado', musculo: 'Femoral' },
  { ejercicio: 'Curl femoral de pie', musculo: 'Femoral' },
  { ejercicio: 'Peso muerto rumano', musculo: 'Femoral' },
  { ejercicio: 'Good mornings', musculo: 'Femoral' },
  { ejercicio: 'Curl femoral mancuerna', musculo: 'Femoral' },

  // Abductores
  { ejercicio: 'Abducción máquina', musculo: 'Abductores' },
  { ejercicio: 'Abducción cable', musculo: 'Abductores' },
  { ejercicio: 'Abducción banda', musculo: 'Abductores' },
  { ejercicio: 'Abducción mancuerna', musculo: 'Abductores' },
  { ejercicio: 'Abducción polea', musculo: 'Abductores' },
  { ejercicio: 'Abducción peso corporal', musculo: 'Abductores' },

  // Aductores
  { ejercicio: 'Aducción máquina', musculo: 'Aductores' },
  { ejercicio: 'Aducción cable', musculo: 'Aductores' },
  { ejercicio: 'Aducción banda', musculo: 'Aductores' },
  { ejercicio: 'Aducción mancuerna', musculo: 'Aductores' },
  { ejercicio: 'Aducción polea', musculo: 'Aductores' },
  { ejercicio: 'Aducción peso corporal', musculo: 'Aductores' },

  // Gemelos
  { ejercicio: 'Elevación de gemelos de pie', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos sentado', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos prensa', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos mancuerna', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos escalón', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos con barra', musculo: 'Gemelos' },

  // Aeróbico
  { ejercicio: 'Cinta', musculo: 'Aeróbico' },
  { ejercicio: 'Bicicleta', musculo: 'Aeróbico' },
  { ejercicio: 'Bicicleta elíptica', musculo: 'Aeróbico' },
  { ejercicio: 'Entrada en calor', musculo: 'Aeróbico' },
  { ejercicio: 'Remorgómetro', musculo: 'Aeróbico' },
  { ejercicio: 'Running', musculo: 'Aeróbico' },
  { ejercicio: 'Bootcamp', musculo: 'Aeróbico' },
];
