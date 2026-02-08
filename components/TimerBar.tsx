import React, { useState, useEffect, useRef, forwardRef, useImperativeHandle } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, TextInput, AppState, Platform } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getTheme } from '../utils/theme';
import { createRestTimerController, createSessionTimerController } from '../utils/timerEngine';
import { ds } from '../utils/design';
import { Audio } from 'expo-av';
import * as Notifications from 'expo-notifications';


interface Props {
  minimized: boolean;
  onMinimize: (min: boolean) => void;
  isDarkMode?: boolean;
  onDurationChange?: (duration: number) => void; // Callback para reportar cambios en la duración
}

// Componente para mostrar tiempo editable
interface TimeDisplayProps {
  time: number;
  onTimeChange: (newTime: number) => void;
  isRunning: boolean;
  theme: any;
  formatTime: (seconds: number) => string;
}

const TimeDisplay: React.FC<TimeDisplayProps> = ({ time, onTimeChange, isRunning, theme, formatTime }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState('');

  const minutes = Math.floor(time / 60);
  const seconds = time % 60;

  const handleTimePress = () => {
    if (!isRunning) {
      setIsEditing(true);
      setEditValue(`${minutes.toString().padStart(2, '0')}${seconds.toString().padStart(2, '0')}`);
    }
  };

  const formatEditInput = (input: string): string => {
    // Remover todo excepto números
    const numbers = input.replace(/\D/g, '');
    
    if (numbers.length <= 2) {
      return numbers;
    } else if (numbers.length <= 4) {
      return `${numbers.slice(0, 2)}:${numbers.slice(2)}`;
    } else {
      return `${numbers.slice(0, 2)}:${numbers.slice(2, 4)}`;
    }
  };

  const handleEditChange = (text: string) => {
    const formatted = formatEditInput(text);
    setEditValue(formatted);
  };

  const handleEditSave = () => {
    if (isEditing) {
      // Extraer números del input
      const numbers = editValue.replace(/\D/g, '');
      
      if (numbers.length >= 2) {
        const mins = parseInt(numbers.slice(0, 2)) || 0;
        const secs = parseInt(numbers.slice(2, 4)) || 0;
        
        const newTime = (mins * 60) + secs;
        
        if (newTime >= 0 && newTime <= 3600) { // Máximo 1 hora
          onTimeChange(newTime);
        }
      }
      setIsEditing(false);
    }
  };

  const handleEditCancel = () => {
    setIsEditing(false);
  };

  if (isEditing) {
    return (
      <View style={styles.editContainer}>
        <TextInput
          style={[styles.timeInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
          value={editValue}
          onChangeText={handleEditChange}
          keyboardType="numeric"
          maxLength={5} // MM:SS
          autoFocus
          onBlur={handleEditSave}
          onSubmitEditing={handleEditSave}
          placeholder="MM:SS"
          placeholderTextColor={theme.textSecondary}
        />
        <View style={styles.editButtons}>
          <TouchableOpacity style={[styles.editBtn, { backgroundColor: theme.buttonSecondary }]} onPress={handleEditSave}>
            <Text style={[styles.editBtnText, { color: theme.buttonText }]}>✓</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.editBtn, { backgroundColor: theme.buttonSecondary }]} onPress={handleEditCancel}>
            <Text style={[styles.editBtnText, { color: theme.buttonText }]}>✗</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.timeDisplayContainer}>
      <TouchableOpacity onPress={handleTimePress} disabled={isRunning}>
        <Text style={[styles.timerValue, { color: theme.textPrimary }]}>{formatTime(time)}</Text>
      </TouchableOpacity>
    </View>
  );
};

