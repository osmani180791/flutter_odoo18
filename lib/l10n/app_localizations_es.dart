// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Tienda Odoo';

  @override
  String get connectTitle => 'Conectar a Odoo';

  @override
  String get urlLabel => 'URL Odoo';

  @override
  String get dbLabel => 'Base de Datos';

  @override
  String get userLabel => 'Usuario';

  @override
  String get passLabel => 'Contraseña';

  @override
  String get loginButton => 'INGRESAR';

  @override
  String get searchHint => 'Buscar producto...';

  @override
  String get categoriesTitle => 'CATEGORÍAS';

  @override
  String get allCategories => 'Todas';

  @override
  String get confirmButton => 'Confirmar';

  @override
  String get saleConfirmed => '¡Venta Confirmada!';

  @override
  String get errorConnection => 'Error de conexión. Revisa HTTPS.';

  @override
  String get errorLogin => 'Usuario o contraseña incorrectos';

  @override
  String get errorDatabase => 'La Base de Datos no existe';

  @override
  String get errorUnknown => 'Error desconocido';

  @override
  String get sessionExpired => 'Tu sesión ha caducado. Ingresa nuevamente.';

  @override
  String get noProducts => 'No se encontraron productos';
}
