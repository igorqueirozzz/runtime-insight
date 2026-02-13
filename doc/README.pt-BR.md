# runtime_insight

[![pub package](https://img.shields.io/pub/v/runtime_insight.svg)](https://pub.dev/packages/runtime_insight)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)

[Read in English](../README.md)

Plugin Flutter que classifica dispositivos em tiers (low/mid/high) com base nas
características de hardware em tempo de execução e fornece monitoramento contínuo
de recursos do app.

## Funcionalidades

- Coleta núcleos de CPU, RAM total, versão do SO, flag de emulador
- Usa a classe de desempenho do Android quando disponível (Android 12+)
- Fornece helpers para verificação de tier e paralelismo recomendado
- Monitoramento contínuo via stream (CPU, RAM, FPS, rede, disco)
- Widget overlay para visualização em tempo real

## Plataformas suportadas

- Android: suporte completo
- iOS: suporte básico (núcleos de CPU, RAM, versão do SO, flag de emulador)

## Instalação

Adicione a dependência ao seu `pubspec.yaml`:

```yaml
dependencies:
  runtime_insight: ^1.0.0
```

## Requisitos

- Flutter 3.3+
- Android API 24+
- iOS 12+

## Uso

```dart
import 'package:runtime_insight/runtime_insight.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RuntimeInsight.init(
    monitoredMetrics: const [
      AppMetric.cpu,
      AppMetric.memory,
      AppMetric.fps,
    ],
  );

  final tier = RuntimeInsight.deviceTier;
  final parallel = RuntimeInsight.maxParallelRecommended;

  if (RuntimeInsight.isLowEnd) {
    // ajustar tarefas pesadas
  }
}
```

### Paralelismo recomendado

```dart
final parallel = RuntimeInsight.maxParallelRecommended;
print('CPU: ${parallel.cpu}');
print('IO: ${parallel.io}');
print('Rede: ${parallel.network}');
```

### Overlay (widget)

```dart
Stack(
  children: [
    const MyApp(),
    Align(
      alignment: Alignment.topRight,
      child: RuntimeInsightOverlay(
        persistenceKey: 'runtime_insight_overlay',
        // Você pode passar strings localizadas aqui
        // strings: RuntimeInsightOverlayStrings(...)
      ),
    ),
  ],
)
```

### Controller (acesso estático)

Controle o overlay de qualquer lugar do app — sem precisar de referência ao widget:

```dart
// Esconder / mostrar
RuntimeInsightOverlayController.instance.hide();
RuntimeInsightOverlayController.instance.show();

// Minimizar / expandir
RuntimeInsightOverlayController.instance.minimize();
RuntimeInsightOverlayController.instance.expand();

// Pausar / resumir fluxo de dados
RuntimeInsightOverlayController.instance.pause();
RuntimeInsightOverlayController.instance.resume();

// Alterar opacidade
RuntimeInsightOverlayController.instance.opacity = 0.6;
```

Você também pode passar um controller dedicado a um overlay específico:

```dart
final meuController = RuntimeInsightOverlayController(minimized: true);

RuntimeInsightOverlay(
  controller: meuController,
  persistenceKey: 'meu_overlay',
)
```

### Migração do 0.x

- `maxParallelJobs` está depreciado → use `maxParallelRecommended`.
- O monitoramento agora suporta listas dinâmicas de métricas e pause/resume.

## Monitoramento (stream)

```dart
final stream = RuntimeInsight.startMonitoring(
  config: const AppResourceMonitoringConfig(
    interval: Duration(seconds: 1),
    movingAverageWindow: 5,
  ),
);

stream.listen((snapshot) {
  print('CPU: ${snapshot.cpuPercent}%');
  print('CPU média: ${snapshot.cpuPercentAvg}%');
  print('RX / s: ${snapshot.networkRxBytesPerSec}');
});

// Controle avançado
await RuntimeInsight.updateMonitoringConfig(
  const AppResourceMonitoringConfig(
    cpu: true,
    memory: true,
    fps: false,
    network: true,
    disk: false,
    interval: Duration(milliseconds: 500),
  ),
);

await RuntimeInsight.pauseMonitoring();
await RuntimeInsight.resumeMonitoring();

// Helpers
await RuntimeInsight.enableMetric(AppMetric.cpu);
await RuntimeInsight.disableMetric(AppMetric.disk);
await RuntimeInsight.setInterval(const Duration(milliseconds: 500));
await RuntimeInsight.setMovingAverageWindow(10);

// Atualizações dinâmicas de métricas
await RuntimeInsight.addMetrics([AppMetric.network]);
await RuntimeInsight.removeMetrics([AppMetric.fps]);
await RuntimeInsight.setMonitoredMetrics([AppMetric.cpu, AppMetric.memory]);
```

## Regras de classificação (Android)

- RAM baixa (<= 3GB) sempre retorna `DeviceTier.low`
- Emulador sempre retorna `DeviceTier.low`
- Caso contrário, um score é calculado a partir de:
  - Núcleos de CPU
  - Tamanho da RAM
  - Classe de desempenho do dispositivo (apenas Android 12+)

Limiares:

- `< 80` → low
- `< 140` → mid
- `>= 140` → high

## Regras de classificação (iOS)

- RAM baixa (<= 3GB) sempre retorna `DeviceTier.low`
- Emulador sempre retorna `DeviceTier.low`
- O score usa peso maior para CPU e menor para RAM

## Observações

- `performanceClass` só está disponível no Android 12+ (API 31)
- iOS não fornece `performanceClass`
- O uso de CPU é por app e normalizado de 0 a 100
- No iOS, bytes de rede são do dispositivo inteiro; bytes de disco são por processo
- iOS fornece apenas bytes/s para rede/disco; contadores absolutos são omitidos

## Apoie

Se este plugin te ajudou, considere apoiar o projeto:

**PayPal:**

[![Doar](https://img.shields.io/badge/Doar-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=T98W8VTCJQVA8)

**PIX:**

Chave: `620b6ef6-574f-447b-aec7-6fac5f3a6be5`

<img src="pix_qrcode.jpg" alt="QR Code PIX" width="200"/>