type TimerBarRef = { resetAllTimers: () => void };
const TimerBar = forwardRef((
  { minimized, onMinimize, isDarkMode, onDurationChange }: Props,
  ref: React.Ref<TimerBarRef>
) => {
  const insets = useSafeAreaInsets();
  const theme = getTheme(isDarkMode || false);

  // Estados para el cronómetro incremental
  const [incrementalTime, setIncrementalTime] = useState(0);
  const [isIncrementalRunning, setIsIncrementalRunning] = useState(false);
  const [incrementalInput, setIncrementalInput] = useState('00:00'); // Para editar el tiempo
  const [isEditingIncremental, setIsEditingIncremental] = useState(false);

  // Estados para el temporizador regresivo
  const [regressiveTime, setRegressiveTime] = useState(60); // 1 minuto por defecto
  const [isRegressiveRunning, setIsRegressiveRunning] = useState(false);
  const [originalRegressiveTime, setOriginalRegressiveTime] = useState(60);
  const [regressiveInput, setRegressiveInput] = useState('01:00'); // Para editar el tiempo
  const [isEditingRegressive, setIsEditingRegressive] = useState(false);

  const scheduledNotificationIdRef = useRef<string | null>(null);
  const isAppActiveRef = useRef<boolean>(true);
  const isRegressiveRunningRef = useRef<boolean>(false);
  const regressiveTimeRef = useRef<number>(regressiveTime);
  const originalRegressiveTimeRef = useRef<number>(originalRegressiveTime);
  const sessionTimerRef = useRef(createSessionTimerController({ initialElapsedSeconds: 0 }));
  const restTimerRef = useRef<ReturnType<typeof createRestTimerController> | null>(null);

  // Función para reproducir notificación
  const playNotification = async () => {
    try {
      const { sound } = await Audio.Sound.createAsync(
        require('../assets/notification.mp3')
      );
      await sound.playAsync();
      
      // Limpiar el sonido después de reproducirlo
      sound.setOnPlaybackStatusUpdate((status) => {
        if ('didJustFinish' in status && status.didJustFinish) {
          sound.unloadAsync();
        }
      });
      
      console.log('Timer finished! Sound played.');
    } catch (error) {
      console.log('Error playing notification:', error);
    }
  };

  // Deshabilitado: no programar notificación push en background
  if (!restTimerRef.current) {
    restTimerRef.current = createRestTimerController({
      durationSeconds: originalRegressiveTimeRef.current,
      onFinished: () => {
        if (isAppActiveRef.current) {
          playNotification();
        }
        setTimeout(() => {
          const duration = originalRegressiveTimeRef.current;
          restTimerRef.current?.setDurationSeconds(duration);
          restTimerRef.current?.setRemainingSeconds(duration);
        }, 1000);
      },
    });
  }

  const scheduleNotification = async (_seconds: number) => { return; };





  // No inicializamos aquí; se hace una sola vez en App.tsx

  // Listener para el estado de la app - simplificado
  useEffect(() => {
    isRegressiveRunningRef.current = isRegressiveRunning;
  }, [isRegressiveRunning]);

  useEffect(() => {
    regressiveTimeRef.current = regressiveTime;
  }, [regressiveTime]);

  useEffect(() => {
    originalRegressiveTimeRef.current = originalRegressiveTime;
  }, [originalRegressiveTime]);

  // Listener para el estado de la app - simplificado
  useEffect(() => {
    const handleAppStateChange = (nextAppState: string) => {
      isAppActiveRef.current = nextAppState === 'active';
      if (nextAppState === 'active') {
        // Cancelar cualquier notificación al volver al foreground
        if (scheduledNotificationIdRef.current) {
          Notifications.cancelScheduledNotificationAsync(scheduledNotificationIdRef.current).catch(() => {});
          scheduledNotificationIdRef.current = null;
        }
        // La app volvió a primer plano, sincronizar timers desde el engine
        const sessionState = sessionTimerRef.current.getState();
        setIncrementalTime(sessionState.elapsedSeconds);
        setIsIncrementalRunning(sessionState.running);
        const restState = restTimerRef.current?.getState();
        if (restState) {
          setRegressiveTime(restState.remainingSeconds);
          setIsRegressiveRunning(restState.running);
        }
      } else {
        // Background/inactive: no programar notificación push (deshabilitado)
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

  useEffect(() => {
    const unsubscribe = sessionTimerRef.current.subscribe((state) => {
      setIncrementalTime(state.elapsedSeconds);
      setIsIncrementalRunning(state.running);
    });
    return () => { unsubscribe(); };
  }, []);

  useEffect(() => {
    const unsubscribe = restTimerRef.current?.subscribe((state) => {
      setRegressiveTime(state.remainingSeconds);
      setIsRegressiveRunning(state.running);
    });
    return () => { if (unsubscribe) unsubscribe(); };
  }, []);

  useEffect(() => {
    if (!restTimerRef.current) return;
    restTimerRef.current.setDurationSeconds(originalRegressiveTime);
    if (!isRegressiveRunning) {
      restTimerRef.current.setRemainingSeconds(originalRegressiveTime);
    }
  }, [originalRegressiveTime, isRegressiveRunning]);

  // Controles del cronómetro incremental
  const handleIncrementalStart = () => { 
    sessionTimerRef.current.start(); 
  };
  const handleIncrementalPause = () => { 
    sessionTimerRef.current.pause(); 
  };
  const handleIncrementalReset = () => {
    sessionTimerRef.current.reset();
    setIncrementalInput('00:00');
  };

  // Función para resetear todos los timers (llamada desde fuera)
  const resetAllTimers = () => {
    // Resetear timer incremental
    sessionTimerRef.current.reset();
    setIncrementalInput('00:00');
    
    // Resetear timer regresivo
    restTimerRef.current?.setDurationSeconds(originalRegressiveTimeRef.current);
    restTimerRef.current?.reset();
    setRegressiveInput(formatTime(originalRegressiveTimeRef.current));
    
    // Cancelar notificaciones push (solo en APK compilada)
    console.log('Notificaciones canceladas');
  };

  // Exponer función de reset a través de ref
  useImperativeHandle(ref, () => ({
    resetAllTimers
  }));
  const handleIncrementalEdit = () => { setIsEditingIncremental(true); };
  const handleIncrementalSave = () => {
    if (isValidTimeFormat(incrementalInput)) {
      const newTime = parseTime(incrementalInput);
      sessionTimerRef.current.setElapsedSeconds(newTime);
      setIncrementalInput(formatTime(newTime));
      setIsEditingIncremental(false);
    }
  };
  const handleIncrementalCancel = () => {
    setIncrementalInput(formatTime(incrementalTime));
    setIsEditingIncremental(false);
  };

  // Controles del temporizador regresivo
  const handleRegressiveStart = async () => { 
    if (!isRegressiveRunning) { 
      restTimerRef.current?.start();
    } 
  };
  const handleRegressivePause = async () => { 
    restTimerRef.current?.pause();
    try {
      if (scheduledNotificationIdRef.current) {
        await Notifications.cancelScheduledNotificationAsync(scheduledNotificationIdRef.current);
        scheduledNotificationIdRef.current = null;
      }
    } catch {}
  };
  const handleRegressiveReset = async () => {
    restTimerRef.current?.setDurationSeconds(originalRegressiveTimeRef.current);
    restTimerRef.current?.reset();
    setRegressiveInput(formatTime(originalRegressiveTimeRef.current));
    try {
      if (scheduledNotificationIdRef.current) {
        await Notifications.cancelScheduledNotificationAsync(scheduledNotificationIdRef.current);
        scheduledNotificationIdRef.current = null;
      }
    } catch {}
  };
  const handleRegressiveEdit = () => { setIsEditingRegressive(true); };
  const handleRegressiveSave = () => {
    if (isValidTimeFormat(regressiveInput)) {
      const newTime = parseTime(regressiveInput);
      setOriginalRegressiveTime(newTime);
      restTimerRef.current?.setDurationSeconds(newTime);
      restTimerRef.current?.setRemainingSeconds(newTime);
      setIsEditingRegressive(false);
    }
  };
  const handleRegressiveCancel = () => {
    setIsEditingRegressive(false);
    setRegressiveInput(formatTime(regressiveTime));
  };

  const handleAdd15Seconds = () => {
    if (isRegressiveRunning) {
      // Si está corriendo, solo ajustar temporalmente el tiempo restante
      const newRemainingTime = regressiveTime + 15;
      restTimerRef.current?.setRemainingSeconds(newRemainingTime);
      // Nunca programar notificación desde aquí. Si está en background,
      // AppState listener se encarga de programar con el tiempo actual.
      if (scheduledNotificationIdRef.current) {
        Notifications.cancelScheduledNotificationAsync(scheduledNotificationIdRef.current).catch(() => {});
        scheduledNotificationIdRef.current = null;
      }
    } else {
      // Si está quieto, modificar la configuración permanente
      const newTime = originalRegressiveTime + 15;
      setOriginalRegressiveTime(newTime);
      restTimerRef.current?.setDurationSeconds(newTime);
      restTimerRef.current?.setRemainingSeconds(newTime);
      setRegressiveInput(formatTime(newTime));
    }
  };

  const handleSubtract15Seconds = () => {
    if (isRegressiveRunning) {
      // Si está corriendo, solo ajustar temporalmente el tiempo restante
      if (regressiveTime > 15) {
        const newRemainingTime = regressiveTime - 15;
        restTimerRef.current?.setRemainingSeconds(newRemainingTime);
        if (scheduledNotificationIdRef.current) {
          Notifications.cancelScheduledNotificationAsync(scheduledNotificationIdRef.current).catch(() => {});
          scheduledNotificationIdRef.current = null;
        }
      }
    } else {
      // Si está quieto, modificar la configuración permanente
      if (originalRegressiveTime > 15) {
        const newTime = originalRegressiveTime - 15;
        setOriginalRegressiveTime(newTime);
        restTimerRef.current?.setDurationSeconds(newTime);
        restTimerRef.current?.setRemainingSeconds(newTime);
        setRegressiveInput(formatTime(newTime));
      }
    }
  };

  const handleAdd1Minute = () => {
    sessionTimerRef.current.setElapsedSeconds(incrementalTime + 60);
  };

  const handleSubtract1Minute = () => {
    if (incrementalTime < 60) return;
    sessionTimerRef.current.setElapsedSeconds(Math.max(0, incrementalTime - 60));
  };

  if (minimized) {
    return (
      <View style={[styles.minimized, { backgroundColor: theme.background, borderColor: theme.border, marginTop: ds.spacing - 2, marginBottom: ds.spacing - 2, borderTopWidth: 1, borderTopColor: ds.header.borderTopColor }]}>
        <View style={[styles.minimizedHeader, { paddingHorizontal: ds.header.paddingHorizontal, paddingTop: ds.header.paddingTop, paddingBottom: ds.header.paddingBottom, minHeight: ds.header.height }]} >
          <Text style={[styles.minTextAligned, { color: theme.textPrimary }]}>Cronómetros</Text>
        <View style={styles.actionArea}>
          <TouchableOpacity style={[styles.expandButton, { backgroundColor: '#D4A574' }]} onPress={() => onMinimize(false)}>
            <Text style={[styles.expandButtonText, { color: '#FFFFFF' }]}>Expandir</Text>
          </TouchableOpacity>
        </View>
        {/* No separator in minimized state to avoid double line */}
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background, borderColor: theme.border, marginTop: ds.spacing - 2, marginBottom: ds.spacing - 2, borderTopWidth: 1, borderTopColor: ds.header.borderTopColor }]}>
      <View style={[styles.header, { paddingHorizontal: ds.header.paddingHorizontal, paddingTop: ds.header.paddingTop, paddingBottom: ds.header.paddingBottom, minHeight: ds.header.height }]}> 
        <Text style={[styles.minTextAligned, { color: theme.textPrimary }]}>Cronómetros</Text>
        <View style={styles.actionArea}>
          <TouchableOpacity style={[styles.minimizeButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => onMinimize(true)}>
            <Text style={[styles.minimizeButtonText, { color: theme.buttonText }]}>Minimizar</Text>
          </TouchableOpacity>
        </View>
      </View>
      <View style={[styles.headerSeparator, { backgroundColor: theme.border, marginTop: ds.header.separatorMarginTop }]} />
      <View style={styles.timers}>
        <View style={[styles.timerBox, { backgroundColor: theme.timerBox, borderColor: theme.border }]}>
          <Text style={[styles.timerLabel, { color: theme.textSecondary }]}>Tiempo total ↑</Text>
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
          {/* Botones +/- 1 minuto para tiempo total */}
          {!isEditingIncremental && (
            <View style={styles.adjustButtons}>
              <TouchableOpacity 
                style={[styles.adjustBtn, { backgroundColor: theme.buttonSecondary }]} 
                onPress={handleSubtract1Minute}
                disabled={incrementalTime < 60}
              >
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.adjustBtnText, { color: theme.buttonText }]}>-1m</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.adjustBtn, { backgroundColor: theme.buttonSecondary }]} 
                onPress={handleAdd1Minute}
              >
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.adjustBtnText, { color: theme.buttonText }]}>+1m</Text>
              </TouchableOpacity>
            </View>
          )}
          
          <View style={styles.btnRow}>
            {!isIncrementalRunning ? (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleIncrementalStart}>
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.btnText, { color: theme.buttonText }]}>Iniciar</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleIncrementalPause}>
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.btnText, { color: theme.buttonText }]}>Pausar</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleIncrementalReset}>
              <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.btnText, { color: theme.buttonText }]}>Resetear</Text>
            </TouchableOpacity>
          </View>
        </View>
        <View style={[styles.timerBox, { backgroundColor: theme.timerBox, borderColor: theme.border }]}>
          <Text style={[styles.timerLabel, { color: theme.textSecondary }]}>Temporizador ↓</Text>
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
            <TimeDisplay
              time={regressiveTime}
              onTimeChange={(newTime) => {
                setOriginalRegressiveTime(newTime);
                restTimerRef.current?.setDurationSeconds(newTime);
                restTimerRef.current?.setRemainingSeconds(newTime);
                setRegressiveInput(formatTime(newTime));
              }}
              isRunning={isRegressiveRunning}
              theme={theme}
              formatTime={formatTime}
            />
          )}
          
          {/* Botones +/- 15 segundos */}
          {!isEditingRegressive && (
            <View style={styles.adjustButtons}>
              <TouchableOpacity 
                style={[styles.adjustBtn, { backgroundColor: theme.buttonSecondary }]} 
                onPress={handleSubtract15Seconds}
                disabled={regressiveTime <= 15}
              >
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.adjustBtnText, { color: theme.buttonText }]}>-15s</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.adjustBtn, { backgroundColor: theme.buttonSecondary }]} 
                onPress={handleAdd15Seconds}
              >
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.adjustBtnText, { color: theme.buttonText }]}>+15s</Text>
              </TouchableOpacity>
            </View>
          )}
          
          <View style={styles.btnRow}>
            {!isRegressiveRunning ? (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleRegressiveStart}>
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.btnText, { color: theme.buttonText }]}>Iniciar</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleRegressivePause}>
                <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.btnText, { color: theme.buttonText }]}>Pausar</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={[styles.btn, { backgroundColor: theme.buttonPrimary }]} onPress={handleRegressiveReset}>
              <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.85} style={[styles.btnText, { color: theme.buttonText }]}>Resetear</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 0,
    paddingVertical: 3, // Unificar con estado minimizado
    paddingHorizontal: 0,
    marginTop: 0, // Sin margen superior para estar más pegado a la línea
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4, // Reducir margen inferior de 8 a 4
    paddingVertical: 3, // Igualar con Minimizado
    paddingHorizontal: 8, // Igualar con ExerciseList
  },
  headerSeparator: {
    height: 1,
    width: '100%',
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 12, // Igualar con ExerciseList
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
    fontSize: 30,
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
    justifyContent: 'center',
    paddingHorizontal: 15,
    gap: 10,
    width: '100%',
  },
  btn: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 6,
    width: 80,
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnText: {
    fontWeight: '600',
    fontSize: 12,
    textAlign: 'center',
    fontFamily: 'System',
  },
  minimized: {
    borderBottomWidth: 1,
    paddingVertical: 6,
    paddingHorizontal: 0, // Evitar doble padding horizontal (lo aporta el header)
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
    marginLeft: 12, // Igualar con ExerciseList
  },
  minimizeButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 0,
  },
  minimizeButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  actionArea: {
    minWidth: ds.sizes.headerActionMinWidth,
    alignItems: 'flex-end',
  },
  minimizedHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 6,
    paddingHorizontal: 8, // Mismo padding que ExerciseList
  },
  expandButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 4, // Igualar con ExerciseList
    // tamaño natural, sin ancho fijo
  },
  expandButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  adjustButtons: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 6,
    paddingHorizontal: 15,
    gap: 10,
    width: '100%',
  },
  adjustBtn: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 6,
    width: 80,
    alignItems: 'center',
    justifyContent: 'center',
  },
  adjustBtnText: {
    fontWeight: '600',
    fontSize: 12,
    textAlign: 'center',
    fontFamily: 'System',
  },
  timeDisplayContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 0,
    width: '100%',
  },
  timePart: {
    fontSize: 22,
    fontWeight: '600',
    fontFamily: 'System',
  },
  timeSeparator: {
    fontSize: 22,
    fontWeight: '600',
    fontFamily: 'System',
    marginHorizontal: 4,
  },
});

export default TimerBar; 
