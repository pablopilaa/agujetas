import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Modal, Alert, Image } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { saveSession } from '../utils/storage';
import SideMenu from './SideMenu';
import { getTheme } from '../utils/theme';

interface Exercise {
  ejercicio: string;
  musculo: string;
  series: Array<{ reps: string; kg: string; rir: number | undefined }>;
}

interface Props {
  exercises: Exercise[];
  setExercises: React.Dispatch<React.SetStateAction<Exercise[]>>;
  onAddExercise?: () => void;
  getIncompleteFieldsCount?: () => number;
  isDarkMode?: boolean;
  onToggleDarkMode?: () => void;
  sessionDuration?: number; // Duración de la sesión en segundos
  onSessionFinish?: () => void; // Callback para resetear timers
}

type SessionType = 'Push' | 'Pull' | 'Piernas' | 'Sesión mixta' | 'Sesión libre';

// Ejercicios predefinidos por tipo de sesión
const sessionExercises: Record<SessionType, Exercise[]> = {
  'Push': [
    { ejercicio: 'Press banca', musculo: 'Pectoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Extensiones de hombros polea', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Tríceps Katana', musculo: 'Tríceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Press inclinado mancuernas', musculo: 'Pectoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Elevaciones laterales', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Triceps sentado', musculo: 'Tríceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Pull': [
    { ejercicio: 'Jalón al pecho', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl bíceps martillo', musculo: 'Bíceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Dominadas lastre', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl bíceps mancuerna', musculo: 'Bíceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Remo mancuernas', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Piernas': [
    { ejercicio: 'Extensiones de piernas', musculo: 'Cuádriceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl femoral acostado', musculo: 'Femoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Prensa de piernas', musculo: 'Cuádriceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Aducción máquina', musculo: 'Aductores', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Abducción máquina', musculo: 'Abductores', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Elevación de gemelos de pie', musculo: 'Gemelos', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Sesión mixta': [
    { ejercicio: 'Press plano mancuernas', musculo: 'Pectoral', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Remo mancuernas', musculo: 'Espalda', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Extensiones de hombros polea', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Curl bíceps martillo', musculo: 'Bíceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Extensiones de tríceps mancuerna', musculo: 'Tríceps', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
    { ejercicio: 'Deltoides posterior', musculo: 'Hombros', series: [{ reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }, { reps: '', kg: '', rir: undefined }] },
  ],
  'Sesión libre': [], // Sesión libre inicia vacía
};

const SessionSelector: React.FC<Props> = ({ exercises, setExercises, onAddExercise, getIncompleteFieldsCount, isDarkMode, onToggleDarkMode, sessionDuration, onSessionFinish }) => {
  const insets = useSafeAreaInsets();
  const [selectedSession, setSelectedSession] = useState<SessionType | null>(null);
  const [showSessionModal, setShowSessionModal] = useState(false);
  const [showSideMenu, setShowSideMenu] = useState(false);
  const theme = getTheme(isDarkMode || false);

  const handleSessionSelect = (sessionType: SessionType) => {
    // Verificar si hay ejercicios en la sesión actual
    if (exercises.length > 0) {
      Alert.alert(
        'Confirmar cambio de sesión',
        '¿Estás seguro? Esto sobrescribirá los ejercicios actuales.',
        [
          {
            text: 'No',
            style: 'cancel',
          },
          {
            text: 'Sí',
            onPress: () => {
              setSelectedSession(sessionType);
              setExercises(sessionExercises[sessionType]);
              setShowSessionModal(false);
            },
          },
        ]
      );
    } else {
      // Si no hay ejercicios, cambiar directamente
      setSelectedSession(sessionType);
      setExercises(sessionExercises[sessionType]);
      setShowSessionModal(false);
    }
  };

  const handleFinishSession = async () => {
    const incompleteFields = getIncompleteFieldsCount ? getIncompleteFieldsCount() : 0;
    let message = exercises.length > 0 
      ? `¿Estás seguro de que quieres finalizar el entreno de ${selectedSession || 'Sesión libre'} con ${exercises.length} ejercicios?`
      : `¿Estás seguro de que quieres finalizar el entreno de ${selectedSession || 'Sesión libre'} (sin ejercicios)?`;
    
    if (incompleteFields > 0) {
      message += `\n\nTienes ${incompleteFields} campos incompletos.`;
    }

    Alert.alert(
      'Confirmar finalización del entreno',
      message,
      [
        {
          text: 'Cancelar',
          style: 'cancel',
        },
        {
          text: 'Finalizar',
          onPress: async () => {
            try {
              const sessionData = {
                tipo: selectedSession || 'Sesión libre',
                fecha: new Date().toLocaleDateString('en-CA'), // Formato YYYY-MM-DD en zona horaria local
                ejercicios: exercises.map(exercise => ({
                  ...exercise,
                  fecha: new Date().toLocaleDateString('en-CA'), // Formato YYYY-MM-DD en zona horaria local
                })),
                duracion: sessionDuration || 0, // Incluir duración de la sesión
              };

              await saveSession(sessionData);
              
              // Resetear timers después de guardar
              if (onSessionFinish) {
                onSessionFinish();
              }
              
              const successMessage = exercises.length > 0 
                ? `¡Excelente trabajo! 🎉\n\nHas completado exitosamente tu entrenamiento de ${selectedSession || 'Sesión libre'} con ${exercises.length} ejercicios.\n\n¡Sigue así, cada sesión te acerca más a tus objetivos! 💪`
                : `¡Bien hecho! 🎉\n\nHas completado tu entrenamiento de ${selectedSession || 'Sesión libre'}.\n\n¡Mantén la consistencia y verás resultados! 💪`;
              
              Alert.alert(
                '¡Entreno Completado! 🏆',
                successMessage,
                [
                  {
                    text: 'OK',
                    onPress: () => {
                      // Limpiar la sesión actual
                      setExercises([]);
                      setSelectedSession(null);
                    },
                  },
                ]
              );
            } catch (error) {
              console.error('Error guardando sesión:', error);
              Alert.alert('Error', 'No se pudo guardar la sesión. Inténtalo de nuevo.');
            }
          },
        },
      ]
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background, borderColor: theme.border }]}>
      <View style={styles.sessionRow}>
                  <TouchableOpacity onPress={() => setShowSideMenu(true)}>
            <Image
              source={isDarkMode ? require('../assets/logo-dark-transparent.png') : require('../assets/logo-transparent.png')}
              style={styles.logo}
              resizeMode="contain"
            />
          </TouchableOpacity>
        <TouchableOpacity 
          style={[styles.sessionButton, { backgroundColor: theme.buttonPrimary }]} 
          onPress={() => setShowSessionModal(true)}
        >
          <Text style={[styles.sessionButtonText, { color: theme.buttonText }]}>
            {selectedSession ? `Sesión: ${selectedSession}` : 'Seleccionar tipo de sesión'}
          </Text>
        </TouchableOpacity>
        
        {selectedSession && (
          <TouchableOpacity 
            style={[styles.finishButton, { backgroundColor: theme.buttonSecondary }]}
            onPress={handleFinishSession}
          >
            <Text style={[styles.finishButtonText, { color: theme.buttonText }]}>Finalizar entreno</Text>
          </TouchableOpacity>
        )}
      </View>



      {/* Modal para seleccionar tipo de sesión */}
      <Modal
        visible={showSessionModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowSessionModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface, paddingTop: insets.top + 20 }]}>
            <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Seleccionar tipo de sesión</Text>
            <ScrollView style={styles.sessionList}>
              {Object.keys(sessionExercises).map((sessionType) => (
                <TouchableOpacity
                  key={sessionType}
                  style={[styles.sessionOption, { borderBottomColor: theme.border }]}
                  onPress={() => handleSessionSelect(sessionType as SessionType)}
                >
                  <Text style={[styles.sessionOptionText, { color: theme.textPrimary }]}>{sessionType}</Text>
                  <Text style={[styles.sessionOptionSubtext, { color: theme.textSecondary }]}>
                    {sessionExercises[sessionType as SessionType].length} ejercicios
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
            <TouchableOpacity 
              style={[styles.cancelButton, { backgroundColor: theme.buttonSecondary }]}
              onPress={() => setShowSessionModal(false)}
            >
              <Text style={[styles.cancelButtonText, { color: theme.buttonText }]}>Cancelar</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Menú lateral */}
      <SideMenu 
        visible={showSideMenu}
        onClose={() => setShowSideMenu(false)}
        isDarkMode={isDarkMode || false}
        onToggleDarkMode={onToggleDarkMode || (() => {})}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 1,
    padding: 4,
  },
  sessionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  logo: {
    width: 40,
    height: 40,
    marginRight: 8,
  },
  sessionButton: {
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
    flex: 1,
    marginRight: 8,
  },
  sessionButtonText: {
    fontWeight: '600',
    fontSize: 16,
    fontFamily: 'System',
  },
  finishButton: {
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
  },
  finishButtonText: {
    fontWeight: '600',
    fontSize: 14,
    fontFamily: 'System',
  },

  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    borderRadius: 12,
    padding: 20,
    width: '80%',
    maxHeight: '70%',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 16,
    fontFamily: 'System',
  },
  sessionList: {
    maxHeight: 300,
  },
  sessionOption: {
    padding: 16,
    borderBottomWidth: 1,
  },
  sessionOptionText: {
    fontSize: 16,
    fontWeight: '600',
    fontFamily: 'System',
  },
  sessionOptionSubtext: {
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
});

export default SessionSelector; 