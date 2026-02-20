import React, { useState, useEffect, useRef, useMemo } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal, ScrollView, Image, Animated, Alert, Dimensions, TouchableWithoutFeedback, Platform, TextInput, ActivityIndicator } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import {
  getSessions,
  deleteSession,
  getBodyWeights,
  addBodyWeight,
  deleteBodyWeight,
  BodyWeightRecord,
  getExerciseCatalog,
  getCustomSessions,
  getSessionTypeOverrides,
  getDeletedSessionTypes,
  getRoutines,
  importSessionsFromCSV,
} from '../utils/storage';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import * as XLSX from 'xlsx';
import { getTheme } from '../utils/theme';
import { predefinedExercises } from '../utils/exerciseCatalog';

interface Props {
  visible: boolean;
  onClose: () => void;
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
  onAddHistoricalSession?: (date: Date, selection?: HistoricalSessionSelection | string) => void;
  onAddSportSession?: (date: Date, sport: string, durationSeconds?: number) => void | Promise<void>;
  isSavingSession?: boolean;
  onSaveSessionToDate?: (date: Date) => void;
  onOpenAnalytics?: () => void;
  onOpenImageManager?: () => void;
}

type HistoricalSessionSelection = {
  kind: 'routine' | 'sessionType' | 'customSession';
  key: string;
  label?: string;
  routineId?: string;
  routineName?: string;
};

interface Session {
  id: string;
  tipo: string;
  fecha: string;
  ejercicios: Array<{
    ejercicio: string;
    musculo: string;
    series: Array<{ reps: string; kg: string; rir: number | undefined; tiempo?: string }>;
    fecha: string;
  }>;
  duracion?: number;
  rutina?: string;
  rutinaId?: string;
}

