import React, { useState, useRef, useEffect } from 'react';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { View, StyleSheet, Modal, Pressable } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import EditMenu from './components/EditMenu';
import TimerBar from './components/TimerBar';
import ExerciseList, { ExerciseListRef } from './components/ExerciseList';
import ExerciseAnalyticsSection from './components/ExerciseAnalyticsSection';
import SessionSelector from './components/SessionSelector';
import WelcomeScreen from './components/WelcomeScreen';
import { getTheme } from './utils/theme';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getBodyWeights, getLastBodyWeightWarningShown, setLastBodyWeightWarningShown } from './utils/storage';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';

// Estado inicial vacío - no hay ejercicios hasta que se seleccione una sesión
const initialData: Array<{
  ejercicio: string;
  musculo: string;
  series: Array<{ reps: string; kg: string; rir: number | undefined }>;
}> = [];

const ACTIVE_SESSION_DRAFT_KEY = '@agujetas_active_session_draft_v1';

type ActiveSessionDraft = {
  exercises: Array<{
    ejercicio: string;
    musculo: string;
    series: Array<{ reps: string; kg: string; rir: number | undefined }>;
  }>;
  sessionDuration: number;
  updatedAtISO: string;
};

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export default function App() {
  const [timerMinimized, setTimerMinimized] = useState(false);
  const [exerciseListMinimized, setExerciseListMinimized] = useState(true);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [exercises, setExercises] = useState(initialData);
  const [isDarkMode, setIsDarkMode] = useState(true);
  const [sessionDuration, setSessionDuration] = useState(0);
  const [showWelcome, setShowWelcome] = useState(true);
  const [isDraftHydrated, setIsDraftHydrated] = useState(false);
  const exerciseListRef = useRef<ExerciseListRef>(null);
  const exercisePickerHandlerRef = useRef<null | ((e: { ejercicio: string; musculo: string }) => void)>(null);
  const timerRef = useRef<{ resetAllTimers: () => void } | null>(null);

  const handleAddExercise = () => {
    exerciseListRef.current?.openAddExerciseModal();
  };

  const openExercisePickerForType = (onPick: (e: { ejercicio: string; musculo: string }) => void) => {
    exercisePickerHandlerRef.current = (picked) => {
      onPick(picked);
      exercisePickerHandlerRef.current = null;
    };
    exerciseListRef.current?.openAddExerciseModal();
  };

  const openImageManager = () => {
    exerciseListRef.current?.openImageManagerModal();
  };

  const openAnalytics = () => {
    setShowAnalytics(true);
  };

  const handleExerciseListMinimize = () => {
    setExerciseListMinimized(!exerciseListMinimized);
  };

  const handleSessionDurationChange = (duration: number) => {
    setSessionDuration(duration);
  };

  const handleSessionFinish = () => {
    // Resetear todos los timers
    if (timerRef.current) {
      timerRef.current.resetAllTimers();
    }
  };

  const getIncompleteFieldsCount = (): number => {
    let count = 0;
    exercises.forEach(exercise => {
      exercise.series.forEach(serie => {
        if (serie.reps.trim() === '' || serie.kg.trim() === '' || serie.rir === undefined) {
          count++;
        }
      });
    });
    return count;
  };

  const toggleDarkMode = () => {
    setIsDarkMode(!isDarkMode);
  };

  const theme = getTheme(isDarkMode);

  // Mostrar welcome al cold start y cerrarlo a los 1000ms
  useEffect(() => {
    let t: any;
    if (showWelcome) {
      t = setTimeout(() => setShowWelcome(false), 1000);
    }
    return () => { if (t) clearTimeout(t); };
  }, [showWelcome]);

  // Restaurar borrador de sesión en progreso (si existe)
  useEffect(() => {
    (async () => {
      try {
        const raw = await AsyncStorage.getItem(ACTIVE_SESSION_DRAFT_KEY);
        if (!raw) return;
        const parsed = JSON.parse(raw) as Partial<ActiveSessionDraft>;
        if (Array.isArray(parsed.exercises)) {
          setExercises(parsed.exercises as typeof initialData);
        }
        if (typeof parsed.sessionDuration === 'number' && parsed.sessionDuration >= 0) {
          setSessionDuration(parsed.sessionDuration);
        }
      } catch {
        // no-op: si el borrador está corrupto, se ignora
      } finally {
        setIsDraftHydrated(true);
      }
    })();
  }, []);

  // Guardado automático de sesión en progreso
  useEffect(() => {
    if (!isDraftHydrated) return;

    const timeout = setTimeout(() => {
      (async () => {
        try {
          if (exercises.length === 0) {
            await AsyncStorage.removeItem(ACTIVE_SESSION_DRAFT_KEY);
            return;
          }
          const payload: ActiveSessionDraft = {
            exercises,
            sessionDuration,
            updatedAtISO: new Date().toISOString(),
          };
          await AsyncStorage.setItem(ACTIVE_SESSION_DRAFT_KEY, JSON.stringify(payload));
        } catch {
          // no-op
        }
      })();
    }, 350);

    return () => clearTimeout(timeout);
  }, [exercises, sessionDuration, isDraftHydrated]);

  // Configura permisos y canal de notificaciones para el temporizador de descanso.
  useEffect(() => {
    (async () => {
      try {
        const permissions = await Notifications.getPermissionsAsync();
        if (permissions.status !== 'granted') {
          const requested = await Notifications.requestPermissionsAsync();
          if (requested.status !== 'granted') {
            console.warn('Notificaciones sin permisos; alertas en segundo plano desactivadas.');
          }
        }

        if (Platform.OS === 'android') {
          await Notifications.setNotificationChannelAsync('rest-timer-v5', {
            name: 'Temporizador de descanso',
            importance: Notifications.AndroidImportance.MAX,
            enableVibrate: true,
            vibrationPattern: [0, 300, 200, 300],
            lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
          });
        }
      } catch (error) {
        console.warn('Error configurando notificaciones locales:', error);
      }
    })();
  }, []);

  // Aviso semanal de peso corporal (solo cold start)
  useEffect(() => {
    (async () => {
      try {
        const list = await getBodyWeights();
        if (!list || list.length === 0) return;
        const lastWeightDate = new Date(list[0].dateISO);
        const now = new Date();
        const daysSince = Math.floor((now.getTime() - lastWeightDate.getTime()) / 86400000);
        if (daysSince < 7) return;
        const lastWarn = await getLastBodyWeightWarningShown();
        if (lastWarn) {
          const lastWarnDate = new Date(lastWarn);
          const daysSinceWarn = Math.floor((now.getTime() - lastWarnDate.getTime()) / 86400000);
          if (daysSinceWarn < 7) return;
        }
        alert('Ya pasó una semana, cargá tu peso actual para un seguimiento más efectivo');
        await setLastBodyWeightWarningShown(now.toISOString());
      } catch {}
    })();
  }, []);

  if (showWelcome) {
    return (
      <WelcomeScreen 
        isDarkMode={isDarkMode} 
        onFinish={() => setShowWelcome(false)} 
      />
    );
  }

  return (
    <SafeAreaProvider>
      <StatusBar style={isDarkMode ? 'light' : 'dark'} backgroundColor={theme.background} />
      <SafeAreaView style={[styles.container, { backgroundColor: theme.background }]} edges={["top", "left", "right"]}>
                 <EditMenu open={drawerOpen} onClose={() => setDrawerOpen(false)} exercises={exercises} setExercises={setExercises} onAddExercise={handleAddExercise} isDarkMode={isDarkMode} />
        <View style={styles.mainContent}>
          <SessionSelector 
          exercises={exercises} 
          setExercises={setExercises} 
          getIncompleteFieldsCount={getIncompleteFieldsCount}
          isDarkMode={isDarkMode}
          onToggleDarkMode={toggleDarkMode}
          sessionDuration={sessionDuration}
          onSessionFinish={handleSessionFinish}
          onOpenExercisePickerForType={openExercisePickerForType}
          onOpenAnalytics={openAnalytics}
          onOpenImageManager={openImageManager}
        />
        <TimerBar 
          minimized={timerMinimized} 
          onMinimize={setTimerMinimized} 
          isDarkMode={isDarkMode}
          onDurationChange={handleSessionDurationChange}
          ref={timerRef}
        />
          <ExerciseList 
            ref={exerciseListRef} 
            expand={exerciseListMinimized} 
            exercises={exercises} 
            setExercises={setExercises}
            onMinimize={handleExerciseListMinimize}
            onAddExercise={handleAddExercise}
            onOpenChatbot={() => setDrawerOpen(true)}
            isDarkMode={isDarkMode}
            onPickExercise={(e) => {
              if (exercisePickerHandlerRef.current) {
                exercisePickerHandlerRef.current(e);
              } else {
                // flujo normal: agregar al listado principal
                setExercises(prev => ([
                  ...prev,
                  { ejercicio: e.ejercicio, musculo: e.musculo, series: [
                    { reps: '', kg: '', rir: undefined },
                    { reps: '', kg: '', rir: undefined },
                    { reps: '', kg: '', rir: undefined },
                  ]}
                ]));
              }
            }}
          />
        </View>
        <Modal
          visible={showAnalytics}
          transparent
          animationType="slide"
          onRequestClose={() => setShowAnalytics(false)}
        >
          <View style={styles.analyticsOverlay}>
            <Pressable style={StyleSheet.absoluteFill} onPress={() => setShowAnalytics(false)} />
            <View style={[styles.analyticsContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}>
              <ExerciseAnalyticsSection
                minimized={false}
                onMinimize={() => setShowAnalytics(false)}
                isDarkMode={isDarkMode}
              />
            </View>
          </View>
        </Modal>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  mainContent: {
    flex: 1,
  },
  analyticsOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.45)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 12,
  },
  analyticsContainer: {
    width: '100%',
    maxHeight: '90%',
    borderWidth: 1,
    borderRadius: 12,
    overflow: 'hidden',
  },

}); 
