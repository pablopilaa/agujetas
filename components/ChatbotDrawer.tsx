import React, { useState, useRef, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Image, Dimensions, Modal, Animated, Alert } from 'react-native';
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

// Base de datos inteligente de ejercicios alternativos
const exerciseDatabase = {
  'Bíceps': {
    'Curl bíceps mancuerna': [
      'Curl bíceps barra',
      'Curl bíceps cable',
      'Curl bíceps martillo',
      'Curl bíceps concentrado',
      'Curl bíceps predicador',
      'Curl bíceps spider',
    ],
    'Curl bíceps barra': [
      'Curl bíceps mancuerna',
      'Curl bíceps cable',
      'Curl bíceps martillo',
      'Curl bíceps concentrado',
    ],
    'Curl bíceps cable': [
      'Curl bíceps mancuerna',
      'Curl bíceps barra',
      'Curl bíceps martillo',
      'Curl bíceps concentrado',
    ],
    'default': [
      'Curl bíceps mancuerna',
      'Curl bíceps barra',
      'Curl bíceps cable',
      'Curl bíceps martillo',
      'Curl bíceps concentrado',
    ]
  },
  'Pectoral': {
    'Press banca': [
      'Press plano mancuernas',
      'Press banca inclinado',
      'Press inclinado mancuernas',
      'Aperturas mancuernas',
      'Press inclinado mancuernas Smith',
      'Peck-Deck (Mariposa)',
      'Fondos paralelas lastre',
    ],
    'Press plano mancuernas': [
      'Press banca',
      'Press banca inclinado',
      'Press inclinado mancuernas',
      'Aperturas mancuernas',
    ],
    'Press inclinado mancuernas': [
      'Press banca',
      'Press plano mancuernas',
      'Press banca inclinado',
      'Aperturas mancuernas',
    ],
    'Peck-Deck (Mariposa)': [
      'Press banca',
      'Press plano mancuernas',
      'Aperturas mancuernas',
      'Press inclinado mancuernas',
    ],
    'default': [
      'Press banca',
      'Press plano mancuernas',
      'Press banca inclinado',
      'Press inclinado mancuernas',
      'Aperturas mancuernas',
      'Peck-Deck (Mariposa)',
    ]
  },
  'Tríceps': {
    'Tríceps Katana': [
      'Extensiones de tríceps cable',
      'Extensiones de tríceps mancuerna',
      'Fondos paralelas',
      'Fondos paralelas lastre',
      'Press cerrado',
      'Extensiones de tríceps en polea',
    ],
    'Extensiones de tríceps cable': [
      'Tríceps Katana',
      'Extensiones de tríceps mancuerna',
      'Fondos paralelas',
      'Fondos paralelas lastre',
      'Press cerrado',
    ],
    'Fondos paralelas': [
      'Tríceps Katana',
      'Extensiones de tríceps cable',
      'Extensiones de tríceps mancuerna',
      'Fondos paralelas lastre',
      'Press cerrado',
    ],
    'Fondos paralelas lastre': [
      'Tríceps Katana',
      'Extensiones de tríceps cable',
      'Extensiones de tríceps mancuerna',
      'Fondos paralelas',
      'Press cerrado',
    ],
    'default': [
      'Tríceps Katana',
      'Extensiones de tríceps cable',
      'Extensiones de tríceps mancuerna',
      'Fondos paralelas',
      'Fondos paralelas lastre',
    ]
  },
  'Hombros': {
    'Extensiones de hombros polea': [
      'Press militar',
      'Press Arnold',
      'Elevaciones laterales',
      'Elevaciones frontales',
      'Elevaciones posteriores',
    ],
    'Press militar': [
      'Extensiones de hombros polea',
      'Press Arnold',
      'Elevaciones laterales',
      'Elevaciones frontales',
    ],
    'default': [
      'Extensiones de hombros polea',
      'Press militar',
      'Press Arnold',
      'Elevaciones laterales',
      'Elevaciones frontales',
    ]
  },
  'Espalda': {
    'Jalón al pecho': [
      'Remo barra',
      'Remo mancuernas',

      'Dominadas',
      'Remo polea',
    ],
    'Dominadas': [
      'Jalón al pecho',
      'Remo barra',
      'Remo mancuernas',

    ],
    'Dominadas lastre': [
      'Jalón al pecho',
      'Remo barra',
      'Remo mancuernas',

    ],
    'default': [
      'Jalón al pecho',
      'Remo barra',
      'Remo mancuernas',

      'Dominadas',
    ]
  },
  'Piernas': {
    'Sentadillas': [
      'Prensa de piernas',
      'Extensiones de cuádriceps',
      'Sentadillas búlgaras',
      'Sentadillas búlgaras mancuernas',
      'Curl de femoral',
      'Peso muerto',
      'Zancadas',
    ],
    'Prensa de piernas': [
      'Sentadillas',
      'Extensiones de cuádriceps',
      'Sentadillas búlgaras',
      'Sentadillas búlgaras mancuernas',
      'Curl de femoral',
      'Peso muerto',
    ],
    'Sentadillas búlgaras': [
      'Sentadillas',
      'Prensa de piernas',
      'Extensiones de cuádriceps',
      'Sentadillas búlgaras mancuernas',
      'Zancadas',
    ],
    'Sentadillas búlgaras mancuernas': [
      'Sentadillas',
      'Prensa de piernas',
      'Extensiones de cuádriceps',
      'Sentadillas búlgaras',
      'Zancadas',
    ],
    'default': [
      'Sentadillas',
      'Prensa de piernas',
      'Extensiones de cuádriceps',
      'Sentadillas búlgaras',
      'Sentadillas búlgaras mancuernas',
      'Curl de femoral',
      'Peso muerto',
    ]
  }
};

