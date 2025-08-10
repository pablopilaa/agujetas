import React, { useState, useRef, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Image, Dimensions, Modal, Animated, Alert, TextInput } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { getTheme } from '../utils/theme';

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

const exerciseDatabase = {
  'Bíceps': { default: ['Curl bíceps mancuerna','Curl bíceps barra','Curl bíceps cable','Curl bíceps martillo','Curl bíceps concentrado'] },
  'Pectoral': { default: ['Press banca','Press plano mancuernas','Press banca inclinado','Press inclinado mancuernas','Aperturas mancuernas','Peck-Deck (Mariposa)'] },
  'Tríceps': { default: ['Tríceps Katana','Extensiones de tríceps cable','Extensiones de tríceps mancuerna','Fondos paralelas','Fondos paralelas lastre'] },
  'Hombros': { default: ['Extensiones de hombros polea','Press militar','Press Arnold','Elevaciones laterales','Elevaciones frontales'] },
  'Espalda': { default: ['Jalón al pecho','Remo barra','Remo mancuernas','Dominadas'] },
  'Piernas': { default: ['Sentadillas','Prensa de piernas','Extensiones de cuádriceps','Sentadillas búlgaras','Curl de femoral','Peso muerto'] },
} as const;

const EditMenu: React.FC<Props> = ({ open, onClose, exercises, setExercises, onAddExercise, isDarkMode }) => {
  const insets = useSafeAreaInsets();
  const [replaceIndex, setReplaceIndex] = useState<number | null>(null);
  const [showReplaceModal, setShowReplaceModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const slideAnimation = useRef(new Animated.Value(-300)).current;
  const theme = getTheme(isDarkMode || false);

  useEffect(() => {
    Animated.timing(slideAnimation, {
      toValue: open ? 0 : -300,
      duration: 300,
      useNativeDriver: true,
    }).start();
  }, [open]);

  const getSuggestionsFor = (exerciseName: string, muscle: string): string[] => {
    const mg: any = (exerciseDatabase as any)[muscle];
    if (!mg) return [];
    const base = mg.default || [];
    return base.filter((n: string) => n.toLowerCase().includes(searchQuery.toLowerCase()));
  };

  const openReplacePicker = (index: number) => {
    setReplaceIndex(index);
    setSearchQuery('');
    setShowReplaceModal(true);
  };

  const applyReplacement = (newName: string) => {
    if (replaceIndex === null) return;
    const updated = exercises.map((ex, idx) => idx === replaceIndex ? { ...ex, ejercicio: newName } : ex);
    setExercises(updated);
    setShowReplaceModal(false);
    setReplaceIndex(null);
  };

  return (
    <>
      <Modal visible={open} transparent animationType="none" onRequestClose={onClose}>
        <View style={styles.overlay}>
          <TouchableOpacity style={styles.overlayTouchable} activeOpacity={1} onPress={onClose} />
          <Animated.View style={[styles.drawer, { paddingTop: insets.top + 16, transform: [{ translateX: slideAnimation }] }]}>
            <View style={styles.header}>
              <View style={styles.titleContainer}>
                <Image source={require('../assets/logo-transparent.png')} style={styles.logo} />
                <Text style={[styles.title, { color: theme.textPrimary }]}>Editar</Text>
              </View>
              <TouchableOpacity style={[styles.closeButton, { backgroundColor: theme.buttonSecondary }]} onPress={onClose}>
                <Text style={[styles.closeButtonText, { color: theme.buttonText }]}>✕</Text>
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.chatBox}>
              <Text style={[styles.chatText]}>Hola! En este menú podés cambiar ejercicios actuales o agregar nuevos.</Text>
              <Text style={styles.sectionTitle}>Ejercicios actuales:</Text>
              {exercises.map((exercise, index) => (
                <View key={index} style={styles.exerciseItem}>
                  <Text style={styles.exerciseName}>{exercise.ejercicio}</Text>
                  <TouchableOpacity style={styles.replaceBtn} onPress={() => openReplacePicker(index)}>
                    <Text style={styles.replaceBtnText}>Cambiar</Text>
                  </TouchableOpacity>
                </View>
              ))}

              {onAddExercise && (
                <TouchableOpacity
                  style={[styles.addExerciseBtn, { backgroundColor: theme.buttonPrimary }]}
                  onPress={() => {
                    // Abrir el buscador/listado completo en lugar de insertar un genérico
                    onAddExercise();
                  }}
                >
                  <Text style={[styles.addExerciseBtnText, { color: theme.buttonText }]}>+ Agregar ejercicio</Text>
                </TouchableOpacity>
              )}
            </ScrollView>
          </Animated.View>
        </View>
      </Modal>

      {/* Selector de reemplazo */}
      <Modal visible={showReplaceModal} transparent animationType="fade" onRequestClose={() => setShowReplaceModal(false)}>
        <View style={styles.overlay}>
          <View style={[styles.replaceModal, { backgroundColor: theme.surface }] }>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Reemplazar ejercicio</Text>
            <TextInput
              value={searchQuery}
              onChangeText={setSearchQuery}
              placeholder="Buscar ejercicio..."
              placeholderTextColor={theme.textSecondary}
              style={[styles.searchInput, { color: theme.textPrimary, borderColor: '#D4A574' }]}
            />
            <ScrollView style={{ maxHeight: 300 }}>
              {replaceIndex !== null && getSuggestionsFor(exercises[replaceIndex].ejercicio, exercises[replaceIndex].musculo)
                .map((name, i) => (
                  <TouchableOpacity key={i} style={styles.suggestionItem} onPress={() => applyReplacement(name)}>
                    <Text>{name}</Text>
                  </TouchableOpacity>
                ))}
            </ScrollView>
            <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 12 }}>
              <TouchableOpacity style={[styles.modalButton, { backgroundColor: '#6D7172' }]} onPress={() => setShowReplaceModal(false)}>
                <Text style={styles.modalButtonText}>Cancelar</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)' },
  overlayTouchable: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  drawer: { position: 'absolute', left: 0, top: 0, width: Dimensions.get('window').width * 0.8, height: '100%', backgroundColor: '#F8F6F2', borderRightWidth: 2, borderColor: '#4F766F', zIndex: 100, padding: 16 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, borderBottomWidth: 1, borderBottomColor: '#333333', paddingBottom: 16 },
  titleContainer: { flexDirection: 'row', alignItems: 'center' },
  logo: { width: 40, height: 40, marginRight: 10 },
  title: { fontSize: 20, fontWeight: '600', color: '#4F766F', fontFamily: 'System' },
  chatBox: { flex: 1, borderWidth: 1, borderColor: '#D4A574', padding: 8, marginTop: 8, backgroundColor: '#FFFFFF', borderRadius: 8 },
  chatText: { color: '#4F766F', marginBottom: 12, fontFamily: 'System' },
  sectionTitle: { fontWeight: '600', color: '#4F766F', marginBottom: 8, fontSize: 16, fontFamily: 'System' },
  exerciseItem: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: '#D4A574' },
  exerciseName: { color: '#4F766F', flex: 1, fontFamily: 'System' },
  replaceBtn: { backgroundColor: '#4F766F', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 4, minWidth: 40, alignItems: 'center' },
  replaceBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 12, fontFamily: 'System' },
  addExerciseBtn: { paddingVertical: 12, paddingHorizontal: 16, borderRadius: 8, alignItems: 'center', marginTop: 16, marginBottom: 8 },
  addExerciseBtnText: { fontWeight: '600', fontSize: 14, fontFamily: 'System' },
  replaceModal: { marginHorizontal: 20, borderRadius: 12, padding: 16 },
  modalTitle: { fontSize: 18, fontWeight: '600', textAlign: 'center', marginBottom: 12 },
  searchInput: { borderWidth: 1, borderRadius: 8, padding: 10, marginBottom: 12, fontFamily: 'System' },
  suggestionItem: { paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: '#D4A574' },
  modalButton: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 8 },
  modalButtonText: { fontWeight: '600', fontFamily: 'System' },
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
});

export default EditMenu;

