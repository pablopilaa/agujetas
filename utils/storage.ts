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
  rutina?: string; // Nombre de la rutina usada al guardar
  rutinaId?: string; // ID de la rutina usada al guardar
}

// Sesiones personalizadas (plantillas)
export interface CustomSession {
  id: string;
  name: string;
  exercises: ExerciseHistory[] | any[]; // permite plantillas sin fecha
}

// Rutinas compuestas por sesiones (por defecto o personalizadas)
export interface Routine {
  id: string;
  name: string;
  sessionRefs: Array<{ type: 'default' | 'custom'; key: string }>; // key: nombre o id
}

// ====== Peso corporal ======
export interface BodyWeightRecord {
  id: string;
  dateISO: string; // YYYY-MM-DD or full ISO
  weightKg: number;
}

const BODY_WEIGHTS_KEY = 'bodyWeights';
const LAST_BODY_WEIGHT_WARNING_KEY = 'last_body_weight_warning_shown';

export const getBodyWeights = async (): Promise<BodyWeightRecord[]> => {
  try {
    const data = await AsyncStorage.getItem(BODY_WEIGHTS_KEY);
    const list: BodyWeightRecord[] = data ? JSON.parse(data) : [];
    // Ordenar descendente por fecha
    return list.sort((a, b) => new Date(b.dateISO).getTime() - new Date(a.dateISO).getTime());
  } catch (error) {
    console.error('Error obteniendo pesos corporales:', error);
    return [];
  }
};

export const addBodyWeight = async (record: Omit<BodyWeightRecord, 'id'>): Promise<BodyWeightRecord> => {
  try {
    const id = Date.now().toString();
    const withId: BodyWeightRecord = { ...record, id };
    const existing = await getBodyWeights();
    const updated = [withId, ...existing];
    await AsyncStorage.setItem(BODY_WEIGHTS_KEY, JSON.stringify(updated));
    return withId;
  } catch (error) {
    console.error('Error agregando peso corporal:', error);
    throw error;
  }
};

export const deleteBodyWeight = async (id: string): Promise<boolean> => {
  try {
    const existing = await getBodyWeights();
    const filtered = existing.filter(r => r.id !== id);
    await AsyncStorage.setItem(BODY_WEIGHTS_KEY, JSON.stringify(filtered));
    return true;
  } catch (error) {
    console.error('Error eliminando peso corporal:', error);
    return false;
  }
};

// Devuelve el último peso cuyo dateISO sea <= a la fecha indicada
export const getBodyWeightAt = async (date: Date): Promise<number | null> => {
  try {
    const list = await getBodyWeights();
    if (list.length === 0) return null;
    const target = date.getTime();
    // Encontrar el más reciente <= target
    const found = list.find(r => new Date(r.dateISO).getTime() <= target);
    return found ? found.weightKg : null;
  } catch {
    return null;
  }
};

export const getLastBodyWeightWarningShown = async (): Promise<string | null> => {
  try {
    return await AsyncStorage.getItem(LAST_BODY_WEIGHT_WARNING_KEY);
  } catch {
    return null;
  }
};

export const setLastBodyWeightWarningShown = async (isoDate: string): Promise<void> => {
  try {
    await AsyncStorage.setItem(LAST_BODY_WEIGHT_WARNING_KEY, isoDate);
  } catch {}
};

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

// ===== Custom Sessions API =====
export const getCustomSessions = async (): Promise<CustomSession[]> => {
  try {
    const data = await AsyncStorage.getItem('customSessions');
    return data ? JSON.parse(data) : [];
  } catch (error) {
    console.error('Error obteniendo sesiones personalizadas:', error);
    return [];
  }
};

export const saveCustomSession = async (session: Omit<CustomSession, 'id'>) => {
  try {
    const id = Date.now().toString();
    const withId: CustomSession = { ...session, id };
    const existing = await getCustomSessions();
    await AsyncStorage.setItem('customSessions', JSON.stringify([withId, ...existing]));
    return withId;
  } catch (error) {
    console.error('Error guardando sesión personalizada:', error);
    throw error;
  }
};

