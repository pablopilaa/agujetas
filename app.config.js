export default ({ config }) => {
  const appVariant = process.env.APP_VARIANT || 'production';
  const easProjectSlug = 'agujetas-v102';
  const variants = {
    development: {
      name: 'Agujetas Dev',
      scheme: 'agujetasdev',
      androidPackage: 'com.pablopilaa.agujetasdev',
      icon: './assets/icon-dev.png',
      adaptiveIcon: './assets/icon-dev.png',
    },
    preview: {
      name: 'Agujetas Preview',
      scheme: 'agujetaspreview',
      androidPackage: 'com.pablopilaa.agujetaspreview',
      icon: './assets/icon-qa.png',
      adaptiveIcon: './assets/icon-qa.png',
    },
    production: {
      name: 'Agujetas',
      scheme: 'agujetas',
      androidPackage: 'com.pablopilaa.Agujetas',
      icon: './assets/icon-prod.png',
      adaptiveIcon: './assets/icon-prod.png',
    },
  };
  const selected = variants[appVariant] || variants.production;

  return {
    ...config,

    name: selected.name,
    slug: easProjectSlug,
    version: '1.0.3',
    scheme: selected.scheme,
    icon: selected.icon,

    android: {
      ...(config.android || {}),
      package: selected.androidPackage,
      adaptiveIcon: {
        ...((config.android || {}).adaptiveIcon || {}),
        foregroundImage: selected.adaptiveIcon,
      },
    },
  };
};
