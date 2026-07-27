// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'OronBox';

  @override
  String get homeTab => '首页';

  @override
  String get exploreTab => '探索';

  @override
  String get devicesTab => '设备';

  @override
  String get pluginsTab => '插件';

  @override
  String get pluginImport => '导入插件';

  @override
  String get pluginInstalled => '已安装';

  @override
  String get pluginMarket => '插件市场';

  @override
  String get pluginMarketUnavailable => '插件市场暂未接入';

  @override
  String get pluginEmpty => '尚未安装插件';

  @override
  String get pluginSelectHint => '选择一个插件查看功能';

  @override
  String get pluginFeatures => '功能';

  @override
  String get pluginDetails => '详情';

  @override
  String get pluginNoFeatures => '此插件没有可用功能';

  @override
  String get pluginAuthor => '作者';

  @override
  String get pluginVersion => '版本';

  @override
  String get pluginApiLevel => 'API 级别';

  @override
  String get pluginWebsite => '网站';

  @override
  String get pluginPermissions => '权限';

  @override
  String get pluginInstallConfirmTitle => '插件安装确认';

  @override
  String get pluginUpdateConfirmTitle => '插件更新确认';

  @override
  String get pluginDeclaredPermissions => '此插件声明了以下权限：';

  @override
  String get pluginNoPermissions => '未声明任何权限';

  @override
  String get pluginUpToDate => '已安装且为最新版本';

  @override
  String get pluginUninstallTitle => '卸载插件';

  @override
  String get pluginUninstallMessage => '插件数据也将被删除';

  @override
  String get settingsTab => '设置';

  @override
  String get search => '搜索';

  @override
  String get resourceListView => '列表视图';

  @override
  String get resourceGridView => '卡片视图';

  @override
  String get refresh => '刷新';

  @override
  String get notifications => '通知';

  @override
  String get pendingTasks => '待处理任务';

  @override
  String get manageDevice => '管理设备';

  @override
  String get installLocalResource => '安装本地资源';

  @override
  String get recentUpdates => '最近更新';

  @override
  String get newlyPublished => '最新发布';

  @override
  String get news => '资讯';

  @override
  String get oronBoxNews => 'OronBox 资讯';

  @override
  String get bandbbsNews => 'BandBBS 资讯';

  @override
  String get astroBoxNews => 'AstroBox 资讯';

  @override
  String get resourceLibrary => '资源库';

  @override
  String get creatorCenter => '创作者中心';

  @override
  String get creatorNewResource => '新建资源';

  @override
  String get creatorSlug => '资源标识';

  @override
  String get creatorResourceName => '资源名称';

  @override
  String get creatorResourceSummary => '资源简介';

  @override
  String get creatorSaveDraft => '保存草稿';

  @override
  String get creatorAddArtifact => '添加资源文件';

  @override
  String get creatorReplaceAsset => '重新上传';

  @override
  String get creatorBindDevices => '绑定设备';

  @override
  String get creatorDeleteResource => '删除';

  @override
  String get creatorIconCover => '图标与封面';

  @override
  String get creatorInvalidImage => '无法解码该图片，请使用 PNG/JPEG/WebP';

  @override
  String get creatorInvalidPackage => '该文件不是 Vela 快应用或表盘';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return '正在处理文件 $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return '正在上传 $percent%';
  }

  @override
  String get creatorPublishServer => '服务器处理中…';

  @override
  String get creatorAstroBoxItemId => '资源 ID';

  @override
  String get creatorAstroBoxRepository => '仓库名';

  @override
  String get creatorAstroBoxTags => '标签（逗号分隔）';

  @override
  String get creatorAstroBoxAuthor => '作者（确保与你的AstroBox用户名一致）';

  @override
  String get creatorAstroBoxBindAccount => '绑定 AstroBox 账号';

  @override
  String get replace => '更换';

  @override
  String get delete => '删除';

  @override
  String get creatorSubmitReview => '提交';

  @override
  String get creatorCorrection => '修正并重新提交';

  @override
  String get creatorUpdateResource => '更新资源';

  @override
  String get creatorArchiveAction => '下架';

  @override
  String get creatorArchiveConfirm => '下架后该资源将从商店隐藏，可随时恢复';

  @override
  String get creatorRestoreAction => '恢复上架';

  @override
  String get creatorDeleteConfirm => '将永久删除该草稿资源，无法恢复';

  @override
  String get creatorDeletePublishedConfirm =>
      '将永久删除 OronBox 资源，并同步删除对应的米坛资源，无法恢复\nAstroBox 上已发布的内容不受影响，如需下架请联系 AstroBox-Repo 维护者';

  @override
  String creatorArtifactCount(Object count) {
    return '$count 个安装包';
  }

  @override
  String get creatorKindMismatchTitle => '文件类型不匹配';

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return '这似乎是一个$detected文件，而你正在创建$expected资源。可以继续保留，但提交审核前请确认。';
  }

  @override
  String get creatorKeepFile => '仍然保留';

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return '「$name」仅剩这一台绑定设备，无法移动';
  }

  @override
  String get creatorAssetsReusedHint => '现有安装包与预览图将沿用，无需重新上传';

  @override
  String get creatorRevisionHistory => '版本历史';

  @override
  String creatorUploadProgress(Object progress) {
    return '正在上传 $progress%';
  }

  @override
  String get filter => '筛选';

  @override
  String get importLocalResource => '导入本地资源';

  @override
  String get allDevices => '全部设备';

  @override
  String get currentDevice => '当前设备';

  @override
  String get all => '全部';

  @override
  String get watchfaces => '表盘';

  @override
  String get quickApps => '快应用';

  @override
  String get firmwareTools => '固件 / 工具';

  @override
  String get resourceTypeFontpack => '字体包';

  @override
  String get resourceTypeIconpack => '图标包';

  @override
  String get localResources => '本地资源';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => '本地';

  @override
  String get install => '安装';

  @override
  String get update => '更新';

  @override
  String get manage => '管理';

  @override
  String get description => '描述';

  @override
  String get supportedDevices => '支持的设备';

  @override
  String get resourceProfile => '资源平台与类型';

  @override
  String creatorArtifactProfileMismatch(Object fileName, Object profile) {
    return '文件 $fileName 与所选的 $profile 不匹配，未添加该文件';
  }

  @override
  String get downloads => '下载包';

  @override
  String downloadTimes(int count) {
    return '$count 次下载';
  }

  @override
  String get changelog => '更新日志';

  @override
  String get notFound => '未找到';

  @override
  String get downloadStarted => '开始下载';

  @override
  String get compatible => '兼容';

  @override
  String get incompatible => '不兼容';

  @override
  String get incompatibleSuffix => '，可能无法正常使用';

  @override
  String get openSourcePage => '开源页面';

  @override
  String get myResources => '我的资源';

  @override
  String get drafts => '草稿';

  @override
  String get pendingReview => '审核中';

  @override
  String get published => '已发布';

  @override
  String get creatorStateSuspended => '已下架';

  @override
  String get creatorStateFrozen => '已冻结';

  @override
  String get creatorSuspendedByOwnerNotice => '资源已下架，可继续编辑并重新提交审核，或直接恢复上架';

  @override
  String get creatorSuspendedByAdminNotice =>
      '资源已被管理员下架，可修改后重新提交审核，审核通过后自动恢复上架';

  @override
  String get creatorFrozenNotice => '资源已被管理员冻结，内容不可修改，仅管理员可解除';

  @override
  String creatorModerationReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get creatorBannedTitle => '账号已被封禁';

  @override
  String get creatorBannedDescription => '你的账号已被管理员封禁，无法使用创作者中心。如有疑问请通过工单联系管理员';

  @override
  String get creatorFrozenTitle => '创作者功能已被冻结';

  @override
  String get creatorFrozenDescription =>
      '你的创作者功能已被管理员冻结，暂时无法提交或管理资源。账号的其它功能不受影响';

  @override
  String get creatorBandBbsNoDevices => '请先为资源文件选择支持的设备';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return '无法确定以下设备对应的米坛资源分区：$devices';
  }

  @override
  String get creatorBandBbsSharedCategory => '同一米坛分区的设备绑定了多个安装包，请让每个分区只对应一个包';

  @override
  String get creatorBandBbsUnresolved => '无法自动确定米坛分区';

  @override
  String get creatorOptionalIcon => '图标（可选，1:1）';

  @override
  String get creatorOptionalCover => '封面（可选，3:2）';

  @override
  String get creatorRequiredIcon => '图标（AstroBox 必选，1:1）';

  @override
  String get creatorRequiredCover => '封面（AstroBox 必选，3:2）';

  @override
  String get creatorIconShapeHint => '当前图标不是方形，在 AstroBox 中可能显示异常';

  @override
  String get creatorCoverShapeHint => '当前封面不是 3:2，在 AstroBox 中可能显示异常';

  @override
  String get creatorTermsBandBbs => '米坛社区条款和规则';

  @override
  String get creatorTermsAstroBox => 'AstroBox-Repo 投稿规范';

  @override
  String get creatorTermsAccept => '我已阅读并同意上述发布协议';

  @override
  String get creatorTermsContinue => '进入创作者中心';

  @override
  String get agree => '同意';

  @override
  String get creatorRulesAccept => '我已阅读并同意上述审核标准';

  @override
  String get creatorBandBbsTermsNotice =>
      'OronBox 审核通过后将以此资源信息直接发布到米坛对应分区\n删除 OronBox 资源会同步删除对应的米坛资源';

  @override
  String get creatorAstroBoxTermsNotice =>
      'OronBox 审核通过后将创建资源分仓库并向 AstroBox 官方仓库提交 PR，由 AstroBox 维护者独立审核\n发布后如需下架，请联系 AstroBox-Repo 维护者';

  @override
  String get failed => '失败 / 需处理';

  @override
  String get newResource => '新建资源';

  @override
  String get basicInfo => '基本信息';

  @override
  String get packageFiles => '资源文件';

  @override
  String get deviceSelection => '选择设备';

  @override
  String get deviceFileMapping => '设备-文件映射';

  @override
  String get publishTargets => '发布目标';

  @override
  String get publishPreview => '发布预览';

  @override
  String get reviewStatus => '审核状态';

  @override
  String get scan => '扫描';

  @override
  String get logs => '日志';

  @override
  String get connectedDevices => '已连接设备';

  @override
  String get pairedDevices => '已配对设备';

  @override
  String get discoveredDevices => '发现设备';

  @override
  String get overview => '概览';

  @override
  String get apps => '应用';

  @override
  String get connection => '连接';

  @override
  String get protocol => '协议';

  @override
  String get error => '错误';

  @override
  String get errorBluetoothUnavailable =>
      '蓝牙不可用，请检查蓝牙是否已开启，并确认系统权限已允许 OronBox 使用蓝牙';

  @override
  String get errorBluetoothConnectFailed =>
      '连接失败，请确认蓝牙权限已授予且蓝牙已开启、设备在附近、未被其他工具或设备占用，并在设备端开启“连接新手机”模式后重试';

  @override
  String get errorBluetoothDisconnected => '蓝牙连接已断开，请重新连接设备';

  @override
  String get errorOperationTimeout => '操作超时，请确认设备仍在附近并重试';

  @override
  String get errorDeviceNotReady => '设备尚未准备好，请先连接并完成认证';

  @override
  String get errorBleCharacteristicsMissing =>
      '未找到需要的 BLE 通道，请重新连接设备或检查设备是否支持该功能';

  @override
  String get errorWebSerialUnavailable =>
      '当前浏览器不支持 Web Serial，请使用 Chrome / Edge 等支持 Web Serial 的浏览器';

  @override
  String get errorAccountPasswordIncorrect => '小米账号或密码错误';

  @override
  String get errorAccountTwoFactorIncomplete => '小米账号二次验证未完成，请重新登录';

  @override
  String get errorUnsupportedFileType => '不支持或无法识别的文件类型';

  @override
  String get errorCertificateVerificationFailed =>
      '证书校验失败，如果正在使用代理，请关闭对本应用的 HTTPS 接管，或确认 Flutter/Dart 能信任其证书';

  @override
  String errorUnknownWithDetail(Object detail) {
    return '操作失败：$detail';
  }

  @override
  String get copyLogs => '复制日志';

  @override
  String get exportLogs => '导出日志';

  @override
  String get clearLogs => '清空日志';

  @override
  String get personalCenter => '个人中心';

  @override
  String get accountAndPublishing => '账号与发布';

  @override
  String get appearance => '外观';

  @override
  String get resources => '资源';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox Repo';

  @override
  String get communitySourceBandBbs => '米坛社区';

  @override
  String get communitySourceHuamiAppStore => '华米应用商店';

  @override
  String get devices => '设备';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return '$count 个设备';
  }

  @override
  String get categories => '分区';

  @override
  String get advanced => '高级';

  @override
  String get aboutOronBox => '关于 OronBox';

  @override
  String get openSourceLicenses => '开放源代码许可';

  @override
  String get acknowledgements => '特别鸣谢';

  @override
  String get acknowledgementsDesc => '查看 OronBox 参考与致谢的开源项目';

  @override
  String get developmentTeam => '开发团队';

  @override
  String get deviceNotConnected => '未连接';

  @override
  String get deviceConnected => '已连接';

  @override
  String get deviceDisconnected => '已断开';

  @override
  String get deviceReconnect => '重新连接';

  @override
  String get deviceConnect => '连接设备';

  @override
  String get deviceSwitch => '切换设备';

  @override
  String get deviceCharging => '充电中';

  @override
  String get deviceFeaturesInstallApp => '安装应用';

  @override
  String get deviceFeaturesInstallAppDesc => '从本地文件安装第三方应用';

  @override
  String get deviceFeaturesInstallWatchface => '安装表盘';

  @override
  String get deviceFeaturesInstallWatchfaceDesc => '从本地文件安装表盘';

  @override
  String get deviceFeaturesInstallFirmware => '安装固件';

  @override
  String get deviceFeaturesInstallFirmwareDesc => '刷写固件或工具包';

  @override
  String get deviceFeaturesManageApps => '管理应用';

  @override
  String get deviceFeaturesManageAppsDesc => '查看并卸载已安装的应用';

  @override
  String get deviceFeaturesManageWatchfaces => '管理表盘';

  @override
  String get deviceFeaturesManageWatchfacesDesc => '查看、删除并设置当前表盘';

  @override
  String get zeppOsMoreFeatures => 'Zepp OS 专区';

  @override
  String get zeppOsMoreFeaturesDescription => '探索你的 Zepp OS 设备';

  @override
  String get zeppOsFindDevice => '查找设备';

  @override
  String get zeppOsFindDeviceDescription => '让设备持续振动或响铃，方便在附近快速找到它。';

  @override
  String get zeppOsFindDeviceStart => '开始查找';

  @override
  String get zeppOsFindDeviceStop => '停止查找';

  @override
  String get deviceFeaturesDeviceInfo => '设备信息';

  @override
  String get deviceFeaturesDeviceInfoDesc => '固件、存储空间与详情';

  @override
  String get switchDeviceTitle => '切换设备';

  @override
  String get savedDevices => '已配对设备';

  @override
  String get scanAndAdd => '扫描并添加';

  @override
  String get scanNotFound => '未发现设备';

  @override
  String get noSavedDevices => '没有已配对设备';

  @override
  String get authkey => '认证密钥';

  @override
  String get authkeyPrompt => '输入设备认证密钥';

  @override
  String get authkeyPlaceholder => '认证密钥';

  @override
  String get connectFailed => '连接失败';

  @override
  String deviceConnectingTo(String deviceName) {
    return '正在连接 $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => '正在准备连接…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return '正在建立 $transport 连接…';
  }

  @override
  String get deviceConnectionInitializing => '正在初始化设备协议…';

  @override
  String get deviceConnectionAuthenticating => '正在认证设备…';

  @override
  String get deviceConnectionFetchingStatus => '正在读取设备信息…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => '未识别设备';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      '在网页端，OronBox 通过 Web Serial 连接设备，已保存的设备会保留在当前浏览器中';

  @override
  String get webSerialConnectDialogTitle => '通过 Web Serial 连接';

  @override
  String get webSerialConnectDialogHint =>
      '输入设备认证密钥，并在浏览器弹窗中选择串口，认证密钥会保存在当前浏览器中';

  @override
  String get cancel => '取消';

  @override
  String get deviceActionsDelete => '删除';

  @override
  String get deviceActionsDisconnect => '断开连接';

  @override
  String get deviceActionsShareQR => '分享二维码';

  @override
  String get deviceShareOronBoxCode => '切换为 OronBox 码';

  @override
  String get deviceShareAstroBoxCompatibleCode => '切换 AstroBox 兼容码';

  @override
  String get installTapToSelectFile => '点击选择文件';

  @override
  String get installPackageName => '包名';

  @override
  String get installWatchfaceId => '表盘 ID';

  @override
  String get deviceInfoTitle => '设备信息';

  @override
  String get deviceInfoGroupDevice => '设备';

  @override
  String get deviceInfoGroupSystem => '系统';

  @override
  String get deviceInfoGroupStatus => '状态';

  @override
  String get fieldName => '名称';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldAuthkey => '认证密钥';

  @override
  String get fieldConnectionType => '连接类型';

  @override
  String get fieldCodename => '代号';

  @override
  String get fieldModel => '型号';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => '固件';

  @override
  String get fieldSerial => '序列号';

  @override
  String get fieldBattery => '电量';

  @override
  String get fieldChargeStatus => '充电状态';

  @override
  String get fieldLastCharge => '上次充电';

  @override
  String get fieldStorage => '存储空间';

  @override
  String get appManagementTitle => '应用管理';

  @override
  String get appManagementNone => '没有已安装的应用';

  @override
  String get appManagementShowSystemApps => '显示系统应用';

  @override
  String get watchfaceManagementTitle => '表盘管理';

  @override
  String get watchfaceManagementNone => '没有已安装的表盘';

  @override
  String get open => '打开';

  @override
  String get externalLinkTitle => '跳转外部链接';

  @override
  String externalLinkDescription(String url) {
    return '即将跳转到 $url\n\n该网站由第三方运营，与 OronBox 没有从属关系，安全性未知，请注意辨别，是否继续访问？';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      '这似乎是一个 AstroBox 资源，您也可以在 OronBox内访问并安装';

  @override
  String get continueToWebsite => '继续访问';

  @override
  String get viewInOronBox => '在 OronBox 中查看';

  @override
  String get uninstall => '卸载';

  @override
  String get enable => '设为当前';

  @override
  String get fail => '失败';

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get close => '关闭';

  @override
  String get desktopTrayShow => '显示窗口';

  @override
  String get desktopTrayExit => '退出 OronBox';

  @override
  String get desktopCloseTitle => '退出确认';

  @override
  String get desktopCloseMessage => '您想要退出 OronBox 吗？';

  @override
  String get desktopCloseRemember => '下次不再询问';

  @override
  String get desktopCloseToTray => '最小化到托盘';

  @override
  String get desktopCloseExit => '退出 OronBox';

  @override
  String get settingsDesktopCloseBehavior => '关闭按钮行为';

  @override
  String get settingsDesktopCloseBehaviorDesc => '选择关闭主窗口时执行的操作';

  @override
  String get desktopCloseBehaviorAsk => '每次询问';

  @override
  String get desktopCloseBehaviorExit => '直接退出';

  @override
  String get desktopCloseBehaviorTray => '最小化到托盘';

  @override
  String get multiDevice => '多设备';

  @override
  String get quickApp => '快应用';

  @override
  String get miniprogram => '小程序';

  @override
  String get miniprograms => '小程序';

  @override
  String get watchface => '表盘';

  @override
  String get firmwareTool => '固件 / 工具';

  @override
  String get fontPack => '字体包';

  @override
  String get iconPack => '图标包';

  @override
  String get free => '免费';

  @override
  String get paid => '付费';

  @override
  String get forcePaid => '强制付费';

  @override
  String get version => '版本';

  @override
  String get noDescription => '暂无描述';

  @override
  String get preview => '预览';

  @override
  String get productAbout => '关于';

  @override
  String get productDeviceRequirements => '系统要求';

  @override
  String get productOtherVersions => '其他版本';

  @override
  String get productInQueue => '已在队列';

  @override
  String get productShare => '分享';

  @override
  String get productViewOnBandBBS => '在米坛查看';

  @override
  String get changeCdn => '切换 CDN';

  @override
  String get cdnErrorTitle => 'AstroBox 数据加载失败';

  @override
  String cdnErrorMessage(Object cdn, Object path) {
    return '当前 CDN（$cdn）无法获取 $path，是否切换 CDN？';
  }

  @override
  String get cdnErrorContinue => '切换 CDN';

  @override
  String get cdnErrorCancel => '取消';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsSource => '下载';

  @override
  String get settingsSourceRestart => '重启后生效';

  @override
  String get settingsQueue => '队列';

  @override
  String get settingsInstall => '安装';

  @override
  String get settingsTools => '神秘工具';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAccountLoginBBS => '登录 BandBBS';

  @override
  String get settingsAccountLoginBBSDesc => '登录以访问米坛资源';

  @override
  String get settingsAccountBandBbsSigningIn => '正在登录';

  @override
  String get settingsAccountBandBbsOpenedBrowser => '已打开浏览器，请完成 BandBBS 授权';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBS 登录成功';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS 登录失败';

  @override
  String get settingsBandBbsAccountRequired => '请先在设置中登录米坛账号';

  @override
  String settingsAccountBandBbsUser(Object userId) {
    return '用户 ID：$userId';
  }

  @override
  String get settingsAccountBBSAccount => '米坛账号';

  @override
  String get bandBbsAccountTitle => '米坛账号';

  @override
  String get bandBbsPurchasedResources => '已购资源';

  @override
  String get bandBbsResourceId => '资源 ID';

  @override
  String get bandBbsResourceIdHint => '输入米坛资源 ID';

  @override
  String get bandBbsQueryResource => '查询';

  @override
  String get bandBbsOpenResource => '在米坛查看';

  @override
  String get bandBbsLogout => '退出登录';

  @override
  String get bandBbsLoggedOut => '已退出登录';

  @override
  String accountSignOutTitle(Object accountName) {
    return '退出 $accountName？';
  }

  @override
  String get accountSignOutMessage => '退出后，如需继续使用相关功能，需要重新登录。';

  @override
  String get bandBbsLoadPreviews => '加载资源帖预览图';

  @override
  String get bandBbsLoadPreviewsDesc => '在资源列表中自动加载帖子附件预览图';

  @override
  String get bandBbsShowAllCategories => '显示所有资源分区';

  @override
  String get bandBbsShowAllCategoriesDesc => '包含默认隐藏的未适配设备分区';

  @override
  String get settingsAccountSyncDevices => '同步设备';

  @override
  String get settingsAccountSyncDevicesDesc => '登录小米账号同步配对设备';

  @override
  String get settingsMiAccount => '小米账号';

  @override
  String get settingsMiAccountDesc => '登录并同步已绑定设备 authkey';

  @override
  String get settingsMiAccountLoginTitle => '小米账号登录';

  @override
  String get settingsMiAccountUsername => '账号';

  @override
  String get settingsMiAccountPassword => '密码';

  @override
  String get settingsMiAccountRememberCredentials => '记住账号密码';

  @override
  String get settingsMiAccountLoginAndSync => '登录并同步';

  @override
  String get settingsMiAccountMissingCredentials => '请输入小米账号和密码';

  @override
  String get settingsMiAccountTwoFactorPrompt => '请在验证页面完成小米账号二次验证';

  @override
  String get settingsMiAccountLoginWindowClosed => '登录窗口已关闭';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return '已同步 $count 台小米设备';
  }

  @override
  String get settingsHuamiAccount => '华米账号';

  @override
  String get settingsHuamiAccountDesc => '登录并保存访问 Zepp 商店所需凭据';

  @override
  String get settingsHuamiAccountSigningIn => '正在登录';

  @override
  String get settingsHuamiAccountSignedIn => '华米账号登录成功';

  @override
  String settingsHuamiAccountUser(Object username) {
    return '账号：$username';
  }

  @override
  String get settingsHuamiAccountLoginTitle => '华米账号登录';

  @override
  String get settingsHuamiAccountUsername => '账号';

  @override
  String get settingsHuamiAccountPassword => '密码';

  @override
  String get settingsHuamiAccountRememberCredentials => '记住密码';

  @override
  String get settingsHuamiAccountLoginAndSave => '登录并保存';

  @override
  String get settingsHuamiAccountMissingCredentials => '请输入华米账号和密码';

  @override
  String get settingsHuamiAccountRequired => '请先在设置中登录华米账号';

  @override
  String get understood => '我知道了';

  @override
  String get settingsGeneralLanguage => '语言';

  @override
  String get settingsGeneralLanguageDesc => '更改应用显示语言';

  @override
  String get settingsWideNavigationPosition => '导航位置';

  @override
  String get settingsWideNavigationPositionDesc => '调整宽屏状态下侧边标签的位置';

  @override
  String get settingsWideNavigationPositionBottom => '置底';

  @override
  String get settingsWideNavigationPositionCenter => '居中';

  @override
  String get settingsWideNavigationPositionSplit => '分离';

  @override
  String get settingsGeneralTranslateTeam => '翻译贡献者';

  @override
  String get settingsAutoReconnectTitle => '自动回连';

  @override
  String get settingsAutoReconnectDesc => '启动时自动连接上次配对的设备';

  @override
  String get settingsGeneralDebugWindow => '调试窗口';

  @override
  String get settingsGeneralDebugWindowDesc => '显示悬浮调试面板';

  @override
  String get settingsSourceOfficialCdn => 'GitHub 源 CDN';

  @override
  String get settingsSourceOfficialCdnDesc => '获取托管在 GitHub 上的社区索引使用的 CDN';

  @override
  String get settingsQueueAutoInstall => '自动安装';

  @override
  String get settingsQueueAutoInstallDesc => '下载完成后自动开始安装';

  @override
  String get settingsQueueDontClear => '不清除安装队列';

  @override
  String get settingsQueueDontClearDesc => '保留已完成的安装队列项';

  @override
  String get settingsInstallSendInterval => '分包间隔';

  @override
  String get settingsInstallSendIntervalDesc => '安装时蓝牙分包发送延迟';

  @override
  String get settingsToolsUnlockCode => '计算解锁码';

  @override
  String get settingsToolsUnlockCodeDesc => '通过 MAC 和 SN 生成小米穿戴解锁码';

  @override
  String get settingsToolsDialogTitle => '解锁码';

  @override
  String get settingsToolsMac => 'MAC 地址';

  @override
  String get settingsToolsSn => '序列号';

  @override
  String get settingsToolsNoticeTitle => '警告';

  @override
  String get settingsToolsNoticeBody => '解锁可能导致保修失效或数据丢失，请自行承担风险';

  @override
  String get settingsToolsAgree => '我已了解风险';

  @override
  String get settingsToolsCalculate => '计算';

  @override
  String get settingsToolsResult => '结果';

  @override
  String get settingsToolsDialogUsage => '用法';

  @override
  String get settingsToolsDialogUsageInfo => '输入设备上显示的 MAC 地址和序列号';

  @override
  String get settingsAboutAboutAstrobox => '关于 OronBox';

  @override
  String get settingsAboutAboutAstroboxDesc => '版本、更新日志和团队';

  @override
  String get settingsAboutDisclaimer => '免责声明';

  @override
  String get settingsAboutDisclaimerDesc => '用户协议与责任声明';

  @override
  String get settingsAboutOpenlog => '日志文件夹';

  @override
  String get settingsAboutOpenlogDesc => '在文件管理器中打开日志目录';

  @override
  String get settingsAboutWebsite => '官方网站';

  @override
  String get settingsAboutWebsiteDesc => '访问 oronbox.zxor.org';

  @override
  String get settingsAboutQQ => 'QQ 群';

  @override
  String get settingsAboutQQDesc => '加入社区群聊';

  @override
  String get settingsAboutLicences => '开放源代码许可';

  @override
  String get settingsAboutLicencesDesc => '查看 Flutter、依赖库与开源组件许可证';

  @override
  String get settingsGuest => '访客';

  @override
  String get settingsTapToSignIn => '点击登录';

  @override
  String get settingsConnected => '已连接';

  @override
  String get settingsNotConnected => '未连接';

  @override
  String get settingsNotSet => '未设置';

  @override
  String get settingsOn => '开启';

  @override
  String get settingsOff => '关闭';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsLight => '浅色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsOledDark => 'OLED 深色';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeModeDesc => '更改应用主题外观';

  @override
  String get settingsDynamicColor => '动态取色';

  @override
  String get settingsDynamicColorDesc => '使用系统主题色调整应用配色';

  @override
  String get settingsColorScheme => '配色方案';

  @override
  String get settingsColorSchemeDesc => '选择应用主题色';

  @override
  String get settingsColorSchemePink => '粉色';

  @override
  String get settingsColorSchemePurple => '紫色';

  @override
  String get settingsColorSchemeTeal => '青色';

  @override
  String get settingsColorSchemeGreen => '绿色';

  @override
  String get settingsColorSchemeRed => '红色';

  @override
  String get settingsColorSchemeAmber => '琥珀色';

  @override
  String get settingsDesktopAccentSource => 'Linux 主题色来源';

  @override
  String get settingsDesktopAccentSourceDesc => '选择从 GTK 或 Qt 读取主题色';

  @override
  String get settingsDesktopAccentSourceSystem => '自动';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsConfirm => '确认';

  @override
  String get settingsOpen => '打开';

  @override
  String get settingsVisit => '访问';

  @override
  String get settingsTeamSlogan => '一款面向 VelaOS 与 ZeppOS 的可穿戴设备管理工具';

  @override
  String get settingsTeamGitHub => 'GitHub 仓库';

  @override
  String get settingsTeamMembers => '团队成员';

  @override
  String get settingsTeamRoleMain => '主开发 / 设计';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS 实现';

  @override
  String get settingsAboutSoftware => '关于软件';

  @override
  String get settingsAboutSoftwareDesc => '版本、更新日志与开发团队';

  @override
  String get settingsAboutSoftwareTagline =>
      '一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建';

  @override
  String get settingsAboutSoftwareRepository => '打开 GitHub 仓库';

  @override
  String get settingsAboutSoftwareTeam => '开发团队';

  @override
  String get settingsAboutSoftwareReleaseName => '当前版本：开发预览';

  @override
  String get settingsAboutSoftwareReleaseBody =>
      '本次更新内容包括：\n• 新增系统强调色支持与主题细节优化\n• 重构资源详情页与列表页，支持按设备分组筛选\n• 用“关于软件”页替换原“团队页”；设置页全面国际化\n• 优化小米 SAR 控制器发送失败错误处理\n• 稳定 Linux 经典 SPP 连接的取消与超时行为\n• 更新 ARB 本地化文案与生成的 l10n 文件';

  @override
  String get settingsAboutSoftwareBuildInfo => '构建信息';

  @override
  String get settingsAboutSoftwareCopyright =>
      'Copyright © OronBox contributors';

  @override
  String get acknowledgementsKazumi => 'Material Design 组件与界面设计参考';

  @override
  String get acknowledgementsAstroBoxPublic => '界面结构、资源流程与交互设计参考';

  @override
  String get acknowledgementsAstroBoxNgCore => '小米设备协议、安装流程与传输行为参考';

  @override
  String get acknowledgementsAstroBoxNgBluetooth => '蓝牙连接行为参考';

  @override
  String get acknowledgementsAstroBoxNgAccount => '小米账号登录、设备同步与 authkey 获取流程参考';

  @override
  String get acknowledgementsAstroBoxNgProvider => '社区资源索引、CDN 与清单解析流程参考';

  @override
  String get acknowledgementsAstroBoxNgAppWasm => 'Web Serial 与浏览器端连接流程参考';

  @override
  String get acknowledgementsGadgetbridge => 'ZeppOS 与可穿戴设备协议研究参考';

  @override
  String get resourceHomeEmptyTitle => '首页未完成';

  @override
  String get resourceHomeEmptySubtitle => '您可以在资源库获取资源';

  @override
  String get resourceCreatorEmptyTitle => '创作者中心未完成';

  @override
  String get resourceCreatorEmptySubtitle => '您可以在资源库管理已获取资源';

  @override
  String get openResourceLibrary => '打开资源库';

  @override
  String get downloadQueueTitle => '下载队列';

  @override
  String get installQueueTitle => '安装队列';

  @override
  String get queueClear => '清空';

  @override
  String get queueStart => '开始';

  @override
  String get queuePause => '暂停';

  @override
  String get downloadQueueEmpty => '暂无下载任务';

  @override
  String get installQueueEmpty => '暂无安装任务';

  @override
  String get localAppInstall => '本地应用安装';

  @override
  String get localWatchfaceInstall => '本地表盘安装';

  @override
  String get localFirmwareInstall => '本地固件安装';

  @override
  String get queueStatusPending => '等待中';

  @override
  String queueStatusDownloading(String percent) {
    return '下载中 $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return '安装中 $percent%';
  }

  @override
  String get queueStatusCompleted => '已完成';

  @override
  String get queueStatusFailed => '失败';

  @override
  String get queueDragToInstall => '松开以加入安装队列';

  @override
  String queueAddedFiles(int count) {
    return '已加入安装队列：$count 个文件';
  }

  @override
  String get installQueueReadFailed => '读取失败';

  @override
  String get installQueueUnsupportedFile => '不支持的文件';

  @override
  String timeTodayAt(Object time) {
    return '今天 $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return '昨天 $time';
  }

  @override
  String get settingsAccountBandBbsAccount => '米坛账号';

  @override
  String get settingsAccountGitHub => 'GitHub 账号';

  @override
  String get settingsAccountGitHubDesc => '连接以用自己的账号发布 AstroBox 资源';

  @override
  String get githubAccountNeedsBandBbs => '登录米坛账号后可连接';

  @override
  String get bandBbsPublishAuthTitle => '发布授权';

  @override
  String get bandBbsResourceQueryTitle => '安装已购付费资源';

  @override
  String get settingsAboutLogs => '运行日志';

  @override
  String get settingsAboutLogsDescription => '查看、导出和管理应用与设备的运行日志';

  @override
  String settingsAboutLogsSize(Object size) {
    return '当前占用 $size';
  }

  @override
  String get settingsAboutLogsExport => '导出';

  @override
  String settingsAboutLogsExported(Object path) {
    return '已导出到 $path';
  }

  @override
  String get settingsAboutLogsEmpty => '暂无可导出的日志';

  @override
  String get settingsAboutLogsClear => '清理';

  @override
  String get settingsDeviceLogsPull => '拉取设备日志';

  @override
  String get settingsDeviceLogsTip =>
      '开始后将从当前连接的小米穿戴设备拉取日志，过程可能需要较长时间。请勿将应用切换到后台或关闭设备屏幕，以免操作中断。';

  @override
  String get settingsDeviceLogsStart => '开始';

  @override
  String get settingsDeviceLogsPulling => '正在拉取设备日志';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return '已接收 $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return '设备日志已保存为 $name';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return '设备日志拉取失败：$error';
  }

  @override
  String get settingsAboutLogsClearConfirm => '将删除当前会话之外的全部日志文件。';

  @override
  String get settingsAboutLogsOpen => '打开日志文件夹';

  @override
  String get settingsAboutLogsOpenFailed => '无法打开日志文件夹';

  @override
  String get settingsLogsFileList => '日志文件';

  @override
  String get settingsAboutLogsWarningTitle => '敏感信息警告';

  @override
  String get settingsAboutLogsWarningMessage =>
      '日志可能包含米坛/小米/华米登录凭证等敏感信息，请勿随意分享给除 OronBox 官方维护者以外的其他人！';

  @override
  String get pluginPermissionRequestTitle => '插件权限请求';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '“$plugin”希望$operation。';
  }

  @override
  String get pluginPermissionOnce => '允许本次';

  @override
  String get pluginPermissionSession => '本次运行中允许';

  @override
  String get pluginPermissionAlways => '始终允许';

  @override
  String get pluginPermissionDeny => '拒绝';

  @override
  String get pluginPermissionOpenExternal => '打开外部链接';

  @override
  String get pluginPermissionPickFile => '访问宿主文件';

  @override
  String get pluginPermissionExportFile => '将文件导出到宿主环境';

  @override
  String get pluginPermissionNetwork => '访问网络';

  @override
  String get pluginPermissionInterconnect => '与设备应用通信';

  @override
  String get pluginPermissionProvider => '注册资源源';

  @override
  String get pluginPermissionReadDevice => '读取设备信息';

  @override
  String get pluginPermissionOperateDevice => '操作设备';

  @override
  String get pluginPermissionObserveProtocol => '读取设备原始协议数据';

  @override
  String get pluginPermissionSendProtocol => '向设备发送原始协议数据';

  @override
  String get pluginPermissionReadAppSide => '读取 AppSide 脚本与事件';

  @override
  String get pluginPermissionOperateAppSide => '管理 AppSide 会话';

  @override
  String get pluginErrorTitle => '插件运行错误';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '“$plugin”运行时发生错误：\n\n$error';
  }

  @override
  String get pluginErrorClearData => '清除插件数据';

  @override
  String get pluginErrorUninstall => '卸载插件';

  @override
  String get pluginErrorSafeMode => '进入安全模式';

  @override
  String get pluginSafeModeTitle => '插件安全模式已启用';

  @override
  String get pluginSafeModeDescription => '所有插件均已停止，退出安全模式后才会重新加载。';

  @override
  String get pluginSafeModeExit => '退出安全模式';

  @override
  String get devTools => 'DevTools';

  @override
  String get devToolsDescriptionDesktop => '启用独立的 DevTools 窗口';

  @override
  String get devToolsDescriptionEntry => '在页面顶栏显示 DevTools 入口';

  @override
  String get devToolsOperationFailed => '无法更改 DevTools 状态';

  @override
  String get resourceTypeErrorTitle => '错误的资源类型';

  @override
  String get resourceTypeUnknownTitle => '无法识别的资源类型';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return '这似乎是一个$detectedType资源，但您选择的资源类型为$selectedType，请选择安装方式';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return '这似乎是一个 $resourcePlatform 设备的$resourceType资源，当前连接的设备为 $deviceName（$devicePlatform），不支持安装，强行安装可能引发不可预知的问题';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'OronBox 无法识别此文件的实际资源类型，是否仍以$selectedType安装？';
  }

  @override
  String get resourceInstallCancel => '取消安装';

  @override
  String get resourceInstallAcknowledge => '我知道了';

  @override
  String get resourceInstallForce => '强制安装';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return '强制安装 (${seconds}s)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return '继续以$type安装';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return '继续以$type安装 (${seconds}s)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return '以$type安装';
  }

  @override
  String get resourceTypeApp => '小程序';

  @override
  String get resourceTypeQuickApp => '快应用';

  @override
  String get resourceTypeWatchface => '表盘';

  @override
  String get resourceTypeFirmware => '固件';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return '安装$type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return '确认要安装 $fileName（$fileSize）吗？';
  }

  @override
  String get resourceInstallConfirm => '确认安装';

  @override
  String get resourceName => '资源名称';

  @override
  String get resourceSummary => '简短说明';

  @override
  String get previewImages => '预览图';

  @override
  String get add => '添加';

  @override
  String get submit => '提交';

  @override
  String get currentAccount => '当前账号';

  @override
  String get submitForReview => '提交审核';

  @override
  String get creatorConfirmTitle => '确认发布计划';

  @override
  String get creatorConfirmOronBox => '资源将提交至 OronBox 审核，审核通过后在 OronBox 资源中发布';

  @override
  String creatorConfirmBandBbs(Object category) {
    return '审核通过后将直接发布到米坛分区 $category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return '审核通过后将由 GitHub 用户 $owner 创建或更新仓库 $repository，并向 ABRepo 提交 PR';
  }

  @override
  String get creatorBandBbsDirectPublish => 'OronBox 审核通过之后直接发布到米坛社区';

  @override
  String get bandBbsCategoryId => '米坛资源分区 ID';

  @override
  String get bandBbsCategory => '米坛资源分区';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return 'OronBox 审核通过之后创建资源分仓库 $repository 并向 AstroBox 官方仓库提交 PR';
  }

  @override
  String get creatorOronBoxRequired => '必选，资源需经过 OronBox 审核';

  @override
  String get creatorOpenInOronBox => '在 OronBox 中查看';

  @override
  String get creatorAstroTags => 'AstroBox 标签';

  @override
  String get creatorAstroTagsHint => '使用逗号或分号分隔多个标签';

  @override
  String get retry => '重试';

  @override
  String get reviewNote => '审核意见';

  @override
  String get creatorReviewRejected => '资源已被打回';

  @override
  String creatorReviewState(Object state) {
    return '审核状态：$state';
  }

  @override
  String get creatorOperationWorking => '正在处理';

  @override
  String get creatorOperationRefreshing => '正在刷新创作者数据';

  @override
  String get creatorOperationCreating => '正在创建资源';

  @override
  String get creatorOperationSaving => '正在保存更改';

  @override
  String get creatorOperationUploading => '正在上传并处理文件';

  @override
  String get creatorOperationBinding => '正在更新支持设备';

  @override
  String get creatorOperationDeleting => '正在删除';

  @override
  String get creatorOperationSubmitting => '正在提交审核';

  @override
  String get creatorOperationAuthorizing => '正在等待授权';

  @override
  String get creatorResolvingPublicationTarget => '正在识别发布分区';

  @override
  String get creatorSessionExpired => 'OronBox 登录已过期，请重新登录后再授权';

  @override
  String get creatorStateApproved => '审核通过';

  @override
  String get creatorStateExternalReview => '外部审核中';

  @override
  String get creatorStateFailed => '发布失败';

  @override
  String get creatorStateSuperseded => '已被新版本取代';

  @override
  String get creatorStateCancelled => '已取消';

  @override
  String get creatorNoResources => '还没有创建资源';

  @override
  String get creatorLoginRequiredTitle => '登录后使用创作者中心';

  @override
  String get creatorLoginRequiredDescription =>
      '需要登录米坛并连接 OronBox 账号，才能创建、编辑和提交资源';

  @override
  String get creatorLoginAction => '登录米坛';

  @override
  String get creatorSelectHint => '从左侧选择资源，或新建一个资源';

  @override
  String get creatorOronBoxReady => 'OronBox 与米坛读取权限可用';

  @override
  String get creatorBandBbsWriteReady => '已获得米坛资源发布权限';

  @override
  String get creatorBandBbsWriteMissing => '未获得米坛写入授权，无法发布到米坛';

  @override
  String creatorGitHubOwnPublishReady(Object login) {
    return '已连接 GitHub，可使用 $login 发布';
  }

  @override
  String get creatorGitHubOwnPublishMissing =>
      '未连接 GitHub，无法以自己的账号发布 AstroBox 资源';

  @override
  String get creatorAuthorize => '授权';

  @override
  String get openCreatorCenter => '进入创作者中心';

  @override
  String get creatorGitHubNotConnected => '尚未连接 GitHub 账号';

  @override
  String creatorGitHubConnected(Object login) {
    return '已连接 GitHub 账号 $login';
  }

  @override
  String get githubAuthorizationFailed => '无法打开 GitHub 授权页面';

  @override
  String get githubAuthorizationTimedOut => 'GitHub 授权超时';

  @override
  String get authorize => '授权';

  @override
  String get creatorBandBbsAuthorized => '已获得米坛资源发布授权';

  @override
  String get creatorBandBbsAuthorizationRequired => '需要单独授权 OronBox 代表您发布米坛资源';

  @override
  String get connect => '连接';

  @override
  String get editResource => '编辑资源';

  @override
  String get legalAndPrivacy => '协议与隐私';

  @override
  String get legalAndPrivacyDesc => '查看用户协议、隐私说明和资源规则';

  @override
  String get termsTitle => '用户协议与免责声明';

  @override
  String get privacyTitle => '隐私说明';

  @override
  String get resourcePublishingTitle => '资源发布协议';

  @override
  String get reviewRulesTitle => '资源审核规则';

  @override
  String get feedbackTitle => '意见反馈';

  @override
  String get feedbackDesc => '提交问题、建议并查看答复';

  @override
  String get reportResource => '举报资源';

  @override
  String get reportComment => '举报评论';

  @override
  String get report => '举报';

  @override
  String get feedbackSubject => '标题';

  @override
  String get feedbackMessage => '意见或问题';

  @override
  String get reportReason => '举报理由';

  @override
  String get submitted => '已提交';

  @override
  String get myFeedback => '我的反馈';

  @override
  String get noFeedback => '暂无记录';

  @override
  String get feedbackProcessing => '处理中';

  @override
  String get feedbackReplied => '已答复';

  @override
  String get feedbackOpen => '待处理';

  @override
  String get feedbackResolved => '已解决';

  @override
  String get feedbackDismissed => '已驳回';

  @override
  String get feedbackClosed => '已关闭';

  @override
  String get feedbackLoading => '正在加载工单';

  @override
  String get feedbackNewTicket => '新建工单';

  @override
  String get feedbackYou => '我';

  @override
  String get feedbackResolution => '处理结论';

  @override
  String get feedbackReplyHint => '回复此工单';

  @override
  String get feedbackConversationClosed => '该工单已关闭，无法继续回复';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get updateChecking => '正在检查更新…';

  @override
  String get updateCheckFailed => '暂时无法检查更新';

  @override
  String get latestVersionInstalled => '当前已是最新版本';

  @override
  String newVersionAvailable(Object version) {
    return '发现新版本 $version';
  }

  @override
  String get viewUpdate => '查看更新';

  @override
  String get oobeWelcomeSlogan =>
      '一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建';

  @override
  String get oobeNext => '下一步';

  @override
  String get oobeBack => '上一步';

  @override
  String get oobeFeatureDevicesTitle => '设备连接';

  @override
  String get oobeFeatureDevicesBody => '连接并管理 VelaOS 与 ZeppOS 可穿戴设备';

  @override
  String get oobeFeatureResourcesTitle => '资源中心';

  @override
  String get oobeFeatureResourcesBody =>
      '支持 OronBox 官方源、AstroBox-Repo、米坛社区与华米应用商店';

  @override
  String get oobeFeaturePluginsTitle => 'JavaScript 插件';

  @override
  String get oobeFeaturePluginsBody => '高性能、高扩展性的 JavaScript 插件系统，支持插件与设备交互';

  @override
  String get oobeFeaturePlatformsTitle => '多端适配';

  @override
  String get oobeFeaturePlatformsBody => '支持 Android、Windows、macOS、Linux 与 Web';

  @override
  String get oobeOpenSourceTitle => '完全开源';

  @override
  String get oobeOpenSourceBody => 'OronBox 客户端与服务端均遵循 AGPL-3.0 开放完整源代码';

  @override
  String get oobeOpenSourceClientLink => '查看客户端源码';

  @override
  String get oobeOpenSourceServerLink => '查看服务端源码';

  @override
  String get oobeAgreementHint => '请阅读并滚动到底部';

  @override
  String get oobeAgreeCheckbox => '我已阅读并同意';

  @override
  String get oobeAgreeContinue => '同意并继续';

  @override
  String get oobeAgreedContinue => '已同意，继续';

  @override
  String get oobeDeclineExit => '退出';

  @override
  String get oobeDeclineWebHint => '不接受协议将无法继续使用，请关闭本页面';

  @override
  String get oobeLoginTitle => '登录账号';

  @override
  String get oobeLoginBandBbsDesc => '登录米坛账号以访问米坛资源并准备使用创作者服务';

  @override
  String get oobeLoginLocalNote => '小米和华米账号登录均在本地完成，相关数据不会被发送给小米/华米以外的第三方';

  @override
  String get oobeLoginXiaomiDesc => '登录小米账号以同步已绑定的小米设备';

  @override
  String get oobeLoginHuamiDesc => '登录华米账号以访问华米应用商店资源';

  @override
  String get oobeCdnTesting => '测速中...';

  @override
  String get oobeCdnSelected => '已选择最佳 CDN';

  @override
  String get oobeCdnTitle => 'GitHub CDN 测速';

  @override
  String get oobeDoneTitle => '一切就绪';

  @override
  String get oobeDoneBody => '开始探索 OronBox 吧';

  @override
  String get oobeStart => '开始使用';

  @override
  String get oobeFinish => '完成';

  @override
  String get settingsReplayOobe => '重新引导';

  @override
  String get settingsReplayOobeDesc => '再次查看欢迎向导与初始设置';

  @override
  String get creatorAuthorized => '已授权';

  @override
  String get back => '返回';

  @override
  String get creatorConnect => '连接';

  @override
  String creatorReviewItemsProgress(Object done, Object total) {
    return '需要修改（已解决 $done/$total）';
  }

  @override
  String get comments => '评论';

  @override
  String get commentEmpty => '还没有评论';

  @override
  String get commentHint => '写下评论';

  @override
  String get commentLoginRequired => '登录米坛账号后参与评论';

  @override
  String get commentPending => '待审核';

  @override
  String get commentDeleted => '已删除';

  @override
  String get commentBlocked => '评论未通过社区规范';

  @override
  String get commentModerationUnavailable => '审核服务暂不可用';

  @override
  String get commentRateLimited => '评论过于频繁，请稍后再试';

  @override
  String get commentReplying => '正在回复这条评论';

  @override
  String get loadMore => '加载更多';

  @override
  String get reply => '回复';

  @override
  String get inbox => '消息箱';

  @override
  String get inboxEmpty => '暂无消息';

  @override
  String get inboxClear => '清空消息';

  @override
  String get inboxClearFailed => '清空消息失败，请稍后重试';

  @override
  String get cleanMode => '功能开关';

  @override
  String get cleanModeDescription => '管理主导航、社区功能与资源源';

  @override
  String get cleanPluginsEntry => '插件主入口';

  @override
  String get cleanSourceHuamiAppStore => '华米应用商店';

  @override
  String get announcementAcknowledge => '知道了';

  @override
  String get cleanHomeFeed => '首页信息流';

  @override
  String get cleanExplore => '资源库';

  @override
  String get cleanInbox => '消息箱';

  @override
  String get cleanAnnouncements => '公告弹窗';

  @override
  String get cleanComments => '评论区';

  @override
  String get cleanCreator => '创作者中心';

  @override
  String get cleanBandBbsLogin => '米坛登录';

  @override
  String get cleanGitHubLogin => 'GitHub 登录';

  @override
  String get cleanSourceOronBox => 'OronBox 资源源';

  @override
  String get cleanSourceBandBbs => '米坛资源源';

  @override
  String get cleanSourceAstroBox => 'AstroBox 资源源';

  @override
  String get cleanExploreEntry => '探索主入口';

  @override
  String get cleanNavigationGroup => '主导航';

  @override
  String get cleanExploreContentGroup => '探索内容';

  @override
  String get cleanResourceSourcesGroup => '资源源';

  @override
  String get cleanCommunityGroup => '社区能力';

  @override
  String get settingsCategoryAccounts => '账号与授权';

  @override
  String get settingsCategoryAccountsDescription => '管理小米、华米、米坛和 GitHub 账号';

  @override
  String get settingsCategoryAppearance => '外观与导航';

  @override
  String get settingsCategoryAppearanceDescription => '语言、主题、导航布局与纯净模式';

  @override
  String get settingsCategoryConnection => '连接与下载';

  @override
  String get settingsCategoryConnectionDescription => '设备连接、下载行为与网络节点';

  @override
  String get settingsCategorySupport => '支持与信息';

  @override
  String get settingsCategorySupportDescription => '反馈、关于、许可、致谢与官方网站';

  @override
  String get settingsCategoryAdvanced => '高级设置';

  @override
  String get settingsCategoryAdvancedDescription => '窗口行为、重新引导与开发工具';
}
