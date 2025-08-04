import AsyncStorage from '@react-native-async-storage/async-storage';

export interface ExerciseHistory {
  ejercicio: string;
  musculo: string;
  series: Array<{
    reps: string;
    kg: string;
    rir: number | undefined;
  }>;
  fecha: string;
}

export interface SessionRecord {
  id: string;
  tipo: string;
  fecha: string;
  ejercicios: ExerciseHistory[];
  duracion?: number; // Duración en segundos
}

// Guardar una sesión completada
export const saveSession = async (session: Omit<SessionRecord, 'id'>) => {
  try {
    const id = Date.now().toString();
    const sessionWithId: SessionRecord = { ...session, id };
    
    // Obtener sesiones existentes
    const existingSessions = await getSessions();
    const updatedSessions = [...existingSessions, sessionWithId];
    
    // Guardar sesiones
    await AsyncStorage.setItem('sessions', JSON.stringify(updatedSessions));
    
    // Guardar historial de ejercicios para memoria de pesos
    for (const ejercicio of session.ejercicios) {
      await saveExerciseHistory(ejercicio);
    }
    
    return sessionWithId;
  } catch (error) {
    console.error('Error guardando sesión:', error);
    throw error;
  }
};

// Obtener todas las sesiones
export const getSessions = async (): Promise<SessionRecord[]> => {
  try {
    const sessions = await AsyncStorage.getItem('sessions');
    return sessions ? JSON.parse(sessions) : [];
  } catch (error) {
    console.error('Error obteniendo sesiones:', error);
    return [];
  }
};

// Guardar historial de un ejercicio específico
export const saveExerciseHistory = async (exercise: ExerciseHistory) => {
  try {
    const key = `exercise_${exercise.ejercicio}`;
    const existingHistory = await getExerciseHistory(exercise.ejercicio);
    
    // Agregar nuevo registro al inicio
    const updatedHistory = [exercise, ...existingHistory];
    
    // Mantener solo los últimos 5 registros
    const limitedHistory = updatedHistory.slice(0, 5);
    
    await AsyncStorage.setItem(key, JSON.stringify(limitedHistory));
  } catch (error) {
    console.error('Error guardando historial de ejercicio:', error);
  }
};

// Obtener historial de un ejercicio específico
export const getExerciseHistory = async (exerciseName: string): Promise<ExerciseHistory[]> => {
  try {
    const key = `exercise_${exerciseName}`;
    const history = await AsyncStorage.getItem(key);
    return history ? JSON.parse(history) : [];
  } catch (error) {
    console.error('Error obteniendo historial de ejercicio:', error);
    return [];
  }
};

// Obtener el último registro de un ejercicio
export const getLastExerciseRecord = async (exerciseName: string): Promise<ExerciseHistory | null> => {
  try {
    const history = await getExerciseHistory(exerciseName);
    return history.length > 0 ? history[0] : null;
  } catch (error) {
    console.error('Error obteniendo último registro:', error);
    return null;
  }
};

// Eliminar una sesión específica por ID
export const deleteSession = async (sessionId: string): Promise<boolean> => {
  try {
    const existingSessions = await getSessions();
    const filteredSessions = existingSessions.filter(session => session.id !== sessionId);
    
    await AsyncStorage.setItem('sessions', JSON.stringify(filteredSessions));
    return true;
  } catch (error) {
    console.error('Error eliminando sesión:', error);
    return false;
  }
};

// Limpiar todo el almacenamiento (para testing)
export const clearAllData = async () => {
  try {
    await AsyncStorage.clear();
    console.log('Datos limpiados exitosamente');
  } catch (error) {
    console.error('Error limpiando datos:', error);
  }
}; 