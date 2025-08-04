export interface Theme {
  // Colores principales
  primary: string;
  secondary: string;
  accent: string;
  
  // Colores de fondo
  background: string;
  surface: string;
  
  // Colores de texto
  textPrimary: string;
  textSecondary: string;
  
  // Colores de bordes
  border: string;
  
  // Colores de estado
  success: string;
  warning: string;
  error: string;
  
  // Colores de componentes específicos
  exerciseBox: string;
  exerciseBoxComplete: string;
  timerBox: string;
  buttonPrimary: string;
  buttonSecondary: string;
  buttonText: string;
}

export const lightTheme: Theme = {
  // Colores principales
  primary: '#4F766F',
  secondary: '#D4A574',
  accent: '#F4CAAB',
  
  // Colores de fondo
  background: '#F8F6F2',
  surface: '#FFFFFF',
  
  // Colores de texto
  textPrimary: '#4F766F',
  textSecondary: '#6D7172',
  
  // Colores de bordes
  border: '#D4A574',
  
  // Colores de estado
  success: '#4F766F',
  warning: '#E2928D',
  error: '#E2928D',
  
  // Colores de componentes específicos
  exerciseBox: 'rgba(244, 202, 171, 0.08)',
  exerciseBoxComplete: 'rgba(79, 118, 111, 0.08)',
  timerBox: 'rgba(244, 202, 171, 0.08)',
  buttonPrimary: '#4F766F',
  buttonSecondary: '#E2928D',
  buttonText: '#FFFFFF',
};

export const darkTheme: Theme = {
  // Colores principales
  primary: '#FFFFFF',
  secondary: '#CCCCCC',
  accent: '#999999',
  
  // Colores de fondo
  background: '#000000',
  surface: '#1A1A1A',
  
  // Colores de texto
  textPrimary: '#FFFFFF',
  textSecondary: '#CCCCCC',
  
  // Colores de bordes
  border: '#333333',
  
  // Colores de estado
  success: '#FFFFFF',
  warning: '#CCCCCC',
  error: '#CCCCCC',
  
  // Colores de componentes específicos
  exerciseBox: 'rgba(255, 255, 255, 0.05)',
  exerciseBoxComplete: 'rgba(255, 255, 255, 0.1)',
  timerBox: 'rgba(255, 255, 255, 0.05)',
  buttonPrimary: '#4F766F', // Mantener verde
  buttonSecondary: '#333333', // Cambiar a gris oscuro para contraste con texto blanco
  buttonText: '#FFFFFF', // Cambiar a blanco para botones verdes
};

export const getTheme = (isDarkMode: boolean): Theme => {
  return isDarkMode ? darkTheme : lightTheme;
}; 