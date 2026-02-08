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

export interface ExerciseCatalogItem {
  ejercicio: string;
  musculo: string;
  createdAtISO: string;
  imageUri?: string;
}

export interface ExerciseCatalog {
  version: 1;
  items: ExerciseCatalogItem[];
}

// ====== Peso corporal ======
export interface BodyWeightRecord {
  id: string;
  dateISO: string; // YYYY-MM-DD or full ISO
  weightKg: number;
}

const BODY_WEIGHTS_KEY = 'bodyWeights';
const LAST_BODY_WEIGHT_WARNING_KEY = 'last_body_weight_warning_shown';
const EXERCISE_CATALOG_KEY = 'exerciseCatalog';

const normalizeExerciseName = (name: string): string => {
  return name
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ');
};

export const getExerciseCatalog = async (): Promise<ExerciseCatalog> => {
  try {
    const data = await AsyncStorage.getItem(EXERCISE_CATALOG_KEY);
    if (!data) return { version: 1, items: [] };
    const parsed = JSON.parse(data);
    if (!parsed || parsed.version !== 1 || !Array.isArray(parsed.items)) {
      return { version: 1, items: [] };
    }
    const items: ExerciseCatalogItem[] = [];
    const seen = new Set<string>();
    for (const raw of parsed.items) {
      if (!raw || typeof raw.ejercicio !== 'string' || typeof raw.musculo !== 'string') continue;
      const ejercicio = raw.ejercicio.trim();
      const musculo = raw.musculo.trim();
      if (!ejercicio || !musculo) continue;
      const imageUri = typeof raw.imageUri === 'string' ? raw.imageUri.trim() : '';
      const key = normalizeExerciseName(ejercicio);
      if (seen.has(key)) continue;
      seen.add(key);
      items.push({
        ejercicio,
        musculo,
        createdAtISO: typeof raw.createdAtISO === 'string' ? raw.createdAtISO : new Date().toISOString(),
        ...(imageUri ? { imageUri } : {}),
      });
    }
    return { version: 1, items };
  } catch (error) {
    console.error('Error obteniendo catálogo de ejercicios:', error);
    return { version: 1, items: [] };
  }
};

export const upsertExerciseInCatalog = async (
  exercise: { ejercicio: string; musculo: string; imageUri?: string }
): Promise<ExerciseCatalogItem | null> => {
  const ejercicio = exercise.ejercicio?.trim();
  const musculo = exercise.musculo?.trim();
  const imageUri = typeof exercise.imageUri === 'string' ? exercise.imageUri.trim() : undefined;
  const hasImageUri = !!imageUri;
  if (!ejercicio || !musculo) return null;
  try {
    const catalog = await getExerciseCatalog();
    const key = normalizeExerciseName(ejercicio);
    const existingIndex = catalog.items.findIndex(item => normalizeExerciseName(item.ejercicio) === key);
    if (existingIndex >= 0) {
      const existing = catalog.items[existingIndex];
      const updated: ExerciseCatalogItem = {
        ...existing,
        ejercicio,
        musculo,
        ...(hasImageUri ? { imageUri } : {}),
      };
      if (
        existing.ejercicio === updated.ejercicio &&
        existing.musculo === updated.musculo &&
        (existing.imageUri || '') === (updated.imageUri || '')
      ) {
        return existing;
      }
      const items = [...catalog.items];
      items[existingIndex] = updated;
      await AsyncStorage.setItem(EXERCISE_CATALOG_KEY, JSON.stringify({ version: 1, items }));
      return updated;
    }
    const created: ExerciseCatalogItem = {
      ejercicio,
      musculo,
      createdAtISO: new Date().toISOString(),
      ...(hasImageUri ? { imageUri } : {}),
    };
    await AsyncStorage.setItem(
      EXERCISE_CATALOG_KEY,
      JSON.stringify({ version: 1, items: [created, ...catalog.items] })
    );
    return created;
  } catch (error) {
    console.error('Error guardando catálogo de ejercicios:', error);
    return null;
  }
};

export const updateExerciseImage = async (ejercicio: string, imageUri: string | null): Promise<boolean> => {
  const name = ejercicio?.trim();
  if (!name) return false;
  try {
    const catalog = await getExerciseCatalog();
    const key = normalizeExerciseName(name);
    const index = catalog.items.findIndex(item => normalizeExerciseName(item.ejercicio) === key);
    if (index < 0) return false;
    const existing = catalog.items[index];
    const updated: ExerciseCatalogItem = { ...existing };
    const nextImage = typeof imageUri === 'string' ? imageUri.trim() : '';
    if (nextImage) {
      updated.imageUri = nextImage;
    } else {
      delete (updated as any).imageUri;
    }
    if ((existing.imageUri || '') === (updated.imageUri || '')) {
      return true;
    }
    const items = [...catalog.items];
    items[index] = updated;
    await AsyncStorage.setItem(EXERCISE_CATALOG_KEY, JSON.stringify({ version: 1, items }));
    return true;
  } catch (error) {
    console.error('Error actualizando imagen de ejercicio:', error);
    return false;
  }
};

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

// Reconstruir índice histórico completo (en memoria) desde sesiones guardadas
export const getExerciseHistoryIndex = async (): Promise<Record<string, ExerciseHistory[]>> => {
  try {
    const sessions = await getSessions();
    const index: Record<string, ExerciseHistory[]> = {};
    for (const session of sessions) {
      if (!session?.ejercicios || session.ejercicios.length === 0) continue;
      for (const ex of session.ejercicios) {
        if (!ex?.ejercicio) continue;
        const key = normalizeExerciseName(ex.ejercicio);
        if (!index[key]) index[key] = [];
        const fecha = ex.fecha && ex.fecha.trim() ? ex.fecha : (session.fecha || '');
        index[key].push({
          ejercicio: ex.ejercicio,
          musculo: ex.musculo,
          series: ex.series,
          fecha,
        });
      }
    }
    for (const key of Object.keys(index)) {
      index[key].sort((a, b) => new Date(a.fecha).getTime() - new Date(b.fecha).getTime());
    }
    return index;
  } catch (error) {
    console.error('Error construyendo índice histórico de ejercicios:', error);
    return {};
  }
};

