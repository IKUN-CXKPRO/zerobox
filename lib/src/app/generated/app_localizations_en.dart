// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OronBox';

  @override
  String get homeTab => 'Home';

  @override
  String get exploreTab => 'Explore';

  @override
  String get devicesTab => 'Devices';

  @override
  String get pluginsTab => 'Plugins';

  @override
  String get pluginImport => 'Import plugin';

  @override
  String get pluginInstalled => 'Installed';

  @override
  String get pluginMarket => 'Plugin market';

  @override
  String get pluginMarketUnavailable =>
      'The plugin market is not available yet';

  @override
  String get pluginEmpty => 'No plugins installed';

  @override
  String get pluginSelectHint => 'Select a plugin to view its features';

  @override
  String get pluginFeatures => 'Features';

  @override
  String get pluginDetails => 'Details';

  @override
  String get pluginNoFeatures => 'This plugin has no available features';

  @override
  String get pluginAuthor => 'Author';

  @override
  String get pluginVersion => 'Version';

  @override
  String get pluginApiLevel => 'API level';

  @override
  String get pluginWebsite => 'Website';

  @override
  String get pluginPermissions => 'Permissions';

  @override
  String get pluginInstallConfirmTitle => 'Confirm plugin installation';

  @override
  String get pluginUpdateConfirmTitle => 'Confirm plugin update';

  @override
  String get pluginDeclaredPermissions =>
      'This plugin declares the following permissions:';

  @override
  String get pluginNoPermissions => 'No permissions declared';

  @override
  String get pluginUpToDate => 'Installed and up to date';

  @override
  String get pluginUninstallTitle => 'Uninstall plugin';

  @override
  String get pluginUninstallMessage =>
      'The plugin\'s data will also be removed';

  @override
  String get settingsTab => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get resourceListView => 'List view';

  @override
  String get resourceGridView => 'Card view';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshing => 'Refreshing';

  @override
  String get notifications => 'Notifications';

  @override
  String get pendingTasks => 'Pending tasks';

  @override
  String get manageDevice => 'Manage device';

  @override
  String get installLocalResource => 'Install local resource';

  @override
  String get recentUpdates => 'Recent updates';

  @override
  String get newlyPublished => 'Newly published';

  @override
  String get news => 'News';

  @override
  String get oronBoxNews => 'OronBox news';

  @override
  String get bandbbsNews => 'BandBBS news';

  @override
  String get astroBoxNews => 'AstroBox news';

  @override
  String get resourceLibrary => 'Resource library';

  @override
  String get creatorCenter => 'Creator center';

  @override
  String get creatorNewResource => 'New resource';

  @override
  String get creatorSlug => 'Resource identifier';

  @override
  String get creatorResourceName => 'Resource name';

  @override
  String get creatorResourceSummary => 'Resource summary';

  @override
  String get creatorSaveDraft => 'Save draft';

  @override
  String get creatorAddArtifact => 'Add resource file';

  @override
  String get creatorReplaceAsset => 'Upload replacement';

  @override
  String get creatorBindDevices => 'Bind devices';

  @override
  String get creatorDeleteResource => 'Delete';

  @override
  String get creatorIconCover => 'Icon & cover';

  @override
  String get creatorInvalidImage =>
      'Unable to decode this image; use PNG/JPEG/WebP';

  @override
  String get creatorInvalidPackage =>
      'This file is not a Vela quick app or watchface';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return 'Processing file $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return 'Uploading $percent%';
  }

  @override
  String get creatorPublishServer => 'Server is processing…';

  @override
  String get creatorAstroBoxItemId => 'Item ID';

  @override
  String get creatorAstroBoxRepository => 'Repository name';

  @override
  String get creatorAstroBoxTags => 'Tags (comma separated)';

  @override
  String get creatorAstroBoxAuthor =>
      'Author (must match your AstroBox username)';

  @override
  String get creatorAstroBoxBindAccount => 'Bind AstroBox account';

  @override
  String get replace => 'Replace';

  @override
  String get delete => 'Delete';

  @override
  String get creatorSubmitReview => 'Submit';

  @override
  String get creatorCorrection => 'Correct and resubmit';

  @override
  String get creatorUpdateResource => 'Update resource';

  @override
  String get creatorArchiveAction => 'Delist';

  @override
  String get creatorArchiveConfirm =>
      'Delisting hides this resource from the store. You can restore it anytime.';

  @override
  String get creatorRestoreAction => 'Relist';

  @override
  String get creatorDeleteConfirm =>
      'This draft resource will be permanently deleted.';

  @override
  String get creatorDeletePublishedConfirm =>
      'Permanently deletes the OronBox resource and the corresponding BandBBS resources. This cannot be undone. Content already published on AstroBox is not affected; contact the AstroBox-Repo maintainers to delist it.';

  @override
  String creatorArtifactCount(Object count) {
    return '$count packages';
  }

  @override
  String get creatorKindMismatchTitle => 'File type mismatch';

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return 'This file looks like a $detected, but this resource is a $expected. You can keep it, but please confirm before submitting for review.';
  }

  @override
  String get creatorKeepFile => 'Keep anyway';

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return '\"$name\" has only this device bound and cannot be moved';
  }

  @override
  String get creatorAssetsReusedHint =>
      'Existing packages and previews are reused — no need to re-upload';

  @override
  String get creatorRevisionHistory => 'Revision history';

  @override
  String creatorUploadProgress(Object progress) {
    return 'Uploading $progress%';
  }

  @override
  String get filter => 'Filter';

  @override
  String get importLocalResource => 'Import local resource';

  @override
  String get allDevices => 'All devices';

  @override
  String get currentDevice => 'Current device';

  @override
  String get all => 'All';

  @override
  String get watchfaces => 'Watchface';

  @override
  String get quickApps => 'Quickapps';

  @override
  String get firmwareTools => 'Firmware / Tools';

  @override
  String get resourceTypeFontpack => 'Font pack';

  @override
  String get resourceTypeIconpack => 'Icon pack';

  @override
  String get localResources => 'Local resources';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => 'Local';

  @override
  String get install => 'Install';

  @override
  String get update => 'Update';

  @override
  String get manage => 'Manage';

  @override
  String get description => 'Description';

  @override
  String get supportedDevices => 'Supported devices';

  @override
  String get resourceProfile => 'Resource platform and type';

  @override
  String creatorArtifactProfileMismatch(Object fileName, Object profile) {
    return '$fileName does not match the selected $profile profile and was not added';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String downloadTimes(int count) {
    return '$count downloads';
  }

  @override
  String get changelog => 'Changelog';

  @override
  String get notFound => 'Not found';

  @override
  String get downloadStarted => 'Download started';

  @override
  String get compatible => 'Compatible with';

  @override
  String get incompatible => 'Incompatible with';

  @override
  String get incompatibleSuffix => '';

  @override
  String get openSourcePage => 'Open source page';

  @override
  String get myResources => 'My resources';

  @override
  String get drafts => 'Drafts';

  @override
  String get pendingReview => 'Pending review';

  @override
  String get published => 'Published';

  @override
  String get creatorStateSuspended => 'Delisted';

  @override
  String get creatorStateFrozen => 'Frozen';

  @override
  String get creatorSuspendedByOwnerNotice =>
      'The resource is delisted. Keep editing and resubmit for review, or restore it directly';

  @override
  String get creatorSuspendedByAdminNotice =>
      'An administrator delisted this resource. Edit and resubmit for review; it is restored once approved';

  @override
  String get creatorFrozenNotice =>
      'An administrator froze this resource. It can no longer be edited and only an administrator can lift the freeze';

  @override
  String creatorModerationReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get creatorBannedTitle => 'Account banned';

  @override
  String get creatorBannedDescription =>
      'Your account was banned by an administrator and the creator center is unavailable. Contact the team through a support ticket if you believe this is a mistake';

  @override
  String get creatorFrozenTitle => 'Creator capability frozen';

  @override
  String get creatorFrozenDescription =>
      'An administrator froze your creator capability, so you cannot submit or manage resources for now. The rest of your account is unaffected';

  @override
  String get creatorBandBbsNoDevices =>
      'Select supported devices for the resource file first';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return 'No BandBBS category could be resolved for: $devices';
  }

  @override
  String get creatorBandBbsSharedCategory =>
      'Devices in the same BandBBS category are bound to multiple packages. Bind one package per category';

  @override
  String get creatorBandBbsUnresolved => 'Unable to resolve a BandBBS category';

  @override
  String get creatorOptionalIcon => 'Icon (optional, 1:1)';

  @override
  String get creatorOptionalCover => 'Cover (optional, 3:2)';

  @override
  String get creatorRequiredIcon => 'Icon (required for AstroBox, 1:1)';

  @override
  String get creatorRequiredCover => 'Cover (required for AstroBox, 3:2)';

  @override
  String get creatorIconShapeHint =>
      'The icon is not square and may look wrong in AstroBox';

  @override
  String get creatorCoverShapeHint =>
      'The cover is not 3:2 and may look wrong in AstroBox';

  @override
  String get creatorTermsBandBbs => 'BandBBS community terms and rules';

  @override
  String get creatorTermsAstroBox => 'AstroBox-Repo submission standards';

  @override
  String get creatorTermsAccept =>
      'I have read and accept the publishing agreements above';

  @override
  String get creatorTermsContinue => 'Enter Creator Center';

  @override
  String get agree => 'Agree';

  @override
  String get creatorRulesAccept =>
      'I have read and agree to the review rules above';

  @override
  String get creatorBandBbsTermsNotice =>
      'After OronBox review, this resource is published directly to the matching BandBBS categories. Deleting the OronBox resource also deletes the corresponding BandBBS resources.';

  @override
  String get creatorAstroBoxTermsNotice =>
      'After OronBox review, a resource repository is created and a PR is submitted to the official AstroBox repository, reviewed independently by AstroBox maintainers. To delist after publication, contact the AstroBox-Repo maintainers.';

  @override
  String get failed => 'Failed / Needs action';

  @override
  String get newResource => 'New resource';

  @override
  String get basicInfo => 'Basic info';

  @override
  String get packageFiles => 'Resource files';

  @override
  String get deviceSelection => 'Device selection';

  @override
  String get deviceFileMapping => 'Device-file mapping';

  @override
  String get publishTargets => 'Publish targets';

  @override
  String get publishPreview => 'Publish preview';

  @override
  String get reviewStatus => 'Review status';

  @override
  String get scan => 'Scan';

  @override
  String get logs => 'Logs';

  @override
  String get connectedDevices => 'Connected devices';

  @override
  String get pairedDevices => 'Paired devices';

  @override
  String get discoveredDevices => 'Discovered devices';

  @override
  String get overview => 'Overview';

  @override
  String get apps => 'Apps';

  @override
  String get deviceAppCount => 'App count';

  @override
  String get deviceWatchfaceCount => 'Watchface count';

  @override
  String get connection => 'Connection';

  @override
  String get protocol => 'Protocol';

  @override
  String get error => 'Error';

  @override
  String get errorBluetoothUnavailable =>
      'Bluetooth is not available. Check that Bluetooth is enabled and OronBox has permission to use it';

  @override
  String get errorBluetoothConnectFailed =>
      'Connection failed. Check Bluetooth permission, keep the device nearby and unoccupied, enable Connect new phone on the device, then try again';

  @override
  String get errorBluetoothDisconnected =>
      'Bluetooth disconnected. Reconnect the device and try again';

  @override
  String get errorOperationTimeout =>
      'Operation timed out. Make sure the device is still nearby and try again';

  @override
  String get errorDeviceNotReady =>
      'Device is not ready. Connect and authenticate the device first';

  @override
  String get errorBleCharacteristicsMissing =>
      'Required BLE channels were not found. Reconnect the device or check whether it supports this feature';

  @override
  String get errorWebSerialUnavailable =>
      'This browser does not support Web Serial. Use Chrome, Edge, or another Web Serial compatible browser';

  @override
  String get errorAccountPasswordIncorrect =>
      'Xiaomi account username or password is incorrect';

  @override
  String get errorAccountTwoFactorIncomplete =>
      'Xiaomi account two-factor verification was not completed. Sign in again';

  @override
  String get errorOronBoxSessionExpired =>
      'Your OronBox session has expired. Sign in to BandBBS again';

  @override
  String get errorNetworkUnavailable =>
      'Unable to reach the service. Check your network and try again';

  @override
  String get errorServiceUnavailable =>
      'The service is temporarily unavailable. Try again later';

  @override
  String get errorPermissionDenied =>
      'You do not have permission to perform this operation';

  @override
  String get errorContentNotFound =>
      'The requested content no longer exists or is unavailable';

  @override
  String get errorRequestConflict =>
      'The content has changed. Refresh it and try again';

  @override
  String get errorRateLimited =>
      'Too many requests. Wait a moment and try again';

  @override
  String get errorFileTooLarge => 'The selected file is too large';

  @override
  String get errorInvalidRequest =>
      'Some submitted information is invalid. Check it and try again';

  @override
  String get errorOperationCancelled => 'Operation cancelled';

  @override
  String get errorUnsupportedFileType =>
      'Unsupported or unrecognized file type';

  @override
  String get errorCertificateVerificationFailed =>
      'Certificate verification failed. If you are using a proxy, disable HTTPS interception for this app or make sure its certificate is trusted by Flutter/Dart';

  @override
  String errorUnknownWithDetail(Object detail) {
    return 'Operation failed: $detail';
  }

  @override
  String get copyLogs => 'Copy logs';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get personalCenter => 'Personal center';

  @override
  String get accountAndPublishing => 'Account & Publishing';

  @override
  String get appearance => 'Appearance';

  @override
  String get resources => 'Resources';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox Repo';

  @override
  String get communitySourceBandBbs => 'BandBBS Community';

  @override
  String get communitySourceHuamiAppStore => 'Amazfit App Store';

  @override
  String get devices => 'Devices';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return '$count devices';
  }

  @override
  String get categories => 'Categories';

  @override
  String get advanced => 'Advanced';

  @override
  String get aboutOronBox => 'About OronBox';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get acknowledgements => 'Special Acknowledgements';

  @override
  String get acknowledgementsDesc =>
      'Open source projects referenced by OronBox';

  @override
  String get developmentTeam => 'Development team';

  @override
  String get deviceNotConnected => 'Not connected';

  @override
  String get deviceConnected => 'Connected';

  @override
  String get deviceDisconnected => 'Disconnected';

  @override
  String get deviceReconnect => 'Reconnect';

  @override
  String get deviceConnect => 'Connect';

  @override
  String get deviceSwitch => 'Switch';

  @override
  String get deviceSyncTime => 'Sync';

  @override
  String get deviceCharging => 'Charging';

  @override
  String get deviceLastChargedNow => 'Charged just now';

  @override
  String deviceLastChargedMinutes(int count) {
    return 'Charged $count min ago';
  }

  @override
  String deviceLastChargedHours(int count) {
    return 'Charged $count hr ago';
  }

  @override
  String deviceLastChargedDays(int count) {
    return 'Charged $count days ago';
  }

  @override
  String get deviceFeaturesInstallApp => 'Install app';

  @override
  String get deviceFeaturesInstallAppDesc =>
      'Install third-party app from local file';

  @override
  String get deviceFeaturesInstallWatchface => 'Install watchface';

  @override
  String get deviceFeaturesInstallWatchfaceDesc =>
      'Install watchface from local file';

  @override
  String get deviceFeaturesInstallFirmware => 'Firmware update';

  @override
  String get deviceFeaturesInstallFirmwareDesc =>
      'Check for device updates or install local firmware';

  @override
  String get firmwareAvailableUpdates => 'Available updates';

  @override
  String get firmwareCheckingUpdates => 'Checking for firmware updates';

  @override
  String get firmwareCheckUpdatesDescription =>
      'Find firmware versions compatible with this device';

  @override
  String get firmwareNoUpdatesFound =>
      'No newer firmware was found for this device';

  @override
  String get firmwareSourceUnavailable =>
      'An online firmware source is not yet available for this device type';

  @override
  String get firmwareVersionUnknown => 'Current firmware version unavailable';

  @override
  String get localFirmwareInstallDescription =>
      'Select and install a local firmware file';

  @override
  String get firmwareCurrentVersion => 'Current version';

  @override
  String get firmwareLatestRelease => 'Latest firmware';

  @override
  String get firmwareUpToDate => 'Your firmware is up to date';

  @override
  String get firmwareUpdateAvailable => 'An update is available';

  @override
  String get firmwareDownloadLatestFull => 'Download latest full package';

  @override
  String get firmwareUpdateNow => 'Update';

  @override
  String get firmwareReleaseNotes => 'Release notes';

  @override
  String get firmwareReleaseNotesUnavailable => 'No release notes available';

  @override
  String firmwareDownloadingProgress(int progress) {
    return 'Downloading $progress%';
  }

  @override
  String get downloadFailed => 'Download failed. Try again later.';

  @override
  String get downloadTaskAdded => 'Added to the download queue';

  @override
  String get deviceFeaturesManageApps => 'Manage apps';

  @override
  String get deviceFeaturesManageAppsDesc =>
      'View and uninstall installed apps';

  @override
  String get deviceFeaturesManageWatchfaces => 'Manage watchfaces';

  @override
  String get deviceFeaturesManageWatchfacesDesc =>
      'View, delete and set current watchface';

  @override
  String get zeppOsMoreFeatures => 'Special features';

  @override
  String get zeppOsMoreFeaturesDescription =>
      'Manage additional features for Zepp OS devices';

  @override
  String get zeppOsDeviceFeaturesSection => 'Device features';

  @override
  String get zeppOsAppsAndDevelopmentSection => 'Apps and development';

  @override
  String get zeppOsAssistant => 'Voice lab';

  @override
  String get zeppOsAssistantDescription =>
      'Capture, monitor, and reply to watch voice assistant sessions';

  @override
  String get zeppOsScreenMirror => 'Screen mirroring';

  @override
  String get zeppOsScreenMirrorDescription =>
      'View the watch screen on this device';

  @override
  String get zeppOsScreenMirrorSemantics => 'Zepp OS watch screen mirror';

  @override
  String zeppOsScreenMirrorUnsupported(Object error) {
    return 'This screen format cannot be displayed: $error';
  }

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get voiceLabTitle => 'Voice lab';

  @override
  String get voiceLabXiaoAi => 'XiaoAI';

  @override
  String get voiceLabReceivingAudio => 'Receiving audio from the watch';

  @override
  String get voiceLabWaiting => 'Waiting for a voice session';

  @override
  String get voiceLabContinuousCapture => 'Continuous capture';

  @override
  String get voiceLabContinuousCaptureDescription =>
      'Request the next recording when the current one ends';

  @override
  String get voiceLabDisableMonitoring => 'Disable live monitoring';

  @override
  String get voiceLabEnableMonitoring => 'Enable live monitoring';

  @override
  String get voiceLabReplyLabel => 'Reply sent to the watch';

  @override
  String get voiceLabReplyHint => 'Enter a reply';

  @override
  String get voiceLabReplyQueued =>
      'Reply queued until the current recording ends';

  @override
  String get voiceLabReplySent => 'Reply sent to the watch';

  @override
  String get voiceLabCapturedData => 'Captured data';

  @override
  String get voiceLabDecoder => 'Decoder';

  @override
  String get voiceLabOpusFrames => 'Opus frames';

  @override
  String get voiceLabDataSize => 'Data size';

  @override
  String get voiceLabPcmSamples => 'PCM samples';

  @override
  String get voiceLabExportOpus => 'Export Opus';

  @override
  String get voiceLabExportWav => 'Export WAV';

  @override
  String get voiceLabClearCapture => 'Clear captured data';

  @override
  String get voiceLabSaveRecording => 'Save voice recording';

  @override
  String get voiceLabSaveOpus => 'Save Opus audio';

  @override
  String get voiceLabAudioProcessingFailedPrefix => 'Audio processing failed';

  @override
  String voiceLabAudioProcessingFailed(Object error) {
    return 'Audio processing failed: $error';
  }

  @override
  String voiceLabContinuousCaptureFailed(Object error) {
    return 'Could not configure continuous capture: $error';
  }

  @override
  String voiceLabAssistantSwitchFailed(Object error) {
    return 'Could not switch voice assistant: $error';
  }

  @override
  String voiceLabExportWavFailed(Object error) {
    return 'Could not export WAV: $error';
  }

  @override
  String voiceLabExportOpusFailed(Object error) {
    return 'Could not export Opus: $error';
  }

  @override
  String get send => 'Send';

  @override
  String sendFailed(Object error) {
    return 'Could not send: $error';
  }

  @override
  String get ready => 'Ready';

  @override
  String get initializing => 'Initializing';

  @override
  String get zeppOsMapSelectPackage => 'Select a Zepp OS map package';

  @override
  String get zeppOsMapReadFailed => 'Could not read the map package';

  @override
  String get zeppOsMapTransferTitle => 'Transfer offline map';

  @override
  String zeppOsMapGarminDetected(Object fileName, Object mapName) {
    return '$fileName\nDetected a single-file Garmin IMG map: $mapName';
  }

  @override
  String get zeppOsMapGarminNoPreview =>
      'This map does not contain a Zepp OS 11/x/y tile tree. The original IMG will be transferred as a single-file map package, so a coverage preview is unavailable.';

  @override
  String zeppOsMapTileSummary(Object fileName, Object count) {
    return '$fileName · $count tiles\nThe preview shows package coverage, not the Garmin IMG rendering on the watch.';
  }

  @override
  String get zeppOsMapWatchConfirmationHint =>
      'You must also confirm the installation on the watch. Keep it close to this device during transfer.';

  @override
  String get zeppOsMapStartTransfer => 'Start transfer';

  @override
  String get zeppOsMapTransferringBluetooth => 'Transferring over Bluetooth';

  @override
  String get zeppOsMapTransferComplete => 'Offline map transfer complete';

  @override
  String get zeppOsMapConversionFailed => 'Map could not be converted safely';

  @override
  String get zeppOsMapSection => 'Maps';

  @override
  String get zeppOsMapTransferAction => 'Transfer map';

  @override
  String get zeppOsMapTransferDescription =>
      'Select a ZIP or Garmin IMG map and send it to the watch';

  @override
  String get zeppOsMapBtClassicHint =>
      'BT Classic bulk transfer is active. After transfer starts, confirm the installation on the watch.';

  @override
  String get zeppOsMapBleHint =>
      'BLE supports map packages up to 2 MB. Switch to BT Classic before transferring a larger map. After transfer starts, confirm the installation on the watch.';

  @override
  String get zeppOsMapPreviewTooLarge =>
      'The map area is too large to preview in full';

  @override
  String zeppOsSettingPageLoadFailed(Object error) {
    return 'Could not load the settings page: $error';
  }

  @override
  String zeppOsAppCompatibilitySaved(Object appId) {
    return 'Compatibility files saved for $appId';
  }

  @override
  String zeppOsAppStorageSaved(Object appId) {
    return 'settingsStorage saved for $appId';
  }

  @override
  String get zeppOsAppSupplementFiles => 'Add app-side or setting files';

  @override
  String get zeppOsAppSupplementCompatibility =>
      'Add mini-app compatibility files';

  @override
  String get zeppOsAppReplaceCompatibility =>
      'Add or replace compatibility files';

  @override
  String get zeppOsAppSideAvailable => 'app-side ✓';

  @override
  String get zeppOsAppSideMissing => 'app-side missing';

  @override
  String get zeppOsSettingAvailable => 'setting ✓';

  @override
  String get zeppOsSettingMissing => 'setting missing';

  @override
  String get zeppOsAppEditStorage => 'Edit settingsStorage';

  @override
  String get zeppOsStorageKeyRequired => 'Key is required';

  @override
  String zeppOsStorageDuplicateKey(Object key) {
    return 'Duplicate key: $key';
  }

  @override
  String get zeppOsStorageDescription =>
      'This data is shared by the setting page and app-side, and is stored as strings according to the Zepp OS specification.';

  @override
  String get zeppOsStorageEmpty => 'No stored entries';

  @override
  String get zeppOsStorageKey => 'Key';

  @override
  String get zeppOsStorageValue => 'Value';

  @override
  String get clear => 'Clear';

  @override
  String get save => 'Save';

  @override
  String get selectedFileReadFailed => 'Could not read the selected file';

  @override
  String get zeppOsAppInvalidHexId => 'Enter a valid hexadecimal App ID';

  @override
  String get zeppOsAppSelectCompatibilityFile =>
      'Select at least one app-side.js or setting.js file';

  @override
  String get zeppOsAppHexId => 'App ID (hexadecimal)';

  @override
  String get optionalDisplayName => 'Display name (optional)';

  @override
  String get zeppOsAppSideUnchanged => 'Keep existing app-side';

  @override
  String get zeppOsSettingUnchanged => 'Keep existing setting';

  @override
  String get selectFile => 'Select file';

  @override
  String get zeppOsAppCompatibilityOverwriteHint =>
      'Saving replaces compatibility files with the same name for this App ID, but does not modify the mini app on the watch.';

  @override
  String zeppOsDebugRefreshFailed(Object error) {
    return 'Automatic refresh failed: $error';
  }

  @override
  String get zeppOsDebugInvalidHex =>
      'HEX must contain complete bytes separated by spaces, line breaks, 0x, commas, or similar separators';

  @override
  String get zeppOsDebugClearEventsTitle => 'Clear events for the current app?';

  @override
  String zeppOsDebugClearEventsDescription(Object appId) {
    return 'All debug events for $appId will be cleared.';
  }

  @override
  String get zeppOsDebugClearEvents => 'Clear events';

  @override
  String get zeppOsDebugRefresh => 'Refresh status and events';

  @override
  String get zeppOsDebugAppList => 'App-side list';

  @override
  String get zeppOsDebugNoApps =>
      'No cached scripts or watch app-side sessions have been detected.';

  @override
  String get zeppOsDebugCached => 'Cached';

  @override
  String get zeppOsDebugNotCached => 'Not cached';

  @override
  String get zeppOsDebugRuntimeRunning => 'runtime running';

  @override
  String get zeppOsDebugRuntimeStopped => 'runtime stopped';

  @override
  String get zeppOsDebugLocalRuntime => 'Local runtime';

  @override
  String get zeppOsDebugCannotStart =>
      'This App ID has no cached script and cannot be started locally.';

  @override
  String get zeppOsDebugCanStart =>
      'The cached script can be started manually without fabricating watch session parameters.';

  @override
  String get zeppOsDebugScriptRunning =>
      'The script is running in local QuickJS.';

  @override
  String get zeppOsDebugStartQuickJs => 'Start QuickJS';

  @override
  String get stop => 'Stop';

  @override
  String get zeppOsDebugMessageEditor => 'Message editor';

  @override
  String get zeppOsDebugUtf8Text => 'UTF-8 text';

  @override
  String get zeppOsDebugJsonCompact => 'JSON (compacted before sending)';

  @override
  String get zeppOsDebugHexBytes => 'HEX bytes';

  @override
  String get zeppOsDebugEncodingFailed =>
      'The current content cannot be encoded in the selected mode';

  @override
  String get zeppOsDebugByteCountUnavailable => 'Bytes: --';

  @override
  String zeppOsDebugBytePreview(Object count, Object hex) {
    return 'Bytes: $count\nHEX: $hex';
  }

  @override
  String get zeppOsDebugInjectLocal =>
      'Inject inbound message into local runtime';

  @override
  String get zeppOsDebugSendToWatch => 'Send to watch';

  @override
  String get zeppOsDebugWaitingForWatch =>
      'Send to watch (waiting for a real session)';

  @override
  String get zeppOsDebugEvents => 'Debug events';

  @override
  String get zeppOsDebugClearCurrentApp => 'Clear current app';

  @override
  String get zeppOsDebugSearch => 'Search type, message, HEX, or readable text';

  @override
  String get zeppOsDebugWatchOnly => 'Real watch messages only';

  @override
  String get zeppOsDebugNoEvents => 'No events match the current filters';

  @override
  String get zeppOsDebugMessageActions => 'Message actions';

  @override
  String get zeppOsDebugLoadEditor => 'Load in editor';

  @override
  String get zeppOsDebugCopyHex => 'Copy HEX';

  @override
  String get zeppOsDebugCopyText => 'Copy text';

  @override
  String get zeppOsDebugSessionStatus => 'Runtime and session status';

  @override
  String zeppOsDebugCachedScript(Object status) {
    return 'Cached script: $status';
  }

  @override
  String zeppOsDebugLocalRuntimeStatus(Object status) {
    return 'Local runtime: $status';
  }

  @override
  String zeppOsDebugWatchSession(Object status) {
    return 'Watch session: $status';
  }

  @override
  String get exists => 'Available';

  @override
  String get notExists => 'Unavailable';

  @override
  String get running => 'Running';

  @override
  String get notRunning => 'Not running';

  @override
  String get notOpen => 'Not open';

  @override
  String get zeppOsDebugWatchSessionOpen => 'Real session open';

  @override
  String get zeppOsDebugRealHeader => 'Real header';

  @override
  String zeppOsDebugLatestStartup(Object status) {
    return 'Latest startup status: $status';
  }

  @override
  String get zeppOsDebugWatchInbound => 'From watch';

  @override
  String get zeppOsDebugWatchOutbound => 'To watch';

  @override
  String get zeppOsDebugLifecycle => 'Lifecycle';

  @override
  String get zeppOsMirrorInterval => 'Frame interval';

  @override
  String get zeppOsMirrorIntervalRange => '10–250';

  @override
  String get zeppOsOfflineMaps => 'Offline maps';

  @override
  String get zeppOsOfflineMapsDescription =>
      'Transfer existing map packages to the watch';

  @override
  String get zeppOsAppSettings => 'App settings';

  @override
  String get zeppOsAppSettingsDescription =>
      'Manage cached settings for Zepp OS apps';

  @override
  String get zeppOsAppDebug => 'App debugging';

  @override
  String get zeppOsAppDebugDescription =>
      'Debug app-side scripts and device communication';

  @override
  String get deviceFeaturesSection => 'Features';

  @override
  String get deviceMusicSync => 'Music sync';

  @override
  String get deviceMusicUpload => 'Transfer music';

  @override
  String get deviceMusicSyncDescription => 'Sync MP3 files to the device';

  @override
  String get deviceMusicChooseDialog =>
      'Select an MP3 file to sync to the device';

  @override
  String get deviceMusicReadFailed => 'Unable to read the selected MP3 file';

  @override
  String deviceMusicSizeInvalid(int maxMb) {
    return 'MP3 files must be larger than 0 bytes and no larger than $maxMb MB';
  }

  @override
  String get deviceMusicUnknownArtist => 'Unknown artist';

  @override
  String get deviceMusicTransferred => 'Music transfer complete';

  @override
  String get deviceMusicLibrary => 'Device music';

  @override
  String get deviceMusicLibraryDescription =>
      'Manage songs and playlists on the device';

  @override
  String get deviceMusicSongs => 'Songs';

  @override
  String deviceMusicSongsTotal(int count) {
    return '$count total';
  }

  @override
  String get deviceMusicNoPlaylist => 'Not in a playlist';

  @override
  String get deviceMusicPlaylists => 'Playlists';

  @override
  String get deviceMusicEmpty => 'No songs on the device';

  @override
  String get deviceMusicNoPlaylists => 'No playlists yet';

  @override
  String deviceMusicLoadFailed(String error) {
    return 'Failed to load device music: $error';
  }

  @override
  String get deviceMusicPlaylistCreate => 'New playlist';

  @override
  String get deviceMusicPlaylistRename => 'Rename playlist';

  @override
  String get deviceMusicPlaylistName => 'Playlist name';

  @override
  String deviceMusicPlaylistLimit(int count) {
    return 'Up to $count playlists';
  }

  @override
  String deviceMusicSongCount(int count) {
    return '$count songs';
  }

  @override
  String get deviceMusicDeleteSong => 'Delete this song from the device?';

  @override
  String get deviceMusicDeletePlaylist => 'Delete this playlist?';

  @override
  String get deviceMusicDeletePlaylistDescription =>
      'Songs in the playlist will remain on the device.';

  @override
  String get deviceMusicManagePlaylists => 'Manage playlists';

  @override
  String get deviceMusicPlaylistMembership => 'Playlists';

  @override
  String deviceMusicTransferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String deviceMusicSelectedFiles(int count) {
    return '$count files selected';
  }

  @override
  String deviceMusicQueueProgress(int current, int total, String name) {
    return 'Transferring $current/$total: $name';
  }

  @override
  String get deviceRecordingsTitle => 'Recording sync';

  @override
  String get deviceRecordingsDescription =>
      'Sync and export recordings from the watch';

  @override
  String get deviceRecordingsHint =>
      'Recordings are received and verified one by one. Export each original file after synchronization.';

  @override
  String get deviceRecordingsSync => 'Sync recordings';

  @override
  String get deviceRecordingsSyncing => 'Receiving';

  @override
  String get deviceRecordingsReading => 'Reading recording list';

  @override
  String deviceRecordingsProgress(int completed, int total, String name) {
    return 'Received $completed/$total: $name';
  }

  @override
  String deviceRecordingsProgressCount(int completed, int total) {
    return 'Received $completed/$total';
  }

  @override
  String get deviceRecordingsEmpty =>
      'Connect the watch and select Sync recordings';

  @override
  String get deviceRecordingsSave => 'Export recording';

  @override
  String get deviceRecordingsNoneOnWatch =>
      'No new recordings were found on the watch';

  @override
  String deviceRecordingsSynced(int count) {
    return 'Synced $count recordings';
  }

  @override
  String deviceRecordingsSaveFailed(String error) {
    return 'Could not export recording: $error';
  }

  @override
  String get deviceMusicTransferTitle => 'Transfer MP3 file';

  @override
  String get deviceMusicVelaDescription =>
      'Sync MP3 files to the device. Each file must not exceed 100 MB.';

  @override
  String get deviceMusicZeppDescription =>
      'MP3 files up to 50 MB are supported. Bluetooth Classic is recommended for faster transfers; BLE is also supported but takes longer.';

  @override
  String get deviceMusicChooseMp3 => 'Select MP3 file';

  @override
  String get deviceMusicSongTitle => 'Track title';

  @override
  String get deviceMusicArtist => 'Artist';

  @override
  String deviceMusicFileSize(Object size) {
    return 'File size: $size';
  }

  @override
  String deviceMusicProgress(Object progress) {
    return 'Transfer progress: $progress%';
  }

  @override
  String get deviceMusicTransferring => 'Transferring';

  @override
  String get deviceMusicSend => 'Start transfer';

  @override
  String get zeppOsFindDevice => 'Find device';

  @override
  String get zeppOsFindDeviceDescription =>
      'Make the device vibrate or ring so you can locate it nearby.';

  @override
  String get zeppOsFindDeviceStart => 'Start finding';

  @override
  String get zeppOsFindDeviceStop => 'Stop finding';

  @override
  String get deviceFeaturesDeviceInfo => 'Device info';

  @override
  String get deviceFeaturesDeviceInfoDesc => 'Firmware, storage and details';

  @override
  String get switchDeviceTitle => 'Switch device';

  @override
  String get savedDevices => 'Saved devices';

  @override
  String get scanAndAdd => 'Scan and add';

  @override
  String get scanNotFound => 'No devices found';

  @override
  String get noSavedDevices => 'No saved devices';

  @override
  String get authkey => 'Auth key';

  @override
  String get authkeyPrompt => 'Enter device auth key';

  @override
  String get authkeyPlaceholder => 'Auth key';

  @override
  String get connectFailed => 'Connection failed';

  @override
  String deviceConnectingTo(String deviceName) {
    return 'Connecting to $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => 'Preparing connection…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return 'Establishing $transport connection…';
  }

  @override
  String get deviceConnectionInitializing => 'Initializing device protocol…';

  @override
  String get deviceConnectionAuthenticating => 'Authenticating device…';

  @override
  String get deviceConnectionFetchingStatus => 'Reading device information…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String deviceEndpointUnavailable(String transport) {
    return 'No $transport endpoint is available. Pair the device in system Bluetooth settings, then scan again.';
  }

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => 'Unrecognized device';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      'On the web, OronBox connects to devices via Web Serial. Saved devices stay in this browser.';

  @override
  String get webSerialConnectDialogTitle => 'Connect via Web Serial';

  @override
  String get webSerialConnectDialogHint =>
      'Enter the device auth key, then select the serial port in the browser prompt. The auth key is saved in this browser.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deviceActionsDelete => 'Delete';

  @override
  String get deviceActionsDisconnect => 'Disconnect';

  @override
  String get deviceActionsShareQR => 'Share QR';

  @override
  String get deviceShareOronBoxCode => 'Switch to OronBox code';

  @override
  String get deviceShareAstroBoxCompatibleCode =>
      'Switch to AstroBox compatible code';

  @override
  String get installTapToSelectFile => 'Tap to select file';

  @override
  String get installPackageName => 'Package name';

  @override
  String get installWatchfaceId => 'Watchface ID';

  @override
  String get deviceInfoTitle => 'Device info';

  @override
  String get deviceInfoGroupDevice => 'Device';

  @override
  String get deviceInfoGroupSystem => 'System';

  @override
  String get deviceInfoGroupStatus => 'Status';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldAuthkey => 'Auth key';

  @override
  String get fieldConnectionType => 'Connection type';

  @override
  String get fieldCodename => 'Codename';

  @override
  String get fieldModel => 'Model';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => 'Firmware';

  @override
  String get fieldSerial => 'Serial';

  @override
  String get fieldBattery => 'Battery';

  @override
  String get fieldChargeStatus => 'Charge status';

  @override
  String get fieldLastCharge => 'Last charge';

  @override
  String get fieldStorage => 'Storage';

  @override
  String get appManagementTitle => 'App management';

  @override
  String get appManagementNone => 'No installed apps';

  @override
  String get appManagementShowSystemApps => 'Show system apps';

  @override
  String get watchfaceManagementTitle => 'Watchface management';

  @override
  String get watchfaceManagementNone => 'No installed watchfaces';

  @override
  String get open => 'Open';

  @override
  String get externalLinkTitle => 'Open external link';

  @override
  String externalLinkDescription(String url) {
    return 'You are about to visit $url\n\nThis website is operated by a third party, is not affiliated with OronBox, and its security is unknown. Please proceed with caution. Do you want to continue?';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      'This appears to be an AstroBox resource. You can also view and install it within OronBox';

  @override
  String get continueToWebsite => 'Continue';

  @override
  String get viewInOronBox => 'View in OronBox';

  @override
  String get uninstall => 'Uninstall';

  @override
  String get enable => 'Enable';

  @override
  String get fail => 'Failed';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get close => 'Close';

  @override
  String get desktopTrayShow => 'Show window';

  @override
  String get desktopTrayExit => 'Exit OronBox';

  @override
  String get desktopCloseTitle => 'Exit confirmation';

  @override
  String get desktopCloseMessage => 'Would you like to exit OronBox?';

  @override
  String get desktopCloseRemember => 'Do not ask again';

  @override
  String get desktopCloseToTray => 'Minimize to tray';

  @override
  String get desktopCloseExit => 'Exit OronBox';

  @override
  String get settingsDesktopCloseBehavior => 'Close button behavior';

  @override
  String get settingsDesktopCloseBehaviorDesc =>
      'Choose what happens when the main window is closed';

  @override
  String get desktopCloseBehaviorAsk => 'Ask every time';

  @override
  String get desktopCloseBehaviorExit => 'Exit immediately';

  @override
  String get desktopCloseBehaviorTray => 'Minimize to tray';

  @override
  String get multiDevice => 'Multi-device';

  @override
  String get quickApp => 'Quickapp';

  @override
  String get miniprogram => 'Miniprogram';

  @override
  String get miniprograms => 'Miniprograms';

  @override
  String get watchface => 'Watchface';

  @override
  String get firmwareTool => 'Firmware / Tool';

  @override
  String get fontPack => 'Font Pack';

  @override
  String get iconPack => 'Icon Pack';

  @override
  String get free => 'Free';

  @override
  String get paid => 'Paid';

  @override
  String get forcePaid => 'Force Paid';

  @override
  String get version => 'Version';

  @override
  String get noDescription => 'No description';

  @override
  String get preview => 'Preview';

  @override
  String get productAbout => 'About';

  @override
  String get productDeviceRequirements => 'Device requirements';

  @override
  String get productOtherVersions => 'Other versions';

  @override
  String get productInQueue => 'In queue';

  @override
  String get productShare => 'Share';

  @override
  String get productViewOnBandBBS => 'View on BandBBS';

  @override
  String get changeCdn => 'Change CDN';

  @override
  String get cdnErrorTitle => 'AstroBox data failed to load';

  @override
  String cdnErrorMessage(Object cdn, Object path) {
    return 'Current CDN ($cdn) could not fetch $path. Would you like to switch CDN?';
  }

  @override
  String get cdnErrorContinue => 'Switch CDN';

  @override
  String get cdnErrorCancel => 'Cancel';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSource => 'Downloads';

  @override
  String get settingsSourceRestart => 'Restart required';

  @override
  String get settingsQueue => 'Queue';

  @override
  String get settingsInstall => 'Installation';

  @override
  String get settingsTools => 'Mysterious Tools';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccountLoginBBS => 'Login to BandBBS';

  @override
  String get settingsAccountLoginBBSDesc =>
      'Sign in to access BandBBS resources';

  @override
  String get settingsAccountBandBbsSigningIn => 'Signing in';

  @override
  String get settingsAccountBandBbsOpenedBrowser =>
      'Browser opened. Complete BandBBS authorization there';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBS signed in';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS sign-in failed';

  @override
  String get settingsBandBbsAccountRequired =>
      'Sign in to your BandBBS account in Settings first';

  @override
  String settingsAccountBandBbsUser(Object userId) {
    return 'User ID: $userId';
  }

  @override
  String get settingsAccountBBSAccount => 'BandBBS account';

  @override
  String get bandBbsAccountTitle => 'BandBBS account';

  @override
  String get bandBbsPurchasedResources => 'Purchased resources';

  @override
  String get bandBbsResourceId => 'Resource ID';

  @override
  String get bandBbsResourceIdHint => 'Enter BandBBS resource ID';

  @override
  String get bandBbsQueryResource => 'Query';

  @override
  String get bandBbsOpenResource => 'View on BandBBS';

  @override
  String get bandBbsLogout => 'Sign out';

  @override
  String get bandBbsLoggedOut => 'Signed out';

  @override
  String accountSignOutTitle(Object accountName) {
    return 'Sign out of $accountName?';
  }

  @override
  String get accountSignOutMessage =>
      'You will need to sign in again to use related features.';

  @override
  String get bandBbsLoadPreviews => 'Load post previews';

  @override
  String get bandBbsLoadPreviewsDesc =>
      'Automatically load attachment previews in the resource list';

  @override
  String get bandBbsShowAllCategories => 'Show all categories';

  @override
  String get bandBbsShowAllCategoriesDesc =>
      'Include categories for unsupported devices hidden by default';

  @override
  String get settingsAccountSyncDevices => 'Sync devices';

  @override
  String get settingsAccountSyncDevicesDesc =>
      'Log in to Mi Account to sync paired devices';

  @override
  String get settingsMiAccount => 'Mi Account';

  @override
  String get settingsMiAccountDesc =>
      'Sign in and sync authkeys from bound devices';

  @override
  String get settingsMiAccountLoginTitle => 'Mi Account login';

  @override
  String get settingsMiAccountUsername => 'Account';

  @override
  String get settingsMiAccountPassword => 'Password';

  @override
  String get settingsMiAccountRememberCredentials =>
      'Remember account and password';

  @override
  String get settingsMiAccountLoginAndSync => 'Sign in and sync';

  @override
  String get settingsMiAccountMissingCredentials =>
      'Enter your Mi Account and password';

  @override
  String get settingsMiAccountTwoFactorPrompt =>
      'Complete Mi Account two-factor verification in the verification page';

  @override
  String get settingsMiAccountLoginWindowClosed =>
      'The login window was closed';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return 'Synced $count Mi devices';
  }

  @override
  String get settingsHuamiAccount => 'Amazfit account';

  @override
  String get settingsHuamiAccountDesc =>
      'Sign in and save credentials for Zepp store access';

  @override
  String get settingsHuamiAccountSigningIn => 'Signing in';

  @override
  String get settingsHuamiAccountSignedIn => 'Amazfit account signed in';

  @override
  String settingsHuamiAccountUser(Object username) {
    return 'Account: $username';
  }

  @override
  String get settingsHuamiAccountLoginTitle => 'Amazfit account login';

  @override
  String get settingsHuamiAccountUsername => 'Account';

  @override
  String get settingsHuamiAccountPassword => 'Password';

  @override
  String get settingsHuamiAccountRememberCredentials => 'Remember password';

  @override
  String get settingsHuamiAccountLoginAndSave => 'Sign in and save';

  @override
  String get settingsHuamiAccountMissingCredentials =>
      'Enter your Amazfit account and password';

  @override
  String get settingsHuamiAccountRequired =>
      'Sign in to your Amazfit account in Settings first';

  @override
  String get understood => 'I understand';

  @override
  String get settingsGeneralLanguage => 'Language';

  @override
  String get settingsGeneralLanguageDesc => 'Change app display language';

  @override
  String get settingsWideNavigationPosition => 'Navigation position';

  @override
  String get settingsWideNavigationPositionDesc =>
      'Adjust side tab placement in the wide-screen state';

  @override
  String get settingsWideNavigationPositionBottom => 'Bottom';

  @override
  String get settingsWideNavigationPositionCenter => 'Center';

  @override
  String get settingsWideNavigationPositionSplit => 'Split';

  @override
  String get settingsGeneralTranslateTeam => 'Translation contributors';

  @override
  String get settingsAutoReconnectTitle => 'Auto reconnect';

  @override
  String get settingsAutoReconnectDesc =>
      'Automatically reconnect to the last paired device on startup';

  @override
  String get settingsGeneralDebugWindow => 'Debug window';

  @override
  String get settingsGeneralDebugWindowDesc => 'Show a floating debug panel';

  @override
  String get settingsSourceOfficialCdn => 'GitHub source CDN';

  @override
  String get settingsSourceOfficialCdnDesc =>
      'CDN used to fetch the GitHub-hosted community index';

  @override
  String get settingsQueueAutoInstall => 'Auto install';

  @override
  String get settingsQueueAutoInstallDesc =>
      'Start installation automatically after download';

  @override
  String get settingsQueueDontClear => 'Don\'t clear install queue';

  @override
  String get settingsQueueDontClearDesc =>
      'Keep completed items in the install queue';

  @override
  String get settingsInstallSendInterval => 'Packet interval';

  @override
  String get settingsInstallSendIntervalDesc =>
      'Delay between Bluetooth fragments during install';

  @override
  String get settingsToolsUnlockCode => 'Calculate unlock code';

  @override
  String get settingsToolsUnlockCodeDesc =>
      'Generate a Mi Wear unlock code from MAC and SN';

  @override
  String get settingsToolsDialogTitle => 'Unlock code';

  @override
  String get settingsToolsMac => 'MAC address';

  @override
  String get settingsToolsSn => 'Serial number';

  @override
  String get settingsToolsNoticeTitle => 'Warning';

  @override
  String get settingsToolsNoticeBody =>
      'Unlocking may void your warranty or cause data loss. Use at your own risk.';

  @override
  String get settingsToolsAgree => 'I understand the risks';

  @override
  String get settingsToolsCalculate => 'Calculate';

  @override
  String get settingsToolsResult => 'Result';

  @override
  String get settingsToolsDialogUsage => 'Usage';

  @override
  String get settingsToolsDialogUsageInfo =>
      'Enter the MAC address and serial number shown on the device.';

  @override
  String get settingsAboutAboutAstrobox => 'About OronBox';

  @override
  String get settingsAboutAboutAstroboxDesc => 'Version, changelog and team';

  @override
  String get settingsAboutDisclaimer => 'Disclaimer';

  @override
  String get settingsAboutDisclaimerDesc =>
      'User agreement and liability statement';

  @override
  String get settingsAboutOpenlog => 'Log folder';

  @override
  String get settingsAboutOpenlogDesc =>
      'Open the log directory in file manager';

  @override
  String get settingsAboutWebsite => 'Official website';

  @override
  String get settingsAboutWebsiteDesc => 'Visit oronbox.zxor.org';

  @override
  String get settingsAboutQQ => 'QQ group';

  @override
  String get settingsAboutQQDesc => 'Join the community chat';

  @override
  String get settingsAboutLicences => 'Open source licenses';

  @override
  String get settingsAboutLicencesDesc =>
      'Licenses for Flutter, dependencies and open source components';

  @override
  String get settingsGuest => 'Guest';

  @override
  String get settingsTapToSignIn => 'Tap to sign in';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsNotConnected => 'Not connected';

  @override
  String get settingsNotSet => 'Not set';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsOledDark => 'OLED dark';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeModeDesc => 'Change app theme appearance';

  @override
  String get settingsDynamicColor => 'Dynamic color';

  @override
  String get settingsDynamicColorDesc =>
      'Use system accent colors for the app theme';

  @override
  String get settingsColorScheme => 'Color scheme';

  @override
  String get settingsColorSchemeDesc => 'Choose the app accent color';

  @override
  String get settingsColorSchemePink => 'Pink';

  @override
  String get settingsColorSchemePurple => 'Purple';

  @override
  String get settingsColorSchemeTeal => 'Teal';

  @override
  String get settingsColorSchemeGreen => 'Green';

  @override
  String get settingsColorSchemeRed => 'Red';

  @override
  String get settingsColorSchemeAmber => 'Amber';

  @override
  String get settingsDesktopAccentSource => 'Linux accent source';

  @override
  String get settingsDesktopAccentSourceDesc =>
      'Choose whether to read accent colors from GTK or Qt';

  @override
  String get settingsDesktopAccentSourceSystem => 'Auto';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsConfirm => 'Confirm';

  @override
  String get settingsOpen => 'Open';

  @override
  String get settingsVisit => 'Visit';

  @override
  String get settingsTeamSlogan =>
      'A pretty fast wearable management tool for VelaOS and ZeppOS.';

  @override
  String get settingsTeamGitHub => 'GitHub Repository';

  @override
  String get settingsTeamMembers => 'Team Members';

  @override
  String get settingsTeamRoleMain => 'Main Developer / Designer';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS implementation';

  @override
  String get settingsAboutSoftware => 'About software';

  @override
  String get settingsAboutSoftwareDesc =>
      'Version, changelog and development team';

  @override
  String get settingsAboutSoftwareTagline =>
      'A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter';

  @override
  String get settingsAboutSoftwareRepository => 'Open GitHub repository';

  @override
  String get settingsAboutSoftwareTeam => 'Development team';

  @override
  String get settingsAboutSoftwareReleaseName =>
      'Current release: development preview';

  @override
  String get settingsAboutSoftwareReleaseBody =>
      'This update includes:\n• System accent color support and theme refinements\n• Redesigned resource detail and list pages with grouped device filters\n• Replaced team page with about software page; localized settings\n• Improved Xiaomi SAR controller send error handling\n• Stabilized Linux classic SPP connect cancellation and timeouts\n• Updated ARB localizations and generated l10n files';

  @override
  String get settingsAboutSoftwareBuildInfo => 'Build info';

  @override
  String get settingsAboutSoftwareCopyright =>
      'Copyright © OronBox contributors';

  @override
  String get acknowledgementsKazumi =>
      'Reference for Material Design components and UI patterns.';

  @override
  String get acknowledgementsAstroBoxPublic =>
      'Reference for UI structure, resource workflows, and interaction design.';

  @override
  String get acknowledgementsAstroBoxNgCore =>
      'Reference for Xiaomi device protocols, install flows, and transfer behavior.';

  @override
  String get acknowledgementsAstroBoxNgBluetooth =>
      'Reference for Bluetooth connection behavior.';

  @override
  String get acknowledgementsAstroBoxNgAccount =>
      'Reference for Xiaomi account login, device sync, and authkey retrieval flows.';

  @override
  String get acknowledgementsAstroBoxNgProvider =>
      'Reference for community resource indexes, CDN handling, and manifest parsing flows.';

  @override
  String get acknowledgementsAstroBoxNgAppWasm =>
      'Reference for Web Serial and browser-side connection flows.';

  @override
  String get acknowledgementsGadgetbridge =>
      'Reference for ZeppOS and wearable protocol research.';

  @override
  String get resourceHomeEmptyTitle => 'Home page is under construction';

  @override
  String get resourceHomeEmptySubtitle =>
      'You can get resources from the library';

  @override
  String get resourceCreatorEmptyTitle =>
      'Creator center is under construction';

  @override
  String get resourceCreatorEmptySubtitle =>
      'You can manage acquired resources in the library';

  @override
  String get openResourceLibrary => 'Open resource library';

  @override
  String get downloadQueueTitle => 'Download queue';

  @override
  String get installQueueTitle => 'Install queue';

  @override
  String get queueClear => 'Clear';

  @override
  String get queueStart => 'Start';

  @override
  String get queuePause => 'Pause';

  @override
  String get downloadQueueEmpty => 'No download tasks';

  @override
  String get installQueueEmpty => 'No install tasks';

  @override
  String get localAppInstall => 'Local app install';

  @override
  String get localWatchfaceInstall => 'Local watchface install';

  @override
  String get localFirmwareInstall => 'Local firmware install';

  @override
  String get queueStatusPending => 'Waiting';

  @override
  String queueStatusDownloading(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return 'Installing $percent%';
  }

  @override
  String get queueStatusCompleted => 'Completed';

  @override
  String get queueStatusFailed => 'Failed';

  @override
  String get queueDragToInstall => 'Release to add to install queue';

  @override
  String queueAddedFiles(int count) {
    return 'Added $count files to install queue';
  }

  @override
  String get installQueueReadFailed => 'Read failed';

  @override
  String get installQueueUnsupportedFile => 'Unsupported file';

  @override
  String timeTodayAt(Object time) {
    return 'Today $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return 'Yesterday $time';
  }

  @override
  String get settingsAccountBandBbsAccount => 'BandBBS Account';

  @override
  String get settingsAccountGitHub => 'GitHub account';

  @override
  String get settingsAccountGitHubDesc =>
      'Connect to publish AstroBox resources as yourself';

  @override
  String get githubAccountNeedsBandBbs => 'Sign in to BandBBS first';

  @override
  String get bandBbsPublishAuthTitle => 'Publish authorization';

  @override
  String get bandBbsResourceQueryTitle => 'Install purchased resources';

  @override
  String get settingsAboutLogs => 'Runtime logs';

  @override
  String get settingsAboutLogsDescription =>
      'View, export, and manage runtime logs from the app and connected devices';

  @override
  String settingsAboutLogsSize(Object size) {
    return 'Currently using $size';
  }

  @override
  String get settingsAboutLogsExport => 'Export';

  @override
  String settingsAboutLogsExported(Object path) {
    return 'Exported to $path';
  }

  @override
  String get settingsAboutLogsEmpty => 'No logs to export yet';

  @override
  String get settingsAboutLogsClear => 'Clear';

  @override
  String get settingsDeviceLogsPull => 'Pull device logs';

  @override
  String get settingsDeviceLogsTip =>
      'This pulls logs from the connected Xiaomi wearable and may take a while. Keep the app in the foreground and the device screen on until it finishes.';

  @override
  String get settingsDeviceLogsStart => 'Start';

  @override
  String get settingsDeviceLogsPulling => 'Pulling device logs';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return 'Received $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return 'Device logs saved as $name';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return 'Unable to pull device logs: $error';
  }

  @override
  String get settingsAboutLogsClearConfirm =>
      'All log files except the current session will be deleted.';

  @override
  String get settingsAboutLogsOpen => 'Open logs folder';

  @override
  String get settingsAboutLogsOpenFailed => 'Unable to open the logs folder';

  @override
  String get settingsLogsFileList => 'Log files';

  @override
  String get settingsAboutLogsWarningTitle => 'Sensitive information warning';

  @override
  String get settingsAboutLogsWarningMessage =>
      'Logs may contain BandBBS, Xiaomi, or Amazfit login credentials and other sensitive information. Do not share them with anyone other than official OronBox maintainers!';

  @override
  String get pluginPermissionRequestTitle => 'Plugin permission request';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '\"$plugin\" wants to $operation.';
  }

  @override
  String get pluginPermissionOnce => 'Allow once';

  @override
  String get pluginPermissionSession => 'Allow this run';

  @override
  String get pluginPermissionAlways => 'Always allow';

  @override
  String get pluginPermissionDeny => 'Deny';

  @override
  String get pluginPermissionOpenExternal => 'open an external link';

  @override
  String get pluginPermissionPickFile => 'access host files';

  @override
  String get pluginPermissionExportFile => 'export a file to the host';

  @override
  String get pluginPermissionNetwork => 'access the network';

  @override
  String get pluginPermissionInterconnect =>
      'communicate with device applications';

  @override
  String get pluginPermissionProvider => 'register a resource provider';

  @override
  String get pluginPermissionReadDevice => 'read device information';

  @override
  String get pluginPermissionOperateDevice => 'operate a device';

  @override
  String get pluginPermissionObserveProtocol => 'read raw device protocol data';

  @override
  String get pluginPermissionSendProtocol =>
      'send raw protocol data to a device';

  @override
  String get pluginPermissionReadAppSide => 'read AppSide scripts and events';

  @override
  String get pluginPermissionOperateAppSide => 'manage AppSide sessions';

  @override
  String get pluginErrorTitle => 'Plugin runtime error';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '\"$plugin\" encountered a runtime error:\n\n$error';
  }

  @override
  String get pluginErrorClearData => 'Clear plugin data';

  @override
  String get pluginErrorUninstall => 'Uninstall plugin';

  @override
  String get pluginErrorSafeMode => 'Enter safe mode';

  @override
  String get pluginSafeModeTitle => 'Plugin safe mode is enabled';

  @override
  String get pluginSafeModeDescription =>
      'All plugins are stopped and will reload after safe mode is disabled.';

  @override
  String get pluginSafeModeExit => 'Exit safe mode';

  @override
  String get devTools => 'DevTools';

  @override
  String get devToolsDescriptionDesktop => 'Open DevTools in a separate window';

  @override
  String get devToolsDescriptionEntry =>
      'Show a DevTools entry button in app bars';

  @override
  String get devToolsOperationFailed => 'Unable to change the DevTools state';

  @override
  String get resourceTypeErrorTitle => 'Incorrect resource type';

  @override
  String get resourceTypeUnknownTitle => 'Unrecognized resource type';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return 'This appears to be a $detectedType resource, but you selected $selectedType. Choose how to install it';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return 'This appears to be a $resourceType resource for a $resourcePlatform device, but the connected device is $deviceName ($devicePlatform). It is not supported and forcing installation may cause unexpected problems';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'OronBox cannot identify the actual resource type. Install it as $selectedType anyway?';
  }

  @override
  String get resourceInstallCancel => 'Cancel installation';

  @override
  String get resourceInstallAcknowledge => 'I understand';

  @override
  String get resourceInstallForce => 'Force install';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return 'Force install (${seconds}s)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return 'Continue as $type';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return 'Continue as $type (${seconds}s)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return 'Install as $type';
  }

  @override
  String get resourceTypeApp => 'miniprogram';

  @override
  String get resourceTypeQuickApp => 'quick app';

  @override
  String get resourceTypeWatchface => 'watchface';

  @override
  String get resourceTypeFirmware => 'firmware';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return 'Install $type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return 'Install $fileName ($fileSize)?';
  }

  @override
  String get resourceInstallConfirm => 'Install';

  @override
  String get resourceName => 'Resource name';

  @override
  String get resourceSummary => 'Short summary';

  @override
  String get previewImages => 'Preview images';

  @override
  String get add => 'Add';

  @override
  String get submit => 'Submit';

  @override
  String get currentAccount => 'current account';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String get creatorConfirmTitle => 'Confirm publishing plan';

  @override
  String get creatorConfirmOronBox =>
      'The resource will be reviewed by OronBox and published in OronBox Resources after approval';

  @override
  String creatorConfirmBandBbs(Object category) {
    return 'After approval, the resource will be published directly to BandBBS category $category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return 'After approval, GitHub user $owner will create or update repository $repository and open an ABRepo pull request';
  }

  @override
  String get creatorBandBbsDirectPublish =>
      'Published directly to the BandBBS community after OronBox review';

  @override
  String get bandBbsCategoryId => 'BandBBS resource category ID';

  @override
  String get bandBbsCategory => 'BandBBS resource category';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return 'After OronBox review, create resource repository $repository and submit a PR to the official AstroBox repo';
  }

  @override
  String get creatorOronBoxRequired =>
      'Required. Resources are reviewed by OronBox';

  @override
  String get creatorOpenInOronBox => 'View in OronBox';

  @override
  String get creatorAstroTags => 'AstroBox tags';

  @override
  String get creatorAstroTagsHint =>
      'Separate multiple tags with commas or semicolons';

  @override
  String get retry => 'Retry';

  @override
  String get reviewNote => 'Review note';

  @override
  String get creatorReviewRejected => 'Resource changes requested';

  @override
  String creatorReviewState(Object state) {
    return 'Review status: $state';
  }

  @override
  String get creatorOperationWorking => 'Working';

  @override
  String get creatorProcessingImage => 'Processing image';

  @override
  String get creatorOperationRefreshing => 'Refreshing creator data';

  @override
  String get creatorOperationCreating => 'Creating resource';

  @override
  String get creatorOperationCreatingCollection => 'Creating collection';

  @override
  String get creatorOperationSaving => 'Saving changes';

  @override
  String get creatorOperationUploading => 'Uploading and processing file';

  @override
  String get creatorOperationBinding => 'Updating supported devices';

  @override
  String get creatorOperationDeleting => 'Deleting';

  @override
  String get creatorOperationSubmitting => 'Submitting for review';

  @override
  String get creatorOperationAuthorizing => 'Waiting for authorization';

  @override
  String get creatorResolvingPublicationTarget =>
      'Resolving publication category';

  @override
  String get creatorSessionExpired =>
      'Your OronBox session has expired. Sign in again before authorizing publishing';

  @override
  String get creatorStateApproved => 'Approved';

  @override
  String get creatorStateExternalReview => 'External review';

  @override
  String get creatorStateFailed => 'Publishing failed';

  @override
  String get creatorStateSuperseded => 'Superseded by a newer revision';

  @override
  String get creatorStateCancelled => 'Cancelled';

  @override
  String get creatorNoResources => 'No resources created yet';

  @override
  String get creatorLoginRequiredTitle => 'Sign in to use Creator Center';

  @override
  String get creatorLoginRequiredDescription =>
      'Sign in to BandBBS and connect your OronBox account before creating, editing, or submitting resources';

  @override
  String get creatorLoginAction => 'Sign in to BandBBS';

  @override
  String get creatorSelectHint =>
      'Select a resource on the left, or create a new one';

  @override
  String get creatorOronBoxReady =>
      'OronBox and BandBBS read access are available';

  @override
  String get creatorBandBbsWriteReady =>
      'BandBBS publishing access is authorized';

  @override
  String get creatorBandBbsWriteMissing =>
      'BandBBS write access is missing, so BandBBS publishing is unavailable';

  @override
  String creatorGitHubOwnPublishReady(Object login) {
    return 'GitHub is connected; publish as $login';
  }

  @override
  String get creatorGitHubOwnPublishMissing =>
      'GitHub is not connected, so AstroBox resources cannot be published under your account';

  @override
  String get creatorAuthorize => 'Authorize';

  @override
  String get openCreatorCenter => 'Open creator center';

  @override
  String get creatorGitHubNotConnected => 'GitHub account is not connected';

  @override
  String creatorGitHubConnected(Object login) {
    return 'Connected as GitHub user $login';
  }

  @override
  String get githubAuthorizationFailed =>
      'Unable to open the GitHub authorization page';

  @override
  String get githubAuthorizationTimedOut => 'GitHub authorization timed out';

  @override
  String get authorize => 'Authorize';

  @override
  String get creatorBandBbsAuthorized =>
      'BandBBS resource publishing is authorized';

  @override
  String get creatorBandBbsAuthorizationRequired =>
      'Authorize OronBox separately to publish BandBBS resources on your behalf';

  @override
  String get connect => 'Connect';

  @override
  String get editResource => 'Edit resource';

  @override
  String get legalAndPrivacy => 'Legal and privacy';

  @override
  String get legalAndPrivacyDesc =>
      'View the terms, privacy notice, and resource rules';

  @override
  String get termsTitle => 'Terms and disclaimer';

  @override
  String get privacyTitle => 'Privacy notice';

  @override
  String get resourcePublishingTitle => 'Resource publishing agreement';

  @override
  String get reviewRulesTitle => 'Resource review rules';

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackDesc => 'Submit feedback and view responses';

  @override
  String get reportResource => 'Report resource';

  @override
  String get reportComment => 'Report comment';

  @override
  String get report => 'Report';

  @override
  String get feedbackSubject => 'Subject';

  @override
  String get feedbackMessage => 'Feedback or issue';

  @override
  String get reportReason => 'Reason for report';

  @override
  String get submitted => 'Submitted';

  @override
  String get myFeedback => 'My feedback';

  @override
  String get noFeedback => 'No feedback yet';

  @override
  String get feedbackProcessing => 'Processing';

  @override
  String get feedbackReplied => 'Replied';

  @override
  String get feedbackOpen => 'Open';

  @override
  String get feedbackResolved => 'Resolved';

  @override
  String get feedbackDismissed => 'Dismissed';

  @override
  String get feedbackClosed => 'Closed';

  @override
  String get feedbackLoading => 'Loading tickets';

  @override
  String get feedbackNewTicket => 'New ticket';

  @override
  String get feedbackYou => 'You';

  @override
  String get feedbackResolution => 'Resolution';

  @override
  String get feedbackReplyHint => 'Reply to this ticket';

  @override
  String get feedbackConversationClosed =>
      'This ticket is closed and cannot be replied to';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateCheckFailed => 'Unable to check for updates';

  @override
  String get latestVersionInstalled => 'You are using the latest version';

  @override
  String newVersionAvailable(Object version) {
    return 'Version $version is available';
  }

  @override
  String get viewUpdate => 'View update';

  @override
  String get oobeWelcomeSlogan =>
      'A beautiful and fast VelaOS / ZeppOS wearable device manager, built with Flutter';

  @override
  String get oobeNext => 'Next';

  @override
  String get oobeBack => 'Back';

  @override
  String get oobeFeatureDevicesTitle => 'Device connection';

  @override
  String get oobeFeatureDevicesBody =>
      'Connect and manage VelaOS and ZeppOS wearable devices';

  @override
  String get oobeFeatureResourcesTitle => 'Resource center';

  @override
  String get oobeFeatureResourcesBody =>
      'Supports the official OronBox source, AstroBox-Repo, BandBBS, and the Amazfit App Store';

  @override
  String get oobeFeaturePluginsTitle => 'JavaScript plugins';

  @override
  String get oobeFeaturePluginsBody =>
      'A high-performance, highly extensible JavaScript plugin system with device interaction';

  @override
  String get oobeFeaturePlatformsTitle => 'Multi-platform';

  @override
  String get oobeFeaturePlatformsBody =>
      'Available on Android, Windows, macOS, Linux, and Web';

  @override
  String get oobeOpenSourceTitle => 'Fully open source';

  @override
  String get oobeOpenSourceBody =>
      'The OronBox client and server both follow GNU AGPL-3.0 with their complete source code available';

  @override
  String get oobeOpenSourceClientLink => 'View client source code';

  @override
  String get oobeOpenSourceServerLink => 'View server source code';

  @override
  String get oobeAgreementHint => 'Please read and scroll to the bottom';

  @override
  String get oobeAgreeCheckbox => 'I have read and agree';

  @override
  String get oobeAgreeContinue => 'Agree and continue';

  @override
  String get oobeAgreedContinue => 'Agreed, continue';

  @override
  String get oobeDeclineExit => 'Exit';

  @override
  String get oobeDeclineWebHint =>
      'You must accept the agreements to continue; please close this page';

  @override
  String get oobeLoginTitle => 'Connect your accounts';

  @override
  String get oobeLoginBandBbsDesc =>
      'Sign in with your BandBBS account to access BandBBS resources and prepare creator services';

  @override
  String get oobeLoginLocalNote =>
      'Xiaomi and Amazfit sign-in run entirely on this device; related data is never sent to any third party other than Xiaomi/Amazfit';

  @override
  String get oobeLoginXiaomiDesc =>
      'Sign in with your Xiaomi account to sync your bound Xiaomi devices';

  @override
  String get oobeLoginHuamiDesc =>
      'Sign in with your Amazfit account to access Amazfit app store resources';

  @override
  String get oobeCdnTesting => 'Testing...';

  @override
  String get oobeCdnSelected => 'Best CDN selected';

  @override
  String get oobeCdnTitle => 'GitHub CDN Speed Test';

  @override
  String get oobeDoneTitle => 'All set';

  @override
  String get oobeDoneBody => 'Start exploring OronBox';

  @override
  String get oobeStart => 'Get started';

  @override
  String get oobeFinish => 'Finish';

  @override
  String get settingsReplayOobe => 'Restart guide';

  @override
  String get settingsReplayOobeDesc =>
      'View the welcome guide and initial setup again';

  @override
  String get creatorAuthorized => 'Authorized';

  @override
  String get back => 'Back';

  @override
  String get creatorConnect => 'Connect';

  @override
  String creatorReviewItemsProgress(Object done, Object total) {
    return 'Requested changes ($done/$total resolved)';
  }

  @override
  String get comments => 'Comments';

  @override
  String get commentEmpty => 'No comments yet';

  @override
  String get commentHint => 'Write a comment';

  @override
  String get commentLoginRequired => 'Sign in with BandBBS to comment';

  @override
  String get commentPending => 'Pending review';

  @override
  String get commentDeleted => 'Deleted';

  @override
  String get commentBlocked =>
      'This comment did not meet the community guidelines';

  @override
  String get commentModerationUnavailable =>
      'Comment moderation is temporarily unavailable';

  @override
  String get commentRateLimited => 'You are commenting too quickly';

  @override
  String get commentReplying => 'Replying to this comment';

  @override
  String get loadMore => 'Load more';

  @override
  String get reply => 'Reply';

  @override
  String get inbox => 'Inbox';

  @override
  String get inboxLoading => 'Loading messages';

  @override
  String get inboxEmpty => 'No messages';

  @override
  String get inboxClear => 'Clear messages';

  @override
  String get inboxClearFailed => 'Could not clear messages. Try again later.';

  @override
  String get cleanMode => 'Feature switches';

  @override
  String get cleanModeDescription =>
      'Manage main navigation, community features, and resource sources';

  @override
  String get cleanPluginsEntry => 'Plugins entry';

  @override
  String get cleanSourceHuamiAppStore => 'Amazfit App Store';

  @override
  String get announcementAcknowledge => 'Got it';

  @override
  String get cleanHomeFeed => 'Home feed';

  @override
  String get cleanExplore => 'Resource library';

  @override
  String get cleanInbox => 'Inbox';

  @override
  String get cleanAnnouncements => 'Announcement popups';

  @override
  String get cleanComments => 'Comments';

  @override
  String get cleanCreator => 'Creator center';

  @override
  String get cleanBandBbsLogin => 'BandBBS sign-in';

  @override
  String get cleanGitHubLogin => 'GitHub sign-in';

  @override
  String get cleanSourceOronBox => 'OronBox source';

  @override
  String get cleanSourceBandBbs => 'BandBBS source';

  @override
  String get cleanSourceAstroBox => 'AstroBox source';

  @override
  String get cleanExploreEntry => 'Explore entry';

  @override
  String get cleanNavigationGroup => 'Main navigation';

  @override
  String get cleanExploreContentGroup => 'Explore content';

  @override
  String get cleanResourceSourcesGroup => 'Resource sources';

  @override
  String get cleanCommunityGroup => 'Community features';

  @override
  String get settingsCategoryAccounts => 'Accounts and authorization';

  @override
  String get settingsCategoryAccountsDescription =>
      'Manage Xiaomi, Amazfit, BandBBS, and GitHub accounts';

  @override
  String get settingsCategoryAppearance => 'Appearance and navigation';

  @override
  String get settingsCategoryAppearanceDescription =>
      'Language, theme, navigation layout, and clean mode';

  @override
  String get settingsCategoryConnection => 'Connections and downloads';

  @override
  String get settingsCategoryConnectionDescription =>
      'Device connections, download behavior, and network endpoints';

  @override
  String get settingsCategorySupport => 'Support and information';

  @override
  String get settingsCategorySupportDescription =>
      'Feedback, about, licenses, acknowledgements, and website';

  @override
  String get settingsCategoryAdvanced => 'Advanced settings';

  @override
  String get settingsCategoryAdvancedDescription =>
      'Window behavior, onboarding, and developer tools';

  @override
  String get oronBoxCoinsTitle => 'Resource coins';

  @override
  String oronBoxCoinsBalance(String balance) {
    return 'Coin balance: $balance';
  }

  @override
  String get oronBoxCoinsCheckin => 'Check in';

  @override
  String get oronBoxCoinsCheckedIn => 'Checked in';

  @override
  String get oronBoxCoinsCheckingIn => 'Checking in';

  @override
  String oronBoxCoinsCheckinReward(int count) {
    return 'Received $count coins';
  }

  @override
  String get oronBoxCoinsDescription =>
      'Check in daily for 1–5 coins and use them to support creators';

  @override
  String resourceFromCollection(String name) {
    return 'From collection $name';
  }

  @override
  String get resourceCoin => 'Coin';

  @override
  String get resourceCoinDialogTitle => 'Coin this resource';

  @override
  String get resourceCoinDialogMessage =>
      'Coin this resource?\n\nThis action cannot be undone\n\nCoins help the resource receive more exposure\n\nThe creator receives 10% of the contributed amount';

  @override
  String get resourceCoinOne => 'Give 1 coin';

  @override
  String get resourceCoinTwo => 'Give 2 coins';

  @override
  String resourceCoinCount(int count) {
    return '$count coins';
  }

  @override
  String get resourceCoinSuccess => 'Coin sent';

  @override
  String get resourceFeatured => 'Featured';

  @override
  String get resourceCollection => 'Collection';

  @override
  String resourceCollectionItems(int count) {
    return '$count resources';
  }

  @override
  String resourceCollectionCoins(int count) {
    return '$count coins in total';
  }

  @override
  String get creatorCollections => 'Resource collections';

  @override
  String get creatorCollectionTag => 'Collection';

  @override
  String get creatorCollectionsDescription =>
      'Group resources of the same type into one collection card';

  @override
  String get creatorNewCollection => 'New collection';

  @override
  String get creatorMoveToCollection => 'Move to collection';

  @override
  String creatorMoveToCollectionConfirm(int count) {
    return 'Move the $count selected resources into this collection?';
  }

  @override
  String get creatorDissolveCollection => 'Dissolve collection';

  @override
  String get creatorResourceList => 'Resources';

  @override
  String get creatorAdditionalLinks => 'Additional links';

  @override
  String get creatorAddLink => 'Add link';

  @override
  String get creatorLinkTitle => 'Link name';

  @override
  String get creatorLinkUrl => 'Link URL';

  @override
  String get creatorCollectionName => 'Collection name';

  @override
  String get creatorCollectionSummary => 'Collection summary';

  @override
  String get creatorCollectionPending => 'Collection metadata is under review';

  @override
  String get creatorCollectionPublished => 'Published';

  @override
  String get creatorCollectionManage => 'Manage resources';

  @override
  String get creatorCollectionRepresentative => 'Representative resource';

  @override
  String get creatorCollectionDeleteConfirm =>
      'Delete this collection? Its resources will only be unlinked.';

  @override
  String get creatorCollectionEdit => 'Edit collection metadata';

  @override
  String get creatorContentAttributes => 'Content attributes';

  @override
  String get creatorAttributeOriginal => 'Original';

  @override
  String get creatorAttributeDerivative => 'Derivative';

  @override
  String get creatorAttributePort => 'Port';

  @override
  String get creatorAttributeTemplateSkin => 'Template skin';

  @override
  String get creatorAttributeAiAssisted => 'AI-assisted';

  @override
  String get creatorAttributeAiGenerated => 'AI-generated';

  @override
  String get creatorAttribution => 'Creators and source';

  @override
  String get creatorCollaborators => 'Co-creators';

  @override
  String get creatorInvite => 'Invite';

  @override
  String get creatorInviteCollaborator => 'Invite a co-creator';

  @override
  String get creatorBandBbsUserId => 'BandBBS user ID';

  @override
  String get creatorNoCollaborators => 'No co-creators linked';

  @override
  String get creatorInvitationPending => 'Waiting for acceptance';

  @override
  String get creatorCollaboratorAccepted => 'Invitation accepted';

  @override
  String get creatorResourceSource => 'Source and authorization';

  @override
  String get creatorOriginalAuthor => 'Original author';

  @override
  String get creatorSourceUrl => 'Source URL';

  @override
  String get creatorLicense => 'License';

  @override
  String get creatorAuthorizationNote => 'Authorization note';

  @override
  String get creatorConfirm => 'Confirm';

  @override
  String get creatorRemove => 'Remove';

  @override
  String get creatorAccept => 'Accept';

  @override
  String get creatorCollaborationInvitations => 'Co-creation invitations';

  @override
  String creatorInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get creatorCoinsLifetime => 'Lifetime coins received';

  @override
  String get creatorCoinsRecent => 'Coins received in 14 days';

  @override
  String get creatorCoinRewards => 'Creator rewards';

  @override
  String get creatorCollectionOrderHint =>
      'Drag to reorder resources in the collection';

  @override
  String get creatorCollectionAddResource => 'Add to collection';

  @override
  String creatorCollectionResourceCount(int count) {
    return '$count resources';
  }

  @override
  String get creatorDecline => 'Decline';
}