const SideMenu: React.FC<Props> = ({
  visible,
  onClose,
  isDarkMode,
  onToggleDarkMode,
  onAddHistoricalSession,
  onAddSportSession,
  isSavingSession,
  onSaveSessionToDate,
  onOpenAnalytics,
  onOpenImageManager,
}) => {
  const insets = useSafeAreaInsets();
  // Footer year no longer used
  // const currentYear = new Date().getFullYear();
  const theme = getTheme(isDarkMode);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedMonth, setSelectedMonth] = useState(new Date());
  const [isCalendarExpanded, setIsCalendarExpanded] = useState(true);
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [showDayDetails, setShowDayDetails] = useState(false);
  const [isContentReady, setIsContentReady] = useState(false);
  const [showExportModal, setShowExportModal] = useState(false);
  const [showBodyWeightModal, setShowBodyWeightModal] = useState(false);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [isExportingExerciseList, setIsExportingExerciseList] = useState(false);
  const [bodyWeights, setBodyWeights] = useState<BodyWeightRecord[]>([]);
  const [bwDate, setBwDate] = useState<Date>(new Date());
  const [showBwDatePicker, setShowBwDatePicker] = useState(false);
  const [bwWeight, setBwWeight] = useState<string>('');
  const [startDate, setStartDate] = useState(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [endDate, setEndDate] = useState(new Date());
  const [exportFormat, setExportFormat] = useState<'csv' | 'xlsx' | 'json' | null>(null);
  const [showStartDatePicker, setShowStartDatePicker] = useState(false);
  const [showEndDatePicker, setShowEndDatePicker] = useState(false);
  const [showOtherSportModal, setShowOtherSportModal] = useState(false);
  const [showSportDurationModal, setShowSportDurationModal] = useState(false);
  const [showDisciplineModal, setShowDisciplineModal] = useState(false);
  const [showGymRoutineModal, setShowGymRoutineModal] = useState(false);
  const [gymRoutineOptions, setGymRoutineOptions] = useState<HistoricalSessionSelection[]>([]);
  const [gymSessionOptions, setGymSessionOptions] = useState<HistoricalSessionSelection[]>([]);
  const [gymPickerStep, setGymPickerStep] = useState<'routine' | 'sessionType'>('routine');
  const [pendingGymRoutineSelection, setPendingGymRoutineSelection] = useState<HistoricalSessionSelection | null>(null);
  const [otherSportName, setOtherSportName] = useState('');
  const [sportDurationInput, setSportDurationInput] = useState('');
  const [pendingSportDate, setPendingSportDate] = useState<Date | null>(null);
  const [pendingSportName, setPendingSportName] = useState('');
  const toggleAnimation = useRef(new Animated.Value(isDarkMode ?22 : 0)).current;
  const slideAnimation = useRef(new Animated.Value(-300)).current;

  useEffect(() => {
    if (visible) {
      setIsContentReady(false);
      // Primero animar la entrada
      Animated.timing(slideAnimation, {
        toValue: 0,
        duration: 250,
        useNativeDriver: true,
      }).start(() => {
        // Despues de la animacion, cargar los datos
        loadSessions();
        loadBodyWeights();
        setIsContentReady(true);
      });
    } else {
      setIsContentReady(false);
      // Animar salida hacia la izquierda
      Animated.timing(slideAnimation, {
        toValue: -300,
        duration: 250,
        useNativeDriver: true,
      }).start();
    }
  }, [visible]);

  useEffect(() => {
    console.log('[debug] useEffect - showDayDetails:', showDayDetails, 'selectedDay:', selectedDay?.toLocaleDateString('es-ES'));
    if (showDayDetails && selectedDay) {
      console.log('[debug] Ejecutando displayDayDetails...');
      displayDayDetails();
    }
  }, [showDayDetails, selectedDay]);

  const loadSessions = async () => {
    try {
      console.log('[debug] Cargando sesiones...');
      const savedSessions = await getSessions();
      console.log('[debug] Sesiones cargadas:', savedSessions?.length || 0);
      setSessions(savedSessions || []);
    } catch (error) {
      console.error('Error cargando sesiones:', error);
    }
  };

  const loadBodyWeights = async () => {
    try {
      const list = await getBodyWeights();
      setBodyWeights(list);
    } catch (e) {
      console.error('Error cargando pesos corporales:', e);
    }
  };

  const getDaysInMonth = (date: Date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const firstDayOfMonth = new Date(year, month, 1).getDay();
    const mondayFirstOffset = (firstDayOfMonth + 6) % 7; // Mon=0 ... Sun=6
    
    const days = [];
    
    for (let i = 0; i < mondayFirstOffset; i++) {
      days.push(null);
    }
    
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(new Date(year, month, i));
    }
    
    return days;
  };

  const trainingDaySet = useMemo(() => {
    const set = new Set<string>();
    (sessions || []).forEach((session) => {
      if (!session?.fecha) return;
      if (session.fecha.includes('T')) {
        set.add(new Date(session.fecha).toLocaleDateString('en-CA'));
      } else {
        set.add(session.fecha);
      }
    });
    return set;
  }, [sessions]);

  const isTrainingDay = (date: Date) => {
    const dateString = date.toLocaleDateString('en-CA'); // Formato YYYY-MM-DD
    return trainingDaySet.has(dateString);
  };

  const isToday = (date: Date) => {
    const today = new Date();
    return date.getDate() === today.getDate() && 
           date.getMonth() === today.getMonth() && 
           date.getFullYear() === today.getFullYear();
  };

  const formatMonth = (date: Date) => {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return `${months[date.getMonth()]} ${date.getFullYear()}`;
  };

  const previousMonth = () => {
    setSelectedMonth(new Date(selectedMonth.getFullYear(), selectedMonth.getMonth() - 1, 1));
  };

  const nextMonth = () => {
    setSelectedMonth(new Date(selectedMonth.getFullYear(), selectedMonth.getMonth() + 1, 1));
  };

  const days = getDaysInMonth(selectedMonth);

  const handleToggleDarkMode = () => {
    const toValue = isDarkMode ?0 : 22;
    Animated.timing(toggleAnimation, {
      toValue,
      duration: 200,
      useNativeDriver: true,
    }).start();
    onToggleDarkMode();
  };

  const handleDayPress = (day: Date) => {
    console.log('[debug] Día presionado:', day.toLocaleDateString('es-ES'));
    // Bloquear dias futuros
    const today = new Date(); today.setHours(0,0,0,0);
    const d = new Date(day); d.setHours(0,0,0,0);
    const isFuture = d.getTime() > today.getTime();
    if (isFuture) {
      Alert.alert('Fecha inválida', 'No podés seleccionar fechas futuras.');
      return;
    }
    
          // Si estamos en modo "guardar sesión", guardar directamente
      if (isSavingSession && onSaveSessionToDate) {
        console.log('[debug] Guardando sesión para fecha:', day.toLocaleDateString('es-ES'));
        try {
          onSaveSessionToDate(day);
          onClose(); // Cerrar el SideMenu
        } catch (error) {
          console.error('[error] Error al guardar sesión:', error);
          Alert.alert('Error', 'No se pudo guardar la sesión. Inténtalo de nuevo.');
        }
        return;
      }
    
    // Comportamiento normal: mostrar detalles del día
    setSelectedDay(day);
    setShowDayDetails(true);
  };

  // Helper: obtener peso corporal para una fecha desde la lista local
  const getBodyWeightAtLocal = (date: Date): number | null => {
    if (!bodyWeights || bodyWeights.length === 0) return null;
    const target = date.getTime();
    let bestTime = -Infinity;
    let bestWeight: number | null = null;
    for (const record of bodyWeights) {
      const t = new Date(record.dateISO).getTime();
      if (t <= target && t > bestTime) {
        bestTime = t;
        bestWeight = record.weightKg;
      }
    }
    return bestWeight;
  };

  const handleDeleteSpecificSession = async (sessionToDelete: Session) => {
    Alert.alert(
      'Confirmar eliminación',
      `¿Estás seguro de que quieres eliminar la sesión "${sessionToDelete.tipo}"?`,
      [
        {
          text: 'Cancelar',
          style: 'cancel',
        },
        {
          text: 'Eliminar',
          style: 'destructive',
          onPress: async () => {
            try {
              await deleteSession(sessionToDelete.id);
              
              // Actualizar el estado local removiendo la sesión eliminada
              const updatedSessions = sessions.filter(session => session.id !== sessionToDelete.id);
              setSessions(updatedSessions);
              
              Alert.alert(
                'Sesión eliminada',
                `Se eliminó la sesión "${sessionToDelete.tipo}" correctamente.`,
                [{ text: 'OK' }]
              );
            } catch (error) {
              Alert.alert('Error', 'No se pudo eliminar la sesión. Inténtalo de nuevo.');
            }
          },
        },
      ]
    );
  };

  // Exportar sesiones de un dia (CSV o XLSX)
  const exportDaySessions = async (day: Date, format: 'csv' | 'xlsx') => {
    const dateString = day.toLocaleDateString('en-CA');
    if (!sessions || sessions.length === 0) {
      Alert.alert('Sin datos', 'No hay sesiones para exportar.');
      return;
    }

    const daySessions = sessions.filter(session => {
      if (!session.fecha) return false;
      // fecha guardada como YYYY-MM-DD (local)
      const sessionDate = session.fecha;
      return sessionDate === dateString;
    });

    if (daySessions.length === 0) {
      Alert.alert('Sin datos', 'No hay sesiones para exportar en este día.');
      return;
    }

    const header = [
      'fecha',
      'fecha_hora_iso',
      'mes',
      'semana_iso',
      'dia_semana',
      'rutina',
      'rutina_id',
      'duracion_hhmmss',
      'duracion_seg',
      'orden_ejercicio',
      'numero_serie',
      'musculo',
      'ejercicio',
      'ejercicio_id',
      'lado',
      'repeticiones',
      'peso_kg',
      'rir',
      'volumen_kg',
      'peso_corporal_kg',
    ];
    const rows: string[][] = [];
    const exerciseIdDictionary = new Map<string, string>();

    type LyftaPreindexedRow = { ejercicio?: string; imageId?: string; normalizedName?: string };
    type ManualMappingRow = { exercise_name?: string; image_id_selected?: string };
    const preindexed = (require('../assets/exercises-images/catalog.preindexed.json') as { exercises?: LyftaPreindexedRow[] }) || { exercises: [] };
    const nameIndex = (require('../assets/exercises-images/localImageNameIndex.json') as { nameToId?: Record<string, string> }) || {};
    const manualMappingRows = (require('../assets/exercises-images/custom_exercises_manual_mapping.json') as ManualMappingRow[]) || [];
    const customCatalog = await getExerciseCatalog();

    const exerciseIdByNormalized = new Map<string, string>();
    for (const row of preindexed.exercises || []) {
      if (row?.normalizedName && row?.imageId) {
        exerciseIdByNormalized.set(row.normalizedName, row.imageId);
      }
    }
    if (nameIndex?.nameToId) {
      for (const [normalized, id] of Object.entries(nameIndex.nameToId)) {
        if (!exerciseIdByNormalized.has(normalized)) {
          exerciseIdByNormalized.set(normalized, id);
        }
      }
    }

    const manualExerciseIdByNormalized = new Map<string, string>();
    manualMappingRows.forEach((row) => {
      const name = String(row?.exercise_name || '').trim();
      const imageId = String(row?.image_id_selected || '').match(/(\d{8})(?!.*\d)/)?.[1];
      if (!name || !imageId) return;
      manualExerciseIdByNormalized.set(normalizeExerciseNameForId(name), imageId);
    });

    const customExerciseIdByNormalized = new Map<string, string>();
    (customCatalog.items || []).forEach((item) => {
      const id = String(item.exerciseId || '').trim();
      if (!id) return;
      const primaryName = String(item.ejercicio || '').trim();
      if (primaryName) {
        customExerciseIdByNormalized.set(normalizeExerciseNameForId(primaryName), id);
      }
      const alias = String(item.aliasFor || '').trim();
      if (alias) {
        customExerciseIdByNormalized.set(normalizeExerciseNameForId(alias), id);
      }
    });

    const resolveExerciseId = (exerciseName: string): string => {
      const normalized = normalizeExerciseNameForId(exerciseName);
      if (!normalized) return '';
      if (manualExerciseIdByNormalized.has(normalized)) {
        return manualExerciseIdByNormalized.get(normalized) || '';
      }
      const direct = exerciseIdByNormalized.get(normalized);
      if (direct) return direct;
      if (normalized.includes('crunches')) {
        const alt = normalized.replace(/\bcrunches\b/g, 'crujidos');
        if (manualExerciseIdByNormalized.has(alt)) return manualExerciseIdByNormalized.get(alt) || '';
        const altId = exerciseIdByNormalized.get(alt);
        if (altId) return altId;
      }
      if (normalized.includes('crunch')) {
        const alt = normalized.replace(/\bcrunch\b/g, 'crujido');
        if (manualExerciseIdByNormalized.has(alt)) return manualExerciseIdByNormalized.get(alt) || '';
        const altId = exerciseIdByNormalized.get(alt);
        if (altId) return altId;
      }
      const customId = customExerciseIdByNormalized.get(normalized);
      if (customId) return customId;
      return '';
    };

    const toHHMMSS = (totalSeconds?: number) => {
      if (!totalSeconds || totalSeconds < 0) return '';
      const h = Math.floor(totalSeconds / 3600);
      const m = Math.floor((totalSeconds % 3600) / 60);
      const s = totalSeconds % 60;
      return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
    };

    const getMonthName = (d: Date) => d.toLocaleDateString('es-ES', { month: 'long' });
    const getISOWeek = (d: Date) => {
      const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
      const dayNum = date.getUTCDay() || 7; // 1..7 (Mon..Sun)
      date.setUTCDate(date.getUTCDate() + 4 - dayNum);
      const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
      const weekNo = Math.ceil((((date as any) - (yearStart as any)) / 86400000 + 1) / 7);
      return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
    };
    const getWeekday = (d: Date) => {
      const day = d.getDay(); // 0..6 (Sun..Sat)
      return day === 0 ?7 : day; // 1..7 (Mon..Sun)
    };

    daySessions.forEach((session, exerciseOrder) => {
      const jsDate = new Date(session.fecha);
      const fechaIso = jsDate.toISOString();
      const fecha = jsDate.toISOString().slice(0,10);
      const mes = getMonthName(jsDate);
      const semanaIso = getISOWeek(jsDate);
      const diaSemana = String(getWeekday(jsDate));
      const durHHMMSS = toHHMMSS(session.duracion);
      const durSeg = session.duracion ? String(session.duracion) : '';
      const bw = getBodyWeightAtLocal(jsDate);
      const pesoCorporal = bw != null ?String(bw) : '';

      if (!session.ejercicios || session.ejercicios.length === 0) {
        rows.push([
          fecha,
          fechaIso,
          mes,
          semanaIso,
          diaSemana,
          session.rutina || '',
          session.rutinaId || '',
          durHHMMSS,
          durSeg,
          String(exerciseOrder + 1),
          '0',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          pesoCorporal,
        ]);
        return;
      }

      session.ejercicios.forEach((ejercicio) => {
        const exerciseName = ejercicio.ejercicio || '';
        const ejercicioId = exerciseName ? resolveExerciseId(exerciseName) : '';
        if (exerciseName && ejercicioId && !exerciseIdDictionary.has(exerciseName)) {
          exerciseIdDictionary.set(exerciseName, ejercicioId);
        }
        const series = ejercicio.series && ejercicio.series.length > 0
          ?ejercicio.series
          : [{ reps: '', kg: '', rir: undefined }];

        series.forEach((serie, serieIndex) => {
          const rep = serie.reps || '';
          const peso = serie.kg || '';
          const rir = serie.rir?.toString() || '';
          const vol = rep && peso ?String(Number(rep) * Number(peso)) : '';

            rows.push([
              fecha,
              fechaIso,
              mes,
              semanaIso,
              diaSemana,
              session.rutina || '',
              session.rutinaId || '',
              durHHMMSS,
              durSeg,
              String(exerciseOrder + 1),
              String(serieIndex + 1),
              ejercicio.musculo || '',
              exerciseName,
              ejercicioId,
              '',
              rep,
              peso,
              rir,
              vol,
              pesoCorporal,
            ]);
        });
      });
    });

    const base = `sesion_${dateString}`;
    const filename = format === 'xlsx' ?`${base}.xlsx` : `${base}.csv`;
    const mimeType = format === 'xlsx' ?'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv';

    try {
      // Generar archivo en cache y compartir (flujo simple y confiable)
      const fileUri = FileSystem.cacheDirectory + filename;
      if (format === 'xlsx') {
        const wb = XLSX.utils.book_new();
        const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
        XLSX.utils.book_append_sheet(wb, ws, 'Sesión');
        const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
        await FileSystem.writeAsStringAsync(fileUri, wbout, { encoding: FileSystem.EncodingType.Base64 });
      } else {
        const csvContent = [header, ...rows].map(r => r.map(f => {
          const needsQuotes = /[",\n]/.test(f);
          const escaped = f.replace(/"/g, '""');
          return needsQuotes ?`"${escaped}"` : escaped;
        }).join(',')).join('\n');
        await FileSystem.writeAsStringAsync(fileUri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });

        if (exerciseIdDictionary.size > 0) {
          const dictHeader = ['ejercicio', 'ejercicio_id'];
          const dictRows = Array.from(exerciseIdDictionary.entries())
            .sort((a, b) => a[0].localeCompare(b[0], 'es', { sensitivity: 'base' }))
            .map(([name, id]) => [name, id]);
          const dictCsv = [dictHeader, ...dictRows]
            .map(r => r.map(escapeCsvField).join(','))
            .join('\n');
          const dictUri = FileSystem.cacheDirectory + `${base}_ejercicios.csv`;
          await FileSystem.writeAsStringAsync(dictUri, dictCsv, { encoding: FileSystem.EncodingType.UTF8 });
          console.log(`[export] Diccionario de ejercicios: ${dictUri}`);
        }
      }
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, { mimeType, dialogTitle: 'Exportar sesión' });
      } else {
        Alert.alert('Exportación', `Archivo generado en cache: ${fileUri}`);
      }
    } catch (e) {
      console.error('Error exportando sesión:', e);
      Alert.alert('Error', 'No se pudo exportar la sesión.');
    }
  };

  const handleDeleteDaySessions = (day: Date) => {
    const dateString = day.toLocaleDateString('en-CA');
    const daySessions = sessions.filter(session => {
      // Verificar que session.fecha existe y no es null/undefined
      if (!session.fecha) return false;
      
      let sessionDate;
      if (session.fecha.includes('T')) {
        sessionDate = new Date(session.fecha).toLocaleDateString('en-CA');
      } else {
        sessionDate = session.fecha;
      }
      return sessionDate === dateString;
    });

    if (daySessions.length === 1) {
      // Si hay solo una sesión, eliminarla directamente
      handleDeleteSpecificSession(daySessions[0]);
    } else {
      // Si hay múltiples sesiones, mostrar selector
      const buttons: any[] = daySessions.map((session, index) => ({
        text: `${session.tipo}`,
        onPress: () => handleDeleteSpecificSession(session)
      }));
      
      buttons.push({
        text: 'Eliminar todas',
        onPress: async () => {
          Alert.alert(
            'Confirmar eliminación múltiple',
            `¿Estás seguro de que quieres eliminar las ${daySessions.length} sesiones del día?`,
            [
              { text: 'Cancelar', style: 'cancel' },
              {
                text: 'Eliminar todas',
                style: 'destructive',
                onPress: async () => {
                  try {
                    for (const session of daySessions) {
                      await deleteSession(session.id);
                    }
                    
                    const updatedSessions = sessions.filter(session => 
                      !daySessions.some(daySession => daySession.id === session.id)
                    );
                    setSessions(updatedSessions);
                    
                    Alert.alert(
                      'Sesiones eliminadas',
                      `Se eliminaron las ${daySessions.length} sesiones correctamente.`,
                      [{ text: 'OK' }]
                    );
                  } catch (error) {
                    Alert.alert('Error', 'No se pudieron eliminar las sesiones. Inténtalo de nuevo.');
                  }
                }
              }
            ]
          );
        }
      });
      
      buttons.push({ text: 'Cancelar', style: 'cancel' });

      Alert.alert(
        'Seleccionar sesión a eliminar',
        `Qué sesión del ${day.toLocaleDateString('es-ES', { day: 'numeric', month: 'long' })} quieres eliminar?`,
        buttons
      );
    }
  };

  const handleStartDateChange = (event: any, selectedDate?: Date) => {
    setShowStartDatePicker(false);
    if (selectedDate) {
      setStartDate(selectedDate);
    }
  };

  const handleEndDateChange = (event: any, selectedDate?: Date) => {
    setShowEndDatePicker(false);
    if (selectedDate) {
      setEndDate(selectedDate);
    }
  };

  const normalizeExerciseKey = (name: string): string =>
    name
      .trim()
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\s+/g, ' ');

  const normalizeLabel = (value: string): string =>
    String(value || '')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/\s+/g, ' ')
      .trim();

  const normalizeExerciseNameForId = (text: string): string =>
    String(text || '')
      .replace(/([a-z])([A-Z])/g, '$1 $2')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[-_/]+/g, ' ')
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\bextensiones?\s+de\s+/g, 'extension ')
      .replace(/\bextensiones?\s+/g, 'extension ')
      .replace(/^empuje de cadera\b/g, 'hip thrust')
      .replace(/^empuje_de_cadera\b/g, 'hip_thrust')
      .replace(/\s+/g, ' ')
      .trim();

  const escapeCsvField = (value: string): string => {
    const text = value ?? '';
    if (/[",\n]/.test(text)) {
      return `"${text.replace(/"/g, '""')}"`;
    }
    return text;
  };

  const exportExerciseListSnapshot = async (format: 'json' | 'csv' | 'csv_fast') => {
    const showExportingOverlay = format !== 'csv_fast';
    if (showExportingOverlay) {
      setIsExportingExerciseList(true);
    }
    try {
      const catalog = await getExerciseCatalog();
      let customSessions: any[] = [];
      let sessionTypeOverrides: any = {};
      let deletedSessionTypes: string[] = [];
      let routines: any[] = [];
      const isFastMode = format === 'csv_fast';

      if (!isFastMode) {
        [customSessions, sessionTypeOverrides, deletedSessionTypes, routines] = await Promise.all([
          getCustomSessions(),
          getSessionTypeOverrides(),
          getDeletedSessionTypes(),
          getRoutines(),
        ]);
      }

      type LyftaCatalogRow = { id?: string | number; name?: string; body_part?: string };
      type ManualMappingRow = { exercise_name?: string; image_id_selected?: string };

      const lyftaRows = (require('../assets/exercises-images/catalog.es.json') as LyftaCatalogRow[]) || [];
      const manualMappingRows = (require('../assets/exercises-images/custom_exercises_manual_mapping.json') as ManualMappingRow[]) || [];

      const mapLyftaBodyPartToMuscle = (bodyPart: string): string => {
        const value = normalizeExerciseKey(bodyPart || '');
        if (!value || value === 'n u l l') return 'General';
        if (value.includes('chest')) return 'Pectoral';
        if (value.includes('back')) return 'Espalda';
        if (value.includes('shoulders')) return 'Hombros';
        if (value.includes('biceps')) return 'Biceps';
        if (value.includes('triceps')) return 'Triceps';
        if (value.includes('quadriceps')) return 'Cuadriceps';
        if (value.includes('hamstrings')) return 'Femoral';
        if (value.includes('thighs')) return 'Piernas';
        if (value.includes('hips')) return 'Gluteos';
        if (value.includes('calves')) return 'Gemelos';
        if (value.includes('waist') || value.includes('abs')) return 'Abdomen';
        if (value.includes('forearms')) return 'Antebrazos';
        if (value.includes('neck')) return 'Cuello';
        if (value.includes('cardio')) return 'Aerobico';
        if (value.includes('full body')) return 'General';
        return 'General';
      };

      const extractImageId = (value: string): string | null => {
        const v = (value || '').trim();
        if (!v || v === 'lyfta_entry_without_local_image' || v === 'not_in_lyfta_catalog') return null;
        const match = v.match(/(\d{8})(?!.*\d)/);
        return match?.[1] || (/^\d{8}$/.test(v) ? v : null);
      };

      const manualImageIdByExercise = new Map<string, string>();
      manualMappingRows.forEach((row) => {
        const exerciseName = (row.exercise_name || '').trim();
        const imageId = extractImageId(row.image_id_selected || '');
        if (!exerciseName || !imageId) return;
        manualImageIdByExercise.set(normalizeExerciseKey(exerciseName), imageId);
      });

      type SnapshotRow = {
        key: string;
        ejercicio: string;
        musculo: string;
        imageId?: string;
        imageUri?: string;
        createdAtISO?: string;
        inLyftaCatalog: boolean;
        inPredefined: boolean;
        inCatalog: boolean;
        inHistory: boolean;
        inCustomSession: boolean;
        inSessionOverride: boolean;
        usageCount: number;
        lastUsedDate: string;
      };

      const rowsByKey = new Map<string, SnapshotRow>();
      const upsertRow = (
        ejercicioRaw: string,
        musculoRaw: string,
        source: 'lyfta' | 'predefined' | 'catalog' | 'history' | 'customSession' | 'override',
        extra?: { imageUri?: string; imageId?: string; createdAtISO?: string; date?: string },
        keyOverride?: string
      ) => {
        const ejercicio = (ejercicioRaw || '').trim();
        if (!ejercicio) return;
        const musculo = (musculoRaw || '').trim() || 'General';
        const key = normalizeExerciseKey(keyOverride || ejercicio);
        if (!key) return;

        const existing = rowsByKey.get(key);
        const row: SnapshotRow = existing || {
          key,
          ejercicio,
          musculo,
          inLyftaCatalog: false,
          inPredefined: false,
          inCatalog: false,
          inHistory: false,
          inCustomSession: false,
          inSessionOverride: false,
          usageCount: 0,
          lastUsedDate: '',
        };

        if (!existing) {
          rowsByKey.set(key, row);
        } else if (source !== 'history' && source !== 'override') {
          row.ejercicio = ejercicio;
          row.musculo = musculo;
        }

        if (source === 'lyfta') row.inLyftaCatalog = true;
        if (source === 'predefined') row.inPredefined = true;
        if (source === 'catalog') row.inCatalog = true;
        if (source === 'history') row.inHistory = true;
        if (source === 'customSession') row.inCustomSession = true;
        if (source === 'override') row.inSessionOverride = true;

        if (extra?.imageId && !row.imageId) row.imageId = extra.imageId;
        if (extra?.imageUri && !row.imageUri) row.imageUri = extra.imageUri;
        if (extra?.createdAtISO && !row.createdAtISO) row.createdAtISO = extra.createdAtISO;

        if (source === 'history') {
          row.usageCount += 1;
          if (extra?.date && (!row.lastUsedDate || extra.date > row.lastUsedDate)) {
            row.lastUsedDate = extra.date;
          }
        }
      };

      // Fuente amplia: catalogo interno de ejercicios (Lyfta local)
      lyftaRows.forEach((row) => {
        const ejercicio = (row?.name || '').trim();
        if (!ejercicio) return;
        const imageId = String(row?.id ?? '').replace(/\D/g, '').padStart(8, '0').slice(-8);
        upsertRow(ejercicio, mapLyftaBodyPartToMuscle(String(row?.body_part || '')), 'lyfta', {
          imageId: imageId || undefined,
          imageUri: imageId ? `app-image://${imageId}` : undefined,
        });
      });

      // Fuente base predefinida
      predefinedExercises.forEach((ex) => upsertRow(ex.ejercicio, ex.musculo, 'predefined'));

      // Catalogo persistente con imagen
      catalog.items.forEach((item) =>
        upsertRow(
          item.ejercicio,
          item.musculo,
          'catalog',
          {
            imageId: item.imageUri?.startsWith('app-image://') ? item.imageUri.replace('app-image://', '') : undefined,
            imageUri: item.imageUri,
            createdAtISO: item.createdAtISO,
          },
          item.aliasFor
        )
      );

      if (!isFastMode) {
        // Histórico de sesiones guardadas
        sessions.forEach((session) => {
          (session.ejercicios || []).forEach((ex) => {
            upsertRow(ex.ejercicio, ex.musculo, 'history', { date: session.fecha });
          });
        });

        // Sesiones personalizadas
        customSessions.forEach((cs: any) => {
          (cs.exercises || []).forEach((ex: any) => {
            upsertRow(ex?.ejercicio || '', ex?.musculo || '', 'customSession');
          });
        });

        // Overrides de tipos de sesión
        Object.values(sessionTypeOverrides || {}).forEach((arr: any) => {
          (arr || []).forEach((ex: any) => {
            upsertRow(ex?.ejercicio || '', ex?.musculo || '', 'override');
          });
        });
      }

      // Overrides manuales de imagen sobre el conjunto final
      rowsByKey.forEach((row) => {
        const manualImageId = manualImageIdByExercise.get(row.key);
        if (!manualImageId) return;
        row.imageId = manualImageId;
        row.imageUri = `app-image://${manualImageId}`;
      });

      const rows = Array.from(rowsByKey.values()).sort((a, b) => a.ejercicio.localeCompare(b.ejercicio, 'es'));
      const baseName = `catalogo_ejercicios_${new Date().toISOString().slice(0, 10)}`;
      const filename = format === 'json'
        ? `${baseName}.json`
        : format === 'csv_fast'
          ? `${baseName}_rápido.csv`
          : `${baseName}.csv`;
      const mimeType = format === 'json' ? 'application/json' : 'text/csv';
      let fileContents = '';

      if (format === 'json') {
        fileContents = JSON.stringify(
          {
            generatedAtISO: new Date().toISOString(),
            totals: {
              exercises: rows.length,
              lyftaCatalogRows: lyftaRows.length,
              sessions: sessions.length,
              customSessions: customSessions.length,
              routines: routines.length,
              deletedDefaultSessionTypes: deletedSessionTypes.length,
            },
            rows,
            routines: isFastMode ? [] : routines,
            customSessions: isFastMode ? [] : customSessions,
            sessionTypeOverrides: isFastMode ? {} : sessionTypeOverrides,
            deletedDefaultSessionTypes: isFastMode ? [] : deletedSessionTypes,
          },
          null,
          2
        );
      } else {
        const header = [
          'exercise_key',
          'ejercicio',
          'musculo',
          'image_id',
          'image_uri',
          'created_at_iso',
          'in_lyfta_catalog',
          'in_predefined',
          'in_catalog',
          'in_history',
          'in_custom_session',
          'in_session_override',
          'usage_count',
          'last_used_date',
        ];
        const lines = rows.map((r) =>
          [
            r.key,
            r.ejercicio,
            r.musculo,
            r.imageId || '',
            r.imageUri || '',
            r.createdAtISO || '',
            r.inLyftaCatalog ? '1' : '0',
            r.inPredefined ? '1' : '0',
            r.inCatalog ? '1' : '0',
            r.inHistory ? '1' : '0',
            r.inCustomSession ? '1' : '0',
            r.inSessionOverride ? '1' : '0',
            String(r.usageCount),
            r.lastUsedDate || '',
          ]
            .map(escapeCsvField)
            .join(',')
        );
        fileContents = `\uFEFF${[header.join(','), ...lines].join('\n')}`;
      }

      // Exportar desde cache + compartir: más rápido y más compatible en Android.
      const fileUri = `${FileSystem.cacheDirectory}${filename}`;
      await FileSystem.writeAsStringAsync(fileUri, fileContents, { encoding: FileSystem.EncodingType.UTF8 });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, {
          mimeType,
          dialogTitle: isFastMode ? 'Exportar lista de ejercicios (CSV rápido)' : 'Exportar lista de ejercicios',
        });
      } else {
        Alert.alert('Exportacion completada', `Archivo generado en cache: ${fileUri}`);
      }
    } catch (error) {
      console.error('Error exportando lista de ejercicios:', error);
      Alert.alert('Error', 'No se pudo exportar la lista de ejercicios.');
    } finally {
      if (showExportingOverlay) {
        setIsExportingExerciseList(false);
      }
    }
  };
  const exportHistoricalData = async () => {
    if (!exportFormat) {
      Alert.alert('Formato requerido', 'Por favor selecciona un formato de exportación.');
      return;
    }

    const start = new Date(startDate); start.setHours(0,0,0,0);
    const end = new Date(endDate); end.setHours(23,59,59,999);
    const filteredSessions = sessions.filter(session => {
      const [y,m,d] = session.fecha.split('-').map(Number);
      const sessionDate = new Date(y, (m || 1) - 1, d || 1);
      return sessionDate >= start && sessionDate <= end;
    });

    const header = ['fecha','fecha_hora_iso','mes','semana_iso','dia_semana','rutina','rutina_id','duracion_hhmmss','duracion_seg','orden_ejercicio','numero_serie','musculo','ejercicio','lado','repeticiones','peso_kg','rir','volumen_kg','peso_corporal_kg'];
    const rows: string[][] = [];

     const toHHMMSS = (totalSeconds?: number) => {
       if (!totalSeconds || totalSeconds < 0) return '';
       const h = Math.floor(totalSeconds / 3600);
       const m = Math.floor((totalSeconds % 3600) / 60);
       const s = totalSeconds % 60;
       return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
     };

     const getMonthName = (d: Date) => d.toLocaleDateString('es-ES', { month: 'long' });
     const getISOWeek = (d: Date) => {
       const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
       const dayNum = date.getUTCDay() || 7;
       date.setUTCDate(date.getUTCDate() + 4 - dayNum);
       const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
       const weekNo = Math.ceil((((date as any) - (yearStart as any)) / 86400000 + 1) / 7);
       return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
     };
     const getWeekday = (d: Date) => {
       const day = d.getDay();
       return day === 0 ?7 : day;
     };

     filteredSessions.forEach((session, exerciseOrder) => {
       const [sy,sm,sd] = session.fecha.split('-').map(Number);
       const jsDate = new Date(sy, (sm || 1) - 1, sd || 1);
       const fecha = session.fecha;
       const tz = -jsDate.getTimezoneOffset();
       const sign = tz >= 0 ?'+' : '-';
       const hh = String(Math.floor(Math.abs(tz) / 60)).padStart(2, '0');
       const mm = String(Math.abs(tz) % 60).padStart(2, '0');
       const fechaIso = `${fecha}T00:00:00${sign}${hh}:${mm}`;
       const mes = getMonthName(jsDate);
       const semanaIso = getISOWeek(jsDate);
       const diaSemana = String(getWeekday(jsDate));
       const durHHMMSS = toHHMMSS(session.duracion);
      const durSeg = session.duracion ? String(session.duracion) : '';
       const bw = getBodyWeightAtLocal(jsDate);
       const pesoCorporal = bw != null ?String(bw) : '';

       if (!session.ejercicios || session.ejercicios.length === 0) {
         rows.push([
           fecha,
           fechaIso,
           mes,
           semanaIso,
           diaSemana,
           session.rutina || '',
           session.rutinaId || '',
           durHHMMSS,
           durSeg,
           String(exerciseOrder + 1),
           '0',
           '',
           '',
           '',
           '',
           '',
           '',
           '',
           pesoCorporal,
         ]);
         return;
       }

       session.ejercicios.forEach((ejercicio) => {
         const series = ejercicio.series && ejercicio.series.length > 0
           ?ejercicio.series
           : [{ reps: '', kg: '', rir: undefined }];

         series.forEach((serie, serieIndex) => {
           const rep = serie.reps || '';
           const peso = serie.kg || '';
           const rir = serie.rir?.toString() || '';
           const vol = rep && peso ?String(Number(rep) * Number(peso)) : '';

           const row = [
             fecha,
             fechaIso,
             mes,
             semanaIso,
             diaSemana,
             session.rutina || '',
             session.rutinaId || '',
             durHHMMSS,
             durSeg,
             String(exerciseOrder + 1),
             String(serieIndex + 1),
             ejercicio.musculo || '',
             ejercicio.ejercicio || '',
             '',
             rep,
             peso,
             rir,
             vol,
             pesoCorporal,
           ];
           rows.push(row);
         });
       });
     });

    const csvContent = [header, ...rows].map(r => r.map(f => {
      const needsQuotes = /[",\n]/.test(f);
      const escaped = f.replace(/"/g, '""');
      return needsQuotes ?`"${escaped}"` : escaped;
    }).join(',')).join('\n');
    const jsonRows = rows.map((row) =>
      Object.fromEntries(header.map((column, index) => [column, row[index] ?? '']))
    );
    const jsonContent = JSON.stringify(
      {
        schema: 'agujetas-historico-v1',
        exportedAtISO: new Date().toISOString(),
        columns: header,
        rows: jsonRows,
      },
      null,
      2
    );

    const fileBase = `historico_${startDate.toISOString().slice(0,10)}_a_${endDate.toISOString().slice(0,10)}`;
    const filename =
      exportFormat === 'xlsx' ?`${fileBase}.xlsx` :
      exportFormat === 'json' ?`${fileBase}.json` :
      `${fileBase}.csv`;
    const mimeType =
      exportFormat === 'xlsx' ?'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' :
      exportFormat === 'json' ?'application/json' :
      'text/csv';

    try {
      if (Platform.OS === 'android' && FileSystem.StorageAccessFramework) {
        const perm = await FileSystem.StorageAccessFramework.requestDirectoryPermissionsAsync();
        if (perm.granted && perm.directoryUri) {
          const uri = await FileSystem.StorageAccessFramework.createFileAsync(perm.directoryUri, filename, mimeType);
          if (exportFormat === 'xlsx') {
            const wb = XLSX.utils.book_new();
            const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
            XLSX.utils.book_append_sheet(wb, ws, 'Histórico');
            const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
            await FileSystem.writeAsStringAsync(uri, wbout, { encoding: FileSystem.EncodingType.Base64 });
          } else if (exportFormat === 'json') {
            await FileSystem.writeAsStringAsync(uri, jsonContent, { encoding: FileSystem.EncodingType.UTF8 });
          } else {
            await FileSystem.writeAsStringAsync(uri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });
          }
          Alert.alert('Exportacion completada', `Archivo guardado: ${filename}`, [{ text: 'OK', onPress: () => setShowExportModal(false) }]);
          return;
        }
        // Si usuario no otorga permisos, fallback a compartir
      }

      // Fallback: compartir archivo desde cache
      const fileUri = FileSystem.cacheDirectory + filename;
      if (exportFormat === 'xlsx') {
        const wb = XLSX.utils.book_new();
        const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
        XLSX.utils.book_append_sheet(wb, ws, 'Histórico');
        const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
        await FileSystem.writeAsStringAsync(fileUri, wbout, { encoding: FileSystem.EncodingType.Base64 });
      } else if (exportFormat === 'json') {
        await FileSystem.writeAsStringAsync(fileUri, jsonContent, { encoding: FileSystem.EncodingType.UTF8 });
      } else {
        await FileSystem.writeAsStringAsync(fileUri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });
      }
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, { mimeType, dialogTitle: 'Exportar histórico de sesiones' });
        setShowExportModal(false);
      } else {
        Alert.alert('Exportacion', `Archivo generado en cache: ${fileUri}`);
      }
    } catch (e) {
      console.error('Error exportando historico:', e);
      Alert.alert('Error', 'No se pudo exportar el historico.');
    }
  };

  const importHistoricalData = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['*/*'],
        copyToCacheDirectory: true,
        multiple: false,
      });

      if (result.canceled || !result.assets?.length) return;

      const picked = result.assets[0];
      const uri = picked.uri;
      const lowerName = (picked.name || '').toLowerCase();
      const mime = (picked.mimeType || '').toLowerCase();
      const isCsv =
        lowerName.endsWith('.csv') ||
        mime.includes('text/csv') ||
        mime.includes('application/csv') ||
        mime.includes('text/plain') ||
        mime.includes('octet-stream');
      const isJson =
        lowerName.endsWith('.json') ||
        mime.includes('/json');
      const isXlsx =
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.xls') ||
        mime.includes('spreadsheetml') ||
        mime.includes('excel');
      if (!isCsv && !isJson && !isXlsx) {
        Alert.alert('Archivo invalido', 'Solo se admiten archivos CSV, XLSX o JSON.');
        return;
      }

      let rows: any[] = [];
      if (isJson) {
        const jsonText = await FileSystem.readAsStringAsync(uri, {
          encoding: FileSystem.EncodingType.UTF8,
        });
        const parsed = JSON.parse(jsonText);
        if (Array.isArray(parsed)) {
          rows = parsed;
        } else if (Array.isArray(parsed?.rows)) {
          if (Array.isArray(parsed.columns) && parsed.rows.length > 0 && Array.isArray(parsed.rows[0])) {
            rows = parsed.rows.map((values: any[]) =>
              Object.fromEntries(parsed.columns.map((column: string, index: number) => [column, values[index] ?? '']))
            );
          } else {
            rows = parsed.rows;
          }
        } else {
          Alert.alert('Archivo invalido', 'El JSON no tiene filas en formato reconocido.');
          return;
        }
      } else if (isXlsx) {
        const base64 = await FileSystem.readAsStringAsync(uri, {
          encoding: FileSystem.EncodingType.Base64,
        });
        const workbook = XLSX.read(base64, { type: 'base64' });
        const firstSheetName = workbook.SheetNames[0];
        if (!firstSheetName) {
          Alert.alert('Archivo invalido', 'El archivo no tiene hojas.');
          return;
        }
        rows = XLSX.utils.sheet_to_json(workbook.Sheets[firstSheetName], { defval: '' }) as any[];
      } else {
        const csvText = await FileSystem.readAsStringAsync(uri, {
          encoding: FileSystem.EncodingType.UTF8,
        });
        const workbook = XLSX.read(csvText, { type: 'string' });
        const firstSheetName = workbook.SheetNames[0];
        if (!firstSheetName) {
          Alert.alert('Archivo invalido', 'El archivo no tiene datos.');
          return;
        }
        rows = XLSX.utils.sheet_to_json(workbook.Sheets[firstSheetName], { defval: '' }) as any[];
      }

      if (!rows.length) {
        Alert.alert('Sin datos', 'El archivo esta vacio o no tiene filas validas.');
        return;
      }

      const { imported, skipped } = await importSessionsFromCSV(rows);
      await loadSessions();
      setShowSettingsModal(false);
      Alert.alert(
        'Importacion completada',
        `Sesiones importadas: ${imported}\nFilas omitidas: ${skipped}`
      );
    } catch (error) {
      console.error('Error importando historico:', error);
      Alert.alert('Error', 'No se pudo importar el historico.');
    }
  };

  const openSportDurationModal = (day: Date, sport: string) => {
    setPendingSportDate(day);
    setPendingSportName(sport);
    setSportDurationInput('');
    setShowSportDurationModal(true);
  };

  const formatSportDurationInput = (raw: string): string => {
    const digits = raw.replace(/\D/g, '').slice(0, 6);
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) {
      const padded = digits.padStart(4, '0');
      return `${padded.slice(0, 2)}:${padded.slice(2)}`;
    }
    const padded = digits.padStart(6, '0');
    return `${padded.slice(0, 2)}:${padded.slice(2, 4)}:${padded.slice(4)}`;
  };

  const parseSportDurationToSeconds = (value: string): number | undefined | null => {
    const numbers = value.replace(/\D/g, '');
    if (!numbers) return undefined;
    const padded = numbers.padStart(6, '0').slice(-6);
    const hh = Number(padded.slice(0, 2)) || 0;
    const mm = Number(padded.slice(2, 4)) || 0;
    const ss = Number(padded.slice(4, 6)) || 0;
    if (mm > 59 || ss > 59) return null;
    return Math.round(hh * 3600 + mm * 60 + ss);
  };

  const saveSportWithDuration = () => {
    const day = pendingSportDate;
    const sport = pendingSportName.trim();
    if (!day || !sport) return;

    const parsedDuration = parseSportDurationToSeconds(sportDurationInput);
    if (parsedDuration === null) {
      Alert.alert('Duración inválida', 'Ingresa un tiempo válido (MM:SS o HH:MM:SS).');
      return;
    }
    const durationSeconds = parsedDuration;

    Promise.resolve(onAddSportSession?.(day, sport, durationSeconds)).finally(() => {
      void loadSessions();
    });
    setShowSportDurationModal(false);
    setPendingSportDate(null);
    setPendingSportName('');
    setSportDurationInput('');
  };

  const closeSportDurationModal = () => {
    setShowSportDurationModal(false);
    setPendingSportDate(null);
    setPendingSportName('');
    setSportDurationInput('');
  };

  const openGymRoutinePicker = async (day: Date) => {
    setPendingSportDate(day);
    setShowDisciplineModal(false);
    setGymPickerStep('routine');
    setPendingGymRoutineSelection(null);
    try {
      const [routines, customSessions, sessionOverrides, deletedTypes] = await Promise.all([
        getRoutines(),
        getCustomSessions(),
        getSessionTypeOverrides(),
        getDeletedSessionTypes(),
      ]);

      const defaultRoutineNames = ['Cardio', 'Upper-Lower', 'Push-Pull-Piernas', 'Push-Pull-Piernas-Mixta'];
      const routineOptions: HistoricalSessionSelection[] = [];
      const seenRoutineNames = new Set<string>();

      const addRoutineOption = (label: string, key: string, routineId?: string) => {
        const normalized = normalizeLabel(label);
        if (!normalized || seenRoutineNames.has(normalized)) return;
        seenRoutineNames.add(normalized);
        routineOptions.push({
          kind: 'routine',
          key,
          label,
          routineId,
          routineName: label,
        });
      };

      defaultRoutineNames.forEach((name) => {
        addRoutineOption(name, `builtin:${normalizeLabel(name)}`);
      });

      (routines || []).forEach((routine) => {
        if (!routine?.name || !routine?.id) return;
        addRoutineOption(routine.name, routine.id, routine.id);
      });

      const defaultSessionTypes = ['Push', 'Pull', 'Piernas', 'Sesión mixta', 'Sesión libre', 'Cardio'];
      const deleted = new Set(deletedTypes || []);
      const extraSessionTypes = Object.keys(sessionOverrides || {}).filter(
        (name) => name && !defaultSessionTypes.includes(name) && !deleted.has(name)
      );

      const sessionOptions: HistoricalSessionSelection[] = [];
      defaultSessionTypes.forEach((name) => {
        if (deleted.has(name)) return;
        sessionOptions.push({ kind: 'sessionType', key: name, label: name });
      });
      extraSessionTypes
        .sort((a, b) => a.localeCompare(b, 'es', { sensitivity: 'base' }))
        .forEach((name) => sessionOptions.push({ kind: 'sessionType', key: name, label: name }));

      const customSessionOptions = (customSessions || [])
        .map((session) => ({
          kind: 'customSession' as const,
          key: session.id,
          label: session.name,
        }))
        .sort((a, b) => a.label.localeCompare(b.label, 'es', { sensitivity: 'base' }));

      setGymRoutineOptions(routineOptions);
      setGymSessionOptions([...sessionOptions, ...customSessionOptions]);
    } catch (error) {
      console.warn('No se pudieron cargar rutinas personalizadas:', error);
      setGymRoutineOptions([]);
      setGymSessionOptions([]);
    }
    setShowGymRoutineModal(true);
  };

  const openDisciplinePicker = (day: Date) => {
    setPendingSportDate(day);
    setShowGymRoutineModal(false);
    setShowDisciplineModal(true);
  };

  const closeDisciplineFlow = () => {
    setShowDisciplineModal(false);
    setShowGymRoutineModal(false);
    setPendingSportDate(null);
    setGymPickerStep('routine');
    setPendingGymRoutineSelection(null);
  };

  const handleDisciplineSelection = (discipline: string) => {
    const day = pendingSportDate;
    if (!day) return;
    if (discipline === 'GYM') {
      openGymRoutinePicker(day);
      return;
    }
    if (discipline === 'Otro') {
      setShowDisciplineModal(false);
      setOtherSportName('');
      setShowOtherSportModal(true);
      return;
    }
    setShowDisciplineModal(false);
    openSportDurationModal(day, discipline);
  };

  const handleGymRoutineSelection = (option: HistoricalSessionSelection) => {
    setPendingGymRoutineSelection(option);
    setGymPickerStep('sessionType');
  };

  const handleGymSessionSelection = (option: HistoricalSessionSelection) => {
    const day = pendingSportDate;
    if (!day) return;
    setShowGymRoutineModal(false);
    setPendingSportDate(null);
    const routine = pendingGymRoutineSelection;
    const routineId = routine?.routineId;
    const routineName = routine?.routineName || routine?.label;
    onAddHistoricalSession?.(day, {
      ...option,
      routineId,
      routineName,
    });
    setPendingGymRoutineSelection(null);
    setGymPickerStep('routine');
  };

  const openAddActivityMenu = (day: Date) => {
    openDisciplinePicker(day);
  };

  const disciplineOptions = ['GYM', 'Futbol', 'Paddle', 'Yoga', 'Bicicleta', 'Natacion', 'Tenis', 'Running', 'Otro'];

  const saveOtherSport = () => {
    const day = pendingSportDate;
    const sport = otherSportName.trim();
    if (!day || !sport) return;
    setShowOtherSportModal(false);
    setOtherSportName('');
    openSportDurationModal(day, sport);
  };

  const displayDayDetails = () => {
    if (!selectedDay) return;

    const dateString = selectedDay.toLocaleDateString('en-CA');
    console.log('[debug] Fecha seleccionada:', dateString);
    console.log('[debug] Total de sesiones:', sessions.length);
    
    const daySessions = sessions.filter(session => {
      // Verificar que session.fecha existe y no es null/undefined
      if (!session.fecha) return false;
      
      let sessionDate;
      if (session.fecha.includes('T')) {
        sessionDate = new Date(session.fecha).toLocaleDateString('en-CA');
      } else {
        sessionDate = session.fecha;
      }
      console.log('[debug] Comparando:', sessionDate, 'con', dateString);
      return sessionDate === dateString;
    });

    console.log('[debug] Sesiones encontradas para el dia:', daySessions.length);

    if (daySessions.length === 0) {
      Alert.alert(
        `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`,
        'No hay entrenamientos registrados para este dia.',
        [
          { text: 'CERRAR', onPress: () => setShowDayDetails(false) },
            {
              text: 'Agregar actividad', 
              onPress: () => {
                setShowDayDetails(false);
                openAddActivityMenu(selectedDay);
              }
            },
            {
              text: 'IMPORTAR SESI\u00d3N',
              onPress: () => {
                setShowDayDetails(false);
                void importHistoricalData();
              }
            },
          ]
        );
      } else {
        const formatExerciseLabel = (exercise: { ejercicio: string; musculo?: string }) => {
          const name = (exercise.ejercicio || '').trim();
          const muscle = (exercise.musculo || '').trim();
          if (!muscle) return name;
          const normalizedName = normalizeExerciseKey(name);
          const normalizedMuscle = normalizeExerciseKey(muscle);
          const alreadyIncludesMuscle =
            normalizedName.includes(`(${normalizedMuscle})`) || normalizedName.endsWith(` ${normalizedMuscle}`);
          return alreadyIncludesMuscle ? name : `${name} (${muscle})`;
        };

        let detailsMessage = '';
        
        daySessions.forEach((session, index) => {
          detailsMessage += `\uD83C\uDFCB\uFE0F ${session.tipo}\n`;
          
          if (session.duracion) {
            const minutes = Math.floor(session.duracion / 60);
            const seconds = session.duracion % 60;
            detailsMessage += `Duración total: ${minutes}:${seconds.toString().padStart(2, '0')}\n`;
          }
          
          detailsMessage += `\uD83D\uDCDD Ejercicios realizados:\n`;
          session.ejercicios.forEach((exercise, exerciseIndex) => {
            detailsMessage += `\n${exerciseIndex + 1}. ${formatExerciseLabel(exercise)}\n`;
            
            const completedSeries = exercise.series.filter(serie => 
              serie.reps || serie.kg || serie.rir
            );
            
            if (completedSeries.length > 0) {
              detailsMessage += `   Series: ${completedSeries.length}\n`;
              completedSeries.forEach((serie, serieIndex) => {
                detailsMessage += `   Serie ${serieIndex + 1}: ${serie.reps || '-'} reps, ${serie.kg || '-'} kg, RIR ${serie.rir || '-'}\n`;
              });
            } else {
              detailsMessage += `   (Sin series completadas)\n`;
            }
          });
        
        if (index < daySessions.length - 1) detailsMessage += '\n';
      });

      // Android solo soporta hasta 3 botones por Alert, así que agrupamos acciones.
      Alert.alert(
        `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`,
        detailsMessage,
        [
          { text: 'CERRAR', onPress: () => setShowDayDetails(false) },
            {
              text: 'AGREGAR...',
              onPress: () => {
                setShowDayDetails(false);
                openAddActivityMenu(selectedDay);
              }
            },
          {
            text: 'ACCIONES...',
            onPress: () => {
              Alert.alert(
                'Acciones',
                'Selecciona una opción',
                [
                  {
                    text: 'EXPORTAR...',
                    onPress: () => {
                      Alert.alert(
                        'Exportar',
                        'Selecciona el formato',
                        [
                          { text: 'CSV', onPress: () => exportDaySessions(selectedDay, 'csv') },
                          { text: 'XLSX', onPress: () => exportDaySessions(selectedDay, 'xlsx') },
                          { text: 'Cancelar', style: 'cancel' },
                        ],
                        { cancelable: true }
                      );
                    }
                  },
                  {
                    text: 'IMPORTAR SESI\u00d3N',
                    onPress: () => {
                      void importHistoricalData();
                    }
                  },
                  {
                    text: 'ELIMINAR...',
                    style: 'destructive',
                    onPress: () => {
                      const perSession = daySessions.map((s) => ({
                        text: `Eliminar sesión: ${s.tipo}`,
                        style: 'destructive' as const,
                        onPress: () => {
                          Alert.alert(
                            'Confirmar',
                            `Eliminar la sesión "${s.tipo}"?`,
                            [
                              { text: 'Cancelar', style: 'cancel' },
                              { text: 'Eliminar', style: 'destructive', onPress: async () => { await deleteSession(s.id); await loadSessions(); } },
                            ],
                            { cancelable: true }
                          );
                        }
                      }));
                      Alert.alert(
                        'Eliminar',
                        'Selecciona que eliminar',
                        [
                          ...perSession,
                          { text: 'Eliminar TODAS', style: 'destructive', onPress: () => {
                              Alert.alert('Confirmar', 'Eliminar TODAS las sesiones de este día?', [
                                { text: 'Cancelar', style: 'cancel' },
                                { text: 'Eliminar', style: 'destructive', onPress: () => handleDeleteDaySessions(selectedDay) }
                              ], { cancelable: true });
                            }
                          },
                          { text: 'Cancelar', style: 'cancel' }
                        ]
                      );
                    }
                  },
                  { text: 'Cancelar', style: 'cancel' },
                ],
                { cancelable: true }
              );
            }
          },
        ]
      );
    }
  };

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="none"
      onRequestClose={onClose}
        >
      <View style={styles.overlay}>
        <TouchableOpacity style={styles.overlayTouchable} activeOpacity={1} onPress={onClose} />
        <Animated.View 
          style={[
            styles.sideMenu, 
            { 
              backgroundColor: theme.surface, 
              paddingTop: insets.top + 16,
              paddingBottom: insets.bottom + 12,
              transform: [{ translateX: slideAnimation }]
            }
          ]}
        >
          {isContentReady && (
            <>
              <View style={styles.header}>
                <View style={styles.titleContainer}>
                  <Image 
                    source={isDarkMode ?require('../assets/logo-dark-transparent.png') : require('../assets/logo-transparent.png')}
                    style={styles.logo}
                    resizeMode="contain"
                  />
                  <Text style={[styles.title, { color: theme.textPrimary }]}>Menú</Text>
                </View>
                <TouchableOpacity style={[styles.closeButton, { backgroundColor: theme.buttonSecondary }]} onPress={onClose}>
                  <Text style={[styles.closeButtonText, { color: theme.buttonText }]}>{'\u2715'}</Text>
                </TouchableOpacity>
              </View>

              <View style={[styles.contentContainer, { flex: 1 }]}>
                {/* 1) Settings */}
                <View style={[styles.separator, { backgroundColor: '#333333' }]} />
                <TouchableOpacity 
                  style={styles.exportSection}
                  onPress={() => setShowSettingsModal(true)}
                >
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary, flex: 0 }]}>Configuración</Text>
                </TouchableOpacity>

                {/* 2) Peso Corporal */}
                <View style={[styles.separator, { backgroundColor: '#333333' }]} />
                <TouchableOpacity 
                  style={styles.exportSection}
                  onPress={() => setShowBodyWeightModal(true)}
                >
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary, flex: 0 }]}>Peso Corporal</Text>
                </TouchableOpacity>

                {/* 3) Detalle por ejercicio */}
                <View style={[styles.separator, { backgroundColor: '#333333' }]} />
                <TouchableOpacity
                  style={styles.exportSection}
                  onPress={() => {
                    onOpenAnalytics?.();
                  }}
                >
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary, flex: 0 }]}>Detalle por ejercicio</Text>
                </TouchableOpacity>

                {/* 4) Calendario de Entrenamiento */}
                <View style={[styles.separator, { backgroundColor: '#333333' }]} />
                <TouchableOpacity 
                  style={styles.calendarHeader}
                  onPress={() => setIsCalendarExpanded(!isCalendarExpanded)}
                >
                  <Text
                    numberOfLines={1}
                    adjustsFontSizeToFit
                    minimumFontScale={0.85}
                    style={[styles.sectionTitle, { color: theme.textPrimary, flexShrink: 1, minWidth: 0 }]}
                  >
                    {isSavingSession ?'\uD83D\uDCC5 Selecciona fecha para guardar sesión' : 'Calendario de entrenamientos'}
                  </Text>
                  <Text style={[styles.expandArrow, { color: theme.textSecondary }]}> 
                    {isCalendarExpanded ?'\u25BC' : '\u25B6'}
                  </Text>
                </TouchableOpacity>
                {isCalendarExpanded ?null : (
                  <View style={{ height: 8 }} />
                )}
                {isCalendarExpanded && (
                  <>
                    <View style={styles.monthSelector}>
                      <TouchableOpacity style={[styles.monthButton, { backgroundColor: '#4F766F' }]} onPress={previousMonth}>
                        <Text style={[styles.monthButtonText, { color: '#FFFFFF' }]}>{'<'}</Text>
                      </TouchableOpacity>
                      <Text style={[styles.monthText, { color: theme.textPrimary }]}>{formatMonth(selectedMonth)}</Text>
                      <TouchableOpacity style={[styles.monthButton, { backgroundColor: '#4F766F' }]} onPress={nextMonth}>
                        <Text style={[styles.monthButtonText, { color: '#FFFFFF' }]}>{'>'}</Text>
                      </TouchableOpacity>
                    </View>
                    <ScrollView style={[styles.calendar, { paddingBottom: 0, maxHeight: Dimensions.get('window').height * 0.40 }]}
                      contentContainerStyle={{ paddingBottom: 0 }}
                      showsVerticalScrollIndicator={false}
                    >
                      <View style={styles.weekDays}>
                        {['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'].map(day => (
                          <Text key={day} style={[styles.weekDayText, { color: theme.textSecondary }]}>{day}</Text>
                        ))}
                      </View>
                      <View style={styles.daysGrid}>
                        {days.map((day, index) => (
                          <View key={index} style={styles.dayContainer}>
                            {day ?(
                              <TouchableOpacity 
                                style={[
                                  styles.day,
                                  { backgroundColor: theme.background, borderColor: theme.border },
                                  isTrainingDay(day) && { backgroundColor: 'rgba(212, 165, 116, 0.3)', borderColor: '#D4A574' },
                                  isToday(day) && !isTrainingDay(day) && { backgroundColor: 'rgba(79, 118, 111, 0.2)', borderColor: 'rgba(79, 118, 111, 0.5)' },
                                  isToday(day) && { borderWidth: 2, borderColor: '#4F766F' }
                                ]}
                                onPress={() => handleDayPress(day)}
                              >
                                <Text style={[
                                  styles.dayText,
                                  { color: theme.textPrimary },
                                  isTrainingDay(day) && { color: '#D4A574', fontWeight: 'bold' },
                                  isToday(day) && !isTrainingDay(day) && { color: '#4F766F', fontWeight: '600' }
                                ]}>
                                  {day.getDate()}
                                </Text>
                              </TouchableOpacity>
                            ) : (
                              <View style={styles.emptyDay} />
                            )}
                          </View>
                        ))}
                      </View>
                    </ScrollView>
                    <View style={[styles.legend, { paddingVertical: 0, marginTop: 0 }]}> 
                      <View style={styles.legendItem}>
                        <View style={[styles.legendDot, { backgroundColor: '#D4A574', borderColor: '#D4A574' }]} />
                        <Text style={[styles.legendText, { color: theme.textSecondary }]}>Día de entrenamiento</Text>
                      </View>
                      <View style={styles.legendItem}>
                        <View style={[styles.legendDot, { backgroundColor: 'transparent', borderColor: '#4F766F', borderWidth: 2 }]} />
                        <Text style={[styles.legendText, { color: theme.textSecondary }]}>Hoy</Text>
                      </View>
                    </View>
                  </>
                )}

            <Modal visible={isExportingExerciseList} transparent animationType="fade">
              <View style={styles.modalOverlay}>
                <View style={[styles.modalContent, { backgroundColor: theme.surface, width: '72%', maxHeight: 180 }]}>
                  <ActivityIndicator size="large" color={theme.buttonPrimary} />
                  <Text style={[styles.modalTitle, { color: theme.textPrimary, marginTop: 14, marginBottom: 6 }]}>
                    Exportando...
                  </Text>
                  <Text style={{ color: theme.textSecondary, textAlign: 'center', fontFamily: 'System' }}>
                    Generando lista completa de ejercicios
                  </Text>
                </View>
              </View>
            </Modal>

            {/* Modal Settings */}
            <Modal
              visible={showSettingsModal}
              transparent={true}
              animationType="slide"
              onRequestClose={() => setShowSettingsModal(false)}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Configuración</Text>

                  <View style={[styles.darkModeContainer, { paddingHorizontal: 0, paddingVertical: 8 }]}>
                    <Text style={[styles.sectionTitle, { color: theme.textPrimary }]}>Modo Oscuro/Claro</Text>
                    <TouchableOpacity
                      style={[styles.toggleButton, { backgroundColor: isDarkMode ? '#4F766F' : '#E0E0E0' }]}
                      onPress={handleToggleDarkMode}
                    >
                      <Animated.View
                        style={[
                          styles.toggleCircle,
                          { backgroundColor: '#FFFFFF', transform: [{ translateX: toggleAnimation }] },
                        ]}
                      />
                    </TouchableOpacity>
                  </View>

                  <View style={[styles.separator, { backgroundColor: theme.border }]} />

                  <TouchableOpacity
                    style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                    onPress={() => {
                      setShowSettingsModal(false);
                      setShowExportModal(true);
                    }}
                  >
                    <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>Exportar Histórico de Sesiones</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                    onPress={() => {
                      void importHistoricalData();
                    }}
                  >
                    <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>Importar Histórico de Sesiones</Text>
                  </TouchableOpacity>

                  <TouchableOpacity
                    style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                    onPress={() => {
                      Alert.alert(
                        'Exportar Lista de Ejercicios',
                        'Selecciona el formato',
                        [
                          { text: 'CSV rápido', onPress: () => { void exportExerciseListSnapshot('csv_fast'); } },
                          { text: 'CSV completo', onPress: () => { void exportExerciseListSnapshot('csv'); } },
                          { text: 'JSON completo', onPress: () => { void exportExerciseListSnapshot('json'); } },
                          { text: 'Cancelar', style: 'cancel' },
                        ],
                        { cancelable: true }
                      );
                    }}
                  >
                    <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>Exportar Lista de Ejercicios</Text>
                  </TouchableOpacity>

                  <TouchableOpacity
                    style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                    onPress={() => {
                      setShowSettingsModal(false);
                      onClose();
                      setTimeout(() => {
                        onOpenImageManager?.();
                      }, 260);
                    }}
                  >
                    <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>Gestor de imágenes</Text>
                  </TouchableOpacity>

                  <View style={styles.modalButtons}>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowSettingsModal(false)}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cerrar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>

            {/* Modal para exportar historico */}
            <Modal
              visible={showExportModal}
              transparent={true}
              animationType="slide"
              onRequestClose={() => setShowExportModal(false)}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Exportar Histórico de Sesiones</Text>
                  
                  <View style={styles.dateRangeContainer}>
                    <Text style={[styles.dateLabel, { color: theme.textPrimary }]}>Desde:</Text>
                    <TouchableOpacity 
                      style={[styles.dateButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowStartDatePicker(true)}
                    >
                      <Text style={[styles.dateButtonText, { color: theme.buttonText }]}>
                        {startDate.toLocaleDateString('es-ES')}
                      </Text>
                    </TouchableOpacity>
                  </View>

                  <View style={styles.dateRangeContainer}>
                    <Text style={[styles.dateLabel, { color: theme.textPrimary }]}>Hasta:</Text>
                    <TouchableOpacity 
                      style={[styles.dateButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowEndDatePicker(true)}
                    >
                      <Text style={[styles.dateButtonText, { color: theme.buttonText }]}>
                        {endDate.toLocaleDateString('es-ES')}
                      </Text>
                    </TouchableOpacity>
                  </View>

                  <View style={styles.formatContainer}>
                    <Text style={[styles.formatLabel, { color: theme.textPrimary }]}>Formato:</Text>
                    <View style={styles.formatButtons}>
                      <TouchableOpacity 
                        style={[
                          styles.formatButton, 
                          { backgroundColor: exportFormat === 'csv' ?theme.buttonPrimary : '#4F766F80' }
                        ]}
                        onPress={() => setExportFormat('csv')}
                      >
                        <Text style={[styles.formatButtonText, { color: exportFormat === 'csv' ?theme.buttonText : theme.textSecondary }]}>CSV</Text>
                      </TouchableOpacity>
                      <TouchableOpacity 
                        style={[
                          styles.formatButton, 
                          { backgroundColor: exportFormat === 'xlsx' ?theme.buttonPrimary : '#4F766F80' }
                        ]}
                        onPress={() => setExportFormat('xlsx')}
                      >
                        <Text style={[styles.formatButtonText, { color: exportFormat === 'xlsx' ?theme.buttonText : theme.textSecondary }]}>XLSX</Text>
                      </TouchableOpacity>
                      <TouchableOpacity 
                        style={[
                          styles.formatButton, 
                          { backgroundColor: exportFormat === 'json' ?theme.buttonPrimary : '#4F766F80' }
                        ]}
                        onPress={() => setExportFormat('json')}
                      >
                        <Text style={[styles.formatButtonText, { color: exportFormat === 'json' ?theme.buttonText : theme.textSecondary }]}>JSON</Text>
                      </TouchableOpacity>
                    </View>
                  </View>

                  <View style={styles.modalButtons}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowExportModal(false)}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={exportHistoricalData}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Exportar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>

            {/* Modal de Seguimiento peso corporal */}
            <Modal
              visible={showBodyWeightModal}
              transparent={true}
              animationType="slide"
              onRequestClose={() => setShowBodyWeightModal(false)}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}> 
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seguimiento peso corporal</Text>

                  {/* Agregar registro */}
                  <View style={styles.dateRangeContainer}>
                    <Text style={[styles.dateLabel, { color: theme.textPrimary }]}>Fecha:</Text>
                    <TouchableOpacity 
                      style={[styles.dateButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowBwDatePicker(true)}
                    >
                      <Text style={[styles.dateButtonText, { color: theme.buttonText }]}>
                        {bwDate.toLocaleDateString('es-ES')}
                      </Text>
                    </TouchableOpacity>
                  </View>
                  <View style={styles.dateRangeContainer}>
                    <Text style={[styles.dateLabel, { color: theme.textPrimary }]}>Peso (kg):</Text>
                    <TextInput
                      style={[styles.dateButton, { backgroundColor: theme.surface, borderWidth: 1, borderColor: theme.border, color: theme.textPrimary }]}
                      keyboardType="numeric"
                      value={bwWeight}
                      onChangeText={setBwWeight}
                      placeholder="Ej: 78.4"
                      placeholderTextColor={theme.textSecondary}
                    />
                  </View>

                  {/* Histórico */}
                  <Text style={[styles.formatLabel, { color: theme.textPrimary }]}>Histórico</Text>
                  <ScrollView style={{ maxHeight: 200 }}>
                    {bodyWeights.length === 0 ?(
                      <Text style={{ color: theme.textSecondary }}>Sin registros</Text>
                    ) : (
                      bodyWeights.map(r => (
                        <View key={r.id} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 6 }}>
                          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                            <Text style={{ color: theme.textPrimary, marginRight: 12 }}>{new Date(r.dateISO).toLocaleDateString('es-ES')}</Text>
                            <Text style={{ color: theme.textPrimary }}>{r.weightKg} kg</Text>
                          </View>
                          <TouchableOpacity
                            style={{ paddingHorizontal: 10, paddingVertical: 6, borderRadius: 6, backgroundColor: '#E57373' }}
                            onPress={() => {
                              Alert.alert(
                                'Eliminar registro',
                                'Seguro que quieres eliminar este peso corporal?',
                                [
                                  { text: 'Cancelar', style: 'cancel' },
                                  { text: 'Eliminar', style: 'destructive', onPress: async () => { await deleteBodyWeight(r.id); await loadBodyWeights(); } },
                                ],
                                { cancelable: true }
                              );
                            }}
                          >
                            <Text style={{ color: '#FFFFFF', fontWeight: '600' }}>Eliminar</Text>
                          </TouchableOpacity>
                        </View>
                      ))
                    )}
                  </ScrollView>

                  <View style={{ marginTop: 12 }}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { alignSelf: 'center', backgroundColor: theme.buttonSecondary }]}
                      onPress={async () => {
                        if (bodyWeights.length === 0) { Alert.alert('Sin datos', 'No hay registros para exportar.'); return; }
                        Alert.alert(
                          'Exportar',
                          'Selecciona el formato',
                          [
                            { text: 'CSV', onPress: async () => {
                              const header = ['Fecha','Peso (kg)'];
                              const rows = bodyWeights.map(r => [new Date(r.dateISO).toISOString().slice(0,10), String(r.weightKg)]);
                              const filename = 'peso_corporal.csv';
                              const csv = [header, ...rows].map(r => r.join(',')).join('\n');
                              const uri = FileSystem.cacheDirectory + filename;
                              await FileSystem.writeAsStringAsync(uri, csv, { encoding: FileSystem.EncodingType.UTF8 });
                              if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: 'text/csv', dialogTitle: 'Exportar peso corporal' });
                            } },
                            { text: 'XLSX', onPress: async () => {
                              const header = ['Fecha','Peso (kg)'];
                              const rows = bodyWeights.map(r => [new Date(r.dateISO).toISOString().slice(0,10), String(r.weightKg)]);
                              const wb = XLSX.utils.book_new();
                              const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
                              XLSX.utils.book_append_sheet(wb, ws, 'Peso');
                              const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
                              const uri = FileSystem.cacheDirectory + 'peso_corporal.xlsx';
                              await FileSystem.writeAsStringAsync(uri, wbout, { encoding: FileSystem.EncodingType.Base64 });
                              if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', dialogTitle: 'Exportar peso corporal' });
                            } },
                            { text: 'Cancelar', style: 'cancel' },
                          ],
                          { cancelable: true }
                        );
                      }}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Exportar histórico de pesos</Text>
                    </TouchableOpacity>
                  </View>

                  <View style={styles.modalButtons}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowBodyWeightModal(false)}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={async () => {
                        const w = Number(bwWeight.replace(',', '.'));
                        if (isNaN(w) || w < 30 || w > 300) {
                          Alert.alert('Valor inválido', 'Ingresa un peso entre 30 y 300 kg.');
                          return;
                        }
                        try {
                          await addBodyWeight({ dateISO: bwDate.toISOString(), weightKg: Number(w.toFixed(1)) });
                          setBwWeight('');
                          await loadBodyWeights();
                          Alert.alert('Guardado', 'Peso corporal registrado.');
                        } catch {
                          Alert.alert('Error', 'No se pudo guardar el peso.');
                        }
                      }}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Guardar</Text>
                    </TouchableOpacity>
                  </View>

                </View>
              </View>
            </Modal>

            <Modal
              visible={showDisciplineModal}
              transparent={true}
              animationType="slide"
              onRequestClose={closeDisciplineFlow}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Disciplina</Text>
                  <ScrollView style={styles.selectionList}>
                    {disciplineOptions.map((option) => (
                      <TouchableOpacity
                        key={option}
                        style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                        onPress={() => handleDisciplineSelection(option)}
                      >
                        <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>{option}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                  <View style={styles.modalButtons}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={closeDisciplineFlow}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>

            <Modal
              visible={showGymRoutineModal}
              transparent={true}
              animationType="slide"
              onRequestClose={closeDisciplineFlow}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>
                    {gymPickerStep === 'routine' ? 'Rutinas' : 'Tipos de sesión'}
                  </Text>
                  <ScrollView style={styles.selectionList}>
                    {gymPickerStep === 'routine' &&
                      gymRoutineOptions.map((option) => (
                        <TouchableOpacity
                          key={`routine-${option.key}`}
                          style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                          onPress={() => handleGymRoutineSelection(option)}
                        >
                          <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>{option.label}</Text>
                        </TouchableOpacity>
                      ))}
                    {gymPickerStep === 'sessionType' &&
                      gymSessionOptions.map((option) => (
                        <TouchableOpacity
                          key={`session-${option.kind}-${option.key}`}
                          style={[styles.selectionOption, { borderBottomColor: theme.border }]}
                          onPress={() => handleGymSessionSelection(option)}
                        >
                          <Text style={[styles.selectionOptionText, { color: theme.textPrimary }]}>{option.label}</Text>
                        </TouchableOpacity>
                      ))}
                    {gymPickerStep === 'routine' && gymRoutineOptions.length === 0 && (
                      <Text style={[styles.selectionOptionText, { color: theme.textSecondary }]}>
                        No hay rutinas ni sesiones configuradas.
                      </Text>
                    )}
                    {gymPickerStep === 'sessionType' && gymSessionOptions.length === 0 && (
                      <Text style={[styles.selectionOptionText, { color: theme.textSecondary }]}>
                        No hay tipos de sesión configurados.
                      </Text>
                    )}
                  </ScrollView>
                  <View style={styles.modalButtons}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => {
                        if (gymPickerStep === 'sessionType') {
                          setGymPickerStep('routine');
                          return;
                        }
                        setShowGymRoutineModal(false);
                        setShowDisciplineModal(true);
                      }}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Atrás</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={closeDisciplineFlow}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>

            <Modal
              visible={showOtherSportModal}
              transparent={true}
              animationType="slide"
              onRequestClose={() => setShowOtherSportModal(false)}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Otro deporte</Text>
                  <TextInput
                    style={[styles.customNameInput, { backgroundColor: theme.background, borderColor: theme.border, color: theme.textPrimary }]}
                    value={otherSportName}
                    onChangeText={setOtherSportName}
                    placeholder="Nombre del deporte"
                    placeholderTextColor={theme.textSecondary}
                    autoFocus
                  />
                  <View style={styles.modalButtons}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setShowOtherSportModal(false)}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={saveOtherSport}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Guardar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>

            <Modal
              visible={showSportDurationModal}
              transparent={true}
              animationType="slide"
              onRequestClose={closeSportDurationModal}
            >
              <View style={styles.modalOverlay}>
                <TouchableOpacity
                  style={styles.modalOverlayTouchable}
                  activeOpacity={1}
                  onPress={() => setShowSettingsModal(false)}
                />
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Duración de la actividad</Text>
                  <Text style={[styles.formatLabel, { color: theme.textPrimary, marginBottom: 8 }]}>
                    {pendingSportName || 'Deporte'}
                  </Text>
                  <TextInput
                    style={[styles.customNameInput, { backgroundColor: theme.background, borderColor: theme.border, color: theme.textPrimary }]}
                    value={sportDurationInput}
                    onChangeText={(text) => setSportDurationInput(formatSportDurationInput(text))}
                    placeholder="HH:MM:SS"
                    placeholderTextColor={theme.textSecondary}
                    keyboardType="number-pad"
                    maxLength={8}
                    autoFocus
                  />
                  <View style={styles.modalButtons}>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={closeSportDurationModal}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={saveSportWithDuration}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Guardar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>
            </Modal>

            {showBwDatePicker && (
              <DateTimePicker
                value={bwDate}
                mode="date"
                display="default"
                onChange={(e, d) => { setShowBwDatePicker(false); if (d) setBwDate(d); }}
                maximumDate={new Date()}
              />
            )}

            {/* Date Pickers */}
            {showStartDatePicker && (
              <DateTimePicker
                value={startDate}
                mode="date"
                display="default"
                onChange={handleStartDateChange}
                maximumDate={endDate}
              />
            )}

            {showEndDatePicker && (
              <DateTimePicker
                value={endDate}
                mode="date"
                display="default"
                onChange={handleEndDateChange}
                minimumDate={startDate}
                maximumDate={new Date()}
              />
            )}

              {/* Footer credit removed per user request */}
            </View>
            </>
          )}
        </Animated.View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  overlayTouchable: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  sideMenu: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: Dimensions.get('window').width * 0.8,
    height: '100%',
    borderRightWidth: 2,
    borderColor: '#4F766F',
    zIndex: 100,
    padding: 16,
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#333333',
  },
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  logo: {
    width: 48,
    height: 48,
    marginRight: 8,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
  },
  closeButton: {
    width: 36,
    height: 36,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#D4A574',
  },
  closeButtonText: {
    fontSize: 18,
    fontWeight: '700',
    fontFamily: 'System',
    lineHeight: 18,
  },
  darkModeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  darkModeText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  toggleButton: {
    width: 50,
    height: 28,
    borderRadius: 14,
    padding: 2,
    justifyContent: 'center',
  },
  toggleCircle: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignSelf: 'flex-start',
  },
  separator: {
    height: 1,
  },
  subSeparator: {
    height: 1,
    marginHorizontal: 32,
    marginVertical: 2,
  },
  contentContainer: {
    flex: 1,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
    flex: 1,
  },
  calendarHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  expandArrow: {
    fontSize: 20,
    fontWeight: '600',
    fontFamily: 'System',
    width: 50,
    textAlign: 'center',
  },
  monthSelector: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
  },
  monthButton: {
    padding: 8,
    borderRadius: 4,
  },
  monthButtonText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  monthText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  calendar: {
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  weekDays: {
    flexDirection: 'row',
    marginBottom: 4,
  },
  weekDayText: {
    flex: 1,
    textAlign: 'center',
    fontSize: 12,
    fontWeight: '600',
    fontFamily: 'System',
  },
  daysGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  dayContainer: {
    width: '14.28%',
    aspectRatio: 1,
    padding: 2,
  },
  day: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 4,
  },
  dayText: {
    fontSize: 14,
    fontFamily: 'System',
  },
  emptyDay: {
    flex: 1,
  },
  legend: {
    paddingHorizontal: 12,
    paddingVertical: 2,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  legendDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    borderWidth: 1,
    marginRight: 8,
  },
  legendText: {
    fontSize: 14,
    fontFamily: 'System',
  },
  exportSection: {
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  exportSubtitle: {
    fontSize: 14,
    fontFamily: 'System',
    marginTop: 4,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalOverlayTouchable: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  modalContent: {
    width: '90%',
    maxWidth: 400,
    borderRadius: 12,
    padding: 20,
    margin: 20,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    textAlign: 'center',
    marginBottom: 20,
  },
  customNameInput: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    fontFamily: 'System',
    marginBottom: 16,
  },
  dateRangeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  dateLabel: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
    width: 60,
  },
  dateButton: {
    flex: 1,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 6,
    marginLeft: 12,
  },
  dateButtonText: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'System',
    textAlign: 'center',
  },
  formatContainer: {
    marginBottom: 20,
  },
  formatLabel: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
    marginBottom: 8,
  },
  formatButtons: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  formatButton: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 6,
    minWidth: 80,
  },
  formatButtonText: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'System',
    textAlign: 'center',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: 20,
  },
  modalButton: {
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 6,
    minWidth: 100,
  },
  modalButtonText: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'System',
    textAlign: 'center',
  },
  selectionList: {
    maxHeight: 320,
  },
  selectionOption: {
    paddingVertical: 14,
    borderBottomWidth: 1,
  },
  selectionOptionText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  selectionSectionTitle: {
    fontSize: 12,
    fontWeight: '700',
    fontFamily: 'System',
    marginTop: 12,
    marginBottom: 6,
    letterSpacing: 0.3,
    textTransform: 'uppercase',
  },
  footer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 8,
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 8,
  },
  footerText: {
    fontSize: 12,
    fontFamily: 'System',
  },
});

export default SideMenu; 