export const deleteCustomSession = async (customId: string): Promise<boolean> => {
  try {
    const existing = await getCustomSessions();
    const filtered = existing.filter(s => s.id !== customId);
    await AsyncStorage.setItem('customSessions', JSON.stringify(filtered));
    return true;
  } catch (error) {
    console.error('Error eliminando sesión personalizada:', error);
    return false;
  }
};

export const updateCustomSession = async (session: CustomSession): Promise<boolean> => {
  try {
    const existing = await getCustomSessions();
    const updated = existing.map(s => (s.id === session.id ? session : s));
    await AsyncStorage.setItem('customSessions', JSON.stringify(updated));
    return true;
  } catch (error) {
    console.error('Error actualizando sesión personalizada:', error);
    return false;
  }
};

// ====== Gestión de tipos de sesión por defecto editados ======
export const getSessionTypeOverrides = async (): Promise<Partial<Record<string, ExerciseHistory[]>>> => {
  try {
    const data = await AsyncStorage.getItem('sessionTypeOverrides');
    return data ? JSON.parse(data) : {};
  } catch (error) {
    console.error('Error obteniendo overrides de tipos de sesión:', error);
    return {};
  }
};

export const saveSessionTypeOverrides = async (overrides: Partial<Record<string, ExerciseHistory[]>>): Promise<boolean> => {
  try {
    await AsyncStorage.setItem('sessionTypeOverrides', JSON.stringify(overrides));
    return true;
  } catch (error) {
    console.error('Error guardando overrides de tipos de sesión:', error);
    return false;
  }
};

export const updateSessionTypeOverride = async (sessionType: string, exercises: ExerciseHistory[]): Promise<boolean> => {
  try {
    const overrides = await getSessionTypeOverrides();
    overrides[sessionType] = exercises;
    await saveSessionTypeOverrides(overrides);
    return true;
  } catch (error) {
    console.error('Error actualizando override de tipo de sesión:', error);
    return false;
  }
};

// ====== Tipos por defecto eliminados ======
export const getDeletedSessionTypes = async (): Promise<string[]> => {
  try {
    const data = await AsyncStorage.getItem('deletedSessionTypes');
    return data ? JSON.parse(data) : [];
  } catch (e) {
    console.error('Error obteniendo tipos eliminados:', e);
    return [];
  }
};

export const addDeletedSessionType = async (name: string): Promise<void> => {
  const current = await getDeletedSessionTypes();
  if (current.includes(name)) return;
  await AsyncStorage.setItem('deletedSessionTypes', JSON.stringify([...current, name]));
};

export const removeDeletedSessionType = async (name: string): Promise<void> => {
  const current = await getDeletedSessionTypes();
  await AsyncStorage.setItem('deletedSessionTypes', JSON.stringify(current.filter(n => n !== name)));
};

// ===== Routines API =====
export const getRoutines = async (): Promise<Routine[]> => {
  try {
    const data = await AsyncStorage.getItem('routines');
    return data ? JSON.parse(data) : [];
  } catch (error) {
    console.error('Error obteniendo rutinas:', error);
    return [];
  }
};

export const saveRoutine = async (routine: Omit<Routine, 'id'>) => {
  try {
    const id = Date.now().toString();
    const withId: Routine = { ...routine, id };
    const existing = await getRoutines();
    await AsyncStorage.setItem('routines', JSON.stringify([withId, ...existing]));
    return withId;
  } catch (error) {
    console.error('Error guardando rutina:', error);
    throw error;
  }
};

export const deleteRoutine = async (routineId: string): Promise<boolean> => {
  try {
    const existing = await getRoutines();
    const filtered = existing.filter(r => r.id !== routineId);
    await AsyncStorage.setItem('routines', JSON.stringify(filtered));
    return true;
  } catch (error) {
    console.error('Error eliminando rutina:', error);
    return false;
  }
};

export const updateRoutine = async (routine: Routine): Promise<boolean> => {
  try {
    const existing = await getRoutines();
    const updated = existing.map(r => (r.id === routine.id ? routine : r));
    await AsyncStorage.setItem('routines', JSON.stringify(updated));
    return true;
  } catch (error) {
    console.error('Error actualizando rutina:', error);
    return false;
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