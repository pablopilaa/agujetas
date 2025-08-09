// Centralized design tokens for spacing, sizes and shared header behaviors
export const ds = {
  spacing: 8, // base unit
  radii: {
    button: 8,
    icon: 6,
    card: 8,
  },
  sizes: {
    buttonHeight: 36,
    iconButton: 28,
    headerActionMinWidth: 120, // ensures actions area doesn't shift
  },
  header: {
    paddingHorizontal: 8,
    paddingTop: 8,
    paddingBottom: 5,
    height: 44,
    borderTopColor: '#D4A574',
    separatorMarginTop: 7,
  },
};

export type DesignSystem = typeof ds;


