import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Image, Dimensions } from 'react-native';
import { getTheme } from '../utils/theme';

interface Props {
  isDarkMode?: boolean;
  onFinish: () => void;
}

const { width, height } = Dimensions.get('window');

const WelcomeScreen: React.FC<Props> = ({ isDarkMode = false, onFinish }) => {
  const theme = getTheme(isDarkMode);
  const [showContent, setShowContent] = useState(false);

  useEffect(() => {
    // Mostrar contenido después de un breve delay
    const timer = setTimeout(() => {
      setShowContent(true);
    }, 500);

    // Ocultar pantalla después de 2 segundos
    const hideTimer = setTimeout(() => {
      onFinish();
    }, 2000);

    return () => {
      clearTimeout(timer);
      clearTimeout(hideTimer);
    };
  }, [onFinish]);

  if (!showContent) {
    return (
      <View style={[styles.container, { backgroundColor: theme.background }]} />
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={styles.content}>
        <Image
          source={isDarkMode ? require('../assets/logo-dark-transparent.png') : require('../assets/logo-transparent.png')}
          style={styles.logo}
          resizeMode="contain"
        />
        <Text style={[styles.signature, { color: theme.textPrimary }]}>
          Desarrollada por Pablo Pilanski
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  logo: {
    width: width * 0.4,
    height: width * 0.4,
    marginBottom: 20,
  },
  signature: {
    fontSize: 16,
    fontWeight: '400',
    fontFamily: 'System',
    textAlign: 'center',
  },
});

export default WelcomeScreen; 