// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Odoo商店';

  @override
  String get connectTitle => '连接到 Odoo';

  @override
  String get urlLabel => 'Odoo 网址';

  @override
  String get dbLabel => '数据库';

  @override
  String get userLabel => '用户名';

  @override
  String get passLabel => '密码';

  @override
  String get loginButton => '登录';

  @override
  String get searchHint => '搜索产品...';

  @override
  String get categoriesTitle => '分类';

  @override
  String get allCategories => '全部';

  @override
  String get confirmButton => '确认';

  @override
  String get saleConfirmed => '销售已确认！';

  @override
  String get errorConnection => '连接错误。请检查 HTTPS。';

  @override
  String get errorLogin => '用户名或密码错误';

  @override
  String get errorDatabase => '数据库不存在';

  @override
  String get errorUnknown => '未知错误';

  @override
  String get sessionExpired => '您的会话已过期。请重新登录。';

  @override
  String get noProducts => '未找到产品';
}
