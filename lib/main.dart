import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Título dinámico
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      // CONFIGURACIÓN DE IDIOMAS
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'), // Español
        Locale('zh'), // Chino
      ],
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// PANTALLA DE LOGIN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // DATOS DE PRODUCCIÓN
  final TextEditingController _urlCtrl = TextEditingController(text: 'https://www.merkadocroqueta.com');
  final TextEditingController _dbCtrl = TextEditingController(text: 'merkadocroqueta');
  final TextEditingController _userCtrl = TextEditingController(text: 'admin');
  final TextEditingController _passCtrl = TextEditingController(text: 'admin');

  bool _isLoading = false;

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!; 
    try { FocusScope.of(context).unfocus(); } catch (_) {}
    
    setState(() => _isLoading = true);
    
    try {
      if (!_urlCtrl.text.startsWith('http')) {
        throw Exception("URL Error");
      }

      final client = OdooClient(_urlCtrl.text);
      
      // Intentar Autenticación
      await client.authenticate(_dbCtrl.text, _userCtrl.text, _passCtrl.text);
      
      final uid = client.sessionId!.userId;
      
      // Solicitar Datos de Empresa
      final resUsers = await client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[['id', '=', uid]]],
        'kwargs': {
          'fields': ['partner_id', 'company_id'], 
          'limit': 1
        },
      });
      
      final partnerId = resUsers[0]['partner_id'][0] as int;
      final companyId = resUsers[0]['company_id'][0] as int;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TiendaScreen(
            client: client, 
            partnerId: partnerId,
            companyId: companyId
          )),
        );
      }
    } catch (e) {
      String errorTexto = e.toString();
      String mensajeMostrar = l10n.errorUnknown;

      if (errorTexto.contains("Access Denied") || errorTexto.contains("authentication failed")) {
        mensajeMostrar = l10n.errorLogin;
      } else if (errorTexto.contains("SocketException") || errorTexto.contains("XMLHttpRequest") || errorTexto.contains("ClientException")) {
        mensajeMostrar = l10n.errorConnection;
      } else if (errorTexto.contains("database")) {
        mensajeMostrar = l10n.errorDatabase;
      } else {
        mensajeMostrar = "${l10n.errorUnknown}: ${errorTexto.replaceAll('Exception:', '').trim()}";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mensajeMostrar, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos una verificación segura para evitar error si l10n aún no cargó
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const CircularProgressIndicator();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store_mall_directory, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                TextField(controller: _urlCtrl, decoration: InputDecoration(labelText: l10n.urlLabel, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.link))),
                const SizedBox(height: 10),
                TextField(controller: _dbCtrl, decoration: InputDecoration(labelText: l10n.dbLabel, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.storage))),
                const SizedBox(height: 10),
                TextField(controller: _userCtrl, decoration: InputDecoration(labelText: l10n.userLabel, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.person))),
                const SizedBox(height: 10),
                TextField(controller: _passCtrl, decoration: InputDecoration(labelText: l10n.passLabel, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock)), obscureText: true),
                const SizedBox(height: 20),
                
                _isLoading 
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: _login, 
                        child: Text(l10n.loginButton, style: const TextStyle(fontSize: 18))
                      ),
                    )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA TIENDA
// ==========================================
class TiendaScreen extends StatefulWidget {
  final OdooClient client;
  final int partnerId;
  final int companyId; 

  const TiendaScreen({
    super.key, 
    required this.client, 
    required this.partnerId,
    required this.companyId, 
  });

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  List<dynamic> _productos = [];
  List<dynamic> _categorias = [];
  bool _cargando = true;
  final Map<int, int> _carrito = {}; 
  int _categoriaSeleccionada = 0; 
  String _busqueda = "";

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final categoriasRaw = await widget.client.callKw({
        'model': 'product.category',
        'method': 'search_read',
        'args': [], 
        'kwargs': {'fields': ['name']},
      });

