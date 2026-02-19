import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime Insight Example'**
  String get appTitle;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @cpuLabel.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get cpuLabel;

  /// No description provided for @ioLabel.
  ///
  /// In en, this message translates to:
  /// **'IO'**
  String get ioLabel;

  /// No description provided for @networkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkLabel;

  /// No description provided for @specs.
  ///
  /// In en, this message translates to:
  /// **'Specs'**
  String get specs;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @cpuCores.
  ///
  /// In en, this message translates to:
  /// **'CPU cores'**
  String get cpuCores;

  /// No description provided for @ramMb.
  ///
  /// In en, this message translates to:
  /// **'RAM (MB)'**
  String get ramMb;

  /// No description provided for @osVersion.
  ///
  /// In en, this message translates to:
  /// **'OS version'**
  String get osVersion;

  /// No description provided for @performanceClass.
  ///
  /// In en, this message translates to:
  /// **'Performance class'**
  String get performanceClass;

  /// No description provided for @emulator.
  ///
  /// In en, this message translates to:
  /// **'Emulator'**
  String get emulator;

  /// No description provided for @helpers.
  ///
  /// In en, this message translates to:
  /// **'Helpers'**
  String get helpers;

  /// No description provided for @monitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get monitoring;

  /// No description provided for @cpuPercent.
  ///
  /// In en, this message translates to:
  /// **'CPU (%)'**
  String get cpuPercent;

  /// No description provided for @cpuAvg.
  ///
  /// In en, this message translates to:
  /// **'CPU avg (%)'**
  String get cpuAvg;

  /// No description provided for @ramAvg.
  ///
  /// In en, this message translates to:
  /// **'RAM avg (MB)'**
  String get ramAvg;

  /// No description provided for @fpsAvg.
  ///
  /// In en, this message translates to:
  /// **'FPS avg'**
  String get fpsAvg;

  /// No description provided for @networkRx.
  ///
  /// In en, this message translates to:
  /// **'Network RX'**
  String get networkRx;

  /// No description provided for @networkRxRate.
  ///
  /// In en, this message translates to:
  /// **'Network RX / s'**
  String get networkRxRate;

  /// No description provided for @networkTx.
  ///
  /// In en, this message translates to:
  /// **'Network TX'**
  String get networkTx;

  /// No description provided for @networkTxRate.
  ///
  /// In en, this message translates to:
  /// **'Network TX / s'**
  String get networkTxRate;

  /// No description provided for @diskRead.
  ///
  /// In en, this message translates to:
  /// **'Disk read'**
  String get diskRead;

  /// No description provided for @diskReadRate.
  ///
  /// In en, this message translates to:
  /// **'Disk read / s'**
  String get diskReadRate;

  /// No description provided for @diskWrite.
  ///
  /// In en, this message translates to:
  /// **'Disk write'**
  String get diskWrite;

  /// No description provided for @diskWriteRate.
  ///
  /// In en, this message translates to:
  /// **'Disk write / s'**
  String get diskWriteRate;

  /// No description provided for @cpuStressTitle.
  ///
  /// In en, this message translates to:
  /// **'CPU stress test'**
  String get cpuStressTitle;

  /// No description provided for @cpuStressRunning.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get cpuStressRunning;

  /// No description provided for @cpuStressHint.
  ///
  /// In en, this message translates to:
  /// **'Press to stress for 5s'**
  String get cpuStressHint;

  /// No description provided for @cpuStressButton.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get cpuStressButton;

  /// No description provided for @overlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime Insight'**
  String get overlayTitle;

  /// No description provided for @tabCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get tabCpu;

  /// No description provided for @tabRam.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get tabRam;

  /// No description provided for @tabDisk.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get tabDisk;

  /// No description provided for @tabNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get tabNetwork;

  /// No description provided for @labelCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get labelCurrent;

  /// No description provided for @labelAverage.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get labelAverage;

  /// No description provided for @labelMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get labelMin;

  /// No description provided for @labelMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get labelMax;

  /// No description provided for @labelSecondary.
  ///
  /// In en, this message translates to:
  /// **'Alt'**
  String get labelSecondary;

  /// No description provided for @legendRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get legendRead;

  /// No description provided for @legendWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get legendWrite;

  /// No description provided for @legendRx.
  ///
  /// In en, this message translates to:
  /// **'RX'**
  String get legendRx;

  /// No description provided for @legendTx.
  ///
  /// In en, this message translates to:
  /// **'TX'**
  String get legendTx;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @tabHttp.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get tabHttp;

  /// No description provided for @httpTitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP Requests'**
  String get httpTitle;

  /// No description provided for @httpActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get httpActive;

  /// No description provided for @httpTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get httpTotal;

  /// No description provided for @httpAvgTime.
  ///
  /// In en, this message translates to:
  /// **'Avg Time'**
  String get httpAvgTime;

  /// No description provided for @httpErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get httpErrors;

  /// No description provided for @httpPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get httpPending;

  /// No description provided for @httpCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get httpCompleted;

  /// No description provided for @httpFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get httpFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
