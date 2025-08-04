import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal, ScrollView, Image, Animated, Alert, Dimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getSessions, deleteSession } from '../utils/storage';
import { getTheme } from '../utils/theme';

interface Props {
  visible: boolean;
  onClose: () => void;
  isDarkMode: boolean;
  onToggleDarkMode: () => void;
}

interface Session {
  id: string;
  tipo: string;
  fecha: string;
  ejercicios: Array<{
    ejercicio: string;
    musculo: string;
    series: Array<{ reps: string; kg: string; rir: number | undefined }>;
    fecha: string;
  }>;
  duracion?: number;
}

const SideMenu: React.FC<Props> = ({ visible, onClose, isDarkMode, onToggleDarkMode }) => {
  const insets = useSafeAreaInsets();
  const theme = getTheme(isDarkMode);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedMonth, setSelectedMonth] = useState(new Date());
  const [isCalendarExpanded, setIsCalendarExpanded] = useState(true);
  const [selectedDay, setSelectedDay] = useState<Date | null>(null);
  const [showDayDetails, setShowDayDetails] = useState(false);
  const [isContentReady, setIsContentReady] = useState(false);
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
    if (showDayDetails && selectedDay) {
      displayDayDetails();
    }
  }, [showDayDetails, selectedDay]);

  const loadSessions = async () => {
    try {
      const savedSessions = await getSessions();
      setSessions(savedSessions || []);
    } catch (error) {
      console.error('Error cargando sesiones:', error);
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
    return sessions.some(session => {
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
    setSelectedDay(day);
    setShowDayDetails(true);
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

  const handleDeleteDaySessions = (day: Date) => {
    const dateString = day.toLocaleDateString('en-CA');
    const daySessions = sessions.filter(session => {
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

  const displayDayDetails = () => {
    if (!selectedDay) return;

    const dateString = selectedDay.toLocaleDateString('en-CA');
    const daySessions = sessions.filter(session => {
      let sessionDate;
      if (session.fecha.includes('T')) {
        sessionDate = new Date(session.fecha).toLocaleDateString('en-CA');
      } else {
        sessionDate = session.fecha;
      }
      return sessionDate === dateString;
    });

    if (daySessions.length === 0) {
      Alert.alert(
        `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`,
        'No hay entrenamientos registrados para este día.',
        [{ text: 'CERRAR', onPress: () => setShowDayDetails(false) }]
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

      Alert.alert(
        `${selectedDay.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}`,
        detailsMessage,
        [
          { text: 'CERRAR', onPress: () => setShowDayDetails(false) },
          { 
            text: 'Eliminar', 
            style: 'destructive',
            onPress: () => {
              setShowDayDetails(false);
              Alert.alert(
                'Confirmar eliminación',
                '¿Estás seguro de que quieres eliminar el entrenamiento de este día?',
                [
                  { text: 'Cancelar', style: 'cancel' },
                  { 
                    text: 'Eliminar', 
                    style: 'destructive',
                    onPress: () => handleDeleteDaySessions(selectedDay)
                  }
                ]
              );
            }
          }
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

              <ScrollView style={styles.contentContainer}>
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

                <View style={[styles.separator, { backgroundColor: '#333333' }]} />

                <TouchableOpacity 
                  style={styles.calendarHeader}
                  onPress={() => setIsCalendarExpanded(!isCalendarExpanded)}
                >
                  <Text style={[styles.sectionTitle, { color: theme.textPrimary }]}>
                    Calendario de Entrenamiento
                  </Text>
                  <Text style={[styles.expandArrow, { color: theme.textSecondary }]}>
                    {isCalendarExpanded ? '▼' : '▶'}
                  </Text>
                </TouchableOpacity>
                
                {!isCalendarExpanded && (
                  <View style={[styles.separator, { backgroundColor: '#333333' }]} />
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

                    <View style={styles.calendar}>
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
                                disabled={!isTrainingDay(day)}
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
                    </View>

                    <View style={[styles.subSeparator, { backgroundColor: '#D4A574' }]} />

                    <View style={styles.legend}>
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
              </>
            )}
              </ScrollView>
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
    padding: 8,
  },
  closeButtonText: {
    fontSize: 20,
    fontFamily: 'System',
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
    marginVertical: 8,
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
    flex: 1,
    padding: 16,
  },
  weekDays: {
    flexDirection: 'row',
    marginBottom: 8,
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
    padding: 16,
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
});

export default SideMenu; 