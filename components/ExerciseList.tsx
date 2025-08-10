import React, { useState, useImperativeHandle, forwardRef, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, Modal } from 'react-native';
// import { Picker } from '@react-native-picker/picker';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getLastExerciseRecord, ExerciseHistory } from '../utils/storage';
import { getTheme } from '../utils/theme';
import { ds } from '../utils/design';

interface Series {
  reps: string;
  kg: string;
  rir: number | undefined;
  tiempo?: string; // Para ejercicios aeróbicos
  done?: boolean; // Marcador manual de serie completada
}

interface Exercise {
  ejercicio: string;
  musculo: string;
  series: Series[];
}

interface Props {
  expand: boolean;
  exercises: Exercise[];
  setExercises: React.Dispatch<React.SetStateAction<Exercise[]>>;
  onMinimize?: () => void;
  onAddExercise?: () => void;
  onOpenChatbot?: () => void;
  isDarkMode?: boolean;
  onPickExercise?: (exercise: { ejercicio: string; musculo: string }) => void;
}

export interface ExerciseListRef {
  openAddExerciseModal: () => void;
}

// Lista completa de ejercicios predefinidos para elegir al agregar
const predefinedExercises = [
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

const ExerciseList = forwardRef<ExerciseListRef, Props>(({ expand, exercises, setExercises, onMinimize, onAddExercise, onOpenChatbot, isDarkMode, onPickExercise }, ref) => {
  const insets = useSafeAreaInsets();
  const theme = getTheme(isDarkMode || false);
  const [showAddExerciseModal, setShowAddExerciseModal] = useState(false);
  const [editingExerciseIndex, setEditingExerciseIndex] = useState<number | null>(null);
  const [editingExerciseName, setEditingExerciseName] = useState('');
  const [editingExerciseMuscle, setEditingExerciseMuscle] = useState('');
  const [previousRecords, setPreviousRecords] = useState<Record<string, ExerciseHistory | null>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const [minimizedExercises, setMinimizedExercises] = useState<Set<number>>(new Set());
  const [showCustomExerciseModal, setShowCustomExerciseModal] = useState(false);
  const [customExerciseName, setCustomExerciseName] = useState('');
  const [customExerciseMuscle, setCustomExerciseMuscle] = useState('Pectoral');

  // Normalizar nombres solo para mostrar (no altera storage ni claves históricas)
  const getDisplayExerciseName = (name: string): string => {
    return name.replace(/Extensiones de\s+/gi, 'Extensión ');
  };

  // Lista de grupos musculares predefinidos
  const muscleGroups = [
    'Pectoral',
    'Espalda', 
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Cuádriceps',
    'Femoral',
    'Abductores',
    'Aductores',
    'Gemelos',
    'Trapecio',
    'Abdomen',
    'Glúteos',
    'Aeróbico'
  ];

  useImperativeHandle(ref, () => ({
    openAddExerciseModal: () => setShowAddExerciseModal(true),
  }));

  // Cargar registros anteriores cuando cambian los ejercicios
  useEffect(() => {
    const loadPreviousRecords = async () => {
      const records: Record<string, ExerciseHistory | null> = {};
      
      for (const exercise of exercises) {
        const lastRecord = await getLastExerciseRecord(exercise.ejercicio);
        records[exercise.ejercicio] = lastRecord;
      }
      
      setPreviousRecords(records);
    };

    if (exercises.length > 0) {
      loadPreviousRecords();
    }
  }, [exercises]);

  const handleChange = (ei: number, si: number, field: keyof Series, value: string) => {
    let processedValue = value;
    
    // Para ejercicios con peso asistido (lastre), convertir valores positivos a negativos automáticamente
    if (field === 'kg' && value && !isNaN(Number(value))) {
      const exercise = exercises[ei];
      if (allowsNegativeWeight(exercise.ejercicio)) {
        const numValue = Number(value);
        // Si el usuario ingresa un valor positivo, convertirlo a negativo
        if (numValue > 0) {
          processedValue = (-numValue).toString();
        }
      }
    }
    
    const updated = exercises.map((ex, i) =>
      i === ei
        ? {
            ...ex,
            series: ex.series.map((s, j) =>
              j === si ? { ...s, [field]: processedValue } : s
            ),
          }
        : ex
    );
    setExercises(updated);
  };

  // Función para verificar si un ejercicio permite peso negativo
  const allowsNegativeWeight = (exerciseName: string): boolean => {
    const lowerName = exerciseName.toLowerCase();
    return lowerName.includes('lastre') || lowerName.includes('asistido') || lowerName.includes('asistida');
  };

  // Función para verificar si un ejercicio es aeróbico
  const isAerobicExercise = (muscleGroup: string): boolean => {
    return muscleGroup === 'Aeróbico';
  };

  const formatTimeInput = (input: string): string => {
    // Remover todo excepto números
    const numbers = input.replace(/\D/g, '');
    
    if (numbers.length <= 2) {
      return numbers;
    } else if (numbers.length <= 4) {
      return `${numbers.slice(0, 2)}:${numbers.slice(2)}`;
    } else if (numbers.length <= 6) {
      return `${numbers.slice(0, 2)}:${numbers.slice(2, 4)}:${numbers.slice(4)}`;
    } else {
      return `${numbers.slice(0, 2)}:${numbers.slice(2, 4)}:${numbers.slice(4, 6)}`;
    }
  };

  const parseTimeToSeconds = (timeString: string): number => {
    const numbers = timeString.replace(/\D/g, '');
    
    if (numbers.length >= 4) {
      const hours = parseInt(numbers.slice(0, 2)) || 0;
      const minutes = parseInt(numbers.slice(2, 4)) || 0;
      const seconds = parseInt(numbers.slice(4, 6)) || 0;
      return (hours * 3600) + (minutes * 60) + seconds;
    } else if (numbers.length >= 2) {
      const minutes = parseInt(numbers.slice(0, 2)) || 0;
      const seconds = parseInt(numbers.slice(2, 4)) || 0;
      return (minutes * 60) + seconds;
    }
    return 0;
  };

  const moveExerciseUp = (index: number) => {
    if (index > 0) {
      const newExercises = [...exercises];
      [newExercises[index], newExercises[index - 1]] = [newExercises[index - 1], newExercises[index]];
      setExercises(newExercises);
    }
  };

  const moveExerciseDown = (index: number) => {
    if (index < exercises.length - 1) {
      const newExercises = [...exercises];
      [newExercises[index], newExercises[index + 1]] = [newExercises[index + 1], newExercises[index]];
      setExercises(newExercises);
    }
  };

  const removeExercise = (index: number) => {
    const newExercises = exercises.filter((_, i) => i !== index);
    setExercises(newExercises);
  };

  const addSeries = (exerciseIndex: number) => {
    const newExercises = [...exercises];
    const isAerobic = isAerobicExercise(exercises[exerciseIndex].musculo);
    newExercises[exerciseIndex].series.push(
      isAerobic ? { reps: '', kg: '', rir: undefined, tiempo: '', done: false } : { reps: '', kg: '', rir: undefined, done: false }
    );
    setExercises(newExercises);
  };

  const removeSeries = (exerciseIndex: number, seriesIndex: number) => {
    const newExercises = [...exercises];
    newExercises[exerciseIndex].series.splice(seriesIndex, 1);
    setExercises(newExercises);
  };

  const toggleExerciseMinimize = (exerciseIndex: number) => {
    const newMinimized = new Set(minimizedExercises);
    if (newMinimized.has(exerciseIndex)) {
      newMinimized.delete(exerciseIndex);
    } else {
      newMinimized.add(exerciseIndex);
    }
    setMinimizedExercises(newMinimized);
  };

  const handleAddCustomExercise = () => {
    if (customExerciseName.trim() && customExerciseMuscle.trim()) {
      const newExercise: Exercise = {
        ejercicio: customExerciseName.trim(),
        musculo: customExerciseMuscle.trim(),
        series: [{ reps: '', kg: '', rir: undefined }]
      };
      
      // Agregar a la lista de ejercicios predefinidos
      predefinedExercises.push({
        ejercicio: customExerciseName.trim(),
        musculo: customExerciseMuscle.trim()
      });
      
      // Agregar a la lista actual
      setExercises([...exercises, newExercise]);
      
      // Limpiar y cerrar modal
      setCustomExerciseName('');
      setCustomExerciseMuscle('Pectoral');
      setShowCustomExerciseModal(false);
    }
  };

  const addExercise = (selectedExercise: { ejercicio: string; musculo: string }) => {
    const isAerobic = isAerobicExercise(selectedExercise.musculo);
    const newExercise: Exercise = {
      ejercicio: selectedExercise.ejercicio,
      musculo: selectedExercise.musculo,
      series: isAerobic ? [
        { reps: '', kg: '', rir: undefined, tiempo: '', done: false },
        { reps: '', kg: '', rir: undefined, tiempo: '', done: false },
        { reps: '', kg: '', rir: undefined, tiempo: '', done: false }
      ] : [
        { reps: '', kg: '', rir: undefined, done: false },
        { reps: '', kg: '', rir: undefined, done: false },
        { reps: '', kg: '', rir: undefined, done: false }
      ],
    };
    setExercises([...exercises, newExercise]);
    setShowAddExerciseModal(false);
  };

  const startEditExercise = (index: number) => {
    setEditingExerciseIndex(index);
    setEditingExerciseName(exercises[index].ejercicio);
    setEditingExerciseMuscle(exercises[index].musculo);
  };

  const saveEditExercise = () => {
    if (editingExerciseIndex !== null) {
      const newExercises = [...exercises];
      newExercises[editingExerciseIndex] = {
        ...newExercises[editingExerciseIndex],
        ejercicio: editingExerciseName,
        musculo: editingExerciseMuscle,
      };
      setExercises(newExercises);
      setEditingExerciseIndex(null);
      setEditingExerciseName('');
      setEditingExerciseMuscle('');
    }
  };

  const cancelEditExercise = () => {
    setEditingExerciseIndex(null);
    setEditingExerciseName('');
    setEditingExerciseMuscle('');
  };

  // Función para normalizar texto (quitar tildes y convertir a minúsculas)
  const normalizeText = (text: string): string => {
    return text
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, ''); // Remueve diacríticos (tildes, etc.)
  };

  // Filtrar ejercicios basado en la búsqueda (insensible a tildes y mayúsculas)
  const filteredExercises = predefinedExercises.filter(exercise =>
    normalizeText(exercise.ejercicio).includes(normalizeText(searchQuery)) ||
    normalizeText(exercise.musculo).includes(normalizeText(searchQuery))
  );

  // Función para verificar si un ejercicio está completo
  const isExerciseComplete = (exercise: Exercise): boolean => {
    // Un ejercicio se considera completo solo cuando TODAS sus series están marcadas como hechas manualmente
    return exercise.series.length > 0 && exercise.series.every(serie => !!serie.done);
  };

  // Función para contar campos incompletos en toda la sesión
  const getIncompleteFieldsCount = (): number => {
    let count = 0;
    exercises.forEach(exercise => {
      // Ahora el indicador de completitud depende del checkbox de cada serie, no del llenado de campos
      exercise.series.forEach(serie => {
        if (!serie.done) count++;
      });
    });
    return count;
  };

  const renderPreviousRecord = (exerciseName: string) => {
    const previousRecord = previousRecords[exerciseName];
    
    if (!previousRecord) return null;

    return (
      <View style={[styles.previousRecordContainer, { borderColor: theme.border }]}>
        <Text style={[styles.previousRecordTitle, { color: theme.textPrimary }]}>Última vez:</Text>
        {previousRecord.series.map((serie, index) => (
          <View key={index} style={styles.previousRecordRow}>
            <Text style={[styles.previousRecordText, { color: theme.textSecondary }]}>
              Serie {index + 1}: {serie.reps} reps, {serie.kg} kg, RIR {serie.rir}
            </Text>
          </View>
        ))}
      </View>
    );
  };

  if (expand) {
    return (
      <View style={[styles.minimizedContainer, { backgroundColor: theme.background, borderColor: theme.border, paddingBottom: insets.bottom, paddingLeft: insets.left, paddingRight: insets.right }]}>
        <View style={[
          styles.minimizedHeader,
          {
            paddingHorizontal: ds.header.paddingHorizontal,
            paddingTop: ds.header.paddingTop,
            paddingBottom: ds.header.paddingBottom + 3,
            minHeight: ds.header.height,
          },
        ]}>
                <Text style={[styles.minimizedTitle, { color: theme.textPrimary }]}>Ejercicios</Text>
                <View style={[styles.headerButtons, { marginRight: 0, minWidth:  ds.sizes.headerActionMinWidth, alignItems: 'flex-end' }]}>
            {onOpenChatbot && (
              <TouchableOpacity style={[styles.chatbotButton, { backgroundColor: theme.buttonPrimary }]} onPress={onOpenChatbot}>
                                  <Text style={[styles.chatbotButtonText, { color: theme.buttonText }]}>Editar</Text>
              </TouchableOpacity>
            )}
                  <TouchableOpacity style={[styles.expandButton, { backgroundColor: '#D4A574' }]} onPress={onMinimize}>
              <Text style={[styles.expandButtonText, { color: '#FFFFFF' }]}>Expandir</Text>
            </TouchableOpacity>
          </View>
        </View>
        <View style={[styles.headerSeparator, { backgroundColor: theme.border, marginTop: ds.header.separatorMarginTop }]} />

        {/* Modales disponibles incluso minimizado para permitir openAddExerciseModal() */}
        <Modal
          visible={showAddExerciseModal}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowAddExerciseModal(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar ejercicio</Text>
              <TouchableOpacity 
                style={[styles.customExerciseButton, { backgroundColor: '#D4A574' }]}
                onPress={() => setShowCustomExerciseModal(true)}
              >
                <Text style={[styles.customExerciseButtonText, { color: '#FFFFFF' }]}>+ Ejercicio personalizado</Text>
              </TouchableOpacity>
              <View style={styles.searchContainer}>
                <TextInput
                  style={[styles.searchInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                  placeholder="Buscar ejercicio o músculo..."
                  value={searchQuery}
                  onChangeText={setSearchQuery}
                  placeholderTextColor={theme.textSecondary}
                />
              </View>
              <ScrollView style={styles.exerciseList}>
                {filteredExercises.map((exercise, index) => (
                  <TouchableOpacity
                    key={index}
                    style={[styles.exerciseOption, { borderBottomColor: theme.border }]}
                    onPress={() => {
                      if (onPickExercise) {
                        onPickExercise(exercise);
                        setShowAddExerciseModal(false);
                        setSearchQuery('');
                      } else {
                        addExercise(exercise);
                      }
                    }}
                  >
                    <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]}>{exercise.ejercicio}</Text>
                    <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]}>{exercise.musculo}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
              <TouchableOpacity 
                style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => {
                  setShowAddExerciseModal(false);
                  setSearchQuery('');
                }}
              >
                <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>

        <Modal
          visible={showCustomExerciseModal}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowCustomExerciseModal(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Agregar ejercicio personalizado</Text>
              <View style={styles.customExerciseForm}>
                <TextInput
                  style={[styles.customExerciseInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                  placeholder="Nombre del ejercicio"
                  value={customExerciseName}
                  onChangeText={setCustomExerciseName}
                  placeholderTextColor={theme.textSecondary}
                />
                <View style={[styles.pickerContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}>
                  <ScrollView style={{ maxHeight: 160 }}>
                    {muscleGroups.map((mg) => (
                      <TouchableOpacity key={mg} style={{ paddingVertical: 8 }} onPress={() => setCustomExerciseMuscle(mg)}>
                        <Text style={{ color: customExerciseMuscle === mg ? '#4F766F' : theme.textPrimary, fontWeight: customExerciseMuscle === mg ? '700' : '500' }}>{mg}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                  <Text style={[styles.pickerLabel, { color: theme.textSecondary, marginTop: 6 }]}>Seleccionado: {customExerciseMuscle}</Text>
                </View>
              </View>
              <View style={styles.customExerciseButtons}>
                <TouchableOpacity 
                  style={[styles.customExerciseAddButton, { backgroundColor: '#D4A574' }]}
                  onPress={() => {
                    if (!customExerciseName.trim()) return;
                    if (onPickExercise) {
                      onPickExercise({ ejercicio: customExerciseName.trim(), musculo: customExerciseMuscle });
                      setShowCustomExerciseModal(false);
                      setShowAddExerciseModal(false);
                      setCustomExerciseName('');
                      setSearchQuery('');
                      return;
                    }
                    handleAddCustomExercise();
                  }}
                >
                  <Text style={[styles.customExerciseAddButtonText, { color: '#FFFFFF' }]}>Agregar</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  style={[styles.customExerciseCancelButton, { backgroundColor: theme.buttonSecondary }]}
                  onPress={() => {
                    setShowCustomExerciseModal(false);
                    setCustomExerciseName('');
                    setCustomExerciseMuscle('Pectoral');
                  }}
                >
                  <Text style={[styles.customExerciseCancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </Modal>
      </View>
    );
  }

  return (
    <View style={[
      styles.container,
      { backgroundColor: theme.background, borderColor: theme.border, paddingBottom: insets.bottom, paddingLeft: insets.left, paddingRight: insets.right, borderTopWidth: 1, borderTopColor: ds.header.borderTopColor }
    ]}>
      <View style={[
        styles.exerciseListHeader,
        {
          paddingHorizontal: ds.header.paddingHorizontal,
          paddingTop: ds.header.paddingTop,
          paddingBottom: ds.header.paddingBottom + 3,
          minHeight: ds.header.height,
        },
      ]}>
        <Text style={[styles.exerciseListTitle, { color: theme.textPrimary }]}>Ejercicios</Text>
        <View style={[styles.headerButtons, { marginRight: 0, minWidth: ds.sizes.headerActionMinWidth, alignItems: 'flex-end' }]}>
          {onOpenChatbot && (
            <TouchableOpacity style={[styles.chatbotButton, { backgroundColor: theme.buttonPrimary }]} onPress={onOpenChatbot}>
                                <Text style={[styles.chatbotButtonText, { color: theme.buttonText }]}>Editar</Text>
            </TouchableOpacity>
          )}
          <TouchableOpacity style={[styles.minimizeButton, { backgroundColor: theme.buttonSecondary }]} onPress={onMinimize}>
            <Text style={[styles.minimizeButtonText, { color: theme.buttonText }]}>Minimizar</Text>
          </TouchableOpacity>
        </View>
      </View>
      <View style={[styles.headerSeparator, { backgroundColor: theme.border, marginTop: ds.header.separatorMarginTop, marginBottom: 12 }]} />
      
      <ScrollView>
        {exercises.map((ex, ei) => (
          <View key={ei} style={[
            styles.exerciseBox,
            { backgroundColor: theme.exerciseBox, borderColor: theme.border },
            isExerciseComplete(ex) && { backgroundColor: theme.exerciseBoxComplete, borderColor: theme.border }
          ]}>
            <View style={[
              styles.exerciseHeader,
              minimizedExercises.has(ei) ? { marginBottom: 0 } : null
            ]}>
              {editingExerciseIndex === ei ? (
                <View style={styles.editExerciseContainer}>
                  <TextInput
                    style={styles.editExerciseInput}
                    value={editingExerciseName}
                    onChangeText={setEditingExerciseName}
                    placeholder="Nombre del ejercicio"
                  />
                  <TextInput
                    style={styles.editExerciseInput}
                    value={editingExerciseMuscle}
                    onChangeText={setEditingExerciseMuscle}
                    placeholder="Músculo"
                  />
                  <View style={styles.editExerciseButtons}>
                    <TouchableOpacity style={styles.saveEditBtn} onPress={saveEditExercise}>
                      <Text style={styles.saveEditBtnText}>✓</Text>
                    </TouchableOpacity>
                    <TouchableOpacity style={styles.cancelEditBtn} onPress={cancelEditExercise}>
                      <Text style={styles.cancelEditBtnText}>✗</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              ) : (
                <>
                  <View style={styles.exerciseTitleContainer}>
                    <Text style={[styles.exerciseTitle, { color: theme.textPrimary }]}>{getDisplayExerciseName(ex.ejercicio)} ({ex.musculo})</Text>
                  </View>
                  <View style={styles.exerciseControls}>
                    <TouchableOpacity 
                      style={[styles.minimizeExerciseBtn, { backgroundColor: '#D4A574' }]} 
                      onPress={() => toggleExerciseMinimize(ei)}
                    >
                      <Text style={[styles.minimizeExerciseBtnText, { color: '#FFFFFF' }]}>
                        {minimizedExercises.has(ei) ? '+' : '−'}
                      </Text>
                    </TouchableOpacity>
                    {ei > 0 && (
                      <TouchableOpacity 
                        style={[styles.controlBtn, { backgroundColor: theme.surface }]} 
                        onPress={() => moveExerciseUp(ei)}
                      >
                        <Text style={[styles.controlBtnText, { color: '#4F766F' }]}>↑</Text>
                      </TouchableOpacity>
                    )}
                    {ei < exercises.length - 1 && (
                      <TouchableOpacity 
                        style={[styles.controlBtn, { backgroundColor: theme.surface }]} 
                        onPress={() => moveExerciseDown(ei)}
                      >
                        <Text style={[styles.controlBtnText, { color: '#4F766F' }]}>↓</Text>
                      </TouchableOpacity>
                    )}
                    <TouchableOpacity 
                      style={[styles.removeBtn, { backgroundColor: theme.buttonSecondary }]} 
                      onPress={() => removeExercise(ei)}
                    >
                      <Text style={[styles.removeBtnText, { color: theme.buttonText }]}>×</Text>
                    </TouchableOpacity>
                  </View>
                </>
              )}
            </View>
            
            {/* Mostrar registro anterior */}
            {!minimizedExercises.has(ei) && renderPreviousRecord(ex.ejercicio)}
            
            {!minimizedExercises.has(ei) && (
              <View style={styles.seriesContainer}>
              <View style={styles.seriesHeader}>
                <View style={styles.seriesHeaderLeft}>
                  {/* Encabezados de cajitas */}
                  <View style={styles.seriesInfo}>
                    <Text style={[styles.columnHeaderText, { color: theme.textSecondary, fontWeight: 'bold', fontSize: 14 }]}>Series</Text>
                  </View>
                  <View style={styles.headerFieldsRow}>
                    {isAerobicExercise(ex.musculo) ? (
                      <View style={styles.headerCellTime}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Tiempo</Text></View>
                    ) : (
                      <>
                        <View style={styles.headerCellSmall}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Reps</Text></View>
                        <View style={styles.headerCellSmall}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Kg</Text></View>
                        <View style={styles.headerCellSmall}><Text style={[styles.headerText, { color: theme.textSecondary }]}>RIR</Text></View>
                      </>
                    )}
                  </View>
                  <View style={styles.headerCellCheck}>
                    <Text style={[styles.headerText, { color: theme.textSecondary }]}>✓</Text>
                  </View>
                </View>
              </View>
              
              {ex.series.map((s, si) => (
                <View key={si} style={styles.seriesRow}>
                  <View style={styles.seriesInfo}>
                    <Text style={[styles.seriesLabel, { color: theme.textSecondary }]}>Serie {si + 1}:</Text>
                    {ex.series.length > 1 && (
                      <TouchableOpacity 
                        style={[styles.removeSeriesBtn, { backgroundColor: theme.buttonSecondary }]}
                        onPress={() => removeSeries(ei, si)}
                      >
                        <Text style={[styles.removeSeriesBtnText, { color: theme.buttonText }]}>×</Text>
                      </TouchableOpacity>
                    )}
                  </View>
                  <View style={styles.seriesFieldsRow}>
                    {isAerobicExercise(ex.musculo) ? (
                      <TextInput
                        style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center', width: 180 }]}
                        placeholder="MM:SS"
                        value={s.tiempo || ''}
                        onChangeText={v => handleChange(ei, si, 'tiempo', formatTimeInput(v))}
                        keyboardType="numeric"
                        maxLength={8} // HH:MM:SS
                        placeholderTextColor={theme.textSecondary}
                      />
                    ) : (
                      <>
                        <TextInput
                          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center' }]}
                          placeholder="Reps"
                          value={s.reps}
                          onChangeText={v => handleChange(ei, si, 'reps', v)}
                          keyboardType="numeric"
                          placeholderTextColor={theme.textSecondary}
                        />
                        <TextInput
                          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center' }]}
                          placeholder={allowsNegativeWeight(ex.ejercicio) ? "Kg (-)" : "Kg"}
                          value={s.kg}
                          onChangeText={v => handleChange(ei, si, 'kg', v)}
                          keyboardType="numeric"
                          placeholderTextColor={theme.textSecondary}
                        />
                        <TextInput
                          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center' }]}
                          placeholder="RIR"
                          value={s.rir?.toString() || ''}
                          onChangeText={v => handleChange(ei, si, 'rir', v.replace(/\D/g, ''))}
                          keyboardType="numeric"
                          placeholderTextColor={theme.textSecondary}
                        />
                      </>
                    )}
                  </View>
                  <View style={{ width: 44, alignItems: 'center', justifyContent: 'center' }}>
                    <TouchableOpacity
                      onPress={() => {
                        const updated = exercises.map((ex, i) =>
                          i === ei
                            ? {
                                ...ex,
                                series: ex.series.map((s2, j) => j === si ? { ...s2, done: !s2.done } : s2),
                              }
                            : ex
                        );
                        setExercises(updated);
                      }}
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: 6,
                        borderWidth: 1,
                        borderColor: theme.border,
                        backgroundColor: s.done ? theme.buttonPrimary : 'transparent',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Text style={{
                        color: s.done ? theme.buttonText : theme.textSecondary,
                        fontWeight: '800',
                        fontSize: 16,
                        lineHeight: 16,
                      }}>
                        {s.done ? '✓' : ''}
                      </Text>
                    </TouchableOpacity>
                  </View>
                </View>
              ))}

              {/* Footer de series: botón para agregar serie */}
              <View style={styles.seriesFooterRow}>
                <TouchableOpacity 
                  style={[styles.addSeriesBtn, { backgroundColor: theme.buttonPrimary }]}
                  onPress={() => addSeries(ei)}
                >
                  <Text style={[styles.addSeriesBtnText, { color: theme.buttonText }]}>+ Agregar serie</Text>
                </TouchableOpacity>
              </View>
            </View>
            )}
          </View>
        ))}
      </ScrollView>

      {/* Botón agregar ejercicio y contador */}
      {onAddExercise && (
        <View style={styles.addExerciseContainer}>
          <TouchableOpacity style={[styles.addExerciseButton, { backgroundColor: theme.buttonPrimary }]} onPress={onAddExercise}>
            <Text style={[styles.addExerciseButtonText, { color: theme.buttonText }]}>+ Agregar ejercicio</Text>
          </TouchableOpacity>
          <Text style={[styles.exerciseCount, { color: theme.textSecondary }]}>{exercises.length} ejercicios</Text>
        </View>
      )}

      {/* Modal para agregar ejercicio */}
      <Modal
        visible={showAddExerciseModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowAddExerciseModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar ejercicio</Text>
            
            {/* Botón para agregar ejercicio personalizado */}
            <TouchableOpacity 
              style={[styles.customExerciseButton, { backgroundColor: '#D4A574' }]}
              onPress={() => setShowCustomExerciseModal(true)}
            >
              <Text style={[styles.customExerciseButtonText, { color: '#FFFFFF' }]}>+ Ejercicio personalizado</Text>
            </TouchableOpacity>
            
            {/* Buscador */}
            <View style={styles.searchContainer}>
              <TextInput
                style={[styles.searchInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                placeholder="Buscar ejercicio o músculo..."
                value={searchQuery}
                onChangeText={setSearchQuery}
                placeholderTextColor={theme.textSecondary}
              />
            </View>
            
            <ScrollView style={styles.exerciseList}>
              {filteredExercises.map((exercise, index) => (
                <TouchableOpacity
                  key={index}
                  style={[styles.exerciseOption, { borderBottomColor: theme.border }]}
                  onPress={() => {
                    if (onPickExercise) {
                      onPickExercise(exercise);
                      setShowAddExerciseModal(false);
                      setSearchQuery('');
                    } else {
                      addExercise(exercise);
                    }
                  }}
                >
                  <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]}>{exercise.ejercicio}</Text>
                  <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]}>{exercise.musculo}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            <TouchableOpacity 
              style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
              onPress={() => {
                setShowAddExerciseModal(false);
                setSearchQuery('');
              }}
            >
              <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Modal para ejercicio personalizado */}
      <Modal
        visible={showCustomExerciseModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowCustomExerciseModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Agregar ejercicio personalizado</Text>
            
            <View style={styles.customExerciseForm}>
              <TextInput
                style={[styles.customExerciseInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                placeholder="Nombre del ejercicio"
                value={customExerciseName}
                onChangeText={setCustomExerciseName}
                placeholderTextColor={theme.textSecondary}
              />
              {/* Selector real de grupo muscular */}
              <View style={[styles.pickerContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}
              >
                <ScrollView style={{ maxHeight: 160 }}>
                  {muscleGroups.map((mg) => (
                    <TouchableOpacity key={mg} style={{ paddingVertical: 8 }} onPress={() => setCustomExerciseMuscle(mg)}>
                      <Text style={{ color: customExerciseMuscle === mg ? '#4F766F' : theme.textPrimary, fontWeight: customExerciseMuscle === mg ? '700' as const : '500' }}>{mg}</Text>
                    </TouchableOpacity>
                  ))}
                </ScrollView>
                <Text style={[styles.pickerLabel, { color: theme.textSecondary, marginTop: 6 }]}>Seleccionado: {customExerciseMuscle}</Text>
              </View>
            </View>
            
            <View style={styles.customExerciseButtons}>
              <TouchableOpacity 
                style={[styles.customExerciseAddButton, { backgroundColor: '#D4A574' }]}
                onPress={() => {
                  if (!customExerciseName.trim()) return;
                  if (onPickExercise) {
                    onPickExercise({ ejercicio: customExerciseName.trim(), musculo: customExerciseMuscle });
                    setShowCustomExerciseModal(false);
                    setShowAddExerciseModal(false);
                    setCustomExerciseName('');
                    setSearchQuery('');
                    return;
                  }
                  handleAddCustomExercise();
                }}
              >
                <Text style={[styles.customExerciseAddButtonText, { color: '#FFFFFF' }]}>Agregar</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.customExerciseCancelButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => {
                  setShowCustomExerciseModal(false);
                  setCustomExerciseName('');
                  setCustomExerciseMuscle('Pectoral');
                }}
              >
                <Text style={[styles.customExerciseCancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderTopWidth: 1,
    padding: 4,
  },
  minimizedContainer: {
    borderTopWidth: 1,
    paddingTop: 8,
    paddingBottom: 4,
    paddingHorizontal: 8,
  },
  exerciseListHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 6,
    paddingHorizontal: 8,
  },
  exerciseListTitle: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 12, // Configuración válida
  },
  headerButtons: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 4,
  },
  chatbotButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 8,
  },
  chatbotButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  minimizeButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
  },
  minimizeButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  minimizedHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  headerSeparator: {
    height: 1,
    width: '100%',
  },
  minimizedTitle: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 12, // Configuración válida
    marginRight: 8, // Agregar margen derecho
  },
  expandButton: {
    backgroundColor: '#D4A574',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 4, // Reducir un poquitito más el margen
  },
  expandButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  exerciseBox: {
    borderWidth: 1,
    marginBottom: 12,
    marginHorizontal: 8, // Achicar para que se vean los bordes laterales
    padding: 8,
    borderRadius: 8,
  },
  exerciseBoxComplete: {
    // Estilo dinámico aplicado en el JSX
  },
  exerciseHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  exerciseTitleContainer: {
    flex: 1,
  },
  exerciseTitle: {
    fontWeight: 'bold', // Cambiar de '600' a 'bold' para destacar más
    fontSize: 14,
    fontFamily: 'System',
  },
  editExerciseContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  editExerciseInput: {
    borderWidth: 1,
    paddingHorizontal: 4,
    paddingVertical: 2,
    marginRight: 4,
    flex: 1,
    fontSize: 12,
    fontFamily: 'System',
  },
  editExerciseButtons: {
    flexDirection: 'row',
  },
  saveEditBtn: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginRight: 2,
    borderRadius: 2,
  },
  saveEditBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  cancelEditBtn: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 2,
  },
  cancelEditBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  exerciseControls: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  controlBtn: {
    borderWidth: 1,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginHorizontal: 2,
    borderRadius: 6,
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  controlBtnDisabled: {
    opacity: 0.5,
  },
  controlBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  minimizeExerciseBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    marginRight: 4,
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  minimizeExerciseBtnText: {
    fontWeight: '600',
    fontSize: 11,
    fontFamily: 'System',
  },
  removeBtn: {
    borderWidth: 1,
    borderColor: '#E2928D',
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginLeft: 4,
    backgroundColor: 'rgba(244, 202, 171, 0.15)', // Color más suave y transparente
    borderRadius: 6,
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeBtnText: {
    color: '#E2928D',
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  previousRecordContainer: {
    padding: 8,
    marginBottom: 8,
    borderRadius: 6,
    borderWidth: 1,
    alignSelf: 'flex-start',
  },
  previousRecordTitle: {
    fontSize: 13,
    fontWeight: '600',
    marginBottom: 4,
    fontFamily: 'System',
  },
  previousRecordRow: {
    marginBottom: 2,
  },
  previousRecordText: {
    fontSize: 12,
    fontFamily: 'System',
  },
  seriesContainer: {
    marginTop: 8,
  },
  seriesHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  seriesHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  seriesTitle: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  addSeriesBtn: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 8,
    minWidth: 180,
    minHeight: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addSeriesBtnText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  columnHeaders: {
    flexDirection: 'row',
    marginBottom: 4,
  },
  seriesLabelContainer: {
    flex: 1,
    paddingHorizontal: 8,
  },
  columnHeaderText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  headerText: {
    fontWeight: 'bold',
    fontSize: 14,
    textAlign: 'center',
    fontFamily: 'System',
  },
  headerCellSmall: {
    width: 56,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 4, // igual que input
  },
  headerCellTime: {
    width: 180,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerCellCheck: {
    width: 44,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerFieldsRow: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'center',
    marginLeft: 0,
  },
  seriesFieldsRow: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'center',
  },
  columnHeaderInput: {
    flex: 1,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
    fontFamily: 'System',
  },
  seriesRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
  },
  seriesFooterRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 12,
  },
  seriesInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    width: 100,
  },
  seriesLabel: {
    flex: 1,
    fontFamily: 'System',
  },
  removeSeriesBtn: {
    width: 28,
    height: 28,
    borderRadius: 6,
    marginLeft: 6,
    marginRight: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeSeriesBtnText: {
    fontWeight: '700',
    fontSize: 12,
    fontFamily: 'System',
    lineHeight: 12,
  },
  input: {
    borderWidth: 1,
    width: 56,
    marginHorizontal: 4,
    paddingHorizontal: 4,
    paddingVertical: 2,
    height: 28,
    borderRadius: 6,
    fontSize: 12,
    fontFamily: 'System',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    borderRadius: 12,
    padding: 20,
    width: '80%',
    maxHeight: '70%',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 16,
    fontFamily: 'System',
  },
  customExerciseButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    marginBottom: 16,
    alignItems: 'center',
  },
  customExerciseButtonText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  exerciseList: {
    maxHeight: 300,
  },
  exerciseOption: {
    padding: 16,
    borderBottomWidth: 1,
  },
  exerciseOptionText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  exerciseOptionSubtext: {
    fontSize: 12,
    marginTop: 4,
    fontFamily: 'System',
  },
  cancelButton: {
    marginTop: 16,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontWeight: '600',
    fontFamily: 'System',
  },
  addExerciseContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#D4A574',
    marginHorizontal: 32,
  },
  addExerciseButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
  },
  addExerciseButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  exerciseCount: {
    fontSize: 12,
    fontFamily: 'System',
  },
  searchContainer: {
    marginBottom: 16,
    paddingHorizontal: 16,
  },
  searchInput: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    fontFamily: 'System',
  },
  customExerciseForm: {
    marginBottom: 20,
  },
  customExerciseInput: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    marginBottom: 12,
    fontFamily: 'System',
  },
  customExerciseButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  customExerciseAddButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginRight: 8,
  },
  customExerciseAddButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
  },
  customExerciseCancelButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginLeft: 8,
  },
  customExerciseCancelButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
  },
  pickerContainer: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 12,
  },
  pickerLabel: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 4,
    fontFamily: 'System',
  },
  pickerNote: {
    fontSize: 12,
    fontStyle: 'italic',
    fontFamily: 'System',
  },
  picker: {
    height: 50,
  },
});

export default ExerciseList; 