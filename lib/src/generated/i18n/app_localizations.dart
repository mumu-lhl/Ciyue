import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_nb.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sc.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'i18n/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fa'),
    Locale('nb'),
    Locale('ru'),
    Locale('sc'),
    Locale('ta'),
    Locale('zh'),
    Locale('zh', 'HK'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @addDictionary.
  ///
  /// In en, this message translates to:
  /// **'Please add a MDX dictionary in the Settings first'**
  String get addDictionary;

  /// No description provided for @startToSearch.
  ///
  /// In en, this message translates to:
  /// **'Start going on a word search :)'**
  String get startToSearch;

  /// No description provided for @manageDictionaries.
  ///
  /// In en, this message translates to:
  /// **'Manage Dictionaries'**
  String get manageDictionaries;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @wordBook.
  ///
  /// In en, this message translates to:
  /// **'Word Book'**
  String get wordBook;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You have to grant the permissions'**
  String get permissionDenied;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @lookup.
  ///
  /// In en, this message translates to:
  /// **'Lookup'**
  String get lookup;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @notSupport.
  ///
  /// In en, this message translates to:
  /// **'Not support this MDX file'**
  String get notSupport;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @readLoudly.
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get readLoudly;

  /// No description provided for @recommendedDictionaries.
  ///
  /// In en, this message translates to:
  /// **'Recommmended Dictionaries'**
  String get recommendedDictionaries;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @customFont.
  ///
  /// In en, this message translates to:
  /// **'Custom Font'**
  String get customFont;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty...'**
  String get empty;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @autoExport.
  ///
  /// In en, this message translates to:
  /// **'Auto Export'**
  String get autoExport;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get addTag;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagName;

  /// No description provided for @tagList.
  ///
  /// In en, this message translates to:
  /// **'Tag List'**
  String get tagList;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @noResult.
  ///
  /// In en, this message translates to:
  /// **'No Result'**
  String get noResult;

  /// No description provided for @updateAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'The Announcement of Updating to %s'**
  String get updateAnnouncement;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @properties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// No description provided for @removeOneHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove History'**
  String get removeOneHistory;

  /// No description provided for @removeOneHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \'%s\' from history?'**
  String get removeOneHistoryConfirm;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear history?'**
  String get clearHistoryConfirm;

  /// No description provided for @default_.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default_;

  /// No description provided for @manageGroups.
  ///
  /// In en, this message translates to:
  /// **'Manage Groups'**
  String get manageGroups;

  /// No description provided for @exportFileName.
  ///
  /// In en, this message translates to:
  /// **'Export File Name'**
  String get exportFileName;

  /// No description provided for @exportDirectory.
  ///
  /// In en, this message translates to:
  /// **'Export Directory'**
  String get exportDirectory;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @totalNumberOfEntries.
  ///
  /// In en, this message translates to:
  /// **'Total Number of Entries'**
  String get totalNumberOfEntries;

  /// No description provided for @sponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsor;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @autoRemoveSearchWord.
  ///
  /// In en, this message translates to:
  /// **'Auto Remove Search Word'**
  String get autoRemoveSearchWord;

  /// No description provided for @secureScreen.
  ///
  /// In en, this message translates to:
  /// **'Anti-Screenshot'**
  String get secureScreen;

  /// No description provided for @searchBarLocation.
  ///
  /// In en, this message translates to:
  /// **'Search Bar Location'**
  String get searchBarLocation;

  /// No description provided for @top.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get top;

  /// No description provided for @bottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get bottom;

  /// No description provided for @sidebarIcon.
  ///
  /// In en, this message translates to:
  /// **'Sidebar Icon'**
  String get sidebarIcon;

  /// No description provided for @exportPath.
  ///
  /// In en, this message translates to:
  /// **'Export Path'**
  String get exportPath;

  /// No description provided for @editWord.
  ///
  /// In en, this message translates to:
  /// **'Edit Word'**
  String get editWord;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @moreOptionsButton.
  ///
  /// In en, this message translates to:
  /// **'More Options Button'**
  String get moreOptionsButton;

  /// No description provided for @titleAlias.
  ///
  /// In en, this message translates to:
  /// **'Title Alias'**
  String get titleAlias;

  /// No description provided for @skipTaggedWord.
  ///
  /// In en, this message translates to:
  /// **'Skip Tagged Word'**
  String get skipTaggedWord;

  /// No description provided for @dictionaryGroups.
  ///
  /// In en, this message translates to:
  /// **'Dictionary Groups'**
  String get dictionaryGroups;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @aiSettings.
  ///
  /// In en, this message translates to:
  /// **'AI Settings'**
  String get aiSettings;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiProvider;

  /// No description provided for @aiModel.
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get aiModel;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @aiExplainWord.
  ///
  /// In en, this message translates to:
  /// **'AI Explain Word'**
  String get aiExplainWord;

  /// No description provided for @outputType.
  ///
  /// In en, this message translates to:
  /// **'Output Type'**
  String get outputType;

  /// No description provided for @richOutput.
  ///
  /// In en, this message translates to:
  /// **'Rich Output'**
  String get richOutput;

  /// No description provided for @simpleOutput.
  ///
  /// In en, this message translates to:
  /// **'Simple Output'**
  String get simpleOutput;

  /// No description provided for @enterTextToTranslate.
  ///
  /// In en, this message translates to:
  /// **'Enter text to translate'**
  String get enterTextToTranslate;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @sourceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Source Language'**
  String get sourceLanguage;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get targetLanguage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'fa', 'nb', 'ru', 'sc', 'ta', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'HK': return AppLocalizationsZhHk();
case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
    case 'fa': return AppLocalizationsFa();
    case 'nb': return AppLocalizationsNb();
    case 'ru': return AppLocalizationsRu();
    case 'sc': return AppLocalizationsSc();
    case 'ta': return AppLocalizationsTa();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
