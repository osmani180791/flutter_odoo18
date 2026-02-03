import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APP VENTA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
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
  // AJUSTA ESTOS DATOS A TU SERVIDOR
  final TextEditingController _urlCtrl = TextEditingController(text: 'https://tu-instancia.odoo.com');
  final TextEditingController _dbCtrl = TextEditingController(text: 'nombre_bd');
  final TextEditingController _userCtrl = TextEditingController(text: 'admin');
  final TextEditingController _passCtrl = TextEditingController(text: 'admin');

  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    try {
      final client = OdooClient(_urlCtrl.text);
      await client.authenticate(_dbCtrl.text, _userCtrl.text, _passCtrl.text);
      
      // Obtener el partner_id para poder vender
      final uid = client.sessionId!.userId;
      final resUsers = await client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[['id', '=', uid]]],
        'kwargs': {'fields': ['partner_id'], 'limit': 1},
      });
      
      final partnerId = resUsers[0]['partner_id'][0] as int;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TiendaScreen(client: client, partnerId: partnerId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conectar a Odoo")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL Odoo')),
              TextField(controller: _dbCtrl, decoration: const InputDecoration(labelText: 'Base de Datos')),
              TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Usuario')),
              TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
              const SizedBox(height: 20),
              _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _login, child: const Text("INGRESAR"))
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA TIENDA (LAYOUT CON BARRA LATERAL + BUSCADOR)
// ==========================================
class TiendaScreen extends StatefulWidget {
  final OdooClient client;
  final int partnerId;

  const TiendaScreen({super.key, required this.client, required this.partnerId});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  List<dynamic> _productos = [];
  List<dynamic> _categorias = [];
  bool _cargando = true;
  final Map<int, int> _carrito = {}; 
  
  // Variables de Filtro
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
          'limit': 200, // Aumentamos límite para ver más cosas
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

  // Lógica de filtrado doble (Categoría + Texto)
  List<dynamic> get _productosFiltrados {
    return _productos.where((p) {
      // 1. Filtro de Categoría
      bool coincideCategoria = true;
      if (_categoriaSeleccionada != 0) {
        coincideCategoria = (p['categ_id'] is List) && (p['categ_id'][0] == _categoriaSeleccionada);
      }

      // 2. Filtro de Búsqueda
      bool coincideTexto = true;
      if (_busqueda.isNotEmpty) {
        coincideTexto = p['name'].toString().toLowerCase().contains(_busqueda.toLowerCase());
      }

      return coincideCategoria && coincideTexto;
    }).toList();
  }

  Future<void> _enviarPedido() async {
    final lineas = <dynamic>[];
    _carrito.forEach((id, cant) {
      if (cant > 0) lineas.add([0, 0, {'product_id': id, 'product_uom_qty': cant}]);
    });

    if (lineas.isEmpty) return;
    setState(() => _cargando = true);
    
    try {
      // Buscar lista de precios por defecto
      final lp = await widget.client.callKw({
          'model': 'product.pricelist', 'method': 'search', 'args': [[]], 'kwargs': {'limit': 1}
      });
      
      final datosPedido = {
        'partner_id': widget.partnerId,
        'order_line': lineas,
        'state': 'draft',
      };
      if (lp.isNotEmpty) datosPedido['pricelist_id'] = lp[0];

      // 1. Crear
      final idPedido = await widget.client.callKw({
        'model': 'sale.order', 'method': 'create', 'args': [datosPedido], 'kwargs': {}
      });

      // 2. Confirmar
      await widget.client.callKw({
        'model': 'sale.order', 'method': 'action_confirm', 'args': [[idPedido]], 'kwargs': {},
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Venta Confirmada!'), backgroundColor: Colors.green)
      );
      setState(() { _carrito.clear(); _cargando = false; });

    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _cargando = false);
    }
  }

  // Helper para convertir imagen
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
    final listaVisual = _productosFiltrados;

    return Scaffold(
      // --- BARRA SUPERIOR CON BUSCADOR ---
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            onChanged: (texto) => setState(() => _busqueda = texto),
            decoration: const InputDecoration(
              hintText: "Buscar producto...",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10), // Ajuste vertical
            ),
          ),
        ),
        centerTitle: true,
      ),

      floatingActionButton: _carrito.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _enviarPedido, 
            label: Text("Confirmar (${_carrito.length})"),
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
              // 1. BARRA LATERAL (CATEGORÍAS)
              Container(
                width: 130, 
                color: Colors.grey[200],
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text("CATEGORÍAS", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    _buildCategoryItem(0, "Todas"),
                    ..._categorias.map((cat) => _buildCategoryItem(cat['id'], cat['name'])),
                  ],
                ),
              ),

              // 2. GRID DE PRODUCTOS (COMPACTO)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: listaVisual.isEmpty 
                  ? const Center(child: Text("No se encontraron productos"))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
                      // Grid dinámico: Máximo 150px de ancho por tarjeta
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
                              // CABECERA (+ / -)
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
                              
                              // IMAGEN Y DATOS
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