      final productosRaw = await widget.client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [[['sale_ok', '=', true]]],
        'kwargs': {
          'fields': ['name', 'list_price', 'id', 'categ_id', 'image_128'],
          'limit': 200,
        },
      });

      setState(() {
        _categorias = categoriasRaw;
        _productos = productosRaw;
        _cargando = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => _cargando = false);
    }
  }

  List<dynamic> get _productosFiltrados {
    return _productos.where((p) {
      bool coincideCategoria = true;
      if (_categoriaSeleccionada != 0) {
        coincideCategoria = (p['categ_id'] is List) && (p['categ_id'][0] == _categoriaSeleccionada);
      }
      bool coincideTexto = true;
      if (_busqueda.isNotEmpty) {
        coincideTexto = p['name'].toString().toLowerCase().contains(_busqueda.toLowerCase());
      }
      return coincideCategoria && coincideTexto;
    }).toList();
  }

  Future<void> _enviarPedido() async {
    final l10n = AppLocalizations.of(context)!;
    final lineas = <dynamic>[];
    _carrito.forEach((id, cant) {
      if (cant > 0) lineas.add([0, 0, {'product_id': id, 'product_uom_qty': cant}]);
    });

    if (lineas.isEmpty) return;
    setState(() => _cargando = true);
    
    try {
      final lp = await widget.client.callKw({
          'model': 'product.pricelist', 'method': 'search', 'args': [[]], 'kwargs': {'limit': 1}
      });
      
      final datosPedido = {
        'partner_id': widget.partnerId,
        'company_id': widget.companyId, 
        'order_line': lineas,
        'state': 'draft',
      };
      
      if (lp.isNotEmpty) datosPedido['pricelist_id'] = lp[0];

      final idPedido = await widget.client.callKw({
        'model': 'sale.order', 'method': 'create', 'args': [datosPedido], 'kwargs': {}
      });

      await widget.client.callKw({
        'model': 'sale.order', 'method': 'action_confirm', 'args': [[idPedido]], 'kwargs': {},
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saleConfirmed), backgroundColor: Colors.green)
      );
      setState(() { _carrito.clear(); _cargando = false; });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _cargando = false);
    }
  }

  Widget _imagenProducto(dynamic imageField) {
    if (imageField is String && imageField.isNotEmpty) {
      try {
        final bytes = base64Decode(imageField);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (e) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }
    }
    return const Icon(Icons.shopping_bag_outlined, size: 30, color: Colors.orangeAccent);
  }

  Widget _buildCategoryItem(int id, String nombre) {
    final isSelected = _categoriaSeleccionada == id;
    return InkWell(
      onTap: () => setState(() => _categoriaSeleccionada = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[100] : Colors.transparent,
          border: isSelected 
            ? Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 4))
            : null,
        ),
        child: Text(
          nombre,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final listaVisual = _productosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            onChanged: (texto) => setState(() => _busqueda = texto),
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: _carrito.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _enviarPedido, 
            label: Text("${l10n.confirmButton} (${_carrito.length})"),
            icon: const Icon(Icons.check),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          )
        : null,
      body: _cargando 
        ? const Center(child: CircularProgressIndicator()) 
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 130, 
                color: Colors.grey[200],
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(l10n.categoriesTitle, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    _buildCategoryItem(0, l10n.allCategories),
                    ..._categorias.map((cat) => _buildCategoryItem(cat['id'], cat['name'])),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: listaVisual.isEmpty 
                  ? Center(child: Text(l10n.noProducts))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150, 
                        childAspectRatio: 0.65, 
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: listaVisual.length,
                      itemBuilder: (ctx, i) {
                        final producto = listaVisual[i];
                        final id = producto['id'];
                        final cantidad = _carrito[id] ?? 0;
                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                height: 35,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                      onPressed: () => setState(() {
                                        if (cantidad > 0) _carrito[id] = cantidad - 1;
                                        if (_carrito[id] == 0) _carrito.remove(id);
                                      }),
                                    ),
                                    Text('$cantidad', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 20),
                                      onPressed: () => setState(() {
                                        _carrito[id] = cantidad + 1;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: _imagenProducto(producto['image_128']),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        producto['name'], 
                                        textAlign: TextAlign.center, 
                                        maxLines: 2, 
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, height: 1.1),
                                      ),
                                      Text("\$${producto['list_price']}", style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ),
              ),
            ],
          ),
    );
  }
}