import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

interface Props {
  onOpen: () => void;
}

const DrawerTrigger: React.FC<Props> = ({ onOpen }) => {
  const insets = useSafeAreaInsets();
  return (
    <View
      style={[
        styles.drawerTrigger,
        { top: insets.top + 217 } // Aumentar a 217px para evitar solaparse con "Cronómetro"
      ]}
      onTouchStart={onOpen}
    >
      <View style={styles.drawerTab}>
        <View style={styles.drawerTabInner} />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  drawerTrigger: {
    position: 'absolute',
    left: 0,
    width: 24,
    height: 80,
    zIndex: 10,
    justifyContent: 'center',
    alignItems: 'flex-start',
  },
  drawerTab: {
    width: 16,
    height: 60,
    backgroundColor: '#4F766F', // CUTTY SARK - verde de la paleta
    borderTopRightRadius: 12,
    borderBottomRightRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 2, height: 0 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
    elevation: 3,
  },
  drawerTabInner: {
    width: 6,
    height: 30,
    backgroundColor: '#fff',
    borderRadius: 3,
    marginLeft: 4,
  },
});

export default DrawerTrigger; 