import React, { useState, useEffect, useRef, forwardRef, useImperativeHandle } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, TextInput, AppState } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getTheme } from '../utils/theme';
import { Audio } from 'expo-av';

interface Props {
  minimized: boolean;
  onMinimize: (min: boolean) => void;
  isDarkMode?: boolean;
  onDurationChange?: (duration: number) => void; // Callback para reportar cambios en la duración
}

const TimerBar = forwardRef<{ resetAllTimers: () => void }, Props>(({ minimized, onMinimize, isDarkMode, onDurationChange }, ref) => {
  const insets = useSafeAreaInsets();
  const theme = getTheme(isDarkMode || false);

  // Estados para el cronómetro incremental
  const [incrementalTime, setIncrementalTime] = useState(0);
  const [isIncrementalRunning, setIsIncrementalRunning] = useState(false);
  const [incrementalInput, setIncrementalInput] = useState('00:00'); // Para editar el tiempo
  const [isEditingIncremental, setIsEditingIncremental] = useState(false);
  const [incrementalStartTime, setIncrementalStartTime] = useState<number | null>(null);
  const [incrementalPausedTime, setIncrementalPausedTime] = useState(0);

  // Estados para el temporizador regresivo
  const [regressiveTime, setRegressiveTime] = useState(60); // 1 minuto por defecto
  const [isRegressiveRunning, setIsRegressiveRunning] = useState(false);
  const [originalRegressiveTime, setOriginalRegressiveTime] = useState(60);
  const [regressiveInput, setRegressiveInput] = useState('01:00'); // Para editar el tiempo
  const [isEditingRegressive, setIsEditingRegressive] = useState(false);
  const [regressiveStartTime, setRegressiveStartTime] = useState<number | null>(null);
  const [regressivePausedTime, setRegressivePausedTime] = useState(0);

  // Referencias para los intervalos
  const incrementalIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const regressiveIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // Función para reproducir notificación
  const playNotification = async () => {
    try {
      const { sound } = await Audio.Sound.createAsync(
        require('../assets/notification.mp3')
      );
      await sound.playAsync();
      
      // Limpiar el sonido después de reproducirlo
      sound.setOnPlaybackStatusUpdate((status) => {
        if (status.didJustFinish) {
          sound.unloadAsync();
        }
      });
      
      console.log('Timer finished! Sound played.');
    } catch (error) {
      console.log('Error playing notification:', error);
    }
  };

  // Listener para el estado de la app - simplificado
  useEffect(() => {
    const handleAppStateChange = (nextAppState: string) => {
      if (nextAppState === 'active') {
        // La app volvió a primer plano, actualizar timers si están corriendo
        if (isIncrementalRunning && incrementalStartTime) {
          const elapsed = Math.floor((Date.now() - incrementalStartTime) / 1000) + incrementalPausedTime;
          setIncrementalTime(elapsed);
        }
        if (isRegressiveRunning && regressiveStartTime) {
          const elapsed = Math.floor((Date.now() - regressiveStartTime) / 1000) + regressivePausedTime;
          const remaining = originalRegressiveTime - elapsed;
          if (remaining > 0) {
            setRegressiveTime(remaining);
          } else {
            setIsRegressiveRunning(false);
            setRegressiveTime(0);
          }
        }
      }
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);
    return () => subscription?.remove();
  }, []); // Sin dependencias para evitar bucles

  // Reportar cambios en la duración del timer incremental
  useEffect(() => {
    if (onDurationChange) {
      onDurationChange(incrementalTime);
    }
  }, [incrementalTime, onDurationChange]);

  // Función para formatear tiempo (segundos a MM:SS o HH:MM:SS)
  const formatTime = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    } else {
      return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
  };

  // Función para convertir MM:SS a segundos
  const parseTime = (timeString: string): number => {
    const parts = timeString.split(':');
    if (parts.length !== 2) return 60;
    const mins = parseInt(parts[0]) || 0;
    const secs = parseInt(parts[1]) || 0;
    return mins * 60 + secs;
  };

  // Función para validar formato de tiempo
  const isValidTimeFormat = (timeString: string): boolean => {
    const regex = /^([0-9]|[0-5][0-9]):([0-5][0-9])$/;
    return regex.test(timeString);
  };

  // Función para formatear input de tiempo automáticamente
  const formatTimeInput = (input: string): string => {
    // Remover caracteres no numéricos excepto ":"
    let cleaned = input.replace(/[^0-9:]/g, '');
    
    // Si no tiene ":", agregarlo después de 2 dígitos
    if (!cleaned.includes(':')) {
      if (cleaned.length >= 2) {
        cleaned = cleaned.slice(0, 2) + ':' + cleaned.slice(2);
      }
    }
    
    // Limitar a formato MM:SS
    if (cleaned.length > 5) {
      cleaned = cleaned.slice(0, 5);
    }
    
    return cleaned;
  };

  // Cronómetro incremental - simplificado
  useEffect(() => {
    if (isIncrementalRunning) {
      const startTime = Date.now();
      setIncrementalStartTime(startTime);
      
      incrementalIntervalRef.current = setInterval(() => {
        const elapsed = Math.floor((Date.now() - startTime) / 1000) + incrementalPausedTime;
        setIncrementalTime(elapsed);
      }, 1000);
    } else {
      if (incrementalIntervalRef.current) {
        clearInterval(incrementalIntervalRef.current);
        incrementalIntervalRef.current = null;
      }
      if (incrementalStartTime) {
        setIncrementalPausedTime(incrementalTime);
        setIncrementalStartTime(null);
      }
    }

    return () => {
      if (incrementalIntervalRef.current) {
        clearInterval(incrementalIntervalRef.current);
      }
    };
  }, [isIncrementalRunning]); // Solo depende de isIncrementalRunning

  // Temporizador regresivo - simplificado
  useEffect(() => {
    if (isRegressiveRunning && regressiveTime > 0) {
      const startTime = Date.now();
      setRegressiveStartTime(startTime);
      
      regressiveIntervalRef.current = setInterval(() => {
        const elapsed = Math.floor((Date.now() - startTime) / 1000) + regressivePausedTime;
        const remaining = originalRegressiveTime - elapsed;
        
        if (remaining <= 0) {
          setIsRegressiveRunning(false);
          setRegressiveTime(0);
          setRegressiveStartTime(null);
          setRegressivePausedTime(0);
          
          // Reproducir notificación al llegar a 00:00
          playNotification();
          
          // Auto-reset al llegar a 00:00
          setTimeout(() => {
            setRegressiveTime(originalRegressiveTime);
          }, 1000);
        } else {
          setRegressiveTime(remaining);
        }
      }, 1000);
    } else {
      if (regressiveIntervalRef.current) {
        clearInterval(regressiveIntervalRef.current);
        regressiveIntervalRef.current = null;
      }
      if (regressiveStartTime) {
        setRegressivePausedTime(originalRegressiveTime - regressiveTime);
        setRegressiveStartTime(null);
      }
    }

    return () => {
      if (regressiveIntervalRef.current) {
        clearInterval(regressiveIntervalRef.current);
      }
    };
  }, [isRegressiveRunning, originalRegressiveTime]); // Solo depende de isRegressiveRunning y originalRegressiveTime

  // Controles del cronómetro incremental
  const handleIncrementalStart = () => { 
    setIsIncrementalRunning(true); 
  };
  const handleIncrementalPause = () => { 
    setIsIncrementalRunning(false); 
  };
  const handleIncrementalReset = () => {
    setIsIncrementalRunning(false);
    setIncrementalTime(0);
    setIncrementalPausedTime(0);
    setIncrementalStartTime(null);
    setIncrementalInput('00:00');
  };

  // Función para resetear todos los timers (llamada desde fuera)
  const resetAllTimers = () => {
    // Resetear timer incremental
    setIsIncrementalRunning(false);
    setIncrementalTime(0);
    setIncrementalPausedTime(0);
    setIncrementalStartTime(null);
    setIncrementalInput('00:00');
    
    // Resetear timer regresivo
    setIsRegressiveRunning(false);
    setRegressiveTime(originalRegressiveTime);
    setRegressivePausedTime(0);
    setRegressiveStartTime(null);
    setRegressiveInput(formatTime(originalRegressiveTime));
  };

  // Exponer función de reset a través de ref
  useImperativeHandle(ref, () => ({
    resetAllTimers
  }));
  const handleIncrementalEdit = () => { setIsEditingIncremental(true); };
  const handleIncrementalSave = () => {
    if (isValidTimeFormat(incrementalInput)) {
      const newTime = parseTime(incrementalInput);
      setIncrementalTime(newTime);
      setIsEditingIncremental(false);
    }
  };
  const handleIncrementalCancel = () => {
    setIncrementalInput(formatTime(incrementalTime));
    setIsEditingIncremental(false);
  };

  // Controles del temporizador regresivo
  const handleRegressiveStart = () => { 
    if (!isRegressiveRunning) { 
      setIsRegressiveRunning(true); 
    } 
  };
  const handleRegressivePause = () => { 
    setIsRegressiveRunning(false); 
  };
  const handleRegressiveReset = () => {
    setIsRegressiveRunning(false);
    setRegressiveTime(originalRegressiveTime);
    setRegressivePausedTime(0);
    setRegressiveStartTime(null);
    setRegressiveInput(formatTime(originalRegressiveTime));
  };
  const handleRegressiveEdit = () => { setIsEditingRegressive(true); };
  const handleRegressiveSave = () => {
    if (isValidTimeFormat(regressiveInput)) {
      const newTime = parseTime(regressiveInput);
      setRegressiveTime(newTime);
      setOriginalRegressiveTime(newTime);
      setIsEditingRegressive(false);
    }
  };
  const handleRegressiveCancel = () => {
    setRegressiveInput(formatTime(regressiveTime));
    setIsEditingRegressive(false);
  };

  if (minimized) {
    return (
      <View style={[styles.minimized, { backgroundColor: theme.background, borderColor: theme.border, marginTop: 6, marginBottom: 6, borderTopWidth: 1, borderTopColor: '#D4A574' }]}>
        <View style={styles.minimizedHeader}>
          <Text style={[styles.minTextAligned, { color: theme.textPrimary }]}>Cronómetro</Text>
          <TouchableOpacity style={[styles.expandButton, { backgroundColor: '#D4A574' }]} onPress={() => onMinimize(false)}>
            <Text style={[styles.expandButtonText, { color: '#FFFFFF' }]}>Expandir</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background, borderColor: theme.border, marginTop: 6, marginBottom: 6, borderTopWidth: 1, borderTopColor: '#D4A574' }]}>
      <View style={[styles.header, { borderBottomColor: theme.border }]}>
        <Text style={[styles.minTextAligned, { color: theme.textPrimary }]}>Cronómetro</Text>
        <TouchableOpacity style={[styles.minimizeButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => onMinimize(true)}>
          <Text style={[styles.minimizeButtonText, { color: theme.buttonText }]}>Minimizar</Text>
        </TouchableOpacity>
      </View>
      <View style={styles.timers}>
        <View style={[styles.timerBox, { backgroundColor: theme.timerBox, borderColor: theme.border }]}>
          <Text style={[styles.timerLabel, { color: theme.textSecondary }]}>Tiempo total</Text>
          {isEditingIncremental ? (
            <View style={styles.editContainer}>
              <TextInput
                style={[styles.timeInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                value={incrementalInput}
                onChangeText={(text) => setIncrementalInput(formatTimeInput(text))}
                placeholder="MM:SS"
                placeholderTextColor={theme.textSecondary}
                keyboardType="numeric"
                maxLength={5}
              />
              <View style={styles.editButtons}>
                <TouchableOpacity style={[styles.editBtn, { backgroundColor: theme.buttonSecondary }]} onPress={handleIncrementalSave}>
                  <Text style={[styles.editBtnText, { color: theme.buttonText }]}>✓</Text>
                </TouchableOpacity>
                <TouchableOpacity style={[styles.editBtn, { backgroundColor: theme.buttonSecondary }]} onPress={handleIncrementalCancel}>
                  <Text style={[styles.editBtnText, { color: theme.buttonText }]}>✗</Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : (
            <TouchableOpacity onPress={handleIncrementalEdit}>
              <Text style={[styles.timerValue, { color: theme.textPrimary }]}>{formatTime(incrementalTime)}</Text>
            </TouchableOpacity>
          )}
          <View style={styles.btnRow}>
            {!isIncrementalRunning ? (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleIncrementalStart}>
                <Text style={[styles.btnText, { color: theme.buttonText }]}>Iniciar</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleIncrementalPause}>
                <Text style={[styles.btnText, { color: theme.buttonText }]}>Pausar</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleIncrementalReset}>
              <Text style={[styles.btnText, { color: theme.buttonText }]}>Resetear</Text>
            </TouchableOpacity>
          </View>
        </View>
        <View style={[styles.timerBox, { backgroundColor: theme.timerBox, borderColor: theme.border }]}>
          <Text style={[styles.timerLabel, { color: theme.textSecondary }]}>Descanso</Text>
          {isEditingRegressive ? (
            <View style={styles.editContainer}>
              <TextInput
                style={[styles.timeInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                value={regressiveInput}
                onChangeText={(text) => setRegressiveInput(formatTimeInput(text))}
                placeholder="MM:SS"
                placeholderTextColor={theme.textSecondary}
                keyboardType="numeric"
                maxLength={5}
              />
              <View style={styles.editButtons}>
                <TouchableOpacity style={[styles.editBtn, { backgroundColor: theme.buttonSecondary }]} onPress={handleRegressiveSave}>
                  <Text style={[styles.editBtnText, { color: theme.buttonText }]}>✓</Text>
                </TouchableOpacity>
                <TouchableOpacity style={[styles.editBtn, { backgroundColor: theme.buttonSecondary }]} onPress={handleRegressiveCancel}>
                  <Text style={[styles.editBtnText, { color: theme.buttonText }]}>✗</Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : (
            <TouchableOpacity onPress={handleRegressiveEdit}>
              <Text style={[styles.timerValue, { color: theme.textPrimary }]}>{formatTime(regressiveTime)}</Text>
            </TouchableOpacity>
          )}
          <View style={styles.btnRow}>
            {!isRegressiveRunning ? (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleRegressiveStart}>
                <Text style={[styles.btnText, { color: theme.buttonText }]}>Iniciar</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleRegressivePause}>
                <Text style={[styles.btnText, { color: theme.buttonText }]}>Pausar</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleRegressiveReset}>
              <Text style={[styles.btnText, { color: theme.buttonText }]}>Resetear</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 1,
    padding: 4, // Reducir padding de 8 a 4
    marginTop: 0, // Sin margen superior para estar más pegado a la línea
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4, // Reducir margen inferior de 8 a 4
    paddingBottom: 4,
    paddingHorizontal: 8, // Igualar con ExerciseList
    borderBottomWidth: 1,
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 4, // Configuración válida
  },
  minBtn: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  timers: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  timerBox: {
    flex: 1,
    marginHorizontal: 4,
    padding: 12, // Aumentar padding de 6 a 12 para más espacio
    borderRadius: 8,
    minHeight: 150, // Reducir altura mínima de 160px a 150px
  },
  timerLabel: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 8, // Aumentar margen inferior de 6 a 8 para más separación
    fontFamily: 'System',
  },
  timerValue: {
    fontSize: 22,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 12, // Aumentar margen inferior de 10 a 12 para más separación
    fontFamily: 'System',
  },
  editContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 10, // Aumentar margen inferior de 6 a 10 para más separación
  },
  timeInput: {
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 6,
    width: 110,
    textAlign: 'center',
    fontSize: 18,
    fontFamily: 'System',
  },
  editButtons: {
    flexDirection: 'row',
    marginLeft: 8,
    alignItems: 'center',
  },
  editBtn: {
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderRadius: 4,
    marginHorizontal: 2,
    width: 28,
    height: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  editBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  btnRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  btn: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 6,
    minWidth: 70,
  },
  btnText: {
    fontWeight: '600',
    fontSize: 14,
    textAlign: 'center',
    fontFamily: 'System',
  },
  minimized: {
    borderBottomWidth: 1,
    padding: 2, // Reducir padding para estado minimizado
    paddingHorizontal: 8, // Igualar con ExerciseList
  },
  minText: {
    fontWeight: '600',
    fontSize: 18,
    fontFamily: 'System',
  },
  minTextAligned: {
    fontWeight: '600',
    fontSize: 18,
    fontFamily: 'System',
    marginLeft: 4, // Configuración válida
  },
  minimizeButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 4, // Igualar con ExerciseList
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
    paddingVertical: 3, // Igualar con ExerciseList
    paddingHorizontal: 8, // Mismo padding que ExerciseList
  },
  expandButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
  },
  expandButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
});

export default TimerBar; 