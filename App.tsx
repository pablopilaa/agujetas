import React, { useState, useRef } from 'react';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { View, StyleSheet } from 'react-native';
import ChatbotDrawer from './components/ChatbotDrawer';
import TimerBar from './components/TimerBar';
import ExerciseList, { ExerciseListRef } from './components/ExerciseList';
import DrawerTrigger from './components/DrawerTrigger';
import SessionSelector from './components/SessionSelector';
import { getTheme } from './utils/theme';

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

  return (
    <SafeAreaProvider>
      <SafeAreaView style={[styles.container, { backgroundColor: theme.background }]} edges={["top", "left", "right"]}>
        <ChatbotDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} exercises={exercises} setExercises={setExercises} onAddExercise={handleAddExercise} isDarkMode={isDarkMode} />
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