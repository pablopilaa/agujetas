class AgujetasLegalContract {
  const AgujetasLegalContract._();

  static const schemaVersion = 2;
  static const effectiveDateIso = '2026-06-01';
  static const effectiveDateLabel = '1 de junio de 2026';
  static const termsVersion = 'terms-2026-06-01-preview';
  static const privacyVersion = 'privacy-2026-06-01-preview';
  static const dataPolicyVersion = 'data-2026-06-01-preview';
  static const notificationsVersion = 'notifications-2026-06-01-preview';

  static const legalReviewNotice =
      'Texto técnico preliminar. Antes de producción debe revisarse con asesoría legal.';

  static const requirements = [
    ConsentRequirement(
      id: 'terms',
      version: termsVersion,
      title: 'Acepto términos y política de privacidad',
      subtitle:
          'Tus sesiones, rutinas, peso corporal y ejercicios propios pertenecen a tu cuenta.',
      details: [
        'Agujetas es una herramienta de registro y planificación de entrenamiento, no reemplaza criterio médico ni profesional.',
        'El usuario es responsable de revisar cargas, técnica, dolor, molestias y riesgos físicos antes de entrenar.',
        'Las funciones Pro, entrenador, rutinas compartidas y métricas pueden cambiar mientras la app esté en fase de test.',
      ],
    ),
    ConsentRequirement(
      id: 'firebaseSync',
      version: dataPolicyVersion,
      title: 'Entiendo la sincronización con Firebase',
      subtitle:
          'Si iniciás sesión con Google, Agujetas puede guardar datos propios en Firebase Auth y Firestore.',
      details: [
        'Se usa Firebase Auth para identificar la cuenta y Firestore para datos de entrenamiento cuando la sincronización esté activa.',
        'No se usa Firebase Storage en el plan gratuito; las imágenes de ejercicios se resuelven localmente o desde alternativas sin assets Lyfta.',
        'La app debe permitir exportar, importar y borrar datos del usuario antes de considerarse lista para producción.',
      ],
    ),
    ConsentRequirement(
      id: 'localMedia',
      version: privacyVersion,
      title: 'Entiendo el uso de imágenes locales',
      subtitle:
          'La galería sólo se solicita si querés asociar una imagen a un ejercicio personalizado.',
      details: [
        'Agujetas no debe incluir, renderizar ni derivar imágenes comerciales de Lyfta en builds comerciales.',
        'Las imágenes elegidas desde galería quedan bajo control del usuario y pueden requerir permisos del sistema.',
        'Si más adelante se habilita subida cloud, debe pedirse consentimiento específico antes de sincronizar archivos.',
      ],
    ),
    ConsentRequirement(
      id: 'notifications',
      version: notificationsVersion,
      title: 'Entiendo el uso de notificaciones',
      subtitle:
          'Los avisos de descanso o peso se piden cuando activás esas funciones, no al abrir la app.',
      details: [
        'Las alertas de descanso pueden sonar o mostrarse aunque la app esté en segundo plano si el sistema lo permite.',
        'Las alertas de seguimiento de peso son recordatorios configurables, no indicaciones médicas.',
        'El usuario debe poder desactivar notificaciones desde Perfil y desde los ajustes del sistema.',
      ],
    ),
  ];
}

class ConsentRequirement {
  const ConsentRequirement({
    required this.id,
    required this.version,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final String id;
  final String version;
  final String title;
  final String subtitle;
  final List<String> details;
}
