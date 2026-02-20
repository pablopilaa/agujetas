import React, { useEffect, useMemo, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal, ScrollView, TextInput } from 'react-native';
import { getTheme } from '../utils/theme';
import { ds } from '../utils/design';
import { getExerciseHistoryIndex } from '../utils/storage';
import ExerciseProgressChart from './ExerciseProgressChart';

interface Props {
  minimized: boolean;
  onMinimize: (value: boolean) => void;
  isDarkMode?: boolean;
}

interface AnalyticsExerciseOption {
  key: string;
  label: string;
  count: number;
  firstDate: string;
  lastDate: string;
}

const normalizeText = (value: string): string => {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
};

const normalizeDateInput = (value: string): string => {
  return value.replace(/[^0-9-]/g, '').slice(0, 10);
};

const getViewLabel = (view: 'daily' | 'weekly' | 'monthly'): string => {
  if (view === 'daily') return 'Diario';
  if (view === 'weekly') return 'Semanal';
  return 'Mensual';
};

const ExerciseAnalyticsSection: React.FC<Props> = ({ minimized, onMinimize, isDarkMode }) => {
  const theme = getTheme(isDarkMode || false);
  const accentColor = theme.buttonPrimary;
  const accentFill = isDarkMode ? 'rgba(79,118,111,0.24)' : 'rgba(79,118,111,0.12)';
  const controlBorder = isDarkMode ? 'rgba(255,255,255,0.20)' : 'rgba(79,118,111,0.22)';
  const sectionBorder = isDarkMode ? 'rgba(255,255,255,0.14)' : 'rgba(79,118,111,0.18)';
  const axisColor = isDarkMode ? 'rgba(255,255,255,0.20)' : 'rgba(79,118,111,0.24)';
  const [showExercisePicker, setShowExercisePicker] = useState(false);
  const [pickerSearch, setPickerSearch] = useState('');
  const [analyticsOptions, setAnalyticsOptions] = useState<AnalyticsExerciseOption[]>([]);
  const [selectedExerciseKey, setSelectedExerciseKey] = useState('');
  const [view, setView] = useState<'daily' | 'weekly' | 'monthly'>('daily');
  const [mode, setMode] = useState<'chart' | 'history'>('chart');
  const [startDateISO, setStartDateISO] = useState('');
  const [endDateISO, setEndDateISO] = useState('');

  const loadOptions = async () => {
    const historyIndex = await getExerciseHistoryIndex();
    const options = Object.entries(historyIndex)
      .map(([key, items]) => {
        const first = items[0];
        const last = items[items.length - 1];
        return {
          key,
          label: first?.ejercicio || key,
          count: items.length,
          firstDate: first?.fecha || '',
          lastDate: last?.fecha || '',
        } as AnalyticsExerciseOption;
      })
      .filter((item) => item.count > 0)
      .sort((a, b) => a.label.localeCompare(b.label, 'es'));

    setAnalyticsOptions(options);

    if (options.length === 0) {
      setSelectedExerciseKey('');
      return;
    }

    const exists = options.some((option) => option.key === selectedExerciseKey);
    const selected = exists ? options.find((option) => option.key === selectedExerciseKey)! : options[0];
    setSelectedExerciseKey(selected.key);
    if (!exists) {
      setStartDateISO(selected.firstDate.slice(0, 10));
      setEndDateISO(selected.lastDate.slice(0, 10));
    }
  };

  useEffect(() => {
    if (minimized) return;
    loadOptions();
  }, [minimized]);

  const selectedOption = analyticsOptions.find((option) => option.key === selectedExerciseKey) || null;

  const filteredOptions = useMemo(() => {
    const q = normalizeText(pickerSearch);
    if (!q) return analyticsOptions;
    return analyticsOptions.filter((option) => normalizeText(option.label).includes(q));
  }, [analyticsOptions, pickerSearch]);

  const handleSelectOption = (option: AnalyticsExerciseOption) => {
    setSelectedExerciseKey(option.key);
    setStartDateISO(option.firstDate.slice(0, 10));
    setEndDateISO(option.lastDate.slice(0, 10));
    setShowExercisePicker(false);
    setPickerSearch('');
  };

  if (minimized) {
    return (
      <View style={[styles.minimized, { backgroundColor: theme.background, borderColor: theme.border, marginTop: ds.spacing - 2, marginBottom: ds.spacing - 2, borderTopWidth: 1, borderTopColor: ds.header.borderTopColor }]}>
        <View style={[styles.header, { paddingHorizontal: ds.header.paddingHorizontal, paddingTop: ds.header.paddingTop, paddingBottom: ds.header.paddingBottom, minHeight: ds.header.height }]}>
          <Text style={[styles.title, { color: theme.textPrimary }]}>Gráfico por ejercicio</Text>
          <View style={styles.actionArea}>
            <TouchableOpacity style={[styles.expandButton, { backgroundColor: '#D4A574' }]} onPress={() => onMinimize(false)}>
              <Text style={[styles.expandButtonText, { color: '#FFFFFF' }]}>Expandir</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background, borderColor: theme.border, marginTop: ds.spacing - 2, marginBottom: ds.spacing - 2, borderTopWidth: 1, borderTopColor: ds.header.borderTopColor }]}>
      <View style={[styles.header, styles.headerCentered, { paddingHorizontal: ds.header.paddingHorizontal, paddingTop: ds.header.paddingTop, paddingBottom: ds.header.paddingBottom, minHeight: ds.header.height }]}>
        <Text style={[styles.title, styles.titleCentered, { color: theme.textPrimary }]}>Gráfico por ejercicio</Text>
      </View>
      <View style={[styles.content, { backgroundColor: 'transparent', borderColor: 'transparent' }] }>
        <TouchableOpacity
          style={[styles.pickerButton, { borderColor: controlBorder, backgroundColor: 'transparent' }]}
          onPress={() => setShowExercisePicker(true)}
        >
          <View style={styles.pickerButtonRow}>
            <Text style={[styles.pickerButtonText, { color: theme.textPrimary }]} numberOfLines={1}>
              {selectedOption ? selectedOption.label : 'Seleccionar ejercicio'}
            </Text>
            <Text style={[styles.pickerButtonChevron, { color: theme.textSecondary }]}>▼</Text>
          </View>
        </TouchableOpacity>

        <View style={styles.toggleRow}>
          {(['chart', 'history'] as const).map((nextMode) => (
            <TouchableOpacity
              key={nextMode}
              style={[
                styles.toggleButton,
                {
                  borderColor: mode === nextMode ? accentColor : controlBorder,
                  backgroundColor: mode === nextMode ? accentFill : 'transparent',
                },
              ]}
              onPress={() => setMode(nextMode)}
            >
              <Text style={[styles.toggleText, { color: mode === nextMode ? accentColor : theme.textSecondary }]}>{nextMode === 'chart' ? 'Gráfico' : 'Tabla'}</Text>
            </TouchableOpacity>
          ))}
        </View>

        {mode === 'chart' ? (
          <View style={styles.toggleRow}>
            {(['daily', 'weekly', 'monthly'] as const).map((nextView) => (
              <TouchableOpacity
                key={nextView}
                style={[
                  styles.toggleButton,
                  {
                    borderColor: view === nextView ? accentColor : controlBorder,
                    backgroundColor: view === nextView ? accentFill : 'transparent',
                  },
                ]}
                onPress={() => setView(nextView)}
              >
                <Text style={[styles.toggleText, { color: view === nextView ? accentColor : theme.textSecondary }]}>
                  {getViewLabel(nextView)}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        ) : null}

        <View style={styles.dateRow}>
          <TextInput
            value={startDateISO}
            onChangeText={(text) => setStartDateISO(normalizeDateInput(text))}
            placeholder="Desde YYYY-MM-DD"
            placeholderTextColor={theme.textSecondary}
            style={[styles.dateInput, { color: theme.textPrimary, borderColor: controlBorder, backgroundColor: 'transparent' }]}
          />
          <TextInput
            value={endDateISO}
            onChangeText={(text) => setEndDateISO(normalizeDateInput(text))}
            placeholder="Hasta YYYY-MM-DD"
            placeholderTextColor={theme.textSecondary}
            style={[styles.dateInput, { color: theme.textPrimary, borderColor: controlBorder, backgroundColor: 'transparent' }]}
          />
        </View>

        <ExerciseProgressChart
          exerciseKey={selectedOption?.key || ''}
          view={view}
          mode={mode}
          startDateISO={startDateISO}
          endDateISO={endDateISO}
          isDarkMode={isDarkMode}
          lineColor={accentColor}
          lineStrokeColor={isDarkMode ? accentColor : '#949B99'}
          axisColor={axisColor}
        />
      </View>

      <View style={styles.footerAction}>
        <TouchableOpacity
          style={[styles.closeButton, { backgroundColor: theme.buttonSecondary }]}
          onPress={() => onMinimize(true)}
        >
          <Text style={[styles.closeButtonText, { color: theme.buttonText }]}>Cerrar</Text>
        </TouchableOpacity>
      </View>

      <Modal visible={showExercisePicker} transparent animationType="fade" onRequestClose={() => setShowExercisePicker(false)}>
        <View style={styles.overlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface }] }>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar ejercicio</Text>
            <TextInput
              value={pickerSearch}
              onChangeText={setPickerSearch}
              placeholder="Buscar ejercicio..."
              placeholderTextColor={theme.textSecondary}
              style={[styles.searchInput, { color: theme.textPrimary, borderColor: controlBorder, backgroundColor: 'transparent' }]}
            />
            <ScrollView style={{ maxHeight: 320 }}>
              {filteredOptions.map((option) => (
                <TouchableOpacity
                  key={option.key}
                  style={[styles.optionRow, { borderBottomColor: theme.border }]}
                  onPress={() => handleSelectOption(option)}
                >
                  <Text style={[styles.optionLabel, { color: theme.textPrimary }]} numberOfLines={1}>{option.label}</Text>
                  <Text style={[styles.optionMeta, { color: theme.textSecondary }]}>{option.count} registros</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            <TouchableOpacity style={[styles.closeModalButton, { backgroundColor: theme.buttonSecondary }]} onPress={() => setShowExercisePicker(false)}>
              <Text style={[styles.closeModalButtonText, { color: theme.buttonText }]}>Cerrar</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 0,
    paddingVertical: 3,
    paddingHorizontal: 0,
    marginTop: 0,
  },
  minimized: {
    borderBottomWidth: 1,
    paddingVertical: 6,
    paddingHorizontal: 0,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
    paddingVertical: 3,
    paddingHorizontal: 8,
  },
  headerCentered: {
    justifyContent: 'center',
  },
  headerSeparator: {
    height: 1,
    width: '100%',
  },
  title: {
    fontWeight: '600',
    fontSize: 18,
    fontFamily: 'System',
    marginLeft: 12,
  },
  titleCentered: {
    marginLeft: 0,
    textAlign: 'center',
    flex: 1,
  },
  actionArea: {
    minWidth: ds.sizes.headerActionMinWidth,
    alignItems: 'flex-end',
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
  footerAction: {
    alignItems: 'center',
    paddingTop: 10,
    paddingBottom: 6,
  },
  closeButton: {
    paddingHorizontal: 22,
    paddingVertical: 10,
    borderRadius: 6,
    minWidth: 120,
    alignItems: 'center',
  },
  closeButtonText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
  expandButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    marginRight: 4,
  },
  expandButtonText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  content: {
    marginHorizontal: 8,
    marginTop: 10,
    marginBottom: 8,
    borderWidth: 0,
    borderRadius: 12,
    padding: 12,
  },
  pickerButton: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 9,
    marginBottom: 10,
  },
  pickerButtonRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
  },
  pickerButtonText: {
    fontSize: 14,
    fontFamily: 'System',
    flexShrink: 1,
  },
  pickerButtonChevron: {
    fontSize: 12,
    fontWeight: '700',
    fontFamily: 'System',
  },
  toggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 8,
    marginBottom: 10,
  },
  toggleButton: {
    flex: 1,
    borderRadius: 999,
    borderWidth: 1,
    paddingVertical: 9,
    alignItems: 'center',
  },
  toggleText: {
    fontWeight: '600',
    fontSize: 12,
    fontFamily: 'System',
  },
  dateRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 10,
  },
  dateInput: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 999,
    paddingVertical: 8,
    paddingHorizontal: 12,
    fontSize: 12,
    fontFamily: 'System',
  },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    width: '86%',
    maxHeight: '78%',
    borderRadius: 12,
    padding: 16,
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
    paddingHorizontal: 10,
    paddingVertical: 8,
    marginBottom: 8,
    fontFamily: 'System',
  },
  optionRow: {
    borderBottomWidth: 1,
    paddingVertical: 10,
  },
  optionLabel: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'System',
  },
  optionMeta: {
    fontSize: 12,
    marginTop: 2,
    fontFamily: 'System',
  },
  closeModalButton: {
    marginTop: 10,
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: 'center',
  },
  closeModalButtonText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },
});

export default ExerciseAnalyticsSection;
