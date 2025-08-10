import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal, ScrollView, Image, Animated, Alert, Dimensions, TouchableWithoutFeedback, Platform, TextInput } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import DateTimePicker from '@react-native-community/datetimepicker';
import { getSessions, deleteSession, getBodyWeights, addBodyWeight, BodyWeightRecord } from '../utils/storage';
import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import * as XLSX from 'xlsx';
import { getTheme } from '../utils/theme';

interface Props {
  visible: boolean;
  onClose: () => void;
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
  onAddHistoricalSession?: (date: Date) => void;
  isSavingSession?: boolean;
  onSaveSessionToDate?: (date: Date) => void;
}

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
}

const SideMenu: React.FC<Props> = ({ visible, onClose, isDarkMode, onToggleDarkMode, onAddHistoricalSession, isSavingSession, onSaveSessionToDate }) => {
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
  const [bodyWeights, setBodyWeights] = useState<BodyWeightRecord[]>([]);
  const [bwDate, setBwDate] = useState<Date>(new Date());
  const [showBwDatePicker, setShowBwDatePicker] = useState(false);
  const [bwWeight, setBwWeight] = useState<string>('');
  const [startDate, setStartDate] = useState(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [endDate, setEndDate] = useState(new Date());
  const [exportFormat, setExportFormat] = useState<'csv' | 'xlsx' | null>(null);
  const [showStartDatePicker, setShowStartDatePicker] = useState(false);
  const [showEndDatePicker, setShowEndDatePicker] = useState(false);
  const toggleAnimation = useRef(new Animated.Value(isDarkMode ? 22 : 0)).current;
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
        // Después de la animación, cargar los datos
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
    console.log('🔍 useEffect - showDayDetails:', showDayDetails, 'selectedDay:', selectedDay?.toLocaleDateString('es-ES'));
    if (showDayDetails && selectedDay) {
      console.log('✅ Ejecutando displayDayDetails...');
      displayDayDetails();
    }
  }, [showDayDetails, selectedDay]);

  const loadSessions = async () => {
    try {
      console.log('🔄 Cargando sesiones...');
      const savedSessions = await getSessions();
      console.log('📊 Sesiones cargadas:', savedSessions?.length || 0);
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
    
    const days = [];
    
    for (let i = 0; i < firstDayOfMonth; i++) {
      days.push(null);
    }
    
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(new Date(year, month, i));
    }
    
    return days;
  };

  const isTrainingDay = (date: Date) => {
    const dateString = date.toLocaleDateString('en-CA'); // Formato YYYY-MM-DD
    if (!sessions || sessions.length === 0) return false;
    
    return sessions.some(session => {
      // Verificar que session.fecha existe y no es null/undefined
      if (!session.fecha) return false;
      
      // Si la fecha está en formato ISO, convertirla
      let sessionDate;
      if (session.fecha.includes('T')) {
        // Formato ISO (fechas antiguas)
        sessionDate = new Date(session.fecha).toLocaleDateString('en-CA');
      } else {
        // Formato local (fechas nuevas)
        sessionDate = session.fecha;
      }
      return sessionDate === dateString;
    });
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
    const toValue = isDarkMode ? 0 : 22;
    Animated.timing(toggleAnimation, {
      toValue,
      duration: 200,
      useNativeDriver: true,
    }).start();
    onToggleDarkMode();
  };

  const handleDayPress = (day: Date) => {
    console.log('👆 Día presionado:', day.toLocaleDateString('es-ES'));
    // Bloquear días futuros
    const today = new Date(); today.setHours(0,0,0,0);
    const d = new Date(day); d.setHours(0,0,0,0);
    const isFuture = d.getTime() > today.getTime();
    if (isFuture) {
      Alert.alert('Fecha inválida', 'No podés seleccionar fechas futuras.');
      return;
    }
    
          // Si estamos en modo "guardar sesión", guardar directamente
      if (isSavingSession && onSaveSessionToDate) {
        console.log('💾 Guardando sesión para fecha:', day.toLocaleDateString('es-ES'));
        try {
          onSaveSessionToDate(day);
          onClose(); // Cerrar el SideMenu
        } catch (error) {
          console.error('❌ Error al guardar sesión:', error);
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
    const found = bodyWeights.find(r => new Date(r.dateISO).getTime() <= target);
    return found ? found.weightKg : null;
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

  // Exportar sesiones de un día (CSV o XLSX)
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

    const header = ['fecha','fecha_hora_iso','mes','semana_iso','dia_semana','rutina','rutina_id','duracion_hhmmss','duracion_seg','orden_ejercicio','numero_serie','musculo','lado','repeticiones','peso_kg','rir','volumen_kg','peso_corporal_kg'];
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
      const dayNum = date.getUTCDay() || 7; // 1..7 (Mon..Sun)
      date.setUTCDate(date.getUTCDate() + 4 - dayNum);
      const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
      const weekNo = Math.ceil((((date as any) - (yearStart as any)) / 86400000 + 1) / 7);
      return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
    };
    const getWeekday = (d: Date) => {
      const day = d.getDay(); // 0..6 (Sun..Sat)
      return day === 0 ? 7 : day; // 1..7 (Mon..Sun)
    };

    daySessions.forEach((session, exerciseOrder) => {
      session.ejercicios.forEach((ejercicio) => {
        ejercicio.series.forEach((serie, serieIndex) => {
          const jsDate = new Date(session.fecha);
          const fechaIso = jsDate.toISOString();
          const fecha = jsDate.toISOString().slice(0,10);
          const mes = getMonthName(jsDate);
          const semanaIso = getISOWeek(jsDate);
          const diaSemana = String(getWeekday(jsDate));
          const durHHMMSS = toHHMMSS(session.duracion);
          const durSeg = String(session.duracion ?? 0);
          const lado = '';
          const rep = serie.reps || '';
          const peso = serie.kg || '';
          const rir = serie.rir?.toString() || '';
          const vol = rep && peso ? String(Number(rep) * Number(peso)) : '';
          const bw = getBodyWeightAtLocal(jsDate);
          const pesoCorporal = bw != null ? String(bw) : '';

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
            lado,
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
    const filename = format === 'xlsx' ? `${base}.xlsx` : `${base}.csv`;
    const mimeType = format === 'xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv';

    try {
      // Generar archivo en caché y compartir (flujo simple y confiable)
      const fileUri = FileSystem.cacheDirectory + filename;
      if (format === 'xlsx') {
        const wb = XLSX.utils.book_new();
        const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
        XLSX.utils.book_append_sheet(wb, ws, 'Sesion');
        const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
        await FileSystem.writeAsStringAsync(fileUri, wbout, { encoding: FileSystem.EncodingType.Base64 });
      } else {
        const csvContent = [header, ...rows].map(r => r.map(f => {
          const needsQuotes = /[",\n]/.test(f);
          const escaped = f.replace(/"/g, '""');
          return needsQuotes ? `"${escaped}"` : escaped;
        }).join(',')).join('\n');
        await FileSystem.writeAsStringAsync(fileUri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });
      }
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, { mimeType, dialogTitle: 'Exportar sesión' });
      } else {
        Alert.alert('Exportación', `Archivo generado en caché: ${fileUri}`);
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
        `¿Qué sesión del ${day.toLocaleDateString('es-ES', { day: 'numeric', month: 'long' })} quieres eliminar?`,
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

    const header = ['fecha','fecha_hora_iso','mes','semana_iso','dia_semana','rutina','rutina_id','duracion_hhmmss','duracion_seg','orden_ejercicio','numero_serie','musculo','lado','repeticiones','peso_kg','rir','volumen_kg','peso_corporal_kg'];
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
       return day === 0 ? 7 : day;
     };

     filteredSessions.forEach((session, exerciseOrder) => {
       session.ejercicios.forEach((ejercicio) => {
         ejercicio.series.forEach((serie, serieIndex) => {
           const [sy,sm,sd] = session.fecha.split('-').map(Number);
           const jsDate = new Date(sy, (sm || 1) - 1, sd || 1);
           const fecha = session.fecha;
           const tz = -jsDate.getTimezoneOffset();
           const sign = tz >= 0 ? '+' : '-';
           const hh = String(Math.floor(Math.abs(tz) / 60)).padStart(2, '0');
           const mm = String(Math.abs(tz) % 60).padStart(2, '0');
           const fechaIso = `${fecha}T00:00:00${sign}${hh}:${mm}`;
           const mes = getMonthName(jsDate);
           const semanaIso = getISOWeek(jsDate);
           const diaSemana = String(getWeekday(jsDate));
           const durHHMMSS = toHHMMSS(session.duracion);
           const durSeg = String(session.duracion ?? 0);
           const lado = '';
           const rep = serie.reps || '';
           const peso = serie.kg || '';
           const rir = serie.rir?.toString() || '';
           const vol = rep && peso ? String(Number(rep) * Number(peso)) : '';
           const bw = getBodyWeightAtLocal(jsDate);
           const pesoCorporal = bw != null ? String(bw) : '';

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
             lado,
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

    const fileBase = `historico_${startDate.toISOString().slice(0,10)}_a_${endDate.toISOString().slice(0,10)}`;
    const filename = exportFormat === 'xlsx' ? `${fileBase}.xlsx` : `${fileBase}.csv`;
    const mimeType = exportFormat === 'xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv';

    try {
      if (Platform.OS === 'android' && FileSystem.StorageAccessFramework) {
        const perm = await FileSystem.StorageAccessFramework.requestDirectoryPermissionsAsync();
        if (perm.granted && perm.directoryUri) {
          const uri = await FileSystem.StorageAccessFramework.createFileAsync(perm.directoryUri, filename, mimeType);
          if (exportFormat === 'xlsx') {
            const wb = XLSX.utils.book_new();
            const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
            XLSX.utils.book_append_sheet(wb, ws, 'Historico');
            const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
            await FileSystem.writeAsStringAsync(uri, wbout, { encoding: FileSystem.EncodingType.Base64 });
          } else {
            const csvContent = [header, ...rows].map(r => r.map(f => {
              const needsQuotes = /[",\n]/.test(f);
              const escaped = f.replace(/"/g, '""');
              return needsQuotes ? `"${escaped}"` : escaped;
            }).join(',')).join('\n');
            await FileSystem.writeAsStringAsync(uri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });
          }
          Alert.alert('Exportación completada', `Archivo guardado: ${filename}`, [{ text: 'OK', onPress: () => setShowExportModal(false) }]);
          return;
        }
        // Si usuario no otorga permisos, fallback a compartir
      }

      // Fallback: compartir archivo desde caché
      const fileUri = FileSystem.cacheDirectory + filename;
      if (exportFormat === 'xlsx') {
        const wb = XLSX.utils.book_new();
        const ws = XLSX.utils.aoa_to_sheet([header, ...rows]);
        XLSX.utils.book_append_sheet(wb, ws, 'Historico');
        const wbout = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
        await FileSystem.writeAsStringAsync(fileUri, wbout, { encoding: FileSystem.EncodingType.Base64 });
      } else {
        const csvContent = [header, ...rows].map(r => r.map(f => {
          const needsQuotes = /[",\n]/.test(f);
          const escaped = f.replace(/"/g, '""');
          return needsQuotes ? `"${escaped}"` : escaped;
        }).join(',')).join('\n');
        await FileSystem.writeAsStringAsync(fileUri, csvContent, { encoding: FileSystem.EncodingType.UTF8 });
      }
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(fileUri, { mimeType, dialogTitle: 'Exportar histórico' });
        setShowExportModal(false);
      } else {
        Alert.alert('Exportación', `Archivo generado en caché: ${fileUri}`);
      }
    } catch (e) {
      console.error('Error exportando histórico:', e);
      Alert.alert('Error', 'No se pudo exportar el histórico.');
    }
  };

  const displayDayDetails = () => {
    if (!selectedDay) return;

    const dateString = selectedDay.toLocaleDateString('en-CA');
    console.log('🔍 Debug - Fecha seleccionada:', dateString);
    console.log('🔍 Debug - Total de sesiones:', sessions.length);
    
    const daySessions = sessions.filter(session => {
      // Verificar que session.fecha existe y no es null/undefined
      if (!session.fecha) return false;
      
      let sessionDate;
      if (session.fecha.includes('T')) {
        sessionDate = new Date(session.fecha).toLocaleDateString('en-CA');
      } else {
        sessionDate = session.fecha;
      }
      console.log('🔍 Debug - Comparando:', sessionDate, 'con', dateString);
      return sessionDate === dateString;
    });

    console.log('🔍 Debug - Sesiones encontradas para el día:', daySessions.length);

    if (daySessions.length === 0) {
      Alert.alert(
        `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`,
        'No hay entrenamientos registrados para este día.',
        [
          { text: 'CERRAR', onPress: () => setShowDayDetails(false) },
          { 
            text: '➕ Agregar sesión', 
            onPress: () => {
              setShowDayDetails(false);
              if (onAddHistoricalSession) {
                onAddHistoricalSession(selectedDay);
              }
            }
          }
        ]
      );
    } else {
      let detailsMessage = `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}\n\n`;
      
      daySessions.forEach((session, index) => {
        detailsMessage += `🏋️ ${session.tipo}\n`;
        
        if (session.duracion) {
          const minutes = Math.floor(session.duracion / 60);
          const seconds = session.duracion % 60;
          detailsMessage += `⏱️ Duración total: ${minutes}:${seconds.toString().padStart(2, '0')}\n`;
        }
        
        detailsMessage += `📝 Ejercicios realizados:\n`;
        session.ejercicios.forEach((exercise, exerciseIndex) => {
          detailsMessage += `\n${exerciseIndex + 1}. ${exercise.ejercicio} (${exercise.musculo})\n`;
          
          const completedSeries = exercise.series.filter(serie => 
            serie.reps || serie.kg || serie.rir
          );
          
          if (completedSeries.length > 0) {
            detailsMessage += `   Series: ${completedSeries.length}\n`;
            completedSeries.forEach((serie, serieIndex) => {
              detailsMessage += `   • Serie ${serieIndex + 1}: ${serie.reps || '-'} reps, ${serie.kg || '-'} kg, RIR ${serie.rir || '-'}\n`;
            });
          } else {
            detailsMessage += `   (Sin series completadas)\n`;
          }
        });
        
        if (index < daySessions.length - 1) detailsMessage += '\n';
      });

      // Nueva UI: CERRAR / EXPORTAR COMO... / ELIMINAR...
      Alert.alert(
        `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`,
        detailsMessage,
        [
          { text: 'CERRAR', onPress: () => setShowDayDetails(false) },
          {
            text: 'EXPORTAR COMO...',
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
            text: 'ELIMINAR...',
            style: 'destructive',
            onPress: () => {
              const perSession = daySessions.map((s) => ({
                text: `Eliminar sesión: ${s.tipo}`,
                style: 'destructive' as const,
                onPress: () => {
                  Alert.alert(
                    'Confirmar',
                    `¿Eliminar la sesión "${s.tipo}"?`,
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
                'Selecciona qué eliminar',
                [
                  ...perSession,
                  { text: 'Eliminar TODAS', style: 'destructive', onPress: () => {
                      Alert.alert('Confirmar', '¿Eliminar TODAS las sesiones de este día?', [
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
                    source={isDarkMode ? require('../assets/logo-dark-transparent.png') : require('../assets/logo-transparent.png')}
                    style={styles.logo}
                    resizeMode="contain"
                  />
                  <Text style={[styles.title, { color: theme.textPrimary }]}>Menú</Text>
                </View>
                <TouchableOpacity style={[styles.closeButton, { backgroundColor: theme.buttonSecondary }]} onPress={onClose}>
                  <Text style={[styles.closeButtonText, { color: theme.buttonText }]}>✕</Text>
                </TouchableOpacity>
              </View>

              <View style={[styles.contentContainer, { flex: 1 }]}>
            {isContentReady && (
              <>
                <View style={styles.darkModeContainer}>
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary }]}>Dark Mode</Text>
                  <TouchableOpacity 
                    style={[styles.toggleButton, { backgroundColor: isDarkMode ? '#4F766F' : '#E0E0E0' }]} 
                    onPress={handleToggleDarkMode}
                  >
                    <Animated.View style={[
                      styles.toggleCircle, 
                      { backgroundColor: '#FFFFFF', transform: [{ translateX: toggleAnimation }] }
                    ]} />
                  </TouchableOpacity>
                </View>

                {/* 2) Seguimiento Peso Corporal */}
                <View style={[styles.separator, { backgroundColor: '#333333' }]} />
                <TouchableOpacity 
                  style={styles.exportSection}
                  onPress={() => setShowBodyWeightModal(true)}
                >
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary, flex: 0 }]}>Seguimiento Peso Corporal</Text>
                </TouchableOpacity>

                {/* 3) Exportar Histórico */}
                <View style={[styles.separator, { backgroundColor: '#333333' }]} />
                <TouchableOpacity 
                  style={styles.exportSection}
                  onPress={() => setShowExportModal(true)}
                >
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary, flex: 0 }]}>Exportar Histórico</Text>
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
                    {isSavingSession ? '📅 Selecciona fecha para guardar sesión' : 'Calendario de Entrenamiento'}
                  </Text>
                  <Text style={[styles.expandArrow, { color: theme.textSecondary }]}> 
                    {isCalendarExpanded ? '▼' : '▶'}
                  </Text>
                </TouchableOpacity>
                {isCalendarExpanded ? null : (
                  <View style={{ height: 8 }} />
                )}
                {isCalendarExpanded && (
                  <>
                    <View style={styles.monthSelector}>
                      <TouchableOpacity style={[styles.monthButton, { backgroundColor: '#4F766F' }]} onPress={previousMonth}>
                        <Text style={[styles.monthButtonText, { color: '#FFFFFF' }]}>‹</Text>
                      </TouchableOpacity>
                      <Text style={[styles.monthText, { color: theme.textPrimary }]}>{formatMonth(selectedMonth)}</Text>
                      <TouchableOpacity style={[styles.monthButton, { backgroundColor: '#4F766F' }]} onPress={nextMonth}>
                        <Text style={[styles.monthButtonText, { color: '#FFFFFF' }]}>›</Text>
                      </TouchableOpacity>
                    </View>
                    <ScrollView style={[styles.calendar, { paddingBottom: 0, maxHeight: Dimensions.get('window').height * 0.40 }]}
                      contentContainerStyle={{ paddingBottom: 0 }}
                      showsVerticalScrollIndicator={false}
                    >
                      <View style={styles.weekDays}>
                        {['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'].map(day => (
                          <Text key={day} style={[styles.weekDayText, { color: theme.textSecondary }]}>{day}</Text>
                        ))}
                      </View>
                      <View style={styles.daysGrid}>
                        {days.map((day, index) => (
                          <View key={index} style={styles.dayContainer}>
                            {day ? (
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

            {/* Modal para exportar histórico */}
            <Modal
              visible={showExportModal}
              transparent={true}
              animationType="slide"
              onRequestClose={() => setShowExportModal(false)}
            >
              <View style={styles.modalOverlay}>
                <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
                  <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Exportar Histórico</Text>
                  
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
                          { backgroundColor: exportFormat === 'csv' ? theme.buttonPrimary : '#4F766F80' }
                        ]}
                        onPress={() => setExportFormat('csv')}
                      >
                        <Text style={[styles.formatButtonText, { color: exportFormat === 'csv' ? theme.buttonText : theme.textSecondary }]}>CSV</Text>
                      </TouchableOpacity>
                      <TouchableOpacity 
                        style={[
                          styles.formatButton, 
                          { backgroundColor: exportFormat === 'xlsx' ? theme.buttonPrimary : '#4F766F80' }
                        ]}
                        onPress={() => setExportFormat('xlsx')}
                      >
                        <Text style={[styles.formatButtonText, { color: exportFormat === 'xlsx' ? theme.buttonText : theme.textSecondary }]}>XLSX</Text>
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
                    {bodyWeights.length === 0 ? (
                      <Text style={{ color: theme.textSecondary }}>Sin registros</Text>
                    ) : (
                      bodyWeights.map(r => (
                        <View key={r.id} style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 6 }}>
                          <Text style={{ color: theme.textPrimary }}>{new Date(r.dateISO).toLocaleDateString('es-ES')}</Text>
                          <Text style={{ color: theme.textPrimary }}>{r.weightKg} kg</Text>
                        </View>
                      ))
                    )}
                  </ScrollView>

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
                          Alert.alert('Valor inválido', 'Ingresá un peso entre 30 y 300 kg.');
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
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Exportar histórico</Text>
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
              </View>

              {/* Footer credit removed per user request */}
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