// Obtener el último registro de un ejercicio
const normalizeLabel = (value: any): string => {
  if (value === undefined || value === null) return '';
  return String(value).trim().replace(/\s+/g, ' ');
};

const normalizeDateToISO = (value: any): string | null => {
  if (!value) return null;
  if (value instanceof Date && !isNaN(value.getTime())) return value.toISOString();
  const raw = String(value).trim();
  if (!raw) return null;
  let date = new Date(raw);
  if (isNaN(date.getTime()) && /^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    date = new Date(`${raw}T00:00:00`);
  }
  return isNaN(date.getTime()) ? null : date.toISOString();
};

const parseDurationSeconds = (value: any): number | undefined => {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'number' && Number.isFinite(value)) return Math.round(value);
  const raw = String(value).trim();
  if (!raw) return undefined;
  if (/^\d+:\d{1,2}(:\d{1,2})?$/.test(raw)) {
    const parts = raw.split(':').map(p => parseInt(p, 10));
    if (parts.length === 2) return parts[0] * 60 + parts[1];
    if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  const num = parseFloat(raw.replace(',', '.'));
  return Number.isFinite(num) ? Math.round(num) : undefined;
};

const normalizeSeries = (series: any): ExerciseHistory['series'] => {
  if (!Array.isArray(series)) return [];
  return series.map(s => ({
    reps: s?.reps !== undefined && s?.reps !== null ? String(s.reps) : '',
    kg: s?.kg !== undefined && s?.kg !== null ? String(s.kg) : '',
    rir: s?.rir !== undefined && s?.rir !== null && s?.rir !== '' ? Number(s.rir) : undefined,
  }));
};

const normalizeExercisesFromRow = (row: any, fallbackFecha: string): ExerciseHistory[] => {
  let ejercicios = row?.ejercicios;
  if (typeof ejercicios === 'string') {
    try {
      ejercicios = JSON.parse(ejercicios);
    } catch {
      ejercicios = null;
    }
  }
  if (Array.isArray(ejercicios)) {
    return ejercicios
      .map((ex: any) => ({
        ejercicio: normalizeLabel(ex?.ejercicio || ex?.exercise || ex?.name),
        musculo: normalizeLabel(ex?.musculo || ex?.muscle),
        series: normalizeSeries(ex?.series || []),
        fecha: normalizeLabel(ex?.fecha) || fallbackFecha,
      }))
      .filter(ex => ex.ejercicio);
  }
  const ejercicio = normalizeLabel(row?.ejercicio || row?.exercise || row?.exerciseName || row?.name);
  if (!ejercicio) return [];
  const musculo = normalizeLabel(row?.musculo || row?.muscle || row?.grupo || row?.group);
  const series = Array.isArray(row?.series)
    ? normalizeSeries(row.series)
    : [{
        reps: row?.reps !== undefined && row?.reps !== null ? String(row.reps) : '',
        kg: row?.kg !== undefined && row?.kg !== null ? String(row.kg) : '',
        rir: row?.rir !== undefined && row?.rir !== null && row?.rir !== '' ? Number(row.rir) : undefined,
      }];
  return [{
    ejercicio,
    musculo,
    series,
    fecha: fallbackFecha,
  }];
};

const buildImportId = (fechaISO: string, tipo: string, duracion?: number, ejercicios: ExerciseHistory[] = []): string => {
  const exercisesPart = ejercicios.map(ex => {
    const name = normalizeExerciseName(ex.ejercicio);
    const series = (ex.series || []).map(s => `${s.reps}|${s.kg}|${s.rir ?? ''}`).join(',');
    return `${name}:${series}`;
  }).join(';');
  return `${fechaISO}|${normalizeLabel(tipo)}|${duracion ?? ''}|${exercisesPart}`;
};

export const importSessionsFromCSV = async (rows: any[]): Promise<{ imported: number; skipped: number }> => {
  const existing = await getSessions();
  const existingImportIds = new Set<string>();
  for (const s of existing as any[]) {
    const importId = s?.source?.importId;
    if (importId) existingImportIds.add(String(importId));
  }
  let imported = 0;
  let skipped = 0;
  const updated = [...existing];
  for (const row of rows || []) {
    const fechaISO = normalizeDateToISO(row?.fecha || row?.date || row?.fechaISO || row?.dateISO);
    if (!fechaISO) { skipped++; continue; }
    const tipo = normalizeLabel(row?.tipo || row?.type || row?.actividad || row?.activityType || row?.sessionType);
    const duracion = parseDurationSeconds(row?.duracion || row?.duration || row?.durationSec || row?.durationSeconds);
    const ejercicios = normalizeExercisesFromRow(row, fechaISO);
    if (ejercicios.length === 0) { skipped++; continue; }
    const importId = buildImportId(fechaISO, tipo, duracion, ejercicios);
    if (existingImportIds.has(importId)) { skipped++; continue; }
    const session: any = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      fecha: fechaISO,
      tipo: tipo || 'Sesión',
      duracion,
      ejercicios,
      source: { type: 'csv', importId },
    };
    updated.push(session);
    existingImportIds.add(importId);
    imported++;
  }
  if (imported > 0) {
    await AsyncStorage.setItem('sessions', JSON.stringify(updated));
  }
  return { imported, skipped };
};

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
