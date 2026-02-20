import React, { useState, useImperativeHandle, forwardRef, useEffect, useMemo, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, Modal, Image, Alert, KeyboardAvoidingView, Platform, FlatList } from 'react-native';
// import { Picker } from '@react-native-picker/picker';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getLastExerciseRecord, ExerciseHistory, getExerciseCatalog, upsertExerciseInCatalog, updateExerciseCatalogItem, updateExerciseImage } from '../utils/storage';
import { getTheme } from '../utils/theme';
import { ds } from '../utils/design';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system';
import { BlurView } from 'expo-blur';

interface Series {
  reps: string;
  kg: string;
  rir: number | undefined;
  tiempo?: string; // Para ejercicios aeróbicos
  done?: boolean; // Marcador manual de serie completada
}

interface Exercise {
  ejercicio: string;
  musculo: string;
  series: Series[];
}

interface Props {
  expand: boolean;
  exercises: Exercise[];
  setExercises: React.Dispatch<React.SetStateAction<Exercise[]>>;
  onMinimize?: () => void;
  onAddExercise?: () => void;
  onOpenChatbot?: () => void;
  isDarkMode?: boolean;
  onPickExercise?: (exercise: { ejercicio: string; musculo: string }) => void;
}

export interface ExerciseListRef {
  openAddExerciseModal: () => void;
  openImageManagerModal: () => void;
}

