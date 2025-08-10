import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Modal, Alert, Image, TextInput, Pressable, TouchableWithoutFeedback } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { saveSession, saveCustomSession, getCustomSessions, deleteCustomSession, updateCustomSession, getSessionTypeOverrides, updateSessionTypeOverride, getDeletedSessionTypes, addDeletedSessionType, type CustomSession, type ExerciseHistory, getRoutines, saveRoutine, updateRoutine, deleteRoutine, type Routine } from '../utils/storage';
import SideMenu from './SideMenu';
import { getTheme } from '../utils/theme';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';

interface Exercise {
  ejercicio: string;
  musculo: string;
  series: Array<{ reps: string; kg: string; rir: number | undefined }>;
}

interface Props {
  exercises: Exercise[];
  setExercises: React.Dispatch<React.SetStateAction<Exercise[]>>;
  onAddExercise?: () => void;
  getIncompleteFieldsCount?: () => number;
  isDarkMode?: boolean;
  onToggleDarkMode?: () => void;
  sessionDuration?: number; // Duración de la sesión en segundos
  onSessionFinish?: () => void; // Callback para resetear timers
}

type SessionType = 'Push' | 'Pull' | 'Piernas' | 'Sesión mixta' | 'Sesión libre' | 'Cardio';

// Ejercicios predefinidos por tipo de sesión
const sessionExercises: Record<SessionType, Exercise[]> = {
  'Push': [
    { ejercicio: 'Press banca', musculo: 'Pectoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Extensiones de hombros polea', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Tríceps Katana', musculo: 'Tríceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Press inclinado mancuernas', musculo: 'Pectoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Elevaciones laterales', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Triceps sentado', musculo: 'Tríceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Pull': [
    { ejercicio: 'Jalón al pecho', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl bíceps martillo', musculo: 'Bíceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Dominadas lastre', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl bíceps mancuerna', musculo: 'Bíceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Remo mancuernas', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Piernas': [
    { ejercicio: 'Extensiones de piernas', musculo: 'Cuádriceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl femoral acostado', musculo: 'Femoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Prensa de piernas', musculo: 'Cuádriceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Aducción máquina', musculo: 'Aductores', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Abducción máquina', musculo: 'Abductores', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Elevación de gemelos de pie', musculo: 'Gemelos', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Sesión mixta': [
    { ejercicio: 'Press plano mancuernas', musculo: 'Pectoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Remo mancuernas', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Extensiones de hombros polea', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl bíceps martillo', musculo: 'Bíceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Extensiones de tríceps mancuerna', musculo: 'Tríceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Deltoides posterior', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Sesión libre': [], // Sesión libre inicia vacía
  'Cardio': [], // Sesión de cardio inicia vacía para agregar ejercicios aeróbicos
};

// Mostrar nombres más cortos para ahorrar espacio en UI
const getDisplaySessionName = (name: string): string => {
  if (name === 'Sesión mixta') return 'Mixta';
  if (name === 'Sesión libre') return 'Libre';
  return name;
};

const SessionSelector: React.FC<Props> = ({ exercises, setExercises, onAddExercise, getIncompleteFieldsCount, isDarkMode, onToggleDarkMode, sessionDuration, onSessionFinish }) => {
  const insets = useSafeAreaInsets();
  const [selectedSession, setSelectedSession] = useState<SessionType | null>(null);
  const [showSessionModal, setShowSessionModal] = useState(false);
  const [showSideMenu, setShowSideMenu] = useState(false);
  const [showCustomNameModal, setShowCustomNameModal] = useState(false);
  const [customSessionName, setCustomSessionName] = useState('');
  const [customSessions, setCustomSessions] = useState<CustomSession[]>([]);
  const [routines, setRoutines] = useState<Routine[]>([]);
  const [showRoutineModal, setShowRoutineModal] = useState(false);
  const [routineName, setRoutineName] = useState('');
  const [editingRoutine, setEditingRoutine] = useState<Routine | null>(null);
  const [routineMode, setRoutineMode] = useState<'list' | 'edit' | 'create' | 'start' | 'import'>('list');
  const [activeRoutine, setActiveRoutine] = useState<Routine | null>(null);
  const [showAddTypeModal, setShowAddTypeModal] = useState(false);
  const [showAddCustomModal, setShowAddCustomModal] = useState(false);
  const [showSessionTypePicker, setShowSessionTypePicker] = useState(false);
  const [typeSearch, setTypeSearch] = useState('');
  const [isEditingHistoricalSession, setIsEditingHistoricalSession] = useState(false);
  const [editingSessionId, setEditingSessionId] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState(new Date());
  // Editor de tipo de sesión (unificado con estética de rutina)
  const [showSessionTypeEditor, setShowSessionTypeEditor] = useState(false);
  const [editingTypeKind, setEditingTypeKind] = useState<'default' | 'custom' | null>(null);
  const [editingTypeKey, setEditingTypeKey] = useState<string>('');
  const [editingTypeName, setEditingTypeName] = useState<string>('');
  const [editingTypeExercises, setEditingTypeExercises] = useState<Exercise[]>([]);
  // Overrides en memoria para tipos por defecto editados por el usuario
  const [sessionOverrides, setSessionOverrides] = useState<Partial<Record<SessionType, ExerciseHistory[]>>>({});
  const [deletedDefaultTypes, setDeletedDefaultTypes] = useState<string[]>([]);
  const theme = getTheme(isDarkMode || false);

  const getSessionTemplate = (sessionType: SessionType): Exercise[] => {
    const overrides = sessionOverrides[sessionType];
    const baseExercises = sessionExercises[sessionType];
    
    if (overrides) {
      // Convertir ExerciseHistory[] a Exercise[]
      return overrides.map(e => ({
        ejercicio: e.ejercicio,
        musculo: e.musculo,
        series: e.series.map(s => ({ reps: s.reps || '', kg: s.kg || '', rir: s.rir })),
      }));
    }
    
    return baseExercises.map(e => ({
      ejercicio: e.ejercicio,
      musculo: e.musculo,
      series: e.series.map(s => ({ ...s })),
    }));
  };

  // Cargar overrides al iniciar
  useEffect(() => {
    (async () => {
      const overrides = await getSessionTypeOverrides();
      setSessionOverrides(overrides);
      const deleted = await getDeletedSessionTypes();
      setDeletedDefaultTypes(deleted);
    })();
  }, []);

  const handleSessionSelect = (sessionType: SessionType) => {
    // Verificar si hay ejercicios en la sesión actual
    if (exercises.length > 0) {
      Alert.alert(
        'Confirmar cambio de sesión',
        '¿Estás seguro? Esto sobrescribirá los ejercicios actuales.',
        [
          {
            text: 'No',
            style: 'cancel',
          },
          {
            text: 'Sí',
            onPress: () => {
              setActiveRoutine(null);
              setSelectedSession(sessionType);
              setExercises(getSessionTemplate(sessionType));
              // NO resetear selectedDate para mantener la fecha histórica
              setShowSessionModal(false);
            },
          },
        ]
      );
    } else {
      // Si no hay ejercicios, cambiar directamente
      setActiveRoutine(null);
      setSelectedSession(sessionType);
      setExercises(getSessionTemplate(sessionType));
      // NO resetear selectedDate para mantener la fecha histórica
      setShowSessionModal(false);
    }
  };

  // Función para agregar entrenamiento de días anteriores
  const handleAddHistoricalSession = (selectedDate: Date) => {
    // Guardar la fecha seleccionada para usarla al finalizar la sesión
    setSelectedDate(selectedDate);
    
    // Cerrar el menú lateral y abrir el modal de selección de sesión
    setShowSideMenu(false);
    setShowSessionModal(true);
  };

  // Función para editar entrenamiento histórico
  const handleEditHistoricalSession = (sessionId: string) => {
    setIsEditingHistoricalSession(true);
    setEditingSessionId(sessionId);
    // Aquí cargaríamos los datos de la sesión histórica
    // Por ahora solo simulamos
    Alert.alert('Editar sesión histórica', 'Funcionalidad en desarrollo');
  };

  // Cargar sesiones personalizadas al abrir la app
  useEffect(() => {
    (async () => {
      const cs = await getCustomSessions();
      setCustomSessions(cs);
      let rs = await getRoutines();
      // Asegurar plantillas por defecto SIEMPRE que no existan por nombre
      const seeds: Array<Omit<Routine, 'id'>> = [
        {
          name: 'Push-Pull-Piernas',
          sessionRefs: [
            { type: 'default', key: 'Push' },
            { type: 'default', key: 'Pull' },
            { type: 'default', key: 'Piernas' },
          ],
        },
        {
          name: 'Upper-Lower',
          sessionRefs: [
            { type: 'default', key: 'Sesión mixta' },
            { type: 'default', key: 'Piernas' },
          ],
        },
        {
          name: 'Cardio semanal',
          sessionRefs: [
            { type: 'default', key: 'Cardio' },
          ],
        },
      ];

      try {
        for (const seed of seeds) {
          const existing = rs.find(r => r.name.toLowerCase() === seed.name.toLowerCase());
          if (!existing) {
            await saveRoutine(seed);
          } else if (!existing.sessionRefs || existing.sessionRefs.length === 0) {
            // Si existe pero vacío, lo completamos con las sesiones sugeridas
            await updateRoutine({ ...existing, sessionRefs: seed.sessionRefs });
          }
        }
        rs = await getRoutines();
      } catch (e) {
        // noop
      }
      setRoutines(rs);
    })();
  }, []);

  // Función para guardar sesión personalizada
  const handleSaveCustomSession = async () => {
    if (!customSessionName.trim()) return;
    try {
      const created = await saveCustomSession({ name: customSessionName.trim(), exercises });
      setCustomSessions([created, ...customSessions]);
      setCustomSessionName('');
      setShowCustomNameModal(false);
      Alert.alert('Sesión personalizada', 'Guardada correctamente');
    } catch (e) {
      Alert.alert('Error', 'No se pudo guardar la sesión personalizada.');
    }
  };

  // Rutinas
  const openNewRoutine = () => {
    setEditingRoutine({ id: '', name: '', sessionRefs: [] });
    setRoutineName('');
    setRoutineMode('create');
    setShowRoutineModal(true);
  };

  // ====== Editor de tipos de sesión (predefinidos) ======
  const openSessionTypeEditor = (sessionType: SessionType) => {
    setEditingTypeKind('default');
    setEditingTypeKey(sessionType);
    setEditingTypeName(sessionType);
    setEditingTypeExercises(getSessionTemplate(sessionType));
    setShowSessionTypeEditor(true);
  };

  // ====== Editor de sesiones personalizadas ======
  const openCustomSessionEditor = (cs: CustomSession) => {
    setEditingTypeKind('custom');
    setEditingTypeKey(cs.id);
    setEditingTypeName(cs.name);
    // @ts-ignore
    setEditingTypeExercises((cs.exercises as any) || []);
    setShowSessionTypeEditor(true);
  };
  const saveRoutineLocal = async () => {
    const name = routineName.trim();
    if (!name) return;
    if (editingRoutine && editingRoutine.id) {
      const updated: Routine = { ...editingRoutine, name };
      await updateRoutine(updated);
    } else {
      await saveRoutine({ name, sessionRefs: editingRoutine?.sessionRefs || [] });
    }
    setShowRoutineModal(false);
    const rs = await getRoutines();
    setRoutines(rs);
    setRoutineMode('list');
  };

  const addSessionRefToEditing = (ref: { type: 'default' | 'custom'; key: string }) => {
    if (!editingRoutine) return;
    setEditingRoutine({ ...editingRoutine, sessionRefs: [...editingRoutine.sessionRefs, ref] });
  };

  const removeSessionRefAt = (idx: number) => {
    if (!editingRoutine) return;
    const next = editingRoutine.sessionRefs.filter((_, i) => i !== idx);
    setEditingRoutine({ ...editingRoutine, sessionRefs: next });
  };

  const moveSessionRef = (idx: number, dir: -1 | 1) => {
    if (!editingRoutine) return;
    const arr = [...editingRoutine.sessionRefs];
    const ni = idx + dir;
    if (ni < 0 || ni >= arr.length) return;
    const tmp = arr[idx];
    arr[idx] = arr[ni];
    arr[ni] = tmp;
    setEditingRoutine({ ...editingRoutine, sessionRefs: arr });
  };

  const startRoutine = (routine: Routine) => {
    // Jerarquía: Rutina -> Tipo de sesión
    // Si la rutina tiene exactamente 1 sesión, cargarla directo.
    // Si tiene más de 1, seguimos mostrando selector de sesión.
    setActiveRoutine(routine);
    if (routine.sessionRefs.length === 1) {
      startRoutineWithSessionRef(routine.sessionRefs[0]);
    } else {
      setEditingRoutine(routine);
      setRoutineMode('start');
      setShowRoutineModal(true);
    }
  };

  const startRoutineWithSessionRef = (ref: { type: 'default' | 'custom'; key: string }) => {
    if (ref.type === 'default') {
      setSelectedSession(ref.key as SessionType);
      // @ts-ignore known map
      setExercises(sessionExercises[ref.key as SessionType]);
    } else {
      const cs = customSessions.find(c => c.id === ref.key);
      if (cs) {
        // @ts-ignore
        setExercises((cs.exercises as any) || []);
        setSelectedSession(cs.name as any);
      }
    }
    setShowRoutineModal(false);
  };

  // Asignación de sesión a rutina
  const [pendingAssignRef, setPendingAssignRef] = useState<{ type: 'default' | 'custom'; key: string } | null>(null);
  const handleAssignToRoutine = (ref: { type: 'default' | 'custom'; key: string }) => {
    setPendingAssignRef(ref);
    setRoutineMode('list');
    setShowRoutineModal(true);
  };
  const assignRefToRoutine = async (routine: Routine) => {
    if (!pendingAssignRef) return;
    const exists = routine.sessionRefs.some(r => r.type === pendingAssignRef.type && r.key === pendingAssignRef.key);
    const updated: Routine = exists ? routine : { ...routine, sessionRefs: [...routine.sessionRefs, pendingAssignRef] };
    if (!exists) {
      await updateRoutine(updated);
    }
    setPendingAssignRef(null);
    setShowRoutineModal(false);
    const rs = await getRoutines();
    setRoutines(rs);
    Alert.alert('Rutina', 'Sesión asignada correctamente a la rutina.');
  };

  const handleAddSessionTypeToRoutine = (ref: { type: 'default' | 'custom'; key: string }) => {
    if (!editingRoutine) return;
    const exists = editingRoutine.sessionRefs.some(r => r.type === ref.type && r.key === ref.key);
    if (exists) {
      Alert.alert('Ya agregado', 'Ese tipo de sesión ya está en la rutina.');
      return;
    }
    setEditingRoutine({ ...editingRoutine, sessionRefs: [...editingRoutine.sessionRefs, ref] });
    setShowSessionTypePicker(false);
  };

  const handleFinishSession = async () => {
    const incompleteFields = getIncompleteFieldsCount ? getIncompleteFieldsCount() : 0;
    
    // Mensaje de confirmación antes de finalizar
    let confirmMessage = `¿Estás seguro de que quieres finalizar tu entrenamiento de ${selectedSession || 'Sesión libre'}?`;
    
    if (incompleteFields > 0) {
      confirmMessage += `\n\nTienes ${incompleteFields} campos sin completar.`;
    }

    Alert.alert(
      'Confirmar finalización',
      confirmMessage,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Finalizar sesión',
          onPress: () => {
            // Si se inició desde calendario, guardar directamente en esa fecha
            if (selectedDate) {
              const today = new Date(); today.setHours(0,0,0,0);
              const d = new Date(selectedDate); d.setHours(0,0,0,0);
              if (d.getTime() > today.getTime()) {
                Alert.alert('Fecha inválida', 'No podés guardar sesiones en el futuro.');
                return;
              }
              saveSessionWithDate(selectedDate);
              return;
            }
            // Caso normal: ofrecer Hoy / Otro día
            Alert.alert(
              '¿Dónde quieres guardar la sesión?',
              'Elige la fecha para guardar tu entrenamiento:',
              [
                { text: 'Cancelar', style: 'cancel' },
                { text: '📅 Hoy', onPress: () => saveSessionWithDate(new Date()) },
                {
                  text: '📅 Otro día',
                  onPress: () => {
                    setShowSideMenu(true);
                    setIsEditingHistoricalSession(true);
                  },
                },
              ]
            );
          },
        },
      ]
    );
  };

  // Función para guardar sesión con fecha específica
  const saveSessionWithDate = async (date: Date) => {
    try {
      // No permitir guardar en futuro
      const today = new Date(); today.setHours(0,0,0,0);
      const target = new Date(date); target.setHours(0,0,0,0);
      if (target.getTime() > today.getTime()) {
        Alert.alert('Fecha inválida', 'No podés guardar sesiones en el futuro.');
        return;
      }
      // Usar fecha local en formato YYYY-MM-DD para evitar desfases por huso horario/DST
      const yyyy = date.getFullYear();
      const mm = String(date.getMonth() + 1).padStart(2, '0');
      const dd = String(date.getDate()).padStart(2, '0');
      const fechaLocal = `${yyyy}-${mm}-${dd}`;
      const ejerciciosHist: ExerciseHistory[] = exercises.map((ex) => ({
        ejercicio: ex.ejercicio,
        musculo: ex.musculo,
        series: ex.series,
        fecha: fechaLocal,
      }));

      const sessionData = {
        fecha: fechaLocal,
        tipo: (selectedSession as string) || 'Sesión libre',
        duracion: sessionDuration || 0,
        ejercicios: ejerciciosHist,
        rutina: activeRoutine?.name || undefined,
        rutinaId: activeRoutine?.id || undefined,
      } as Omit<import('../utils/storage').SessionRecord, 'id'>;

              await saveSession(sessionData);
              
      // Después de guardar, limpiar y cerrar sin ofrecer exportación
      Alert.alert('Sesión guardada', `Tu sesión ha sido guardada para el ${date.toLocaleDateString('es-ES')}.`, [
        {
          text: 'Cerrar',
          onPress: () => {
            setExercises([]);
            setSelectedSession(null);
            setIsEditingHistoricalSession(false);
            if (onSessionFinish) onSessionFinish();
          },
        },
      ]);
            } catch (error) {
      Alert.alert('Error', 'No se pudo guardar la sesión.');
    }
  };

  // Función para exportar en formato CSV
  const exportToCSV = () => {
    if (exercises.length === 0) {
      Alert.alert('Sin datos', 'No hay ejercicios para exportar.');
      return;
    }

    const date = new Date().toLocaleDateString('es-ES');
    const time = new Date().toLocaleTimeString('es-ES');
    const durationMinutes = sessionDuration ? Math.floor(sessionDuration / 60) : 0;
    const durationSeconds = sessionDuration ? (sessionDuration % 60) : 0;
    
    let csvContent = `INFORME DE ENTRENAMIENTO\n`;
    csvContent += `================================\n`;
    csvContent += `Fecha: ${date}\n`;
    csvContent += `Hora: ${time}\n`;
    csvContent += `Tipo de sesión: ${selectedSession || 'Sesión libre'}\n`;
    csvContent += `Duración total: ${durationMinutes}:${durationSeconds.toString().padStart(2, '0')}\n`;
    csvContent += `Ejercicios realizados: ${exercises.length}\n`;
    csvContent += `================================\n\n`;
    csvContent += 'Ejercicio,Músculo,Serie,Repeticiones,Peso (kg),RIR\n';
    
    exercises.forEach((exercise, exerciseIndex) => {
      exercise.series.forEach((serie, serieIndex) => {
        csvContent += `"${exercise.ejercicio}","${exercise.musculo}",${serieIndex + 1},"${serie.reps}","${serie.kg}",${serie.rir || ''}\n`;
      });
    });

    // Exportar directamente sin confirmación adicional
    console.log('CSV Content:', csvContent);
    Alert.alert('Exportado', 'Datos CSV exportados correctamente.');
  };

  // Función para exportar en formato XLSX (simulado)
  const exportToXLSX = () => {
    if (exercises.length === 0) {
      Alert.alert('Sin datos', 'No hay ejercicios para exportar.');
      return;
    }

    const date = new Date().toLocaleDateString('es-ES');
    const time = new Date().toLocaleTimeString('es-ES');
    const durationMinutes = sessionDuration ? Math.floor(sessionDuration / 60) : 0;
    const durationSeconds = sessionDuration ? (sessionDuration % 60) : 0;
    
    let xlsxContent = `INFORME DE ENTRENAMIENTO - EXCEL\n`;
    xlsxContent += `================================\n`;
    xlsxContent += `Fecha: ${date}\n`;
    xlsxContent += `Hora: ${time}\n`;
    xlsxContent += `Tipo de sesión: ${selectedSession || 'Sesión libre'}\n`;
    xlsxContent += `Duración total: ${durationMinutes}:${durationSeconds.toString().padStart(2, '0')}\n`;
    xlsxContent += `Ejercicios realizados: ${exercises.length}\n`;
    xlsxContent += `================================\n\n`;
    xlsxContent += 'Ejercicio,Músculo,Serie,Repeticiones,Peso (kg),RIR\n';
    
    exercises.forEach((exercise, exerciseIndex) => {
      exercise.series.forEach((serie, serieIndex) => {
        xlsxContent += `"${exercise.ejercicio}","${exercise.musculo}",${serieIndex + 1},"${serie.reps}","${serie.kg}",${serie.rir || ''}\n`;
      });
    });

    // Exportar directamente sin confirmación adicional
    console.log('XLSX Content:', xlsxContent);
    Alert.alert('Exportado', 'Datos XLSX exportados correctamente.');
  };

  // Función para mostrar opciones de exportación
  const handleExport = () => {
    Alert.alert(
      'Exportar datos',
      'Selecciona el formato de exportación:',
      [
        {
          text: 'CSV (Tabla)',
          onPress: exportToCSV,
        },
        {
          text: 'XLSX (Excel)',
          onPress: exportToXLSX,
        },
        {
          text: 'Cancelar',
          style: 'cancel',
        },
      ],
      { cancelable: true }
    );
  };

  // ===== Export/Import Rutinas =====
  const exportRoutine = async (routine: Routine) => {
    try {
      const data = JSON.stringify(routine, null, 2);
      const fileUri = FileSystem.cacheDirectory + `rutina_${routine.name.replace(/\s+/g,'_')}.json`;
      await FileSystem.writeAsStringAsync(fileUri, data, { encoding: FileSystem.EncodingType.UTF8 });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, { mimeType: 'application/json', dialogTitle: 'Compartir rutina' });
      } else {
        Alert.alert('Exportación', 'Archivo de rutina guardado en caché');
      }
    } catch (e) {
      Alert.alert('Error', 'No se pudo exportar la rutina');
    }
  };

  const chooseRoutineToExport = () => {
    if (routines.length === 0) {
      Alert.alert('Rutinas', 'No hay rutinas para exportar', [{ text: 'OK' }], { cancelable: true });
      return;
    }
    const buttons = routines.map(r => ({ text: r.name, onPress: () => exportRoutine(r) }));
    buttons.push({ text: 'Cancelar', style: 'cancel' as const });
    Alert.alert('Exportar rutina', 'Elige una rutina', buttons, { cancelable: true });
  };

  const openExportImportMenu = () => {
    Alert.alert(
      'Exportar/Importar',
      'Elige una opción',
      [
        { text: 'Exportar rutina', onPress: chooseRoutineToExport },
        { text: 'Importar rutina', onPress: importRoutine },
        { text: 'Cancelar', style: 'cancel' },
      ],
      { cancelable: true }
    );
  };

  const importRoutine = async () => {
    try {
      Alert.alert(
        'Importar rutina',
        'Selecciona un archivo exportado desde Agujetas (.json).',
        [
          { text: 'Cancelar', style: 'cancel' },
          { text: 'Continuar', onPress: async () => {
            try {
              const res = await DocumentPicker.getDocumentAsync({ type: '*/*', multiple: false, copyToCacheDirectory: true });
              if (res.canceled) return;
              const asset = res.assets?.[0];
              if (!asset?.uri) {
                Alert.alert('Archivo inválido', 'No se pudo acceder al archivo seleccionado.');
                return;
              }
              // Leer siempre y validar por contenido, no solo por extensión
              let content = await FileSystem.readAsStringAsync(asset.uri, { encoding: FileSystem.EncodingType.UTF8 });
              // Quitar BOM si existe
              content = content.replace(/^\uFEFF/, '');
              let routineObj: any;
              try {
                routineObj = JSON.parse(content);
              } catch {
                Alert.alert('Formato inválido', 'El archivo no contiene un JSON válido.');
                return;
              }
              if (!routineObj?.name || !Array.isArray(routineObj?.sessionRefs)) {
                Alert.alert('Formato inválido', 'El archivo no parece ser una rutina válida.');
                return;
              }
              await saveRoutine({ name: routineObj.name, sessionRefs: routineObj.sessionRefs });
              const rs = await getRoutines();
              setRoutines(rs);
              Alert.alert('Importación', 'Rutina importada correctamente');
            } catch (err) {
              Alert.alert('Error', 'No se pudo importar la rutina');
            }
          } }
        ],
        { cancelable: true }
      );
    } catch (e) {
      Alert.alert('Error', 'No se pudo iniciar la importación');
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background, borderColor: theme.border }]}>
      <View style={styles.sessionRow}>
        <TouchableOpacity onPress={() => setShowSideMenu(true)} style={styles.hamburgerTouchable}>
          <View style={styles.hamburgerIcon}>
            <View style={[styles.hamburgerLine, { backgroundColor: isDarkMode ? '#FFFFFF' : '#4F766F' }]} />
            <View style={[styles.hamburgerLine, { backgroundColor: isDarkMode ? '#FFFFFF' : '#4F766F' }]} />
            <View style={[styles.hamburgerLine, { backgroundColor: isDarkMode ? '#FFFFFF' : '#4F766F' }]} />
          </View>
        </TouchableOpacity>
        <TouchableOpacity 
          style={[styles.finishButton, { backgroundColor: theme.buttonPrimary, marginRight: 4, flexShrink: 1, minWidth: 0 }]}
          onPress={() => { setRoutineMode('list'); setEditingRoutine(null); setPendingAssignRef(null); setShowRoutineModal(true); }}
        >
          <Text
            numberOfLines={1}
            adjustsFontSizeToFit
            minimumFontScale={0.8}
            style={[styles.finishButtonText, { color: theme.buttonText }]}
          >
            {activeRoutine ? `Rutina: ${activeRoutine.name}` : 'Rutina'}
          </Text>
          </TouchableOpacity>
        <TouchableOpacity 
          style={[styles.sessionButton, { backgroundColor: theme.buttonPrimary, marginLeft: 4, minWidth: 0 }]} 
          onPress={() => setShowSessionModal(true)}
        >
          <Text
            numberOfLines={1}
            adjustsFontSizeToFit
            minimumFontScale={0.7}
            ellipsizeMode="tail"
            style={[styles.sessionButtonText, { color: theme.buttonText }]}
          >
            {selectedSession ? `Sesión: ${getDisplaySessionName(String(selectedSession))}` : 'Tipo de sesión'}
          </Text>
        </TouchableOpacity>
        
        {selectedSession && (
          <TouchableOpacity 
            style={[styles.finishButton, { backgroundColor: theme.buttonSecondary, flexShrink: 1, minWidth: 0 }]}
            onPress={handleFinishSession}
          >
            <Text
              numberOfLines={1}
              adjustsFontSizeToFit
              minimumFontScale={0.85}
              style={[styles.finishButtonText, { color: theme.buttonText }]}
            >
              Finalizar entreno
            </Text>
          </TouchableOpacity>
        )}
      </View>



      {/* Modal para seleccionar tipo de sesión */}
      <Modal
        visible={showSessionModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowSessionModal(false)}
      >
        <TouchableWithoutFeedback onPress={() => setShowSessionModal(false)}>
        <View style={styles.modalOverlay}>
            <TouchableWithoutFeedback>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar tipo de sesión</Text>
            <ScrollView style={styles.sessionList}>
              {Object.keys(sessionExercises).filter(st => !deletedDefaultTypes.includes(st)).map((sessionType) => (
                <TouchableOpacity
                  key={sessionType}
                  style={[styles.sessionOption, { borderBottomColor: theme.border }]}
                  onPress={() => handleSessionSelect(sessionType as SessionType)}
                  onLongPress={() => {
                        // Abrir editor visual del tipo de sesión (misma lógica que rutinas)
                        setShowSessionModal(false);
                        openSessionTypeEditor(sessionType as SessionType);
                      }}
                >
                  <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>{sessionType}</Text>
                      <Text style={[styles.sessionOptionSubtext, { color: theme.textSecondary }]}> 
                        {getSessionTemplate(sessionType as SessionType).length} ejercicios
                  </Text>
                </TouchableOpacity>
              ))}
              {customSessions.map((cs) => (
                <TouchableOpacity
                  key={cs.id}
                  style={[styles.sessionOption, { borderBottomColor: theme.border }]}
                  onPress={() => {
                    setActiveRoutine(null);
                    setSelectedSession(cs.name as any);
                    // @ts-ignore plantilla a estructura Exercise
                    setExercises((cs.exercises as any) || []);
                    setShowSessionModal(false);
                  }}
                  onLongPress={() => {
                    openCustomSessionEditor(cs);
                  }}
                >
                  <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>{cs.name} (Personalizada)</Text>
                  <Text style={[styles.sessionOptionSubtext, { color: theme.textSecondary }]}>
                    {(cs.exercises?.length || 0)} ejercicios
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            
            <TouchableOpacity 
              style={[styles.cancelButton, { backgroundColor: theme.buttonPrimary }]}
              onPress={() => setShowCustomNameModal(true)}
            >
              <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>+ Agregar sesión personalizada</Text>
            </TouchableOpacity>
            <TouchableOpacity 
              style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
              onPress={() => setShowSessionModal(false)}
            >
              <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
            </TouchableOpacity>
          </View>
        </TouchableWithoutFeedback>
        </View>
        </TouchableWithoutFeedback>
      </Modal>

      {/* Modal Editor de tipo de sesión (misma estética que rutina) */}
      <Modal
        visible={showSessionTypeEditor}
        transparent
        animationType="slide"
        onRequestClose={() => setShowSessionTypeEditor(false)}
      >
        <TouchableWithoutFeedback onPress={() => setShowSessionTypeEditor(false)}>
          <View style={styles.modalOverlay}>
            <TouchableWithoutFeedback>
              <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }] }>
                <View style={{ paddingBottom: 8 }}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Editar tipo de sesión</Text>
                  <TextInput
                    placeholder="Nombre del tipo"
                    placeholderTextColor={theme.textSecondary}
                    value={editingTypeName}
                    onChangeText={setEditingTypeName}
                    editable={editingTypeKind === 'custom'}
                    style={[styles.customNameInput, { backgroundColor: theme.background, borderColor: theme.border, color: theme.textPrimary }]}
                  />
                  <TouchableOpacity style={[styles.cancelButton, { backgroundColor: theme.buttonPrimary }]} onPress={() => {
                    setEditingTypeExercises(prev => ([
                      ...prev,
                      { ejercicio: 'Nuevo ejercicio', musculo: '', series: [
                        { reps: '', kg: '', rir: undefined },
                        { reps: '', kg: '', rir: undefined },
                        { reps: '', kg: '', rir: undefined },
                      ]}
                    ]));
                  }}>
                    <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>+ Añadir ejercicio</Text>
                  </TouchableOpacity>
                </View>
                <View style={{ flexGrow: 1, minHeight: 0 }}>
                  <ScrollView>
                    {editingTypeExercises.map((ex, idx) => (
                      <View key={`${ex.ejercicio}-${idx}`} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 6 }}>
                        <View style={{ flex: 1 }}>
                          <Text style={{ color: theme.textPrimary, fontWeight: '600' }}>{ex.ejercicio}</Text>
                          <Text style={{ color: theme.textSecondary, fontSize: 12 }}>{ex.musculo}</Text>
                        </View>
                        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                          <TouchableOpacity onPress={() => {
                            if (idx === 0) return;
                            setEditingTypeExercises(prev => {
                              const arr = [...prev];
                              const tmp = arr[idx - 1];
                              arr[idx - 1] = arr[idx];
                              arr[idx] = tmp;
                              return arr;
                            });
                          }} style={{ marginRight: 8 }}>
                            <Text style={{ color: theme.textSecondary }}>↑</Text>
                          </TouchableOpacity>
                          <TouchableOpacity onPress={() => {
                            if (idx === editingTypeExercises.length - 1) return;
                            setEditingTypeExercises(prev => {
                              const arr = [...prev];
                              const tmp = arr[idx + 1];
                              arr[idx + 1] = arr[idx];
                              arr[idx] = tmp;
                              return arr;
                            });
                          }} style={{ marginRight: 8 }}>
                            <Text style={{ color: theme.textSecondary }}>↓</Text>
                          </TouchableOpacity>
                          <TouchableOpacity onPress={() => setEditingTypeExercises(prev => prev.filter((_, i) => i !== idx))}>
                            <Text style={{ color: 'red' }}>Eliminar</Text>
                          </TouchableOpacity>
                        </View>
                      </View>
                    ))}
                  </ScrollView>
                </View>
                <View style={styles.modalButtons}>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary, flex: 1 }]} onPress={() => setShowSessionTypeEditor(false)}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonPrimary, flex: 1 }]} onPress={async () => {
                    if (editingTypeKind === 'default') {
                      const exerciseHistory = editingTypeExercises.map(e => ({
                        ejercicio: e.ejercicio,
                        musculo: e.musculo,
                        series: e.series.map(s => ({ reps: s.reps || '', kg: s.kg || '', rir: s.rir })),
                        fecha: new Date().toISOString(),
                      }));
                      setSessionOverrides(prev => ({ ...prev, [editingTypeKey as SessionType]: exerciseHistory }));
                      await updateSessionTypeOverride(editingTypeKey as SessionType, exerciseHistory);
                      setShowSessionTypeEditor(false);
                    } else if (editingTypeKind === 'custom') {
                      const found = customSessions.find(cs => cs.id === editingTypeKey);
                      if (found) {
                        const updated = { ...found, name: editingTypeName, exercises: editingTypeExercises } as CustomSession;
                        await updateCustomSession(updated);
                        const next = await getCustomSessions();
                        setCustomSessions(next);
                      }
                      setShowSessionTypeEditor(false);
                    }
                  }}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Guardar</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: '#E57373', flex: 1 }]} onPress={async () => {
                    Alert.alert(
                      'Eliminar tipo de sesión',
                      `¿Seguro que deseas eliminar "${editingTypeName}"? Esta acción no se puede deshacer.`,
                      [
                        { text: 'Cancelar', style: 'cancel' },
                        { text: 'Eliminar', style: 'destructive', onPress: async () => {
                          if (editingTypeKind === 'default') {
                            await addDeletedSessionType(editingTypeKey as SessionType);
                            const deleted = await getDeletedSessionTypes();
                            setDeletedDefaultTypes(deleted);
                            setShowSessionTypeEditor(false);
                            return;
                          }
                          const ok = await deleteCustomSession(editingTypeKey);
                          if (ok) {
                            const next = await getCustomSessions();
                            setCustomSessions(next);
                            setShowSessionTypeEditor(false);
                          }
                        } }
                      ]
                    );
                  }}>
                    <Text style={[styles.modalButtonText, { color: '#fff' }]}>Eliminar</Text>
                  </TouchableOpacity>
                </View>
              </View>
            </TouchableWithoutFeedback>
          </View>
        </TouchableWithoutFeedback>
      </Modal>
      {/* Modal para nombre de sesión personalizada */}
      <Modal
        visible={showCustomNameModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowCustomNameModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Guardar sesión personalizada</Text>
            
            <TextInput
              style={[styles.customNameInput, { 
                backgroundColor: theme.background, 
                borderColor: theme.border, 
                color: theme.textPrimary 
              }]}
              placeholder="Nombre de la sesión"
              placeholderTextColor={theme.textSecondary}
              value={customSessionName}
              onChangeText={setCustomSessionName}
              autoFocus
            />
            
            <View style={styles.modalButtons}>
              <TouchableOpacity 
                style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                onPress={handleSaveCustomSession}
              >
                <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Guardar</Text>
              </TouchableOpacity>
              
              <TouchableOpacity 
                style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => setShowCustomNameModal(false)}
              >
                <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* Modal Rutina */}
      <Modal
        visible={showRoutineModal}
        transparent
        animationType="slide"
        onRequestClose={() => setShowRoutineModal(false)}
      >
        <TouchableWithoutFeedback onPress={() => setShowRoutineModal(false)}>
          <View style={styles.modalOverlay}>
            <TouchableWithoutFeedback>
              <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }] }>
            {routineMode === 'list' && (
              <>
                <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Rutinas</Text>
                {/* Lista de rutinas */}
                <ScrollView style={styles.sessionList}>
                  {routines.map((r) => (
                    <TouchableOpacity
                      key={r.id}
                      style={[styles.sessionOption, { borderBottomColor: theme.border }]}
                      onPress={() => (pendingAssignRef ? assignRefToRoutine(r) : startRoutine(r))}
                      onLongPress={() => {
                        setEditingRoutine(r);
                        setRoutineName(r.name);
                        setRoutineMode('edit');
                      }}
                    >
                      <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>{r.name}</Text>
                      <Text style={[styles.sessionOptionSubtext, { color: theme.textSecondary }]}>{r.sessionRefs.length} sesiones</Text>
                    </TouchableOpacity>
                  ))}
                </ScrollView>

                {/* Acciones debajo del listado */}
                <View style={styles.modalButtons}>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setShowRoutineModal(false)}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1} adjustsFontSizeToFit>Cancelar</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]} onPress={openNewRoutine}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1} adjustsFontSizeToFit>+ Crear rutina</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: '#4F766F' }]} onPress={openExportImportMenu}>
                    <Text style={[styles.modalButtonText, { color: '#fff' }]} numberOfLines={1} adjustsFontSizeToFit>Exportar/Importar</Text>
                  </TouchableOpacity>
                </View>
              </>
            )}

            {/* Modo crear/editar */}
            {(routineMode === 'create' || routineMode === 'edit') && (
              <View>
                <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>{routineMode === 'create' ? 'Crear rutina' : 'Editar rutina'}</Text>
                <TextInput
                  placeholder="Nombre de la rutina"
                  placeholderTextColor={theme.textSecondary}
                  value={routineName}
                  onChangeText={setRoutineName}
                  style={[styles.customNameInput, { backgroundColor: theme.background, borderColor: theme.border, color: theme.textPrimary }]}
                />
                {routineMode === 'edit' && (
                  <TouchableOpacity style={[styles.cancelButton, { backgroundColor: theme.buttonPrimary }]} onPress={() => setShowSessionTypePicker(true)}>
                    <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>+ Añadir tipo de sesión</Text>
                  </TouchableOpacity>
                )}
                {/* Listado resumido de sesiones incluidas */}
                {editingRoutine && editingRoutine.sessionRefs.length > 0 && (
                  <View style={{ maxHeight: 160 }}>
                    <ScrollView>
                      {editingRoutine.sessionRefs.map((ref, idx) => (
                        <View key={`${ref.type}-${ref.key}-${idx}`} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 6 }}>
                          <Text style={{ color: theme.textPrimary }}>
                            {ref.type === 'default' ? ref.key : (customSessions.find(c => c.id === ref.key)?.name || 'Personalizada')}
                          </Text>
                          <View style={{ flexDirection: 'row' }}>
                            <TouchableOpacity onPress={() => moveSessionRef(idx, -1)} style={{ marginRight: 8 }}>
                              <Text style={{ color: theme.textSecondary }}>↑</Text>
                            </TouchableOpacity>
                            <TouchableOpacity onPress={() => moveSessionRef(idx, 1)} style={{ marginRight: 8 }}>
                              <Text style={{ color: theme.textSecondary }}>↓</Text>
                            </TouchableOpacity>
                            <TouchableOpacity onPress={() => removeSessionRefAt(idx)}>
                              <Text style={{ color: 'red' }}>Eliminar</Text>
                            </TouchableOpacity>
                          </View>
                        </View>
                      ))}
                    </ScrollView>
                  </View>
                )}

                {/* Acciones */}
                <View style={styles.modalButtons}>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary, flex: 1 }]} onPress={() => { setRoutineMode('list'); setEditingRoutine(null); }}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonPrimary, flex: 1 }]} onPress={saveRoutineLocal}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Guardar</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: '#E57373', flex: 1 }]} onPress={async () => {
                    if (editingRoutine && editingRoutine.id) {
                      const ok = await deleteRoutine(editingRoutine.id);
                      if (ok) {
                        const rs = await getRoutines();
                        setRoutines(rs);
                        setShowRoutineModal(false);
                        setRoutineMode('list');
                      }
                    }
                  }}>
                    <Text style={[styles.modalButtonText, { color: '#fff' }]}>Eliminar</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}

            {/* Modo asignar: tocar rutina para asignar */}
            {routineMode === 'list' && pendingAssignRef && (
              <Text style={{ color: theme.textSecondary, textAlign: 'center', marginTop: 8 }}>Selecciona una rutina para asignar la sesión</Text>
            )}

            {/* Modo iniciar: elegir una sesión de la rutina */}
            {routineMode === 'start' && editingRoutine && (
              <View style={{ marginTop: 12 }}>
                <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Selecciona el tipo de sesión</Text>
                {editingRoutine.sessionRefs.length === 0 ? (
                  <Text style={{ color: theme.textSecondary, textAlign: 'center' }}>La rutina no tiene sesiones</Text>
                ) : (
                  <ScrollView style={{ maxHeight: 180 }}>
                    {editingRoutine.sessionRefs.map((ref, idx) => (
                      <TouchableOpacity key={`${ref.type}-${ref.key}-${idx}`} style={[styles.sessionOption, { borderBottomColor: theme.border }]} onPress={() => startRoutineWithSessionRef(ref)}>
                        <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>
                          {ref.type === 'default' ? ref.key : (customSessions.find(c => c.id === ref.key)?.name || 'Personalizada')}
                        </Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                )}
                <View style={styles.modalButtons}>
                  <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setShowRoutineModal(false)}>
                    <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}

            {/* Picker de tipo de sesión para añadir a la rutina */}
            <Modal visible={showSessionTypePicker} transparent animationType="slide" onRequestClose={() => setShowSessionTypePicker(false)}>
              <View style={styles.modalOverlay}>
                <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }] }>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Añadir tipo de sesión</Text>
                  <TextInput
                    placeholder="Buscar tipo de sesión"
                    placeholderTextColor={theme.textSecondary}
                    value={typeSearch}
                    onChangeText={setTypeSearch}
                    style={[styles.customNameInput, { backgroundColor: theme.background, borderColor: theme.border, color: theme.textPrimary }]}
                  />
                  <ScrollView style={{ maxHeight: 220 }}>
                    {Object.keys(sessionExercises).filter(st => !deletedDefaultTypes.includes(st as string)).map((st, idx) => (
                      <TouchableOpacity key={`${st}-${idx}`} style={[styles.sessionOption, { borderBottomColor: theme.border }]} onPress={() => handleAddSessionTypeToRoutine({ type: 'default', key: st })}>
                        <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>{st}</Text>
                        <Text style={[styles.sessionOptionSubtext, { color: theme.textSecondary }]}>{sessionExercises[st as SessionType].length} ejercicios</Text>
                      </TouchableOpacity>
                    ))}
                    {customSessions.map((cs, idx) => (
                      <TouchableOpacity key={`${cs.id}-${idx}`} style={[styles.sessionOption, { borderBottomColor: theme.border }]} onPress={() => handleAddSessionTypeToRoutine({ type: 'custom', key: cs.id })}>
                        <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>{cs.name} (Personalizada)</Text>
                        <Text style={[styles.sessionOptionSubtext, { color: theme.textSecondary }]}>{(cs.exercises?.length || 0)} ejercicios</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                  <View style={styles.modalButtons}>
                    <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setShowSessionTypePicker(false)}>
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>
              </View>
            </TouchableWithoutFeedback>
          </View>
        </TouchableWithoutFeedback>
      </Modal>

      {/* Menú lateral */}
      <SideMenu 
        visible={showSideMenu}
        onClose={() => setShowSideMenu(false)}
        isDarkMode={isDarkMode || false}
        onToggleDarkMode={onToggleDarkMode || (() => {})}
        onAddHistoricalSession={(date: Date) => handleAddHistoricalSession(date)}
        isSavingSession={isEditingHistoricalSession}
        onSaveSessionToDate={(date: Date) => saveSessionWithDate(date)}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 1,
    padding: 4,
  },
  sessionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  logo: {
    width: 40,
    height: 40,
    marginRight: 8,
  },
  hamburgerTouchable: {
    padding: 6,
    marginRight: 8,
  },
  hamburgerIcon: {
    width: 20,
    height: 14,
    justifyContent: 'space-between',
  },
  hamburgerLine: {
    height: 2,
    borderRadius: 1,
  },
  sessionButton: {
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
    flexGrow: 1,
    flexShrink: 1,
    marginHorizontal: 8,
  },
  sessionButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
  },
  finishButton: {
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
  },
  finishButtonText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  exportButton: {
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
    marginRight: 8,
    width: 40,
    height: 40,
    justifyContent: 'center',
  },
  exportButtonText: {
    fontWeight: '600',
    fontSize: 18,
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
    width: '86%',
    maxHeight: '80%',
    overflow: 'hidden',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 16,
    fontFamily: 'System',
  },
  sessionList: {
    maxHeight: 300,
  },
  sessionOption: {
    padding: 16,
    borderBottomWidth: 1,
  },
  sessionOptionText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  sessionOptionSubtext: {
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

  customNameInput: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    marginVertical: 16,
    fontSize: 16,
    fontFamily: 'System',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8 as any,
    marginTop: 16,
  },
  modalButton: {
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    flex: 1,
    minWidth: 0,
    minHeight: 44,
    justifyContent: 'center',
  },
  modalButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
    maxWidth: '100%',
  },
});

export default SessionSelector; 