import React, { useState, useRef, useEffect } from 'react';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { View, StyleSheet } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import EditMenu from './components/EditMenu';
import TimerBar from './components/TimerBar';
import ExerciseList, { ExerciseListRef } from './components/ExerciseList';
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

export default function App() {
  const [timerMinimized, setTimerMinimized] = useState(false);
  const [exerciseListMinimized, setExerciseListMinimized] = useState(true);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [exercises, setExercises] = useState(initialData);
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [sessionDuration, setSessionDuration] = useState(0);
  const [showWelcome, setShowWelcome] = useState(true);
  const exerciseListRef = useRef<ExerciseListRef>(null);
  const timerRef = useRef<{ resetAllTimers: () => void } | null>(null);

  const handleAddExercise = () => {
    exerciseListRef.current?.openAddExerciseModal();
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

  // Notificaciones push deshabilitadas por decisión del proyecto
  useEffect(() => { /* no-op */ }, []);

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
          />
        </View>
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

}); 