// Lista completa de ejercicios predefinidos para elegir al agregar
const predefinedExercises = [
  // Pectoral
  { ejercicio: 'Press banca', musculo: 'Pectoral' },
  { ejercicio: 'Press plano mancuernas', musculo: 'Pectoral' },
  { ejercicio: 'Press banca inclinado', musculo: 'Pectoral' },
  { ejercicio: 'Press inclinado mancuernas', musculo: 'Pectoral' },
  { ejercicio: 'Aperturas mancuernas', musculo: 'Pectoral' },
  { ejercicio: 'Press inclinado mancuernas Smith', musculo: 'Pectoral' },
  { ejercicio: 'Peck-Deck (Mariposa)', musculo: 'Pectoral' },
  
  // Hombros
  { ejercicio: 'Press militar', musculo: 'Hombros' },
  { ejercicio: 'Press militar mancuernas', musculo: 'Hombros' },
  { ejercicio: 'Extensión hombros polea', musculo: 'Hombros' },
  { ejercicio: 'Elevaciones laterales', musculo: 'Hombros' },
  { ejercicio: 'Elevaciones frontales', musculo: 'Hombros' },
  { ejercicio: 'Press inclinado mancuernas Smith', musculo: 'Hombros' },
  { ejercicio: 'Deltoides posterior', musculo: 'Hombros' },
  
  // Tríceps
  { ejercicio: 'Tríceps Katana', musculo: 'Tríceps' },
  { ejercicio: 'Extensión tríceps cable', musculo: 'Tríceps' },
  { ejercicio: 'Extensión tríceps mancuerna', musculo: 'Tríceps' },
  { ejercicio: 'Fondos paralelas', musculo: 'Tríceps' },
  { ejercicio: 'Fondos paralelas lastre', musculo: 'Tríceps' },
  { ejercicio: 'Press cerrado', musculo: 'Tríceps' },
  { ejercicio: 'Extensión tríceps polea', musculo: 'Tríceps' },
  { ejercicio: 'Triceps sentado', musculo: 'Tríceps' },
  
  // Bíceps
  { ejercicio: 'Curl bíceps mancuerna', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps barra', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps cable', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps martillo', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps concentrado', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps predicador', musculo: 'Bíceps' },
  { ejercicio: 'Curl bíceps spider', musculo: 'Bíceps' },
  
  // Espalda
  { ejercicio: 'Remo barra', musculo: 'Espalda' },
  { ejercicio: 'Remo mancuernas', musculo: 'Espalda' },
  { ejercicio: 'Remo polea', musculo: 'Espalda' },
  { ejercicio: 'Remo T', musculo: 'Espalda' },
  { ejercicio: 'Jalón al pecho', musculo: 'Espalda' },
  { ejercicio: 'Dominadas', musculo: 'Espalda' },
  { ejercicio: 'Dominadas lastre', musculo: 'Espalda' },
  
  // Cuádriceps
  { ejercicio: 'Sentadillas', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas mancuernas', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas frontales', musculo: 'Cuádriceps' },
  { ejercicio: 'Prensa de piernas', musculo: 'Cuádriceps' },
  { ejercicio: 'Extensión piernas', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas búlgaras', musculo: 'Cuádriceps' },
  { ejercicio: 'Sentadillas búlgaras mancuernas', musculo: 'Cuádriceps' },
  
  // Femoral
  { ejercicio: 'Curl femoral acostado', musculo: 'Femoral' },
  { ejercicio: 'Curl femoral sentado', musculo: 'Femoral' },
  { ejercicio: 'Curl femoral de pie', musculo: 'Femoral' },
  { ejercicio: 'Peso muerto rumano', musculo: 'Femoral' },
  { ejercicio: 'Good mornings', musculo: 'Femoral' },
  { ejercicio: 'Curl femoral mancuerna', musculo: 'Femoral' },
  
  // Abductores
  { ejercicio: 'Abducción máquina', musculo: 'Abductores' },
  { ejercicio: 'Abducción cable', musculo: 'Abductores' },
  { ejercicio: 'Abducción banda', musculo: 'Abductores' },
  { ejercicio: 'Abducción mancuerna', musculo: 'Abductores' },
  { ejercicio: 'Abducción polea', musculo: 'Abductores' },
  { ejercicio: 'Abducción peso corporal', musculo: 'Abductores' },
  
  // Aductores
  { ejercicio: 'Aducción máquina', musculo: 'Aductores' },
  { ejercicio: 'Aducción cable', musculo: 'Aductores' },
  { ejercicio: 'Aducción banda', musculo: 'Aductores' },
  { ejercicio: 'Aducción mancuerna', musculo: 'Aductores' },
  { ejercicio: 'Aducción polea', musculo: 'Aductores' },
  { ejercicio: 'Aducción peso corporal', musculo: 'Aductores' },
  
  // Gemelos
  { ejercicio: 'Elevación de gemelos de pie', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos sentado', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos prensa', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos mancuerna', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos escalón', musculo: 'Gemelos' },
  { ejercicio: 'Elevación de gemelos con barra', musculo: 'Gemelos' },
  
  // Aeróbico
  { ejercicio: 'Cinta', musculo: 'Aeróbico' },
  { ejercicio: 'Bicicleta', musculo: 'Aeróbico' },
  { ejercicio: 'Bicicleta elíptica', musculo: 'Aeróbico' },
  { ejercicio: 'Entrada en calor', musculo: 'Aeróbico' },
  { ejercicio: 'Remorgómetro', musculo: 'Aeróbico' },
  { ejercicio: 'Running', musculo: 'Aeróbico' },
  { ejercicio: 'Bootcamp', musculo: 'Aeróbico' },
];

type CatalogExerciseItem = {
  key?: string;
  ejercicio: string;
  musculo: string;
  imageUri?: string;
  aliasFor?: string;
  exerciseId?: string;
  imageId?: string;
  thumbnailUrl?: string;
  sortName?: string;
  sortMuscle?: string;
  searchText?: string;
};
type AppLibraryImageItem = {
  id: string;
  source: any;
  names: string[];
  primaryName: string;
  normalizedSearchText: string;
};

type LyftaPreindexedRow = {
  key: string;
  ejercicio: string;
  musculo: string;
  imageId?: string;
  thumbnailUrl?: string;
  normalizedName: string;
};

type LyftaPreindexedData = {
  version?: number;
  generatedAtISO?: string;
  exercises: LyftaPreindexedRow[];
  exactImageIdByNormalized?: Record<string, string>;
  imageNamesById?: Record<string, string[]>;
};
type ManualMappingRow = {
  exercise_name?: string;
  image_id_selected?: string;
};

const APP_IMAGE_URI_PREFIX = 'app-image://';
const manualMappingRows = (require('../assets/exercises-images/custom_exercises_manual_mapping.json') as ManualMappingRow[]) || [];

const normalizeExerciseName = (text: string): string =>
  text
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[-_/]+/g, ' ')
    .replace(/[^a-z0-9\s]/g, ' ')
    // Unificar variantes tipo "Extensiones de piernas" vs "Extension piernas"
    .replace(/\bextensiones?\s+de\s+/g, 'extension ')
    .replace(/\bextensiones?\s+/g, 'extension ')
    .replace(/^empuje de cadera\b/g, 'hip thrust')
    .replace(/^empuje_de_cadera\b/g, 'hip_thrust')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeSearchText = (text: string): string =>
  text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');

const isExcludedExerciseName = (name: string): boolean => {
  const normalized = normalizeExerciseName(name);
  return (
    normalized.startsWith('musculos del cuerpo') ||
    normalized.startsWith('musculo corporal') ||
    normalized.startsWith('medicion de')
  );
};

let cachedLocalImageMap: Record<string, any> | null = null;
let cachedLocalImageMapThumbs: Record<string, any> | null = null;
let cachedLocalImageNameIndex: Record<string, string> | null = null;
let cachedAppImageLibraryItems: AppLibraryImageItem[] | null = null;
let cachedLyftaData: {
  exercises: CatalogExerciseItem[];
  exactImageIdByNormalized: Record<string, string>;
  imageNamesById: Record<string, string[]>;
} | null = null;
const APP_LIBRARY_PAGE_SIZE = 30;

const getLocalImageMap = (): Record<string, any> => {
  if (!cachedLocalImageMap) {
    const imported = require('../assets/exercises-images/localImageMap');
    cachedLocalImageMap = (imported?.exerciseLocalImageMap || {}) as Record<string, any>;
  }
  return cachedLocalImageMap;
};

const getLocalImageThumbMap = (): Record<string, any> => {
  if (!cachedLocalImageMapThumbs) {
    const imported = require('../assets/exercises-images/localImageMapThumbs');
    cachedLocalImageMapThumbs = (imported?.exerciseLocalImageMapThumbs || {}) as Record<string, any>;
  }
  return cachedLocalImageMapThumbs;
};

const getLocalImageNameIndex = (): Record<string, string> => {
  if (!cachedLocalImageNameIndex) {
    const imported = require('../assets/exercises-images/localImageNameIndex.json');
    cachedLocalImageNameIndex = (imported?.nameToId || imported || {}) as Record<string, string>;
  }
  return cachedLocalImageNameIndex;
};

const getAppImageLibraryItems = (): AppLibraryImageItem[] => {
  if (cachedAppImageLibraryItems) return cachedAppImageLibraryItems;

  const imageNamesById = getLyftaData().imageNamesById || {};
  const localImageThumbMap = getLocalImageThumbMap();

  cachedAppImageLibraryItems = Object.keys(localImageThumbMap)
    .map((id) => {
      const names = imageNamesById[id] || [];
      const primaryName = names[0] || `Imagen ${id}`;
      const normalizedSearchText = normalizeSearchText(`${primaryName} ${id}`);
      return {
        id,
        source: localImageThumbMap[id],
        names,
        primaryName,
        normalizedSearchText,
      };
    });

  return cachedAppImageLibraryItems;
};

const extractImageId = (value: string): string | null => {
  const trimmed = (value || '').trim();
  if (!trimmed) return null;
  if (trimmed === 'lyfta_entry_without_local_image' || trimmed === 'not_in_lyfta_catalog') return null;
  const idMatch = trimmed.match(/(\d{8})(?!.*\d)/);
  if (idMatch?.[1]) return idMatch[1];
  if (/^\d{8}$/.test(trimmed)) return trimmed;
  return null;
};

const mapLyftaBodyPartToMuscle = (bodyPart: string): string => {
  const value = normalizeExerciseName(bodyPart);
  if (!value || value === 'n u l l') return 'General';
  if (value.includes('chest')) return 'Pectoral';
  if (value.includes('back')) return 'Espalda';
  if (value.includes('shoulders')) return 'Hombros';
  if (value.includes('biceps')) return 'Bíceps';
  if (value.includes('triceps')) return 'Tríceps';
  if (value.includes('quadriceps')) return 'Cuádriceps';
  if (value.includes('hamstrings')) return 'Femoral';
  if (value.includes('thighs')) return 'Piernas';
  if (value.includes('hips')) return 'Glúteos';
  if (value.includes('calves')) return 'Gemelos';
  if (value.includes('waist') || value.includes('abs')) return 'Abdomen';
  if (value.includes('forearms')) return 'Antebrazos';
  if (value.includes('neck')) return 'Cuello';
  if (value.includes('cardio')) return 'Aeróbico';
  if (value.includes('full body')) return 'General';
  return 'General';
};

const getLyftaData = () => {
  if (cachedLyftaData) return cachedLyftaData;

  const preindexed = (require('../assets/exercises-images/catalog.preindexed.json') as LyftaPreindexedData) || { exercises: [] };
  const exercises = (preindexed.exercises || []).map((row) => {
    const sortName = normalizeSearchText(row.ejercicio);
    const sortMuscle = normalizeSearchText(row.musculo || 'Sin grupo');
    return {
      key: row.key,
      ejercicio: row.ejercicio,
      musculo: row.musculo,
      ...(row.imageId ? { imageId: row.imageId } : {}),
      ...(row.thumbnailUrl ? { thumbnailUrl: row.thumbnailUrl } : {}),
      sortName,
      sortMuscle,
      searchText: `${sortName} ${sortMuscle}`,
    };
  });

  cachedLyftaData = {
    exercises,
    exactImageIdByNormalized: preindexed.exactImageIdByNormalized || {},
    imageNamesById: preindexed.imageNamesById || {},
  };
  return cachedLyftaData;
};

const ExerciseList = forwardRef<ExerciseListRef, Props>(({ expand, exercises, setExercises, onMinimize, onAddExercise, onOpenChatbot, isDarkMode, onPickExercise }, ref) => {
  const insets = useSafeAreaInsets();
  const theme = getTheme(isDarkMode || false);
  const [showAddExerciseModal, setShowAddExerciseModal] = useState(false);
  const [showEditCatalogExerciseModal, setShowEditCatalogExerciseModal] = useState(false);
  const [editCatalogMode, setEditCatalogMode] = useState<'menu' | 'name' | 'muscle'>('menu');
  const [editCatalogExercise, setEditCatalogExercise] = useState<CatalogExerciseItem | null>(null);
  const [editCatalogName, setEditCatalogName] = useState('');
  const [editCatalogMuscle, setEditCatalogMuscle] = useState('Pectoral');
  const [editCatalogOriginalName, setEditCatalogOriginalName] = useState('');
  const [editCatalogOriginalMuscle, setEditCatalogOriginalMuscle] = useState('');
  const [previousRecords, setPreviousRecords] = useState<Record<string, ExerciseHistory | null>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const [searchQueryDebounced, setSearchQueryDebounced] = useState('');
  const [minimizedExercises, setMinimizedExercises] = useState<Set<number>>(new Set());
  const [showCustomExerciseModal, setShowCustomExerciseModal] = useState(false);
  const [customExerciseName, setCustomExerciseName] = useState('');
  const [customExerciseMuscle, setCustomExerciseMuscle] = useState('Pectoral');
  const [selectedAddExercise, setSelectedAddExercise] = useState<CatalogExerciseItem | null>(null);
  const [customCatalogItems, setCustomCatalogItems] = useState<CatalogExerciseItem[]>([]);
  const [showImageManagerModal, setShowImageManagerModal] = useState(false);
  const [imageManagerSearchQuery, setImageManagerSearchQuery] = useState('');
  const [selectedImageExercise, setSelectedImageExercise] = useState<CatalogExerciseItem | null>(null);
  const [showAppImageLibraryModal, setShowAppImageLibraryModal] = useState(false);
  const [appImageLibrarySearchQuery, setAppImageLibrarySearchQuery] = useState('');
  const [appImageLibraryVisibleCount, setAppImageLibraryVisibleCount] = useState(APP_LIBRARY_PAGE_SIZE);
  const [lyftaLoaded, setLyftaLoaded] = useState(false);
  const [lyftaLoading, setLyftaLoading] = useState(false);
  const [showImagePreviewModal, setShowImagePreviewModal] = useState(false);
  const [previewImageSource, setPreviewImageSource] = useState<any>(null);
  const [previewImageFallbackSource, setPreviewImageFallbackSource] = useState<any>(null);
  const [mainListViewportHeight, setMainListViewportHeight] = useState(1);
  const [mainListContentHeight, setMainListContentHeight] = useState(1);
  const [mainListScrollY, setMainListScrollY] = useState(0);
  const [addListViewportHeight, setAddListViewportHeight] = useState(1);
  const [addListContentHeight, setAddListContentHeight] = useState(1);
  const [addListScrollY, setAddListScrollY] = useState(0);
  const imageMatchCache = useRef<Map<string, any | null>>(new Map());
  const addExerciseLongPressRef = useRef<string | null>(null);
  const isDark = isDarkMode || false;
  const scrollbarTrackColor = isDark ? 'rgba(255,255,255,0.22)' : 'rgba(79,118,111,0.24)';
  const scrollbarThumbColor = isDark ? '#9FC4BD' : '#4F766F';

  const getScrollbarMetrics = (viewportHeight: number, contentHeight: number, scrollY: number) => {
    if (contentHeight <= viewportHeight || viewportHeight <= 0) {
      return { visible: false, thumbHeight: viewportHeight, thumbTop: 0 };
    }
    const maxScroll = Math.max(1, contentHeight - viewportHeight);
    const thumbHeight = Math.max(26, (viewportHeight / contentHeight) * viewportHeight);
    const thumbTop = (Math.min(scrollY, maxScroll) / maxScroll) * (viewportHeight - thumbHeight);
    return { visible: true, thumbHeight, thumbTop };
  };

  const mainScrollbar = getScrollbarMetrics(mainListViewportHeight, mainListContentHeight, mainListScrollY);
  const addScrollbar = getScrollbarMetrics(addListViewportHeight, addListContentHeight, addListScrollY);

  // Normalizar nombres solo para mostrar (no altera storage ni claves históricas)
  const getDisplayExerciseName = (name: string): string => {
    return name
      .replace(/Extensiones de\s+/gi, 'Extensión ')
      .replace(/^Empuje de cadera\b/gi, 'Hip Thrust');
  };

  // Lista de grupos musculares predefinidos
  const muscleGroups = [
    'Pectoral',
    'Espalda', 
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Cuádriceps',
    'Femoral',
    'Abductores',
    'Aductores',
    'Gemelos',
    'Trapecio',
    'Abdomen',
    'Glúteos',
    'Aeróbico',
    'Antebrazos',
    'Cuello',
    'General',
    'Piernas'
  ].sort((a, b) => a.localeCompare(b, 'es', { sensitivity: 'base' }));

  const compareCatalogExercises = (a: CatalogExerciseItem, b: CatalogExerciseItem): number => {
    const muscleA = a.sortMuscle || '';
    const muscleB = b.sortMuscle || '';
    if (muscleA < muscleB) return -1;
    if (muscleA > muscleB) return 1;
    const nameA = a.sortName || '';
    const nameB = b.sortName || '';
    if (nameA < nameB) return -1;
    if (nameA > nameB) return 1;
    return 0;
  };

  const ensureLyftaLoaded = () => {
    if (lyftaLoaded || lyftaLoading) return;
    setLyftaLoading(true);
    setTimeout(() => {
      getLyftaData();
      setLyftaLoaded(true);
      setLyftaLoading(false);
    }, 0);
  };

  useImperativeHandle(ref, () => ({
    openAddExerciseModal: () => {
      setShowAddExerciseModal(true);
    },
    openImageManagerModal: () => {
      setImageManagerSearchQuery('');
      setSelectedImageExercise(null);
      setShowImageManagerModal(true);
      void refreshExerciseCatalog();
    },
  }));

  // Cargar registros anteriores cuando cambian los ejercicios
  useEffect(() => {
    const loadPreviousRecords = async () => {
      const records: Record<string, ExerciseHistory | null> = {};
      
      for (const exercise of exercises) {
        const lastRecord = await getLastExerciseRecord(exercise.ejercicio);
        records[exercise.ejercicio] = lastRecord;
      }
      
      setPreviousRecords(records);
    };

    if (exercises.length > 0) {
      loadPreviousRecords();
    }
  }, [exercises]);

  const normalizeExerciseKey = (name: string): string =>
    normalizeExerciseName(name).replace(/\s+/g, '');
  const getCatalogExerciseKey = (exercise: CatalogExerciseItem): string =>
    exercise.key || normalizeExerciseKey(exercise.aliasFor || exercise.ejercicio);

  const normalizeText = (text: string): string => {
    return normalizeSearchText(text);
  };

  const ensureCatalogFields = (item: CatalogExerciseItem): CatalogExerciseItem => {
    if (item.sortName && item.sortMuscle && item.searchText) return item;
    const sortName = item.sortName || normalizeSearchText(item.ejercicio);
    const sortMuscle = item.sortMuscle || normalizeSearchText(item.musculo || 'Sin grupo');
    const aliasText = item.aliasFor ? normalizeSearchText(item.aliasFor) : '';
    const searchText = item.searchText || `${sortName} ${sortMuscle} ${aliasText}`.trim();
    return { ...item, sortName, sortMuscle, searchText };
  };

  const getCatalogItemKey = (item: CatalogExerciseItem): string =>
    item.key || normalizeExerciseKey(item.aliasFor || item.ejercicio);

  const mergeExerciseCatalog = (customItems: CatalogExerciseItem[], includeLyfta: boolean) => {
    const merged = new Map<string, CatalogExerciseItem>();
    if (includeLyfta) {
      const lyftaExercises = getLyftaData().exercises;
      lyftaExercises.forEach((ex) => {
        if (isExcludedExerciseName(ex.ejercicio)) return;
        const key = getCatalogItemKey(ex);
        if (!merged.has(key)) merged.set(key, ex);
      });
    }
    predefinedExercises.forEach((ex) => {
      if (isExcludedExerciseName(ex.ejercicio)) return;
      const key = getCatalogItemKey(ex);
      const previous = merged.get(key);
      const mergedItem = previous ? { ...previous, ...ex } : ex;
      merged.set(key, ensureCatalogFields(mergedItem));
    });
    customItems.forEach((ex) => {
      if (isExcludedExerciseName(ex.ejercicio)) return;
      const key = getCatalogItemKey(ex);
      const previous = merged.get(key);
      const mergedItem = previous ? { ...previous, ...ex } : ex;
      merged.set(key, ensureCatalogFields(mergedItem));
    });
    return Array.from(merged.values()).map((item) => ensureCatalogFields(item));
  };

  const refreshExerciseCatalog = async () => {
    const catalog = await getExerciseCatalog();
    setCustomCatalogItems(
      catalog.items.map((item) => ({
        ejercicio: item.ejercicio,
        musculo: item.musculo,
        imageUri: item.imageUri,
        aliasFor: item.aliasFor,
        exerciseId: item.exerciseId,
      }))
    );
  };

  useEffect(() => {
    refreshExerciseCatalog();
  }, []);


  useEffect(() => {
    const timeout = setTimeout(() => {
      setSearchQueryDebounced(searchQuery);
    }, 120);
    return () => clearTimeout(timeout);
  }, [searchQuery]);

  useEffect(() => {
    if (!showAddExerciseModal) {
      setSelectedAddExercise(null);
      return;
    }
    ensureLyftaLoaded();
  }, [showAddExerciseModal]);

  useEffect(() => {
    if (!showAddExerciseModal) {
      addExerciseLongPressRef.current = null;
      if (showEditCatalogExerciseModal) {
        closeEditCatalogExerciseMenu();
      }
    }
  }, [showAddExerciseModal]);

  useEffect(() => {
    if (lyftaLoaded) {
      imageMatchCache.current.clear();
      cachedAppImageLibraryItems = null;
    }
  }, [lyftaLoaded]);

  const manualImageIdByExercise = useMemo(() => {
    const map = new Map<string, string>();
    manualMappingRows.forEach((row) => {
      const exerciseName = String(row?.exercise_name || '').trim();
      const imageId = extractImageId(String(row?.image_id_selected || ''));
      if (!exerciseName || !imageId) return;
      map.set(normalizeExerciseKey(exerciseName), imageId);
    });
    return map;
  }, []);

  const getManualMappedImageId = (
    primaryKey?: string | null,
    secondaryKey?: string | null
  ): string | null => {
    if (primaryKey) {
      const direct = manualImageIdByExercise.get(primaryKey);
      if (direct) return direct;
    }
    if (secondaryKey) {
      const secondary = manualImageIdByExercise.get(secondaryKey);
      if (secondary) return secondary;
    }
    return null;
  };

  const resolveLocalImageIdByName = (primaryName?: string | null, secondaryName?: string | null): string | null => {
    const index = getLocalImageNameIndex();
    if (!index || Object.keys(index).length === 0) return null;
    const nameVariants = (name?: string | null): string[] => {
      if (!name) return [];
      const normalized = normalizeExerciseName(name);
      if (!normalized) return [];
      const variants = new Set<string>([normalized]);
      if (normalized.includes('crunches')) {
        variants.add(normalized.replace(/\bcrunches\b/g, 'crujidos'));
      }
      if (normalized.includes('crunch')) {
        variants.add(normalized.replace(/\bcrunch\b/g, 'crujido'));
      }
      return Array.from(variants);
    };

    for (const candidate of nameVariants(primaryName)) {
      if (index[candidate]) return index[candidate];
    }
    for (const candidate of nameVariants(secondaryName)) {
      if (index[candidate]) return index[candidate];
    }
    return null;
  };

  const customCatalogMap = useMemo(() => {
    const map = new Map<string, CatalogExerciseItem>();
    customCatalogItems.forEach((item) => {
      map.set(normalizeExerciseKey(item.ejercicio), item);
      if (item.aliasFor) {
        map.set(normalizeExerciseKey(item.aliasFor), item);
      }
    });
    return map;
  }, [customCatalogItems]);

  const appImageLibrary = useMemo<AppLibraryImageItem[]>(() => {
    if (!showAppImageLibraryModal) return [];
    return getAppImageLibraryItems();
  }, [showAppImageLibraryModal]);

  const filteredAppImageLibrary = useMemo(() => {
    const normalizedQuery = normalizeText(appImageLibrarySearchQuery).trim();
    const filtered = !normalizedQuery
      ? appImageLibrary
      : appImageLibrary.filter((item) => item.normalizedSearchText.includes(normalizedQuery));
    return filtered.slice(0, appImageLibraryVisibleCount);
  }, [appImageLibrary, appImageLibrarySearchQuery, appImageLibraryVisibleCount]);

  useEffect(() => {
    if (!showAppImageLibraryModal) {
      setAppImageLibraryVisibleCount(APP_LIBRARY_PAGE_SIZE);
      return;
    }
    setAppImageLibraryVisibleCount(APP_LIBRARY_PAGE_SIZE);
  }, [showAppImageLibraryModal, appImageLibrarySearchQuery]);

  const resolveLyftaImageByName = (exerciseName: string): any | null => {
    const cacheKey = normalizeExerciseKey(exerciseName);
    if (imageMatchCache.current.has(cacheKey)) {
      return imageMatchCache.current.get(cacheKey) ?? null;
    }

    const normalizedName = normalizeExerciseName(exerciseName);
    if (!normalizedName) {
      imageMatchCache.current.set(cacheKey, null);
      return null;
    }

    if (!lyftaLoaded) return null;

    const imageId = getLyftaData().exactImageIdByNormalized[normalizedName];
    if (!imageId) {
      imageMatchCache.current.set(cacheKey, null);
      return null;
    }
    const imageSource = getLocalImageMap()[imageId] || null;
    imageMatchCache.current.set(cacheKey, imageSource);
    return imageSource;
  };

  const getExerciseImageLookup = (exercise: CatalogExerciseItem | Exercise) => {
    const exerciseName = exercise.ejercicio;
    const exerciseKey = normalizeExerciseKey(exerciseName);
    const exerciseAlias = (exercise as CatalogExerciseItem).aliasFor;
    let catalogItem = customCatalogMap.get(exerciseKey);
    if (!catalogItem && exerciseAlias) {
      catalogItem = customCatalogMap.get(normalizeExerciseKey(exerciseAlias));
    }
    const aliasFor = catalogItem?.aliasFor || exerciseAlias;
    const primaryName = aliasFor && aliasFor !== exerciseName ? aliasFor : exerciseName;
    const secondaryName = aliasFor && aliasFor !== exerciseName ? exerciseName : null;
    return {
      catalogItem,
      primaryName,
      secondaryName,
      primaryKey: normalizeExerciseKey(primaryName),
      secondaryKey: secondaryName ? normalizeExerciseKey(secondaryName) : null,
    };
  };

  const getExerciseImageSource = (exercise: CatalogExerciseItem | Exercise): any | null => {
    const { catalogItem, primaryName, secondaryName, primaryKey, secondaryKey } = getExerciseImageLookup(exercise);
    const customUri = catalogItem?.imageUri || (exercise as CatalogExerciseItem).imageUri;
    if (customUri) {
      if (customUri.startsWith(APP_IMAGE_URI_PREFIX)) {
        const imageId = customUri.slice(APP_IMAGE_URI_PREFIX.length);
        return getLocalImageMap()[imageId] || null;
      }
      return { uri: customUri };
    }

    const directImageId = (exercise as CatalogExerciseItem).imageId;
    if (directImageId) {
      const localSource = getLocalImageMap()[directImageId];
      if (localSource) return localSource;
    }

    const manualMappedImageId = getManualMappedImageId(primaryKey, secondaryKey);
    if (manualMappedImageId) {
      const localSource = getLocalImageMap()[manualMappedImageId];
      if (localSource) return localSource;
    }

    const localNameImageId = resolveLocalImageIdByName(primaryName, secondaryName);
    if (localNameImageId) {
      const localSource = getLocalImageMap()[localNameImageId];
      if (localSource) return localSource;
    }

    const primaryMatch = resolveLyftaImageByName(primaryName);
    if (primaryMatch) return primaryMatch;
    if (secondaryName) return resolveLyftaImageByName(secondaryName);
    return null;
  };

  const getExerciseThumbnailSource = (exercise: CatalogExerciseItem | Exercise): any | null => {
    const { catalogItem } = getExerciseImageLookup(exercise);
    const customUri = catalogItem?.imageUri || (exercise as CatalogExerciseItem).imageUri;
    if (customUri) {
      if (customUri.startsWith(APP_IMAGE_URI_PREFIX)) {
        const imageId = customUri.slice(APP_IMAGE_URI_PREFIX.length);
        return getLocalImageThumbMap()[imageId] || getLocalImageMap()[imageId] || null;
      }
      return { uri: customUri };
    }

    const imageId = resolveExerciseImageId(exercise);
    if (imageId) {
      const localSource = getLocalImageThumbMap()[imageId] || getLocalImageMap()[imageId] || null;
      if (localSource) return localSource;
    }

    const { primaryKey, secondaryKey } = getExerciseImageLookup(exercise);
    const manualMappedImageId = getManualMappedImageId(primaryKey, secondaryKey);
    if (manualMappedImageId) {
      return getLocalImageThumbMap()[manualMappedImageId] || getLocalImageMap()[manualMappedImageId] || null;
    }

    const { primaryName, secondaryName } = getExerciseImageLookup(exercise);
    const localNameImageId = resolveLocalImageIdByName(primaryName, secondaryName);
    if (localNameImageId) {
      return getLocalImageThumbMap()[localNameImageId] || getLocalImageMap()[localNameImageId] || null;
    }

    return null;
  };

  const getAddModalThumbnailSource = (exercise: CatalogExerciseItem): any | null => {
    return getExerciseThumbnailSource(exercise);
  };

  const resolveExerciseImageId = (exercise: CatalogExerciseItem | Exercise): string | null => {
    const { catalogItem, primaryName, secondaryName, primaryKey, secondaryKey } = getExerciseImageLookup(exercise);
    const customUri = catalogItem?.imageUri || (exercise as CatalogExerciseItem).imageUri;
    if (customUri?.startsWith(APP_IMAGE_URI_PREFIX)) {
      return customUri.slice(APP_IMAGE_URI_PREFIX.length);
    }

    const directImageId = (exercise as CatalogExerciseItem).imageId;
    if (directImageId) return directImageId;

    const normalizedPrimary = normalizeExerciseName(primaryName);
    if (normalizedPrimary) {
      const exactPrimary = getLyftaData().exactImageIdByNormalized[normalizedPrimary];
      if (exactPrimary) return exactPrimary;
    }
    if (secondaryName) {
      const normalizedSecondary = normalizeExerciseName(secondaryName);
      if (normalizedSecondary) {
        return getLyftaData().exactImageIdByNormalized[normalizedSecondary] || null;
      }
    }
    return null;
  };

  const getExercisePreviewImageSource = (exercise: CatalogExerciseItem | Exercise): any | null => {
    const { catalogItem } = getExerciseImageLookup(exercise);
    const customUri = catalogItem?.imageUri || (exercise as CatalogExerciseItem).imageUri;
    if (customUri && !customUri.startsWith(APP_IMAGE_URI_PREFIX)) {
      return { uri: customUri };
    }
    return getExerciseImageSource(exercise);
  };

  const openImagePreview = (source: any | null, fallbackSource?: any | null) => {
    const resolvedSource = source || fallbackSource || null;
    if (!resolvedSource) return;
    setPreviewImageSource(resolvedSource);
    setPreviewImageFallbackSource(fallbackSource || null);
    setShowImagePreviewModal(true);
  };

  const closeImagePreview = () => {
    setShowImagePreviewModal(false);
    setPreviewImageSource(null);
    setPreviewImageFallbackSource(null);
  };

  const addCatalogExercises = useMemo(() => {
    return mergeExerciseCatalog(customCatalogItems, lyftaLoaded);
  }, [customCatalogItems, lyftaLoaded]);
  const imageManagerCatalogExercises = useMemo(() => {
    if (!showImageManagerModal) return [];
    return mergeExerciseCatalog(customCatalogItems, false);
  }, [customCatalogItems, showImageManagerModal]);
  const sortedAddCatalogExercises = useMemo(() => {
    if (addCatalogExercises.length === 0) return [];
    return [...addCatalogExercises].sort(compareCatalogExercises);
  }, [addCatalogExercises]);

  useEffect(() => {
    if (!showAddExerciseModal || !selectedAddExercise) return;
    const key = getCatalogExerciseKey(selectedAddExercise);
    const refreshed = addCatalogExercises.find((exercise) => getCatalogExerciseKey(exercise) === key);
    if (refreshed) {
      setSelectedAddExercise(refreshed);
    }
  }, [addCatalogExercises, selectedAddExercise, showAddExerciseModal]);

  const catalogExercisesSearchIndex = useMemo(() => {
    if (sortedAddCatalogExercises.length === 0) return [];
    return sortedAddCatalogExercises.map((exercise) => ({
      exercise,
      searchText: exercise.searchText || `${normalizeText(exercise.ejercicio)} ${normalizeText(exercise.musculo)} ${normalizeText(exercise.aliasFor || '')}`,
    }));
  }, [sortedAddCatalogExercises]);

  const imageManagerExercises = useMemo(() => {
    if (!showImageManagerModal) return [];
    const normalizedQuery = normalizeText(imageManagerSearchQuery).trim();
    const source = normalizedQuery
      ? imageManagerCatalogExercises.filter((exercise) => (
          normalizeText(exercise.ejercicio).includes(normalizedQuery) ||
          normalizeText(exercise.musculo).includes(normalizedQuery)
        ))
      : imageManagerCatalogExercises.slice(0, 220);

      const list = source
        .map((exercise) => {
          const { catalogItem, primaryKey, secondaryKey } = getExerciseImageLookup(exercise);
          const customUri = catalogItem?.imageUri || exercise.imageUri;
          const hasManualImage =
            manualImageIdByExercise.has(primaryKey) ||
            (secondaryKey ? manualImageIdByExercise.has(secondaryKey) : false);
          const hasImage = !!customUri || hasManualImage;
          const imageSource = getExerciseThumbnailSource(exercise);
          return { ...exercise, imageSource, hasImage: !!imageSource || hasImage };
        })
      .sort((a, b) => {
        if (a.hasImage !== b.hasImage) return a.hasImage ? -1 : 1;
        return a.ejercicio.localeCompare(b.ejercicio, 'es');
      });
    return list;
  }, [imageManagerCatalogExercises, imageManagerSearchQuery, customCatalogMap, manualImageIdByExercise, showImageManagerModal]);

  const chooseImageFromGallery = async (exercise: CatalogExerciseItem) => {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      Alert.alert('Permiso requerido', 'Necesitás habilitar permisos de galería para asignar imágenes.');
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: false,
      quality: 0.8,
    });
    if (result.canceled || !result.assets?.[0]?.uri) return;

    const sourceUri = result.assets[0].uri;
    const fileNameSafe = normalizeExerciseKey(exercise.ejercicio).replace(/\s+/g, '_');
    const folder = `${FileSystem.documentDirectory}exercise-images`;
    const destination = `${folder}/${Date.now()}_${fileNameSafe}.jpg`;

    await FileSystem.makeDirectoryAsync(folder, { intermediates: true });
    await FileSystem.copyAsync({ from: sourceUri, to: destination });
    await upsertExerciseInCatalog({ ejercicio: exercise.ejercicio, musculo: exercise.musculo, imageUri: destination });
    await refreshExerciseCatalog();

    setSelectedImageExercise({ ...exercise, imageUri: destination });
    Alert.alert('Imagen guardada', 'La imagen quedó asociada al ejercicio.');
    openImagePreview({ uri: destination });
  };

  const chooseImageFromAppLibrary = async (exercise: CatalogExerciseItem, imageId: string) => {
    const imageUri = `${APP_IMAGE_URI_PREFIX}${imageId}`;
    await upsertExerciseInCatalog({ ejercicio: exercise.ejercicio, musculo: exercise.musculo, imageUri });
    await refreshExerciseCatalog();
    setSelectedImageExercise({ ...exercise, imageUri });
    setShowAppImageLibraryModal(false);
    const webpSource = getLocalImageMap()[imageId] || null;
    const thumbSource = getLocalImageThumbMap()[imageId] || null;
    Alert.alert('Imagen guardada', 'La imagen quedó asociada al ejercicio.');
    openImagePreview(webpSource, thumbSource || webpSource);
  };

  const loadMoreAppImageLibrary = () => {
    if (!showAppImageLibraryModal) return;
    setAppImageLibraryVisibleCount((prev) => Math.min(prev + APP_LIBRARY_PAGE_SIZE, appImageLibrary.length));
  };

  const removeExerciseImage = (exercise: CatalogExerciseItem) => {
    Alert.alert(
      'Quitar imagen',
      `¿Querés quitar la imagen de "${getDisplayExerciseName(exercise.ejercicio)}"?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Quitar',
          style: 'destructive',
          onPress: async () => {
            await upsertExerciseInCatalog({ ejercicio: exercise.ejercicio, musculo: exercise.musculo });
            await updateExerciseImage(exercise.ejercicio, null);
            await refreshExerciseCatalog();
            setSelectedImageExercise({ ...exercise, imageUri: undefined });
          },
        },
      ],
      { cancelable: true }
    );
  };

  const handleChange = (ei: number, si: number, field: keyof Series, value: string) => {
    let processedValue = value;
    
    // Para ejercicios con peso asistido (lastre), convertir valores positivos a negativos automáticamente
    if (field === 'kg' && value && !isNaN(Number(value))) {
      const exercise = exercises[ei];
      if (allowsNegativeWeight(exercise.ejercicio)) {
        const numValue = Number(value);
        // Si el usuario ingresa un valor positivo, convertirlo a negativo
        if (numValue > 0) {
          processedValue = (-numValue).toString();
        }
      }
    }
    
    const updated = exercises.map((ex, i) =>
      i === ei
        ? {
            ...ex,
            series: ex.series.map((s, j) =>
              j === si ? { ...s, [field]: processedValue } : s
            ),
          }
        : ex
    );
    setExercises(updated);
  };

  // Función para verificar si un ejercicio permite peso negativo
  const allowsNegativeWeight = (exerciseName: string): boolean => {
    const lowerName = exerciseName.toLowerCase();
    return lowerName.includes('lastre') || lowerName.includes('asistido') || lowerName.includes('asistida');
  };

  // Función para verificar si un ejercicio es aeróbico
  const isAerobicExercise = (muscleGroup: string): boolean => {
    return muscleGroup === 'Aeróbico';
  };

  const formatTimeInput = (input: string): string => {
    // Remover todo excepto números
    const numbers = input.replace(/\D/g, '');
    
    if (numbers.length <= 2) {
      return numbers;
    } else if (numbers.length <= 4) {
      return `${numbers.slice(0, 2)}:${numbers.slice(2)}`;
    } else if (numbers.length <= 6) {
      return `${numbers.slice(0, 2)}:${numbers.slice(2, 4)}:${numbers.slice(4)}`;
    } else {
      return `${numbers.slice(0, 2)}:${numbers.slice(2, 4)}:${numbers.slice(4, 6)}`;
    }
  };

  const parseTimeToSeconds = (timeString: string): number => {
    const numbers = timeString.replace(/\D/g, '');
    
    if (numbers.length >= 4) {
      const hours = parseInt(numbers.slice(0, 2)) || 0;
      const minutes = parseInt(numbers.slice(2, 4)) || 0;
      const seconds = parseInt(numbers.slice(4, 6)) || 0;
      return (hours * 3600) + (minutes * 60) + seconds;
    } else if (numbers.length >= 2) {
      const minutes = parseInt(numbers.slice(0, 2)) || 0;
      const seconds = parseInt(numbers.slice(2, 4)) || 0;
      return (minutes * 60) + seconds;
    }
    return 0;
  };

  const moveExercise = (fromIndex: number, toIndex: number) => {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= exercises.length || toIndex >= exercises.length) {
      return;
    }

    setExercises((prev) => {
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= prev.length || toIndex >= prev.length || fromIndex === toIndex) return prev;
      const next = [...prev];
      const [moved] = next.splice(fromIndex, 1);
      next.splice(toIndex, 0, moved);
      return next;
    });

    setMinimizedExercises((prev) => {
      if (prev.size === 0) return prev;
      const next = new Set<number>();
      prev.forEach((idx) => {
        if (idx === fromIndex) {
          next.add(toIndex);
          return;
        }
        if (fromIndex < toIndex && idx > fromIndex && idx <= toIndex) {
          next.add(idx - 1);
          return;
        }
        if (fromIndex > toIndex && idx >= toIndex && idx < fromIndex) {
          next.add(idx + 1);
          return;
        }
        next.add(idx);
      });
      return next;
    });
  };

  const removeExercise = (index: number) => {
    const newExercises = exercises.filter((_, i) => i !== index);
    setExercises(newExercises);
  };

  const addSeries = (exerciseIndex: number) => {
    const newExercises = [...exercises];
    const isAerobic = isAerobicExercise(exercises[exerciseIndex].musculo);
    newExercises[exerciseIndex].series.push(
      isAerobic ? { reps: '', kg: '', rir: undefined, tiempo: '', done: false } : { reps: '', kg: '', rir: undefined, done: false }
    );
    setExercises(newExercises);
  };

  const removeSeries = (exerciseIndex: number, seriesIndex: number) => {
    const newExercises = [...exercises];
    newExercises[exerciseIndex].series.splice(seriesIndex, 1);
    setExercises(newExercises);
  };

  const toggleExerciseMinimize = (exerciseIndex: number) => {
    const newMinimized = new Set(minimizedExercises);
    if (newMinimized.has(exerciseIndex)) {
      newMinimized.delete(exerciseIndex);
    } else {
      newMinimized.add(exerciseIndex);
    }
    setMinimizedExercises(newMinimized);
  };

  const minimizeAllExercises = () => {
    if (exercises.length === 0) return;
    setMinimizedExercises(new Set(exercises.map((_, idx) => idx)));
  };

  const expandAllExercises = () => {
    setMinimizedExercises(new Set());
  };

  const allExercisesMinimized =
    exercises.length > 0 && exercises.every((_, idx) => minimizedExercises.has(idx));

  const handleAddCustomExercise = async () => {
    const name = customExerciseName.trim();
    const muscle = customExerciseMuscle.trim();
    if (!name || !muscle) return;
    const exercise = { ejercicio: name, musculo: muscle };
    await upsertExerciseInCatalog(exercise);
    await refreshExerciseCatalog();
    if (onPickExercise) {
      onPickExercise(exercise);
      setShowCustomExerciseModal(false);
      setShowAddExerciseModal(false);
      setCustomExerciseName('');
      setSearchQuery('');
      return;
    }
    const newExercise: Exercise = {
      ejercicio: name,
      musculo: muscle,
      series: [{ reps: '', kg: '', rir: undefined }]
    };
    setExercises([...exercises, newExercise]);
    setCustomExerciseName('');
    setCustomExerciseMuscle('Pectoral');
    setShowCustomExerciseModal(false);
  };

  const addExercise = (selectedExercise: { ejercicio: string; musculo: string }) => {
    const isAerobic = isAerobicExercise(selectedExercise.musculo);
    const newExercise: Exercise = {
      ejercicio: selectedExercise.ejercicio,
      musculo: selectedExercise.musculo,
      series: isAerobic ? [
        { reps: '', kg: '', rir: undefined, tiempo: '', done: false },
        { reps: '', kg: '', rir: undefined, tiempo: '', done: false },
        { reps: '', kg: '', rir: undefined, tiempo: '', done: false }
      ] : [
        { reps: '', kg: '', rir: undefined, done: false },
        { reps: '', kg: '', rir: undefined, done: false },
        { reps: '', kg: '', rir: undefined, done: false }
      ],
    };
    setExercises([...exercises, newExercise]);
    setShowAddExerciseModal(false);
  };

  const openEditCatalogExerciseMenu = (exercise: CatalogExerciseItem) => {
    setEditCatalogExercise(exercise);
    setEditCatalogName(exercise.ejercicio);
    setEditCatalogMuscle(exercise.musculo || 'Pectoral');
    setEditCatalogOriginalName(exercise.ejercicio);
    setEditCatalogOriginalMuscle(exercise.musculo || 'Pectoral');
    setEditCatalogMode('menu');
    setShowEditCatalogExerciseModal(true);
  };

  const closeEditCatalogExerciseMenu = () => {
    setShowEditCatalogExerciseModal(false);
    setEditCatalogMode('menu');
    setEditCatalogExercise(null);
    setEditCatalogName('');
    setEditCatalogMuscle('Pectoral');
    setEditCatalogOriginalName('');
    setEditCatalogOriginalMuscle('');
  };

  const handleAddExerciseOptionPress = (exercise: CatalogExerciseItem) => {
    const key = getCatalogExerciseKey(exercise);
    if (addExerciseLongPressRef.current === key) {
      addExerciseLongPressRef.current = null;
      return;
    }
    const isAlreadySelected =
      !!selectedAddExercise && getCatalogExerciseKey(selectedAddExercise) === key;
    if (isAlreadySelected) {
      setSelectedAddExercise(null);
      return;
    }
    setSelectedAddExercise(exercise);
  };

  const handleAddExerciseOptionLongPress = (exercise: CatalogExerciseItem) => {
    const key = getCatalogExerciseKey(exercise);
    addExerciseLongPressRef.current = key;
    openEditCatalogExerciseMenu(exercise);
    setTimeout(() => {
      if (addExerciseLongPressRef.current === key) {
        addExerciseLongPressRef.current = null;
      }
    }, 600);
  };

  const confirmAddSelectedExercise = () => {
    if (!selectedAddExercise) return;
    if (onPickExercise) {
      onPickExercise(selectedAddExercise);
    } else {
      addExercise(selectedAddExercise);
    }
    setShowAddExerciseModal(false);
    setSearchQuery('');
    setSelectedAddExercise(null);
  };

  const handleSaveCatalogEdit = async (mode: 'name' | 'muscle') => {
    if (!editCatalogExercise) return;
    const nextName = editCatalogName.trim();
    const nextMuscle = editCatalogMuscle.trim();
    if (!nextName || !nextMuscle) return;
    const nameChanged = nextName !== editCatalogOriginalName;
    const muscleChanged = nextMuscle !== editCatalogOriginalMuscle;
    const message =
      mode === 'name'
        ? 'Nombre actualizado correctamente.'
        : 'Grupo muscular actualizado correctamente.';
    if (!nameChanged && !muscleChanged) {
      setEditCatalogMode('menu');
      Alert.alert('Guardado', message);
      return;
    }
    const updated = await updateExerciseCatalogItem(editCatalogOriginalName, {
      ejercicio: nextName,
      musculo: nextMuscle,
    });
    if (!updated) {
      await upsertExerciseInCatalog({
        ejercicio: nextName,
        musculo: nextMuscle,
        imageUri: editCatalogExercise.imageUri,
        aliasFor: editCatalogExercise.aliasFor || editCatalogOriginalName,
      });
    }
    await refreshExerciseCatalog();
    const nextAliasFor =
      editCatalogExercise.aliasFor ||
      (nameChanged ? editCatalogOriginalName : undefined);
    setEditCatalogExercise({
      ...editCatalogExercise,
      ejercicio: nextName,
      musculo: nextMuscle,
      ...(nextAliasFor ? { aliasFor: nextAliasFor } : {}),
    });
    setEditCatalogOriginalName(nextName);
    setEditCatalogOriginalMuscle(nextMuscle);
    setEditCatalogMode('menu');
    Alert.alert('Guardado', message);
  };

  const handleCancelCatalogEdit = () => {
    setEditCatalogName(editCatalogOriginalName);
    setEditCatalogMuscle(editCatalogOriginalMuscle || 'Pectoral');
    setEditCatalogMode('menu');
  };

  // Filtrar ejercicios basado en la búsqueda (insensible a tildes y mayúsculas)
  const filteredExerciseCandidates = useMemo(() => {
    if (!showAddExerciseModal) return [];
    const normalizedQuery = normalizeText(searchQueryDebounced).trim();
    if (!normalizedQuery) {
      return sortedAddCatalogExercises;
    }

    const results: CatalogExerciseItem[] = [];
    const tokens = normalizedQuery.split(/\s+/).filter(Boolean);
    for (const row of catalogExercisesSearchIndex) {
      if (tokens.every((token) => row.searchText.includes(token))) {
        results.push(row.exercise);
      }
    }
    return results;
  }, [sortedAddCatalogExercises, catalogExercisesSearchIndex, searchQueryDebounced, showAddExerciseModal, lyftaLoaded]);

  const filteredExercises = filteredExerciseCandidates;
  const isExerciseListLoading = !lyftaLoaded && sortedAddCatalogExercises.length === 0;

  const renderAddExerciseRow = ({ item }: { item: CatalogExerciseItem }) => {
    const exercise = item;
    const optionImageSource = getAddModalThumbnailSource(exercise);
    const isSelected =
      !!selectedAddExercise &&
      getCatalogExerciseKey(selectedAddExercise) === getCatalogExerciseKey(exercise);

    return (
      <View
        style={[
          styles.exerciseOption,
          { borderBottomColor: theme.border },
          isSelected ? { backgroundColor: theme.background } : null,
        ]}
      >
        <View style={styles.exerciseOptionRow}>
          {optionImageSource ? (
            <TouchableOpacity
              activeOpacity={0.85}
              onPress={() => openImagePreview(getExercisePreviewImageSource(exercise), optionImageSource)}
            >
              <Image source={optionImageSource} style={styles.exerciseOptionThumb} resizeMode="contain" />
            </TouchableOpacity>
          ) : null}
          <TouchableOpacity
            style={{ flex: 1 }}
            activeOpacity={0.85}
            delayLongPress={250}
            onPress={() => handleAddExerciseOptionPress(exercise)}
            onLongPress={() => handleAddExerciseOptionLongPress(exercise)}
          >
            <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]}>{getDisplayExerciseName(exercise.ejercicio)}</Text>
            <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]}>{exercise.musculo}</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  };

  const renderAddExerciseList = () => (
    <View style={styles.exerciseListWrapper}>
      <View style={[styles.listWithScrollbar, styles.listWithScrollbarFill]}>
        {isExerciseListLoading ? (
          <View
            style={[styles.exerciseList, styles.exerciseListDynamic, styles.addExerciseList]}
            onLayout={(e) => setAddListViewportHeight(e.nativeEvent.layout.height)}
          >
            <View style={styles.loadingRow}>
              <Text style={[styles.loadingText, { color: theme.textSecondary }]}>Cargando ejercicios...</Text>
            </View>
          </View>
        ) : (
          <FlatList
            style={[styles.exerciseList, styles.exerciseListDynamic, styles.addExerciseList]}
            data={filteredExercises}
            keyExtractor={(item, index) => `${getCatalogExerciseKey(item)}-${index}`}
            renderItem={renderAddExerciseRow}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
            scrollEventThrottle={16}
            initialNumToRender={16}
            maxToRenderPerBatch={24}
            windowSize={8}
            removeClippedSubviews
            onLayout={(e) => setAddListViewportHeight(e.nativeEvent.layout.height)}
            onContentSizeChange={(_, h) => setAddListContentHeight(Math.max(1, h))}
            onScroll={(e) => {
              const offsetY = e.nativeEvent.contentOffset.y;
              setAddListScrollY(offsetY);
            }}
          />
        )}
        {!isExerciseListLoading && addScrollbar.visible ? (
          <View pointerEvents="none" style={[styles.scrollbarTrack, { backgroundColor: scrollbarTrackColor }]}>
            <View
              style={[
                styles.scrollbarThumb,
                {
                  backgroundColor: scrollbarThumbColor,
                  height: addScrollbar.thumbHeight,
                  transform: [{ translateY: addScrollbar.thumbTop }],
                },
              ]}
            />
          </View>
        ) : null}
      </View>
    </View>
  );

  // Función para verificar si un ejercicio está completo
  const isExerciseComplete = (exercise: Exercise): boolean => {
    // Un ejercicio se considera completo solo cuando TODAS sus series están marcadas como hechas manualmente
    return exercise.series.length > 0 && exercise.series.every(serie => !!serie.done);
  };

  // Función para contar campos incompletos en toda la sesión
  const getIncompleteFieldsCount = (): number => {
    let count = 0;
    exercises.forEach(exercise => {
      // Ahora el indicador de completitud depende del checkbox de cada serie, no del llenado de campos
      exercise.series.forEach(serie => {
        if (!serie.done) count++;
      });
    });
    return count;
  };

  const renderPreviousRecord = (exerciseName: string) => {
    const previousRecord = previousRecords[exerciseName];
    
    if (!previousRecord) return null;
    const formatPrevValue = (value: string | number | undefined | null): string => {
      const text = value === undefined || value === null ? '' : String(value).trim();
      return text === '' ? '-' : text;
    };

    return (
      <View style={[styles.previousRecordContainer, { borderColor: theme.border }]}>
        <Text style={[styles.previousRecordTitle, { color: theme.textPrimary }]}>Última vez:</Text>
        <View style={[styles.equalRow, styles.previousRecordHeaderRow]}>
          <View style={[styles.equalCell, styles.equalEdgeCell]}>
            <View style={styles.previousRecordSpacer} />
          </View>
          <View style={[styles.equalCell, styles.equalEdgeCell]}>
            <Text style={[styles.previousRecordHeaderText, { color: theme.textSecondary }]}>Serie</Text>
          </View>
          <View style={[styles.equalCell, styles.equalCenterCell]}>
            <Text style={[styles.previousRecordHeaderText, { color: theme.textSecondary }]}>Kg</Text>
          </View>
          <View style={[styles.equalCell, styles.equalCenterCell]}>
            <Text style={[styles.previousRecordHeaderText, { color: theme.textSecondary }]}>Reps</Text>
          </View>
          <View style={[styles.equalCell, styles.equalCenterCell]}>
            <Text style={[styles.previousRecordHeaderText, { color: theme.textSecondary }]}>RIR</Text>
          </View>
          <View style={[styles.equalCell, styles.equalEdgeCell]}>
            <View style={styles.previousRecordSpacer} />
          </View>
        </View>
        {previousRecord.series.map((serie, index) => (
          <View key={index} style={[styles.equalRow, styles.previousRecordRow]}>
            <View style={[styles.equalCell, styles.equalEdgeCell]}>
              <View style={styles.previousRecordSpacer} />
            </View>
            <View style={[styles.equalCell, styles.equalEdgeCell]}>
              <Text style={[styles.previousRecordText, { color: theme.textSecondary }]}>S{index + 1}</Text>
            </View>
            <View style={[styles.equalCell, styles.equalCenterCell]}>
              <Text style={[styles.previousRecordText, { color: theme.textSecondary }]}>
                {formatPrevValue(serie.kg)}
              </Text>
            </View>
            <View style={[styles.equalCell, styles.equalCenterCell]}>
              <Text style={[styles.previousRecordText, { color: theme.textSecondary }]}>
                {formatPrevValue(serie.reps)}
              </Text>
            </View>
            <View style={[styles.equalCell, styles.equalCenterCell]}>
              <Text style={[styles.previousRecordText, { color: theme.textSecondary }]}>
                {formatPrevValue(serie.rir)}
              </Text>
            </View>
            <View style={[styles.equalCell, styles.equalEdgeCell]}>
              <View style={styles.previousRecordSpacer} />
            </View>
          </View>
        ))}
      </View>
    );
  };

  if (expand) {
    return (
      <View style={[styles.minimizedContainer, { backgroundColor: theme.background, borderColor: theme.border, paddingBottom: insets.bottom, paddingLeft: insets.left, paddingRight: insets.right }]}>
        <View style={[
          styles.minimizedHeader,
          {
            paddingHorizontal: ds.header.paddingHorizontal,
            paddingTop: ds.header.paddingTop,
            paddingBottom: ds.header.paddingBottom + 3,
            minHeight: ds.header.height,
          },
        ]}>
                <Text style={[styles.minimizedTitle, { color: theme.textPrimary }]}>Ejercicios</Text>
                <View style={[styles.headerButtons, { marginRight: 0, minWidth:  ds.sizes.headerActionMinWidth, alignItems: 'flex-end' }]}>
            {onOpenChatbot && (
              <TouchableOpacity style={[styles.chatbotButton, { backgroundColor: theme.buttonPrimary }]} onPress={onOpenChatbot}>
                                  <Text style={[styles.chatbotButtonText, { color: theme.buttonText }]}>Editar</Text>
              </TouchableOpacity>
            )}
                  <TouchableOpacity style={[styles.expandButton, { backgroundColor: '#D4A574' }]} onPress={onMinimize}>
              <Text style={[styles.expandButtonText, { color: '#FFFFFF' }]}>Expandir</Text>
            </TouchableOpacity>
          </View>
        </View>
        <View style={[styles.headerSeparator, { backgroundColor: theme.border, marginTop: ds.header.separatorMarginTop }]} />

        {/* Modales disponibles incluso minimizado para permitir openAddExerciseModal() */}
        <Modal
          visible={showAddExerciseModal}
          transparent={true}
          animationType="fade"
          onRequestClose={() => setShowAddExerciseModal(false)}
        >
          <KeyboardAvoidingView
            style={[styles.modalOverlay, styles.addExerciseModalOverlay]}
            behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
            keyboardVerticalOffset={Platform.OS === 'ios' ? insets.top : 0}
          >
            <View style={[styles.modalContent, styles.addExerciseModalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar ejercicio</Text>
              <TouchableOpacity 
                style={[styles.customExerciseButton, { backgroundColor: '#D4A574' }]}
                onPress={() => setShowCustomExerciseModal(true)}
              >
                <Text style={[styles.customExerciseButtonText, { color: '#FFFFFF' }]}>+ Ejercicio personalizado</Text>
              </TouchableOpacity>
              <View style={[styles.searchContainer, styles.searchContainerWithClear]}>
                <TextInput
                  style={[
                    styles.searchInput,
                    searchQuery ? styles.searchInputWithClear : null,
                    { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary },
                  ]}
                  placeholder="Buscar ejercicio o músculo..."
                  value={searchQuery}
                  onChangeText={setSearchQuery}
                  placeholderTextColor={theme.textSecondary}
                />
                {searchQuery ? (
                  <TouchableOpacity
                    style={styles.searchClearButton}
                    onPress={() => setSearchQuery('')}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                  >
                    <Text style={[styles.searchClearButtonText, { color: theme.textSecondary }]}>×</Text>
                  </TouchableOpacity>
                ) : null}
              </View>
              <View style={styles.addExerciseListArea}>
                {renderAddExerciseList()}
              </View>
              <View style={styles.addExerciseModalActions}>
                <TouchableOpacity
                  style={[styles.addExerciseModalButton, { backgroundColor: theme.buttonPrimary }, !selectedAddExercise ? styles.disabledActionButton : null]}
                  onPress={confirmAddSelectedExercise}
                  disabled={!selectedAddExercise}
                >
                  <Text style={[styles.addExerciseModalButtonText, { color: theme.buttonText }]}>Agregar</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  style={[styles.addExerciseModalButton, { backgroundColor: theme.buttonSecondary }]}
                  onPress={() => {
                    setShowAddExerciseModal(false);
                    setSearchQuery('');
                    setSelectedAddExercise(null);
                  }}
                >
                  <Text style={[styles.addExerciseModalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                </TouchableOpacity>
              </View>
            </View>
          </KeyboardAvoidingView>
        </Modal>

        <Modal
          visible={showEditCatalogExerciseModal}
          transparent={true}
          animationType="fade"
          onRequestClose={closeEditCatalogExerciseMenu}
        >
          <KeyboardAvoidingView
            style={styles.modalOverlay}
            behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
            keyboardVerticalOffset={Platform.OS === 'ios' ? insets.top : 0}
          >
            <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Editar ejercicio</Text>
              {editCatalogExercise ? (
                editCatalogMode === 'menu' ? (
                  <>
                  <View style={styles.editCatalogInfoText}>
                    <Text style={[styles.editCatalogInfoTitle, { color: theme.textPrimary }]} numberOfLines={2}>
                      Nombre actual: {getDisplayExerciseName(editCatalogExercise.ejercicio)}
                    </Text>
                    <Text style={[styles.editCatalogInfoSubtext, { color: theme.textSecondary }]} numberOfLines={1}>
                      Grupo actual: {editCatalogExercise.musculo}
                    </Text>
                  </View>
                    <View style={styles.editCatalogActions}>
                      <TouchableOpacity
                        style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                        onPress={() => setEditCatalogMode('name')}
                      >
                        <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cambiar nombre</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                        onPress={() => setEditCatalogMode('muscle')}
                      >
                        <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cambiar grupo</Text>
                      </TouchableOpacity>
                    </View>
                  </>
                ) : editCatalogMode === 'name' ? (
                  <View style={styles.editCatalogSection}>
                    <Text style={[styles.editCatalogLabel, { color: theme.textSecondary }]}>Nuevo nombre</Text>
                    <TextInput
                      style={[styles.customExerciseInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                      placeholder="Nombre del ejercicio"
                      value={editCatalogName}
                      onChangeText={setEditCatalogName}
                      placeholderTextColor={theme.textSecondary}
                    />
                    <View style={styles.editCatalogButtons}>
                      <TouchableOpacity
                        style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                        onPress={() => handleSaveCatalogEdit('name')}
                      >
                        <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Guardar</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                        onPress={handleCancelCatalogEdit}
                      >
                        <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cancelar</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                ) : (
                  <View style={styles.editCatalogSection}>
                    <Text style={[styles.editCatalogLabel, { color: theme.textSecondary }]}>Seleccionar grupo muscular</Text>
                    <View style={[styles.pickerContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}>
                      <ScrollView style={{ maxHeight: 160 }} showsVerticalScrollIndicator persistentScrollbar>
                        {muscleGroups.map((mg) => (
                          <TouchableOpacity key={mg} style={{ paddingVertical: 8 }} onPress={() => setEditCatalogMuscle(mg)}>
                            <Text style={{ color: editCatalogMuscle === mg ? theme.textPrimary : theme.textSecondary, fontWeight: editCatalogMuscle === mg ? '700' : '500' }}>{mg}</Text>
                          </TouchableOpacity>
                        ))}
                      </ScrollView>
                      <Text style={[styles.pickerLabel, { color: theme.textSecondary, marginTop: 6 }]}>Seleccionado: {editCatalogMuscle}</Text>
                    </View>
                    <View style={styles.editCatalogButtons}>
                      <TouchableOpacity
                        style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                        onPress={() => handleSaveCatalogEdit('muscle')}
                      >
                        <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Guardar</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                        onPress={handleCancelCatalogEdit}
                      >
                        <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cancelar</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                )
              ) : null}
              {editCatalogMode === 'menu' ? (
              <TouchableOpacity
                style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={closeEditCatalogExerciseMenu}
              >
                <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cerrar</Text>
              </TouchableOpacity>
              ) : null}
            </View>
          </KeyboardAvoidingView>
        </Modal>

        <Modal
          visible={showCustomExerciseModal}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowCustomExerciseModal(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Agregar ejercicio personalizado</Text>
              <View style={styles.customExerciseForm}>
                <TextInput
                  style={[styles.customExerciseInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                  placeholder="Nombre del ejercicio"
                  value={customExerciseName}
                  onChangeText={setCustomExerciseName}
                  placeholderTextColor={theme.textSecondary}
                />
                <View style={[styles.pickerContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}>
                  <ScrollView style={{ maxHeight: 160 }} showsVerticalScrollIndicator persistentScrollbar>
                    {muscleGroups.map((mg) => (
                      <TouchableOpacity key={mg} style={{ paddingVertical: 8 }} onPress={() => setCustomExerciseMuscle(mg)}>
                        <Text style={{ color: customExerciseMuscle === mg ? theme.textPrimary : theme.textSecondary, fontWeight: customExerciseMuscle === mg ? '700' : '500' }}>{mg}</Text>
                      </TouchableOpacity>
                    ))}
                  </ScrollView>
                  <Text style={[styles.pickerLabel, { color: theme.textSecondary, marginTop: 6 }]}>Seleccionado: {customExerciseMuscle}</Text>
                </View>
              </View>
              <View style={styles.customExerciseButtons}>
                <TouchableOpacity 
                  style={[styles.customExerciseAddButton, { backgroundColor: '#D4A574' }]}
                  onPress={handleAddCustomExercise}
                >
                  <Text style={[styles.customExerciseAddButtonText, { color: '#FFFFFF' }]}>Agregar</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  style={[styles.customExerciseCancelButton, { backgroundColor: theme.buttonSecondary }]}
                  onPress={() => {
                    setShowCustomExerciseModal(false);
                    setCustomExerciseName('');
                    setCustomExerciseMuscle('Pectoral');
                  }}
                >
                  <Text style={[styles.customExerciseCancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </Modal>

        <Modal
          visible={showImageManagerModal}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowImageManagerModal(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Gestor de imágenes</Text>
              <View style={styles.searchContainer}>
                <TextInput
                  style={[styles.searchInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                  placeholder="Buscar ejercicio..."
                  value={imageManagerSearchQuery}
                  onChangeText={setImageManagerSearchQuery}
                  placeholderTextColor={theme.textSecondary}
                />
              </View>

              {selectedImageExercise && (
                <View style={[styles.imageManagerSelectedBox, { borderColor: theme.border, backgroundColor: theme.background }]}>
                  <Text style={[styles.imageManagerSelectedTitle, { color: theme.textPrimary }]} numberOfLines={1}>
                    {getDisplayExerciseName(selectedImageExercise.ejercicio)}
                  </Text>
                  <View style={styles.imageManagerActions}>
                    {(() => {
                      const listThumbSource = (selectedImageExercise as any).imageSource as any;
                      const selectedSource = getExercisePreviewImageSource(selectedImageExercise);
                      const hasImage = !!(listThumbSource || selectedSource);
                      return (
                        <>
                          {hasImage ? (
                            <TouchableOpacity
                              style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                              onPress={() => openImagePreview(selectedSource || listThumbSource, getExerciseImageSource(selectedImageExercise))}
                            >
                              <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Ver</Text>
                            </TouchableOpacity>
                          ) : null}

                          <TouchableOpacity
                            style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]} 
                            onPress={() => {
                              setShowAppImageLibraryModal(true);
                              setAppImageLibrarySearchQuery('');
                            }}
                          >
                            <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Biblioteca</Text>
                          </TouchableOpacity>

                          <TouchableOpacity
                            style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                            onPress={() => void chooseImageFromGallery(selectedImageExercise)}
                          >
                            <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Galería</Text>
                          </TouchableOpacity>

                          {hasImage ? (
                            <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => removeExerciseImage(selectedImageExercise)}>
                              <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Quitar</Text>
                            </TouchableOpacity>
                          ) : null}

                          <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setSelectedImageExercise(null)}>
                            <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cancelar</Text>
                          </TouchableOpacity>
                        </>
                      );
                    })()}
                  </View>
                </View>
              )}

              <ScrollView style={styles.exerciseList} showsVerticalScrollIndicator persistentScrollbar>
                {imageManagerExercises.map((exercise, index) => (
                  <TouchableOpacity
                    key={`${exercise.ejercicio}-${index}`}
                    style={[
                      styles.exerciseOption,
                      { borderBottomColor: theme.border },
                      selectedImageExercise?.ejercicio === exercise.ejercicio && { backgroundColor: theme.background }
                    ]}
                    onPress={() => setSelectedImageExercise(exercise)}
                  >
                    <View style={styles.exerciseOptionRow}>
                      {exercise.imageSource ? (
                        <Image source={exercise.imageSource} style={styles.exerciseOptionThumb} resizeMode="cover" />
                      ) : (
                        <View style={[styles.exerciseOptionThumb, { backgroundColor: theme.background, borderColor: theme.border, borderWidth: 1 }]} />
                      )}
                      <View style={{ flex: 1 }}>
                        <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]}>{getDisplayExerciseName(exercise.ejercicio)}</Text>
                        <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]}>
                          {exercise.musculo} {exercise.hasImage ? '• con imagen' : '• sin imagen'}
                        </Text>
                      </View>
                    </View>
                  </TouchableOpacity>
                ))}
              </ScrollView>

              <TouchableOpacity
                style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => {
                  setShowImageManagerModal(false);
                  setSelectedImageExercise(null);
                  setImageManagerSearchQuery('');
                }}
              >
                <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cerrar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>

        <Modal
          visible={showAppImageLibraryModal}
          transparent={true}
          animationType="slide"
          onRequestClose={() => setShowAppImageLibraryModal(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
              <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Biblioteca de imágenes</Text>
              <View style={styles.searchContainer}>
                <TextInput
                  style={[styles.searchInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                  placeholder="Buscar por nombre o ID..."
                  value={appImageLibrarySearchQuery}
                  onChangeText={setAppImageLibrarySearchQuery}
                  placeholderTextColor={theme.textSecondary}
                />
              </View>
              <FlatList
                style={styles.exerciseList}
                data={filteredAppImageLibrary}
                keyExtractor={(item) => item.id}
                showsVerticalScrollIndicator
                persistentScrollbar
                keyboardShouldPersistTaps="handled"
                initialNumToRender={8}
                maxToRenderPerBatch={8}
                windowSize={3}
                removeClippedSubviews
                onEndReachedThreshold={0.6}
                onEndReached={loadMoreAppImageLibrary}
                renderItem={({ item }) => (
                  <TouchableOpacity
                    style={[styles.exerciseOption, { borderBottomColor: theme.border }]}
                    onPress={() => {
                      if (!selectedImageExercise) return;
                      Alert.alert(
                        'Asignar imagen',
                        `¿Querés asignar "${item.primaryName}" a "${getDisplayExerciseName(selectedImageExercise.ejercicio)}"?`,
                        [
                          { text: 'Cancelar', style: 'cancel' },
                          { text: 'Asignar', onPress: () => void chooseImageFromAppLibrary(selectedImageExercise, item.id) },
                        ],
                        { cancelable: true }
                      );
                    }}
                  >
                    <View style={styles.exerciseOptionRow}>
                      <TouchableOpacity
                        activeOpacity={0.85}
                        onPress={() => {
                          const fullSource = getLocalImageMap()[item.id] || null;
                          openImagePreview(fullSource || item.source, item.source);
                        }}
                      >
                        <Image source={item.source} style={styles.exerciseOptionThumb} resizeMode="cover" />
                      </TouchableOpacity>
                      <View style={{ flex: 1 }}>
                        <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]} numberOfLines={1}>
                          {item.primaryName}
                        </Text>
                        <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]} numberOfLines={1}>
                          ID: {item.id}
                        </Text>
                      </View>
                    </View>
                  </TouchableOpacity>
                )}
                ListEmptyComponent={
                  <View style={styles.loadingRow}>
                    <Text style={[styles.loadingText, { color: theme.textSecondary }]}>Sin resultados</Text>
                  </View>
                }
              />
              <TouchableOpacity
                style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => setShowAppImageLibraryModal(false)}
              >
                <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cerrar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>

        <Modal
          visible={showImagePreviewModal}
          transparent={true}
          animationType="fade"
          onRequestClose={closeImagePreview}
        >
          <View style={styles.modalOverlay}>
            <TouchableOpacity style={styles.imagePreviewBackdrop} activeOpacity={1} onPress={closeImagePreview}>
              {previewImageSource ? (
                <Image
                  source={previewImageSource}
                  style={styles.imagePreview}
                  resizeMode="contain"
                  onError={() => {
                    if (previewImageFallbackSource && previewImageSource !== previewImageFallbackSource) {
                      setPreviewImageSource(previewImageFallbackSource);
                      return;
                    }
                    console.warn('[images] No se pudo abrir la imagen en preview.');
                  }}
                />
              ) : null}
            </TouchableOpacity>
          </View>
        </Modal>
      </View>
    );
  }

  return (
    <View style={[
      styles.container,
      { backgroundColor: theme.background, borderColor: theme.border, paddingBottom: insets.bottom, paddingLeft: insets.left, paddingRight: insets.right, borderTopWidth: 1, borderTopColor: ds.header.borderTopColor }
    ]}>
      <View style={[
        styles.exerciseListHeader,
        {
          paddingHorizontal: ds.header.paddingHorizontal,
          paddingTop: ds.header.paddingTop,
          paddingBottom: ds.header.paddingBottom + 3,
          minHeight: ds.header.height,
        },
      ]}>
        <Text style={[styles.exerciseListTitle, { color: theme.textPrimary }]}>Ejercicios</Text>
        <View style={[styles.headerButtons, { marginRight: 0, minWidth: ds.sizes.headerActionMinWidth, alignItems: 'flex-end' }]}>
          {onOpenChatbot && (
            <TouchableOpacity style={[styles.chatbotButton, { backgroundColor: theme.buttonPrimary }]} onPress={onOpenChatbot}>
                                <Text style={[styles.chatbotButtonText, { color: theme.buttonText }]}>Editar</Text>
            </TouchableOpacity>
          )}
          <TouchableOpacity style={[styles.minimizeButton, { backgroundColor: theme.buttonSecondary }]} onPress={onMinimize}>
            <Text style={[styles.minimizeButtonText, { color: theme.buttonText }]}>Minimizar</Text>
          </TouchableOpacity>
        </View>
      </View>
      <View style={[styles.headerSeparator, { backgroundColor: theme.border, marginTop: ds.header.separatorMarginTop, marginBottom: 12 }]} />
      
      <View style={styles.mainListWithScrollbar}>
        <ScrollView
          showsVerticalScrollIndicator
          persistentScrollbar
          scrollEventThrottle={16}
          onLayout={(e) => {
            const h = e.nativeEvent.layout.height;
            setMainListViewportHeight(h);
          }}
          onContentSizeChange={(_, h) => {
            setMainListContentHeight(Math.max(1, h));
          }}
          onScroll={(e) => {
            setMainListScrollY(e.nativeEvent.contentOffset.y);
          }}
        >
          {exercises.map((ex, ei) => (
            <View
              key={`${ex.ejercicio}-${ei}`}
              style={[
                styles.exerciseBox,
                { backgroundColor: theme.exerciseBox, borderColor: theme.border },
                isExerciseComplete(ex) && { backgroundColor: theme.exerciseBoxComplete, borderColor: theme.border },
              ]}
            >
            <View style={[
              styles.exerciseHeader,
              minimizedExercises.has(ei) ? { marginBottom: 0 } : null
            ]}>
              {(() => {
                const exerciseImageSource = getExerciseThumbnailSource(ex);
                if (!exerciseImageSource) return null;
                return (
                  <TouchableOpacity
                    style={styles.exerciseThumbButton}
                    onPress={() => openImagePreview(getExercisePreviewImageSource(ex), exerciseImageSource)}
                  >
                    <Image source={exerciseImageSource} style={styles.exerciseThumb} resizeMode="cover" />
                  </TouchableOpacity>
                );
              })()}
              <View style={styles.exerciseTitleContainer}>
                <Text style={[styles.exerciseTitle, { color: theme.textPrimary }]}>
                  {getDisplayExerciseName(ex.ejercicio)} ({ex.musculo})
                </Text>
              </View>
              <View style={styles.exerciseControls}>
                <TouchableOpacity 
                  style={[styles.minimizeExerciseBtn, { backgroundColor: '#D4A574' }]} 
                  onPress={() => toggleExerciseMinimize(ei)}
                >
                  <Text style={[styles.minimizeExerciseBtnText, { color: '#FFFFFF' }]}>
                    {minimizedExercises.has(ei) ? '+' : '−'}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.controlBtn, { borderColor: theme.border, backgroundColor: theme.surface }, ei === 0 ? styles.controlBtnDisabled : null]}
                  onPress={() => moveExercise(ei, ei - 1)}
                  disabled={ei === 0}
                >
                  <Text style={[styles.controlBtnText, { color: theme.textPrimary }]}>↑</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.controlBtn, { borderColor: theme.border, backgroundColor: theme.surface }, ei === exercises.length - 1 ? styles.controlBtnDisabled : null]}
                  onPress={() => moveExercise(ei, ei + 1)}
                  disabled={ei === exercises.length - 1}
                >
                  <Text style={[styles.controlBtnText, { color: theme.textPrimary }]}>↓</Text>
                </TouchableOpacity>
                <TouchableOpacity 
                  style={[styles.removeBtn, { backgroundColor: theme.buttonSecondary }]} 
                  onPress={() => removeExercise(ei)}
                >
                  <Text style={[styles.removeBtnText, { color: theme.buttonText }]}>×</Text>
                </TouchableOpacity>
              </View>
            </View>
            
            {/* Mostrar registro anterior */}
            {!minimizedExercises.has(ei) && renderPreviousRecord(ex.ejercicio)}
            
            {!minimizedExercises.has(ei) && (
              <View style={styles.seriesContainer}>
              <View style={styles.seriesHeader}>
                {isAerobicExercise(ex.musculo) ? (
                  <View style={styles.seriesHeaderLeft}>
                    <View style={styles.seriesInfo}>
                      <Text style={[styles.columnHeaderText, { color: theme.textSecondary, fontWeight: 'bold', fontSize: 14 }]}>Serie</Text>
                    </View>
                    <View style={styles.headerFieldsRow}>
                      <View style={styles.headerCellTime}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Tiempo</Text></View>
                    </View>
                    <View style={styles.headerCellCheck}>
                      <Text style={[styles.headerText, { color: theme.textSecondary }]}>✓</Text>
                    </View>
                  </View>
                ) : (
                  <View style={styles.equalRow}>
                    <View style={[styles.equalCell, styles.equalEdgeCell]}><Text style={[styles.headerText, { color: theme.textSecondary }]}>×</Text></View>
                    <View style={[styles.equalCell, styles.equalEdgeCell]}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Serie</Text></View>
                    <View style={[styles.equalCell, styles.equalCenterCell]}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Kg</Text></View>
                    <View style={[styles.equalCell, styles.equalCenterCell]}><Text style={[styles.headerText, { color: theme.textSecondary }]}>Reps</Text></View>
                    <View style={[styles.equalCell, styles.equalCenterCell]}><Text style={[styles.headerText, { color: theme.textSecondary }]}>RIR</Text></View>
                    <View style={[styles.equalCell, styles.equalEdgeCell]}><Text style={[styles.headerText, { color: theme.textSecondary }]}>✓</Text></View>
                  </View>
                )}
              </View>
              
              {ex.series.map((s, si) => (
                isAerobicExercise(ex.musculo) ? (
                  <View key={si} style={styles.seriesRow}>
                    <View style={styles.seriesInfo}>
                      <Text style={[styles.seriesLabel, { color: theme.textSecondary }]}>{`S${si + 1}`}</Text>
                      {ex.series.length > 1 && (
                        <TouchableOpacity 
                          style={[styles.removeSeriesBtn, { backgroundColor: theme.buttonSecondary }]}
                          onPress={() => removeSeries(ei, si)}
                        >
                          <Text style={[styles.removeSeriesBtnText, { color: theme.buttonText }]}>×</Text>
                        </TouchableOpacity>
                      )}
                    </View>
                    <View style={styles.seriesFieldsRow}>
                      <TextInput
                        style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center', width: 180 }]}
                        placeholder="MM:SS"
                        value={s.tiempo || ''}
                        onChangeText={v => handleChange(ei, si, 'tiempo', formatTimeInput(v))}
                        keyboardType="numeric"
                        maxLength={8} // HH:MM:SS
                        placeholderTextColor={theme.textSecondary}
                      />
                    </View>
                    <View style={{ width: 44, alignItems: 'center', justifyContent: 'center' }}>
                      <TouchableOpacity 
                        onPress={() => {
                          const updated = exercises.map((ex, i) =>
                            i === ei
                              ? {
                                  ...ex,
                                  series: ex.series.map((s2, j) => j === si ? { ...s2, done: !s2.done } : s2),
                                }
                              : ex
                          );
                          setExercises(updated);
                        }}
                        style={{
                          width: 28,
                          height: 28,
                          borderRadius: 6,
                          borderWidth: 1,
                          borderColor: theme.border,
                          backgroundColor: s.done ? theme.buttonPrimary : 'transparent',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                      >
                        <Text style={{
                          color: s.done ? theme.buttonText : theme.textSecondary,
                          fontWeight: '800',
                          fontSize: 16,
                          lineHeight: 16,
                        }}>
                          {s.done ? '✓' : ''}
                        </Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                ) : (
                  <View key={si} style={[styles.equalRow, styles.equalSeriesRow]}>
                    <View style={[styles.equalCell, styles.equalEdgeCell]}>
                      {ex.series.length > 1 ? (
                        <TouchableOpacity 
                          style={[styles.removeSeriesBtn, { backgroundColor: theme.buttonSecondary, marginLeft: 0, marginRight: 0 }]}
                          onPress={() => removeSeries(ei, si)}
                        >
                          <Text style={[styles.removeSeriesBtnText, { color: theme.buttonText }]}>×</Text>
                        </TouchableOpacity>
                      ) : (
                        <View style={styles.equalEmpty} />
                      )}
                    </View>
                    <View style={[styles.equalCell, styles.equalEdgeCell]}>
                      <Text style={[styles.seriesLabel, styles.equalSeriesLabel, { color: theme.textSecondary, textAlign: 'center' }]}>{`S${si + 1}`}</Text>
                    </View>
                    <View style={[styles.equalCell, styles.equalCenterCell]}>
                      <TextInput
                        style={[styles.equalInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center' }]}
                        placeholder="Kg"
                        value={s.kg?.toString().trim() || ''}
                        onChangeText={v => handleChange(ei, si, 'kg', v)}
                        keyboardType="numeric"
                        placeholderTextColor={theme.textSecondary}
                      />
                    </View>
                    <View style={[styles.equalCell, styles.equalCenterCell]}>
                      <TextInput
                        style={[styles.equalInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center' }]}
                        placeholder="Reps"
                        value={s.reps?.toString().trim() || ''}
                        onChangeText={v => handleChange(ei, si, 'reps', v)}
                        keyboardType="numeric"
                        placeholderTextColor={theme.textSecondary}
                      />
                    </View>
                    <View style={[styles.equalCell, styles.equalCenterCell]}>
                      <TextInput
                        style={[styles.equalInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary, textAlign: 'center' }]}
                        placeholder="RIR"
                        value={s.rir?.toString() || ''}
                        onChangeText={v => handleChange(ei, si, 'rir', v.replace(/\D/g, ''))}
                        keyboardType="numeric"
                        placeholderTextColor={theme.textSecondary}
                      />
                    </View>
                    <View style={[styles.equalCell, styles.equalEdgeCell]}>
                      <TouchableOpacity
                        onPress={() => {
                          const updated = exercises.map((ex, i) =>
                            i === ei
                              ? {
                                  ...ex,
                                  series: ex.series.map((s2, j) => j === si ? { ...s2, done: !s2.done } : s2),
                                }
                              : ex
                          );
                          setExercises(updated);
                        }}
                        style={{
                          width: 28,
                          height: 28,
                          borderRadius: 6,
                          borderWidth: 1,
                          borderColor: theme.border,
                          backgroundColor: s.done ? theme.buttonPrimary : 'transparent',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                      >
                        <Text style={{
                          color: s.done ? theme.buttonText : theme.textSecondary,
                          fontWeight: '800',
                          fontSize: 16,
                          lineHeight: 16,
                        }}>
                          {s.done ? '✓' : ''}
                        </Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                )
              ))}

              {/* Footer de series: botón para agregar serie */}
              <View style={styles.seriesFooterRow}>
                <TouchableOpacity 
                  style={[styles.addSeriesBtn, { backgroundColor: theme.buttonPrimary }]}
                  onPress={() => addSeries(ei)}
                >
                  <Text style={[styles.addSeriesBtnText, { color: theme.buttonText }]}>+ Agregar serie</Text>
                </TouchableOpacity>
              </View>
            </View>
            )}
            </View>
          ))}
        </ScrollView>
        {mainScrollbar.visible ? (
          <View pointerEvents="none" style={[styles.scrollbarTrack, { backgroundColor: scrollbarTrackColor }]}>
            <View
              style={[
                styles.scrollbarThumb,
                {
                  backgroundColor: scrollbarThumbColor,
                  height: mainScrollbar.thumbHeight,
                  transform: [{ translateY: mainScrollbar.thumbTop }],
                },
              ]}
            />
          </View>
        ) : null}
      </View>

      {/* Botón agregar ejercicio y contador */}
      {onAddExercise && (
        <View style={styles.addExerciseContainer}>
          <View style={styles.addExerciseActions}>
            <TouchableOpacity style={[styles.addExerciseButton, { backgroundColor: theme.buttonPrimary }]} onPress={onAddExercise}>
              <Text style={[styles.addExerciseButtonText, { color: theme.buttonText }]}>+ Agregar ejercicio</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.addExerciseButton,
                { backgroundColor: allExercisesMinimized ? '#D4A574' : theme.buttonSecondary },
                exercises.length === 0 ? styles.disabledActionButton : null
              ]}
              onPress={allExercisesMinimized ? expandAllExercises : minimizeAllExercises}
              disabled={exercises.length === 0}
            >
              <Text style={[styles.addExerciseButtonText, { color: theme.buttonText }]}>
                {allExercisesMinimized ? 'Expandir todos' : 'Minimizar todos'}
              </Text>
            </TouchableOpacity>
          </View>
          <Text style={[styles.exerciseCount, { color: theme.textSecondary }]}>{exercises.length} ejercicios</Text>
        </View>
      )}

      {/* Modal para agregar ejercicio */}
      <Modal
        visible={showAddExerciseModal}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setShowAddExerciseModal(false)}
      >
        <KeyboardAvoidingView
          style={[styles.modalOverlay, styles.addExerciseModalOverlay]}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={Platform.OS === 'ios' ? insets.top : 0}
        >
          <View style={[styles.modalContent, styles.addExerciseModalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar ejercicio</Text>
            
            {/* Botón para agregar ejercicio personalizado */}
            <TouchableOpacity 
              style={[styles.customExerciseButton, { backgroundColor: '#D4A574' }]}
              onPress={() => setShowCustomExerciseModal(true)}
            >
              <Text style={[styles.customExerciseButtonText, { color: '#FFFFFF' }]}>+ Ejercicio personalizado</Text>
            </TouchableOpacity>
            
            {/* Buscador */}
            <View style={[styles.searchContainer, styles.searchContainerWithClear]}>
              <TextInput
                style={[
                  styles.searchInput,
                  searchQuery ? styles.searchInputWithClear : null,
                  { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary },
                ]}
                placeholder="Buscar ejercicio o músculo..."
                value={searchQuery}
                onChangeText={setSearchQuery}
                placeholderTextColor={theme.textSecondary}
              />
              {searchQuery ? (
                <TouchableOpacity
                  style={styles.searchClearButton}
                  onPress={() => setSearchQuery('')}
                  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                >
                  <Text style={[styles.searchClearButtonText, { color: theme.textSecondary }]}>×</Text>
                </TouchableOpacity>
              ) : null}
            </View>
            
            <View style={styles.addExerciseListArea}>
              {renderAddExerciseList()}
            </View>
            <View style={styles.addExerciseModalActions}>
              <TouchableOpacity
                style={[styles.addExerciseModalButton, { backgroundColor: theme.buttonPrimary }, !selectedAddExercise ? styles.disabledActionButton : null]}
                onPress={confirmAddSelectedExercise}
                disabled={!selectedAddExercise}
              >
                <Text style={[styles.addExerciseModalButtonText, { color: theme.buttonText }]}>Agregar</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.addExerciseModalButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => {
                  setShowAddExerciseModal(false);
                  setSearchQuery('');
                  setSelectedAddExercise(null);
                }}
              >
                <Text style={[styles.addExerciseModalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      <Modal
        visible={showEditCatalogExerciseModal}
        transparent={true}
        animationType="fade"
        onRequestClose={closeEditCatalogExerciseMenu}
      >
        <KeyboardAvoidingView
          style={styles.modalOverlay}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          keyboardVerticalOffset={Platform.OS === 'ios' ? insets.top : 0}
        >
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Editar ejercicio</Text>
            {editCatalogExercise ? (
              editCatalogMode === 'menu' ? (
                <>
                  <View style={styles.editCatalogInfoText}>
                    <Text style={[styles.editCatalogInfoTitle, { color: theme.textPrimary }]} numberOfLines={2}>
                      Nombre actual: {getDisplayExerciseName(editCatalogExercise.ejercicio)}
                    </Text>
                    <Text style={[styles.editCatalogInfoSubtext, { color: theme.textSecondary }]} numberOfLines={1}>
                      Grupo actual: {editCatalogExercise.musculo}
                    </Text>
                  </View>
                  <View style={styles.editCatalogActions}>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={() => setEditCatalogMode('name')}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cambiar nombre</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={() => setEditCatalogMode('muscle')}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cambiar grupo</Text>
                    </TouchableOpacity>
                  </View>
                </>
              ) : editCatalogMode === 'name' ? (
                <View style={styles.editCatalogSection}>
                  <Text style={[styles.editCatalogLabel, { color: theme.textSecondary }]}>Nuevo nombre</Text>
                  <TextInput
                    style={[styles.customExerciseInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                    placeholder="Nombre del ejercicio"
                    value={editCatalogName}
                    onChangeText={setEditCatalogName}
                    placeholderTextColor={theme.textSecondary}
                  />
                  <View style={styles.editCatalogButtons}>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={() => handleSaveCatalogEdit('name')}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Guardar</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={handleCancelCatalogEdit}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cancelar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              ) : (
                <View style={styles.editCatalogSection}>
                  <Text style={[styles.editCatalogLabel, { color: theme.textSecondary }]}>Seleccionar grupo muscular</Text>
                  <View style={[styles.pickerContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}>
                    <ScrollView style={{ maxHeight: 160 }} showsVerticalScrollIndicator persistentScrollbar>
                      {muscleGroups.map((mg) => (
                        <TouchableOpacity key={mg} style={{ paddingVertical: 8 }} onPress={() => setEditCatalogMuscle(mg)}>
                          <Text style={{ color: editCatalogMuscle === mg ? theme.textPrimary : theme.textSecondary, fontWeight: editCatalogMuscle === mg ? '700' : '500' }}>{mg}</Text>
                        </TouchableOpacity>
                      ))}
                    </ScrollView>
                    <Text style={[styles.pickerLabel, { color: theme.textSecondary, marginTop: 6 }]}>Seleccionado: {editCatalogMuscle}</Text>
                  </View>
                  <View style={styles.editCatalogButtons}>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]}
                      onPress={() => handleSaveCatalogEdit('muscle')}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Guardar</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                      onPress={handleCancelCatalogEdit}
                    >
                      <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cancelar</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              )
            ) : null}
            {editCatalogMode === 'menu' ? (
                <TouchableOpacity
                  style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
                  onPress={closeEditCatalogExerciseMenu}
                >
                  <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cerrar</Text>
                </TouchableOpacity>
            ) : null}
          </View>
        </KeyboardAvoidingView>
      </Modal>

      {/* Modal para ejercicio personalizado */}
      <Modal
        visible={showCustomExerciseModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowCustomExerciseModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Agregar ejercicio personalizado</Text>
            
            <View style={styles.customExerciseForm}>
              <TextInput
                style={[styles.customExerciseInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                placeholder="Nombre del ejercicio"
                value={customExerciseName}
                onChangeText={setCustomExerciseName}
                placeholderTextColor={theme.textSecondary}
              />
              {/* Selector real de grupo muscular */}
              <View style={[styles.pickerContainer, { backgroundColor: theme.surface, borderColor: theme.border }]}
              >
                <ScrollView style={{ maxHeight: 160 }} showsVerticalScrollIndicator persistentScrollbar>
                  {muscleGroups.map((mg) => (
                    <TouchableOpacity key={mg} style={{ paddingVertical: 8 }} onPress={() => setCustomExerciseMuscle(mg)}>
                      <Text style={{ color: customExerciseMuscle === mg ? theme.textPrimary : theme.textSecondary, fontWeight: customExerciseMuscle === mg ? '700' as const : '500' }}>{mg}</Text>
                    </TouchableOpacity>
                  ))}
                </ScrollView>
                <Text style={[styles.pickerLabel, { color: theme.textSecondary, marginTop: 6 }]}>Seleccionado: {customExerciseMuscle}</Text>
              </View>
            </View>
            
            <View style={styles.customExerciseButtons}>
              <TouchableOpacity 
                style={[styles.customExerciseAddButton, { backgroundColor: '#D4A574' }]}
                onPress={handleAddCustomExercise}
              >
                <Text style={[styles.customExerciseAddButtonText, { color: '#FFFFFF' }]}>Agregar</Text>
              </TouchableOpacity>
              <TouchableOpacity 
                style={[styles.customExerciseCancelButton, { backgroundColor: theme.buttonSecondary }]}
                onPress={() => {
                  setShowCustomExerciseModal(false);
                  setCustomExerciseName('');
                  setCustomExerciseMuscle('Pectoral');
                }}
              >
                <Text style={[styles.customExerciseCancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      <Modal
        visible={showImageManagerModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowImageManagerModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Gestor de imágenes</Text>
            <View style={styles.searchContainer}>
              <TextInput
                style={[styles.searchInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                placeholder="Buscar ejercicio..."
                value={imageManagerSearchQuery}
                onChangeText={setImageManagerSearchQuery}
                placeholderTextColor={theme.textSecondary}
              />
            </View>

            {selectedImageExercise && (
              <View style={[styles.imageManagerSelectedBox, { borderColor: theme.border, backgroundColor: theme.background }]}>
                  <Text style={[styles.imageManagerSelectedTitle, { color: theme.textPrimary }]} numberOfLines={1}>
                    {getDisplayExerciseName(selectedImageExercise.ejercicio)}
                  </Text>
                <View style={styles.imageManagerActions}>
                  {(() => {
                    const listThumbSource = (selectedImageExercise as any).imageSource as any;
                    const selectedSource = getExercisePreviewImageSource(selectedImageExercise);
                    const hasImage = !!(listThumbSource || selectedSource);
                    return (
                      <>
                        {hasImage ? (
                          <TouchableOpacity
                            style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                            onPress={() => openImagePreview(selectedSource || listThumbSource, getExerciseImageSource(selectedImageExercise))}
                          >
                            <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Ver</Text>
                          </TouchableOpacity>
                        ) : null}

                        <TouchableOpacity
                          style={[styles.modalButton, { backgroundColor: theme.buttonPrimary }]} 
                          onPress={() => {
                            setShowAppImageLibraryModal(true);
                            setAppImageLibrarySearchQuery('');
                          }}
                        >
                          <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Biblioteca</Text>
                        </TouchableOpacity>

                        <TouchableOpacity
                          style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]}
                          onPress={() => void chooseImageFromGallery(selectedImageExercise)}
                        >
                          <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Galería</Text>
                        </TouchableOpacity>

                        {hasImage ? (
                          <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => removeExerciseImage(selectedImageExercise)}>
                            <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Quitar</Text>
                          </TouchableOpacity>
                        ) : null}

                        <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setSelectedImageExercise(null)}>
                          <Text style={[styles.modalButtonText, { color: theme.buttonText }]} numberOfLines={1}>Cancelar</Text>
                        </TouchableOpacity>
                      </>
                    );
                  })()}
                </View>
              </View>
            )}

            <ScrollView style={styles.exerciseList} showsVerticalScrollIndicator persistentScrollbar>
              {imageManagerExercises.map((exercise, index) => (
                <TouchableOpacity
                  key={`${exercise.ejercicio}-${index}`}
                  style={[
                    styles.exerciseOption,
                    { borderBottomColor: theme.border },
                    selectedImageExercise?.ejercicio === exercise.ejercicio && { backgroundColor: theme.background }
                  ]}
                  onPress={() => setSelectedImageExercise(exercise)}
                >
                  <View style={styles.exerciseOptionRow}>
                    {exercise.imageSource ? (
                      <Image source={exercise.imageSource} style={styles.exerciseOptionThumb} resizeMode="cover" />
                    ) : (
                      <View style={[styles.exerciseOptionThumb, { backgroundColor: theme.background, borderColor: theme.border, borderWidth: 1 }]} />
                    )}
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]}>{getDisplayExerciseName(exercise.ejercicio)}</Text>
                      <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]}>
                        {exercise.musculo} {exercise.hasImage ? '• con imagen' : '• sin imagen'}
                      </Text>
                    </View>
                  </View>
                </TouchableOpacity>
              ))}
            </ScrollView>

            <TouchableOpacity
              style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
              onPress={() => {
                setShowImageManagerModal(false);
                setSelectedImageExercise(null);
                setImageManagerSearchQuery('');
              }}
            >
              <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cerrar</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal
        visible={showAppImageLibraryModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowAppImageLibraryModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Biblioteca de imágenes</Text>
            <View style={styles.searchContainer}>
              <TextInput
                style={[styles.searchInput, { backgroundColor: theme.surface, borderColor: theme.border, color: theme.textPrimary }]}
                placeholder="Buscar por nombre o ID..."
                value={appImageLibrarySearchQuery}
                onChangeText={setAppImageLibrarySearchQuery}
                placeholderTextColor={theme.textSecondary}
              />
            </View>
            <FlatList
              style={styles.exerciseList}
              data={filteredAppImageLibrary}
              keyExtractor={(item) => item.id}
              showsVerticalScrollIndicator
              persistentScrollbar
              keyboardShouldPersistTaps="handled"
              initialNumToRender={8}
              maxToRenderPerBatch={8}
              windowSize={3}
              removeClippedSubviews
              onEndReachedThreshold={0.6}
              onEndReached={loadMoreAppImageLibrary}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={[styles.exerciseOption, { borderBottomColor: theme.border }]}
                  onPress={() => {
                    if (!selectedImageExercise) return;
                    void chooseImageFromAppLibrary(selectedImageExercise, item.id);
                  }}
                >
                  <View style={styles.exerciseOptionRow}>
                    <Image source={item.source} style={styles.exerciseOptionThumb} resizeMode="cover" />
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.exerciseOptionText, { color: theme.textPrimary }]} numberOfLines={1}>
                        {item.primaryName}
                      </Text>
                      <Text style={[styles.exerciseOptionSubtext, { color: theme.textSecondary }]} numberOfLines={1}>
                        ID: {item.id}
                      </Text>
                    </View>
                  </View>
                </TouchableOpacity>
              )}
              ListEmptyComponent={
                <View style={styles.loadingRow}>
                  <Text style={[styles.loadingText, { color: theme.textSecondary }]}>Sin resultados</Text>
                </View>
              }
            />
            <TouchableOpacity
              style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
              onPress={() => setShowAppImageLibraryModal(false)}
            >
              <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cerrar</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal
        visible={showImagePreviewModal}
        transparent={true}
        animationType="fade"
        onRequestClose={closeImagePreview}
      >
        <View style={styles.imagePreviewOverlay}>
          <BlurView
            intensity={isDark ? 30 : 20}
            tint={isDark ? 'dark' : 'light'}
            style={StyleSheet.absoluteFillObject}
            pointerEvents="none"
            experimentalBlurMethod={Platform.OS === 'android' ? 'dimezisBlurView' : undefined}
          />
          <TouchableOpacity
            style={[styles.imagePreviewCloseButton, { backgroundColor: theme.surface, borderColor: theme.border }]}
            onPress={closeImagePreview}
            activeOpacity={0.85}
          >
            <Text style={[styles.imagePreviewCloseButtonText, { color: theme.textPrimary }]}>×</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.imagePreviewBackdrop} activeOpacity={1} onPress={closeImagePreview}>
            {previewImageSource ? (
              <Image
                source={previewImageSource}
                style={styles.imagePreview}
                resizeMode="contain"
                onError={() => {
                  if (previewImageFallbackSource && previewImageSource !== previewImageFallbackSource) {
                    setPreviewImageSource(previewImageFallbackSource);
                    return;
                  }
                  console.warn('[images] No se pudo abrir la imagen en preview.');
                }}
              />
            ) : null}
          </TouchableOpacity>
        </View>
      </Modal>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderTopWidth: 1,
    padding: 4,
  },
  minimizedContainer: {
    borderTopWidth: 1,
    paddingTop: 8,
    paddingBottom: 4,
    paddingHorizontal: 8,
  },
  exerciseListHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 6,
    paddingHorizontal: 8,
  },
  exerciseListTitle: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 12, // Configuración válida
  },
  headerButtons: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 4,
  },
  chatbotButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 8,
  },
  chatbotButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  minimizeButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
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
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  headerSeparator: {
    height: 1,
    width: '100%',
  },
  minimizedTitle: {
    fontSize: 18,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 12, // Configuración válida
    marginRight: 8, // Agregar margen derecho
  },
  expandButton: {
    backgroundColor: '#D4A574',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 4, // Reducir un poquitito más el margen
  },
  expandButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  exerciseBox: {
    borderWidth: 1,
    marginBottom: 12,
    marginHorizontal: 8, // Achicar para que se vean los bordes laterales
    padding: 8,
    borderRadius: 8,
  },
  exerciseBoxComplete: {
    // Estilo dinámico aplicado en el JSX
  },
  exerciseHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  exerciseTitleContainer: {
    flex: 1,
  },
  exerciseThumbButton: {
    marginRight: 8,
    borderRadius: 8,
    overflow: 'hidden',
  },
  exerciseThumb: {
    width: 44,
    height: 44,
  },
  exerciseTitle: {
    fontWeight: 'bold', // Cambiar de '600' a 'bold' para destacar más
    fontSize: 14,
    fontFamily: 'System',
  },
  editExerciseContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  editExerciseInput: {
    borderWidth: 1,
    paddingHorizontal: 4,
    paddingVertical: 2,
    marginRight: 4,
    flex: 1,
    fontSize: 12,
    fontFamily: 'System',
  },
  editExerciseButtons: {
    flexDirection: 'row',
  },
  saveEditBtn: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginRight: 2,
    borderRadius: 2,
  },
  saveEditBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  cancelEditBtn: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 2,
  },
  cancelEditBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  exerciseControls: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  controlBtn: {
    borderWidth: 1,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginHorizontal: 2,
    borderRadius: 6,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dragHandleTouchArea: {
    width: 24,
    height: 28,
    marginHorizontal: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dragHandleTouchAreaActive: {
    transform: [{ scale: 1.08 }],
  },
  gripIcon: {
    width: 10,
    height: 14,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  gripColumn: {
    height: '100%',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dragDot: {
    width: 3,
    height: 3,
    borderRadius: 1.5,
  },
  dragDotActive: {
    width: 4,
    height: 4,
    borderRadius: 2,
  },
  controlBtnDisabled: {
    opacity: 0.5,
  },
  controlBtnText: {
    fontWeight: '600',
    fontSize: 16,
    lineHeight: 16,
    fontFamily: 'System',
  },
  minimizeExerciseBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    marginRight: 4,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  minimizeExerciseBtnText: {
    fontWeight: '600',
    fontSize: 16,
    lineHeight: 16,
    fontFamily: 'System',
  },
  removeBtn: {
    borderWidth: 1,
    borderColor: '#E2928D',
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginLeft: 4,
    backgroundColor: 'rgba(244, 202, 171, 0.15)', // Color más suave y transparente
    borderRadius: 6,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeBtnText: {
    color: '#E2928D',
    fontWeight: '600',
    fontSize: 16,
    lineHeight: 16,
    fontFamily: 'System',
  },
  previousRecordContainer: {
    paddingVertical: 6,
    paddingHorizontal: 0,
    marginBottom: 8,
    marginHorizontal: -1,
    borderRadius: 6,
    borderWidth: 1,
    alignSelf: 'stretch',
    width: '100%',
  },
  previousRecordTitle: {
    fontSize: 13,
    fontWeight: '600',
    fontFamily: 'System',
    marginLeft: 6,
  },
  previousRecordHeaderRow: {
    marginBottom: 0,
  },
  previousRecordHeaderText: {
    fontSize: 12,
    fontWeight: '600',
    fontFamily: 'System',
  },
  previousRecordSpacer: {
    width: 28,
    height: 14,
  },
  previousRecordRow: {
    marginBottom: 0,
    alignItems: 'center',
  },
  previousRecordText: {
    fontSize: 12,
    fontFamily: 'System',
  },
  seriesContainer: {
    marginTop: 8,
  },
  seriesHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  seriesHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  equalRow: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
  },
  equalSeriesRow: {
    marginVertical: 3,
  },
  equalCell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  equalEdgeCell: {
    flex: 0.7,
  },
  equalCenterCell: {
    flex: 1.3,
  },
  equalInput: {
    borderWidth: 1,
    width: '92%',
    maxWidth: 64,
    paddingHorizontal: 4,
    paddingVertical: 2,
    height: 28,
    borderRadius: 6,
    fontSize: 12,
    fontFamily: 'System',
  },
  equalEmpty: {
    width: 28,
    height: 28,
  },
  seriesTitle: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  draggingExerciseBox: {
    opacity: 0.86,
    zIndex: 30,
    elevation: 8,
  },
  dragTargetExerciseBox: {
    borderWidth: 2,
  },
  addSeriesBtn: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 8,
    minWidth: 180,
    minHeight: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addSeriesBtnText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  columnHeaders: {
    flexDirection: 'row',
    marginBottom: 4,
  },
  seriesLabelContainer: {
    flex: 1,
    paddingHorizontal: 8,
  },
  columnHeaderText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  headerText: {
    fontWeight: 'bold',
    fontSize: 14,
    textAlign: 'center',
    fontFamily: 'System',
  },
  headerCellSmall: {
    width: 56,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 4, // igual que input
  },
  headerCellTime: {
    width: 180,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerCellCheck: {
    width: 44,
    minHeight: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerFieldsRow: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'center',
    marginLeft: 0,
  },
  seriesFieldsRow: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'center',
  },
  columnHeaderInput: {
    flex: 1,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
    fontFamily: 'System',
  },
  seriesRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
  },
  seriesFooterRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 12,
  },
  seriesInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    width: 76,
  },
  seriesLabel: {
    flex: 1,
    fontFamily: 'System',
  },
  equalSeriesLabel: {
    flex: 0,
    lineHeight: 28,
    includeFontPadding: false,
  },
  removeSeriesBtn: {
    width: 28,
    height: 28,
    borderRadius: 6,
    marginLeft: 1,
    marginRight: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeSeriesBtnText: {
    fontWeight: '700',
    fontSize: 12,
    fontFamily: 'System',
    lineHeight: 12,
  },
  input: {
    borderWidth: 1,
    width: 56,
    marginHorizontal: 4,
    paddingHorizontal: 4,
    paddingVertical: 2,
    height: 28,
    borderRadius: 6,
    fontSize: 12,
    fontFamily: 'System',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  imagePreviewOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addExerciseModalOverlay: {
    justifyContent: 'center',
    paddingHorizontal: 12,
    paddingVertical: 12,
  },
  modalContent: {
    borderRadius: 12,
    padding: 20,
    width: '80%',
    maxHeight: '70%',
    overflow: 'hidden',
  },
  addExerciseModalContent: {
    width: '90%',
    maxHeight: '85%',
    height: '85%',
    minHeight: 260,
    paddingBottom: 12,
    flexShrink: 1,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 16,
    fontFamily: 'System',
  },
  customExerciseButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    marginBottom: 16,
    alignItems: 'center',
  },
  customExerciseButtonText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  exerciseList: {
    maxHeight: 300,
    paddingRight: 10,
  },
  exerciseListWrapper: {
    flex: 1,
    minHeight: 0,
    overflow: 'hidden',
  },
  addExerciseList: {
    flex: 1,
    minHeight: 0,
    maxHeight: '100%',
  },
  exerciseListDynamic: {
    flex: 1,
    minHeight: 0,
  },
  listWithScrollbar: {
    position: 'relative',
  },
  listWithScrollbarFill: {
    flex: 1,
    minHeight: 0,
    overflow: 'hidden',
  },
  addExerciseListArea: {
    flex: 1,
    minHeight: 0,
  },
  mainListWithScrollbar: {
    flex: 1,
    position: 'relative',
  },
  scrollbarTrack: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 6,
    borderRadius: 999,
    opacity: 0.85,
    overflow: 'hidden',
  },
  scrollbarThumb: {
    width: '100%',
    borderRadius: 999,
  },
  loadingRow: {
    paddingVertical: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    fontSize: 14,
    fontFamily: 'System',
    fontWeight: '600',
  },
  exerciseGroupHeader: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  exerciseGroupHeaderText: {
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.3,
    fontFamily: 'System',
  },
  exerciseOption: {
    padding: 16,
    borderBottomWidth: 1,
  },
  exerciseOptionRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  exerciseOptionThumb: {
    width: 46,
    height: 46,
    borderRadius: 8,
    marginRight: 10,
  },
  exerciseOptionText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  exerciseOptionSubtext: {
    fontSize: 12,
    marginTop: 4,
    fontFamily: 'System',
  },
  cancelButton: {
    marginTop: 16,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontWeight: '600',
    fontFamily: 'System',
  },
  modalButton: {
    flexGrow: 1,
    flexBasis: '45%',
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 0,
  },
  modalButtonText: {
    fontWeight: '600',
    fontSize: 13,
    fontFamily: 'System',
    textAlign: 'center',
  },
  editCatalogInfoText: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    marginBottom: 12,
  },
  editCatalogInfoTitle: {
    fontSize: 15,
    fontWeight: '600',
    fontFamily: 'System',
  },
  editCatalogInfoSubtext: {
    fontSize: 12,
    marginTop: 4,
    fontFamily: 'System',
  },
  editCatalogActions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8 as any,
    marginBottom: 12,
  },
  editCatalogSection: {
    marginBottom: 8,
  },
  editCatalogLabel: {
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 6,
    fontFamily: 'System',
  },
  editCatalogButtons: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8 as any,
    marginTop: 8,
  },
  addExerciseModalActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 10 as any,
    marginTop: 16,
  },
  addExerciseModalButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  addExerciseModalButtonText: {
    fontWeight: '600',
    fontFamily: 'System',
  },
  imageManagerSelectedBox: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 10,
    marginHorizontal: 16,
    marginBottom: 12,
  },
  imageManagerSelectedTitle: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'System',
    marginBottom: 8,
  },
  imageManagerActions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8 as any,
  },
  imagePreviewBackdrop: {
    flex: 1,
    width: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  imagePreviewCloseButton: {
    position: 'absolute',
    top: 16,
    right: 16,
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2,
  },
  imagePreviewCloseButtonText: {
    fontSize: 22,
    fontWeight: '700',
    lineHeight: 22,
    fontFamily: 'System',
  },
  imagePreview: {
    width: '100%',
    height: '80%',
  },
  addExerciseContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#D4A574',
    marginHorizontal: 32,
  },
  addExerciseActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8 as any,
  },
  addExerciseButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
  },
  disabledActionButton: {
    opacity: 0.5,
  },
  addExerciseButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  exerciseCount: {
    fontSize: 12,
    fontFamily: 'System',
  },
  searchContainer: {
    marginBottom: 16,
    paddingHorizontal: 16,
  },
  searchContainerWithClear: {
    position: 'relative',
  },
  searchInput: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    fontFamily: 'System',
  },
  searchInputWithClear: {
    paddingRight: 36,
  },
  searchClearButton: {
    position: 'absolute',
    right: 26,
    top: '50%',
    width: 22,
    height: 22,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
    transform: [{ translateY: -11 }],
  },
  searchClearButtonText: {
    fontSize: 18,
    fontWeight: '600',
    lineHeight: 18,
    fontFamily: 'System',
  },
  customExerciseForm: {
    marginBottom: 20,
  },
  customExerciseInput: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    marginBottom: 12,
    fontFamily: 'System',
  },
  customExerciseButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  customExerciseAddButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginRight: 8,
  },
  customExerciseAddButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
  },
  customExerciseCancelButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginLeft: 8,
  },
  customExerciseCancelButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
  },
  pickerContainer: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 12,
  },
  pickerLabel: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 4,
    fontFamily: 'System',
  },
  pickerNote: {
    fontSize: 12,
    fontStyle: 'italic',
    fontFamily: 'System',
  },
  picker: {
    height: 50,
  },
});

export default ExerciseList; 

