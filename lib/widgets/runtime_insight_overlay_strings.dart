/// Localisable strings used by [RuntimeInsightOverlay].
///
/// Use the [RuntimeInsightOverlayStrings.english] factory for sensible defaults,
/// or create a custom instance for other languages.
class RuntimeInsightOverlayStrings {
  final String title;
  final String tabCpu;
  final String tabRam;
  final String tabDisk;
  final String tabNetwork;
  final String cpuTitle;
  final String ramTitle;
  final String diskTitle;
  final String networkTitle;
  final String labelCurrent;
  final String labelAverage;
  final String labelMin;
  final String labelMax;
  final String labelSecondary;
  final String legendRead;
  final String legendWrite;
  final String legendRx;
  final String legendTx;
  final String pause;
  final String resume;
  final String close;
  final String minimize;
  final String expand;
  final String tabHttp;
  final String httpTitle;
  final String httpActive;
  final String httpTotal;
  final String httpAvgTime;
  final String httpErrors;
  final String httpPending;
  final String httpCompleted;
  final String httpFailed;

  const RuntimeInsightOverlayStrings({
    required this.title,
    required this.tabCpu,
    required this.tabRam,
    required this.tabDisk,
    required this.tabNetwork,
    required this.cpuTitle,
    required this.ramTitle,
    required this.diskTitle,
    required this.networkTitle,
    required this.labelCurrent,
    required this.labelAverage,
    required this.labelMin,
    required this.labelMax,
    required this.labelSecondary,
    required this.legendRead,
    required this.legendWrite,
    required this.legendRx,
    required this.legendTx,
    required this.pause,
    required this.resume,
    required this.close,
    required this.minimize,
    required this.expand,
    required this.tabHttp,
    required this.httpTitle,
    required this.httpActive,
    required this.httpTotal,
    required this.httpAvgTime,
    required this.httpErrors,
    required this.httpPending,
    required this.httpCompleted,
    required this.httpFailed,
  });

  factory RuntimeInsightOverlayStrings.english() {
    return const RuntimeInsightOverlayStrings(
      title: 'Runtime Insight',
      tabCpu: 'CPU',
      tabRam: 'RAM',
      tabDisk: 'Disk',
      tabNetwork: 'Network',
      cpuTitle: 'CPU (%)',
      ramTitle: 'RAM (MB)',
      diskTitle: 'Disk (bytes/s)',
      networkTitle: 'Network (bytes/s)',
      labelCurrent: 'Current',
      labelAverage: 'Avg',
      labelMin: 'Min',
      labelMax: 'Max',
      labelSecondary: 'Alt',
      legendRead: 'Read',
      legendWrite: 'Write',
      legendRx: 'RX',
      legendTx: 'TX',
      pause: 'Pause',
      resume: 'Resume',
      close: 'Close',
      minimize: 'Minimize',
      expand: 'Expand',
      tabHttp: 'HTTP',
      httpTitle: 'HTTP Requests',
      httpActive: 'Active',
      httpTotal: 'Total',
      httpAvgTime: 'Avg Time',
      httpErrors: 'Errors',
      httpPending: 'Pending',
      httpCompleted: 'Done',
      httpFailed: 'Failed',
    );
  }

  /// Português do Brasil.
  factory RuntimeInsightOverlayStrings.portugueseBr() {
    return const RuntimeInsightOverlayStrings(
      title: 'Runtime Insight',
      tabCpu: 'CPU',
      tabRam: 'RAM',
      tabDisk: 'Disco',
      tabNetwork: 'Rede',
      cpuTitle: 'CPU (%)',
      ramTitle: 'RAM (MB)',
      diskTitle: 'Disco (bytes/s)',
      networkTitle: 'Rede (bytes/s)',
      labelCurrent: 'Atual',
      labelAverage: 'Média',
      labelMin: 'Mín',
      labelMax: 'Máx',
      labelSecondary: 'Alt',
      legendRead: 'Leitura',
      legendWrite: 'Escrita',
      legendRx: 'RX',
      legendTx: 'TX',
      pause: 'Pausar',
      resume: 'Retomar',
      close: 'Fechar',
      minimize: 'Minimizar',
      expand: 'Expandir',
      tabHttp: 'HTTP',
      httpTitle: 'Requisições HTTP',
      httpActive: 'Ativas',
      httpTotal: 'Total',
      httpAvgTime: 'Tempo Médio',
      httpErrors: 'Erros',
      httpPending: 'Pendente',
      httpCompleted: 'Concluída',
      httpFailed: 'Falhou',
    );
  }

  /// Español.
  factory RuntimeInsightOverlayStrings.spanish() {
    return const RuntimeInsightOverlayStrings(
      title: 'Runtime Insight',
      tabCpu: 'CPU',
      tabRam: 'RAM',
      tabDisk: 'Disco',
      tabNetwork: 'Red',
      cpuTitle: 'CPU (%)',
      ramTitle: 'RAM (MB)',
      diskTitle: 'Disco (bytes/s)',
      networkTitle: 'Red (bytes/s)',
      labelCurrent: 'Actual',
      labelAverage: 'Prom',
      labelMin: 'Mín',
      labelMax: 'Máx',
      labelSecondary: 'Alt',
      legendRead: 'Lectura',
      legendWrite: 'Escritura',
      legendRx: 'RX',
      legendTx: 'TX',
      pause: 'Pausar',
      resume: 'Reanudar',
      close: 'Cerrar',
      minimize: 'Minimizar',
      expand: 'Expandir',
      tabHttp: 'HTTP',
      httpTitle: 'Solicitudes HTTP',
      httpActive: 'Activas',
      httpTotal: 'Total',
      httpAvgTime: 'Tiempo Prom',
      httpErrors: 'Errores',
      httpPending: 'Pendiente',
      httpCompleted: 'Completada',
      httpFailed: 'Fallida',
    );
  }
}
