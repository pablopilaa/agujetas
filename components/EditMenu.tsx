import React, { useState, useRef, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Image,
  Dimensions,
  Modal,
  Animated,
  TextInput,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getTheme } from '../utils/theme';
import { getExerciseCatalog, getExerciseHistoryIndex } from '../utils/storage';
import { predefinedExercises } from '../utils/exerciseCatalog';
import ExerciseProgressChart from './ExerciseProgressChart';

interface Series {
  reps: string;
  kg: string;
  rir: number | undefined;
}

interface Exercise {
  ejercicio: string;
  musculo: string;
  series: Series[];
}

interface Props {
  open: boolean;
  onClose: () => void;
  exercises: Exercise[];
  setExercises: React.Dispatch<React.SetStateAction<Exercise[]>>;
  onAddExercise?: () => void;
  isDarkMode?: boolean;
}

interface AnalyticsExerciseOption {
  key: string;
  label: string;
  count: number;
  firstDate: string;
  lastDate: string;
}

const normalizeText = (text: string): string => {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
};

const normalizeDateInput = (value: string): string => {
  return value.replace(/[^0-9-]/g, '').slice(0, 10);
};

const EditMenu: React.FC<Props> = ({ open, onClose, exercises, setExercises, onAddExercise, isDarkMode }) => {
  const insets = useSafeAreaInsets();
  const theme = getTheme(isDarkMode || false);
  const slideAnimation = useRef(new Animated.Value(-300)).current;

  const [replaceIndex, setReplaceIndex] = useState<number | null>(null);
  const [showReplaceModal, setShowReplaceModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [customCatalogItems, setCustomCatalogItems] = useState<Array<{ ejercicio: string; musculo: string }>>([]);

  const [showAnalyticsPanel, setShowAnalyticsPanel] = useState(false);
  const [showAnalyticsPicker, setShowAnalyticsPicker] = useState(false);
  const [analyticsOptions, setAnalyticsOptions] = useState<AnalyticsExerciseOption[]>([]);
  const [selectedAnalyticsKey, setSelectedAnalyticsKey] = useState('');
  const [analyticsView, setAnalyticsView] = useState<'daily' | 'weekly' | 'monthly'>('daily');
  const [analyticsMode, setAnalyticsMode] = useState<'chart' | 'history'>('chart');
  const [analyticsStartDate, setAnalyticsStartDate] = useState('');
  const [analyticsEndDate, setAnalyticsEndDate] = useState('');

  useEffect(() => {
    Animated.timing(slideAnimation, {
      toValue: open ? 0 : -300,
      duration: 300,
      useNativeDriver: true,
    }).start();
  }, [open, slideAnimation]);

  useEffect(() => {
    if (!showReplaceModal) return;
    let active = true;
    (async () => {
      const catalog = await getExerciseCatalog();
      if (!active) return;
      setCustomCatalogItems(catalog.items.map(item => ({ ejercicio: item.ejercicio, musculo: item.musculo })));
    })();
    return () => {
      active = false;
    };
  }, [showReplaceModal]);

  useEffect(() => {
    if (!open) return;
    let active = true;
    (async () => {
      const historyIndex = await getExerciseHistoryIndex();
      if (!active) return;
      const nextOptions = Object.entries(historyIndex)
        .map(([key, items]) => {
          const first = items[0];
          const last = items[items.length - 1];
          return {
            key,
            label: first?.ejercicio || key,
            count: items.length,
            firstDate: first?.fecha || '',
            lastDate: last?.fecha || '',
          };
        })
        .filter(option => option.count > 0)
        .sort((a, b) => a.label.localeCompare(b.label, 'es'));

      setAnalyticsOptions(nextOptions);

      if (nextOptions.length === 0) {
        setSelectedAnalyticsKey('');
        return;
      }

      const stillExists = nextOptions.some(option => option.key === selectedAnalyticsKey);
      const selected = stillExists ? nextOptions.find(option => option.key === selectedAnalyticsKey)! : nextOptions[0];

      setSelectedAnalyticsKey(selected.key);
      if (!stillExists) {
        setAnalyticsStartDate(selected.firstDate.slice(0, 10));
        setAnalyticsEndDate(selected.lastDate.slice(0, 10));
      }
    })();

    return () => {
      active = false;
    };
  }, [open, selectedAnalyticsKey]);

  const mergeCatalog = (customItems: Array<{ ejercicio: string; musculo: string }>) => {
    const merged = new Map<string, { ejercicio: string; musculo: string }>();
    predefinedExercises.forEach((ex) => {
      merged.set(normalizeText(ex.ejercicio), ex);
    });
    customItems.forEach((ex) => {
      const key = normalizeText(ex.ejercicio);
      if (!merged.has(key)) {
        merged.set(key, ex);
      }
    });
    return Array.from(merged.values());
  };

  const openReplacePicker = (index: number) => {
    setReplaceIndex(index);
    setSearchQuery('');
    setShowReplaceModal(true);
  };

  const applyReplacement = (newName: string) => {
    if (replaceIndex === null) return;
    const updated = exercises.map((ex, idx) => (idx === replaceIndex ? { ...ex, ejercicio: newName } : ex));
    setExercises(updated);
    setShowReplaceModal(false);
    setReplaceIndex(null);
  };

  const replacementSuggestions = useMemo(() => {
    if (replaceIndex === null) return [] as Array<{ ejercicio: string; musculo: string }>;
    const ex = exercises[replaceIndex];
    const catalogAll = mergeCatalog(customCatalogItems);
    const muscleKey = normalizeText(ex.musculo);
    const currentKey = normalizeText(ex.ejercicio);
    const sameMuscle = catalogAll.filter(item => normalizeText(item.musculo) === muscleKey);
    const baseList = sameMuscle.length > 0 ? sameMuscle : catalogAll;
    const query = searchQuery.trim() ? normalizeText(searchQuery) : '';

    const applyFilter = (list: Array<{ ejercicio: string; musculo: string }>) => {
      const filtered = query
        ? list.filter(item => normalizeText(item.ejercicio).includes(query))
        : list;
      return filtered.filter(item => normalizeText(item.ejercicio) !== currentKey);
    };

    const filteredBase = applyFilter(baseList);
    return filteredBase.length > 0 ? filteredBase : applyFilter(catalogAll);
  }, [replaceIndex, exercises, customCatalogItems, searchQuery]);

  const selectedAnalyticsOption = analyticsOptions.find(option => option.key === selectedAnalyticsKey) || null;

  const handleSelectAnalyticsExercise = (option: AnalyticsExerciseOption) => {
    setSelectedAnalyticsKey(option.key);
    setAnalyticsStartDate(option.firstDate.slice(0, 10));
    setAnalyticsEndDate(option.lastDate.slice(0, 10));
    setShowAnalyticsPicker(false);
  };

  return (
    <>
      <Modal visible={open} transparent animationType="none" onRequestClose={onClose}>
        <View style={styles.overlay}>
          <TouchableOpacity style={styles.overlayTouchable} activeOpacity={1} onPress={onClose} />
          <Animated.View
            style={[
              styles.drawer,
              { paddingTop: insets.top + 16, transform: [{ translateX: slideAnimation }], backgroundColor: theme.surface },
            ]}
          >
            <View style={[styles.header, { borderBottomColor: theme.border }]}>
              <View style={styles.titleContainer}>
                <Image
                  source={isDarkMode ? require('../assets/logo-dark-transparent.png') : require('../assets/logo-transparent.png')}
                  style={styles.logo}
                />
                <Text style={[styles.title, { color: theme.textPrimary }]}>Editar</Text>
              </View>
              <TouchableOpacity style={[styles.closeButton, { backgroundColor: theme.buttonSecondary }]} onPress={onClose}>
                <Text style={[styles.closeButtonText, { color: theme.buttonText }]}>✕</Text>
              </TouchableOpacity>
            </View>

            <ScrollView style={[styles.chatBox, { backgroundColor: theme.surface, borderColor: theme.border }]}>
              <Text style={[styles.chatText, { color: theme.textSecondary }]}>Hola! En este menu podes cambiar ejercicios actuales o agregar nuevos.</Text>
              <Text style={[styles.sectionTitle, { color: theme.textPrimary }]}>Ejercicios actuales:</Text>

              {exercises.map((exercise, index) => (
                <View key={index} style={[styles.exerciseItem, { borderBottomColor: theme.border }]}>
                  <Text style={[styles.exerciseName, { color: theme.textPrimary }]}>{exercise.ejercicio}</Text>
                  <TouchableOpacity style={[styles.replaceBtn, { backgroundColor: theme.buttonPrimary }]} onPress={() => openReplacePicker(index)}>
                    <Text style={[styles.replaceBtnText, { color: theme.buttonText }]}>Cambiar</Text>
                  </TouchableOpacity>
                </View>
              ))}

              {onAddExercise && (
                <TouchableOpacity style={[styles.addExerciseBtn, { backgroundColor: theme.buttonPrimary }]} onPress={onAddExercise}>
                  <Text style={[styles.addExerciseBtnText, { color: theme.buttonText }]}>+ Agregar ejercicio</Text>
                </TouchableOpacity>
              )}

              <View style={[styles.analyticsContainer, { borderColor: theme.border, backgroundColor: theme.background }] }>
                <TouchableOpacity style={styles.analyticsHeader} onPress={() => setShowAnalyticsPanel(prev => !prev)}>
                  <Text style={[styles.analyticsTitle, { color: theme.textPrimary }]}>Progreso por ejercicio</Text>
                  <Text style={[styles.analyticsChevron, { color: theme.textSecondary }]}>{showAnalyticsPanel ? '▲' : '▼'}</Text>
                </TouchableOpacity>

                {showAnalyticsPanel && (
                  <View>
                    <TouchableOpacity
                      style={[styles.analyticsPickerButton, { borderColor: theme.border, backgroundColor: theme.surface }]}
                      onPress={() => setShowAnalyticsPicker(true)}
                    >
                      <Text style={[styles.analyticsPickerText, { color: theme.textPrimary }]}> 
                        {selectedAnalyticsOption ? selectedAnalyticsOption.label : 'Seleccionar ejercicio'}
                      </Text>
                    </TouchableOpacity>

                    <View style={styles.analyticsToggleRow}>
                      {(['daily', 'weekly', 'monthly'] as const).map((view) => (
                        <TouchableOpacity
                          key={view}
                          style={[
                            styles.analyticsToggleBtn,
                            { backgroundColor: analyticsView === view ? theme.buttonPrimary : theme.buttonSecondary },
                          ]}
                          onPress={() => setAnalyticsView(view)}
                        >
                          <Text style={[styles.analyticsToggleText, { color: theme.buttonText }]}>{view}</Text>
                        </TouchableOpacity>
                      ))}
                    </View>

                    <View style={styles.analyticsToggleRow}>
                      {(['chart', 'history'] as const).map((mode) => (
                        <TouchableOpacity
                          key={mode}
                          style={[
                            styles.analyticsToggleBtn,
                            { backgroundColor: analyticsMode === mode ? theme.buttonPrimary : theme.buttonSecondary },
                          ]}
                          onPress={() => setAnalyticsMode(mode)}
                        >
                          <Text style={[styles.analyticsToggleText, { color: theme.buttonText }]}>{mode === 'chart' ? 'Grafico' : 'Historico'}</Text>
                        </TouchableOpacity>
                      ))}
                    </View>

                    <View style={styles.analyticsDatesRow}>
                      <TextInput
                        value={analyticsStartDate}
                        onChangeText={(text) => setAnalyticsStartDate(normalizeDateInput(text))}
                        placeholder="Start YYYY-MM-DD"
                        placeholderTextColor={theme.textSecondary}
                        style={[styles.analyticsDateInput, { color: theme.textPrimary, borderColor: theme.border, backgroundColor: theme.surface }]}
                      />
                      <TextInput
                        value={analyticsEndDate}
                        onChangeText={(text) => setAnalyticsEndDate(normalizeDateInput(text))}
                        placeholder="End YYYY-MM-DD"
                        placeholderTextColor={theme.textSecondary}
                        style={[styles.analyticsDateInput, { color: theme.textPrimary, borderColor: theme.border, backgroundColor: theme.surface }]}
                      />
                    </View>

                    {selectedAnalyticsOption ? (
                      <ExerciseProgressChart
                        exerciseKey={selectedAnalyticsOption.key}
                        view={analyticsView}
                        mode={analyticsMode}
                        startDateISO={analyticsStartDate}
                        endDateISO={analyticsEndDate}
                        isDarkMode={isDarkMode}
                      />
                    ) : (
                      <Text style={{ color: theme.textSecondary }}>No hay historial aun.</Text>
                    )}
                  </View>
                )}
              </View>
            </ScrollView>
          </Animated.View>
        </View>
      </Modal>

      <Modal visible={showReplaceModal} transparent animationType="fade" onRequestClose={() => setShowReplaceModal(false)}>
        <View style={styles.overlay}>
          <View style={[styles.replaceModal, { backgroundColor: theme.surface }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Reemplazar ejercicio</Text>
            <TextInput
              value={searchQuery}
              onChangeText={setSearchQuery}
              placeholder="Buscar ejercicio..."
              placeholderTextColor={theme.textSecondary}
              style={[styles.searchInput, { color: theme.textPrimary, borderColor: theme.border }]}
            />
            <ScrollView style={{ maxHeight: 300 }}>
              {replacementSuggestions.map((item, i) => (
                <TouchableOpacity key={`${item.ejercicio}-${i}`} style={[styles.suggestionItem, { borderBottomColor: theme.border }]} onPress={() => applyReplacement(item.ejercicio)}>
                  <Text style={{ color: theme.textPrimary }}>{item.ejercicio}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 12 }}>
              <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setShowReplaceModal(false)}>
                <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      <Modal visible={showAnalyticsPicker} transparent animationType="fade" onRequestClose={() => setShowAnalyticsPicker(false)}>
        <View style={styles.overlay}>
          <View style={[styles.replaceModal, { backgroundColor: theme.surface }] }>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar ejercicio</Text>
            <ScrollView style={{ maxHeight: 300 }}>
              {analyticsOptions.map((option) => (
                <TouchableOpacity
                  key={option.key}
                  style={[styles.suggestionItem, { borderBottomColor: theme.border }]}
                  onPress={() => handleSelectAnalyticsExercise(option)}
                >
                  <Text style={{ color: theme.textPrimary }}>{option.label}</Text>
                  <Text style={{ color: theme.textSecondary, fontSize: 12 }}>{option.count} registros</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 12 }}>
              <TouchableOpacity style={[styles.modalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setShowAnalyticsPicker(false)}>
                <Text style={[styles.modalButtonText, { color: theme.buttonText }]}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  overlayTouchable: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  drawer: {
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
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
    borderBottomWidth: 1,
    paddingBottom: 16,
  },
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  logo: {
    width: 40,
    height: 40,
    marginRight: 10,
  },
  title: {
    fontSize: 20,
    fontWeight: '600',
    fontFamily: 'System',
  },
  chatBox: {
    flex: 1,
    borderWidth: 1,
    padding: 8,
    marginTop: 8,
    borderRadius: 8,
  },
  chatText: {
    marginBottom: 12,
    fontFamily: 'System',
  },
  sectionTitle: {
    fontWeight: '600',
    marginBottom: 8,
    fontSize: 16,
    fontFamily: 'System',
  },
  exerciseItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  exerciseName: {
    flex: 1,
    fontFamily: 'System',
  },
  replaceBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    minWidth: 40,
    alignItems: 'center',
  },
  replaceBtnText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  addExerciseBtn: {
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
    marginBottom: 8,
  },
  addExerciseBtnText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  replaceModal: {
    marginHorizontal: 20,
    borderRadius: 12,
    padding: 16,
    marginTop: 120,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 12,
    fontFamily: 'System',
  },
  searchInput: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 10,
    marginBottom: 12,
    fontFamily: 'System',
  },
  suggestionItem: {
    paddingVertical: 10,
    borderBottomWidth: 1,
  },
  modalButton: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  modalButtonText: {
    fontWeight: '600',
    fontFamily: 'System',
  },
  closeButton: {
    width: 36,
    height: 36,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#D4A574',
  },
  closeButtonText: {
    fontSize: 18,
    fontWeight: '700',
    fontFamily: 'System',
    lineHeight: 18,
  },
  analyticsContainer: {
    marginTop: 14,
    borderWidth: 1,
    borderRadius: 10,
    padding: 10,
  },
  analyticsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  analyticsTitle: {
    fontSize: 15,
    fontWeight: '700',
    fontFamily: 'System',
  },
  analyticsChevron: {
    fontSize: 14,
    fontFamily: 'System',
  },
  analyticsPickerButton: {
    borderWidth: 1,
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 12,
    marginBottom: 8,
  },
  analyticsPickerText: {
    fontSize: 14,
    fontFamily: 'System',
  },
  analyticsToggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
    gap: 8,
  },
  analyticsToggleBtn: {
    flex: 1,
    borderRadius: 8,
    paddingVertical: 8,
    alignItems: 'center',
  },
  analyticsToggleText: {
    fontSize: 12,
    fontWeight: '600',
    fontFamily: 'System',
  },
  analyticsDatesRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 8,
  },
  analyticsDateInput: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 8,
    paddingVertical: 8,
    paddingHorizontal: 10,
    fontSize: 12,
    fontFamily: 'System',
  },
});

export default EditMenu;