const ChatbotDrawer: React.FC<Props> = ({ open, onClose, exercises, setExercises, onAddExercise, isDarkMode }) => {
  const insets = useSafeAreaInsets();
  const [loading, setLoading] = useState<number | null>(null);
  const slideAnimation = useRef(new Animated.Value(-300)).current;
  const theme = getTheme(isDarkMode || false);

  useEffect(() => {
    if (open) {
      // Animar entrada desde la izquierda
      Animated.timing(slideAnimation, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    } else {
      // Animar salida hacia la izquierda
      Animated.timing(slideAnimation, {
        toValue: -300,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }
  }, [open]);

  const replaceExerciseWithAI = (exerciseIndex: number) => {
    const exercise = exercises[exerciseIndex];
    setLoading(exerciseIndex);
    
    setTimeout(() => {
      try {
        console.log('Ejercicio a cambiar:', exercise.ejercicio);
        console.log('Músculo:', exercise.musculo);
        
        const muscleGroup = exerciseDatabase[exercise.musculo as keyof typeof exerciseDatabase];
        let alternatives: string[] = [];
        
        if (muscleGroup) {
          alternatives = muscleGroup[exercise.ejercicio as keyof typeof muscleGroup] || 
                       muscleGroup['default'] || [];
        }
        
        // Filtrar alternativas que ya están en la lista actual
        const currentExercises = exercises.map(ex => ex.ejercicio);
        const availableAlternatives = alternatives.filter(alt => 
          !currentExercises.includes(alt)
        );
        
        console.log('Alternativas encontradas:', alternatives);
        console.log('Alternativas disponibles (sin duplicados):', availableAlternatives);
        
        if (availableAlternatives.length > 0) {
          const randomIndex = Math.floor(Math.random() * availableAlternatives.length);
          const newExercise = availableAlternatives[randomIndex];
          
          const updatedExercise = {
            ...exercise,
            ejercicio: newExercise,
          };
          
          const updatedExercises = exercises.map((ex, index) =>
            index === exerciseIndex ? updatedExercise : ex
          );
          
          setExercises(updatedExercises);
        } else {
          console.log('No se encontraron alternativas disponibles para:', exercise.ejercicio);
          // Si no hay alternativas disponibles, mostrar un mensaje
          Alert.alert(
            'Sin alternativas',
            'No hay ejercicios alternativos disponibles que no estén ya en tu rutina actual.',
            [{ text: 'OK' }]
          );
        }
      } catch (error) {
        console.error('Error al buscar ejercicio alternativo:', error);
      } finally {
        setLoading(null);
      }
    }, 500);
  };

  return (
    <Modal
      visible={open}
      transparent={true}
      animationType="none"
      onRequestClose={onClose}
        >
      <View style={styles.overlay}>
        <TouchableOpacity style={styles.overlayTouchable} activeOpacity={1} onPress={onClose} />
        <Animated.View 
          style={[
            styles.drawer, 
            { 
              paddingTop: insets.top + 16,
              transform: [{ translateX: slideAnimation }]
            }
          ]}
        >
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
            <Text style={styles.chatText}>
              Hola! En este menú podés cambiar ejercicios actuales o agregar nuevos.
            </Text>
            
            <Text style={styles.sectionTitle}>Ejercicios actuales:</Text>
            {exercises.map((exercise, index) => (
              <View key={index} style={styles.exerciseItem}>
                <Text style={styles.exerciseName}>{exercise.ejercicio}</Text>
                <TouchableOpacity 
                  style={[styles.replaceBtn, loading === index && styles.replaceBtnDisabled]}
                  onPress={() => replaceExerciseWithAI(index)}
                  disabled={loading === index}
                >
                  <Text style={styles.replaceBtnText}>
                    {loading === index ? '...' : 'Cambiar'}
                  </Text>
                </TouchableOpacity>
              </View>
            ))}

            {onAddExercise && (
              <TouchableOpacity 
                style={[styles.addExerciseBtn, { backgroundColor: theme.buttonPrimary }]}
                onPress={onAddExercise}
              >
                <Text style={[styles.addExerciseBtnText, { color: theme.buttonText }]}>
                  + Agregar ejercicio
                </Text>
              </TouchableOpacity>
            )}
          </ScrollView>
        </Animated.View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
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
    backgroundColor: '#F8F6F2',
    borderRightWidth: 2,
    borderColor: '#4F766F',
    zIndex: 100,
    padding: 16,
  },
  closeBtn: {
    alignSelf: 'flex-end',
    marginBottom: 8,
  },
  closeText: {
    color: '#4F766F',
    fontWeight: '600',
    fontFamily: 'System',
  },
  closeButton: {
    padding: 8,
  },
  closeButtonText: {
    fontSize: 20,
    fontFamily: 'System',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#333333',
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
    color: '#4F766F',
    fontFamily: 'System',
  },
  chatBox: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#D4A574',
    padding: 8,
    marginTop: 8,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
  },
  chatText: {
    color: '#4F766F',
    marginBottom: 12,
    fontFamily: 'System',
  },
  sectionTitle: {
    fontWeight: '600',
    color: '#4F766F',
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
    borderBottomColor: '#D4A574',
  },
  exerciseName: {
    color: '#4F766F',
    flex: 1,
    fontFamily: 'System',
  },
  replaceBtn: {
    backgroundColor: '#4F766F',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    minWidth: 40,
    alignItems: 'center',
  },
  replaceBtnDisabled: {
    backgroundColor: '#6D7172',
  },
  replaceBtnText: {
    color: '#FFFFFF',
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
});

export default ChatbotDrawer; 