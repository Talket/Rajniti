import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes/app_router.dart'; 
import 'package:provider/provider.dart';
import 'state/cart_provider.dart'; 


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://krmyucvjiscxojifacqo.supabase.co', 
    anonKey: 'sb_publishable_K0gonwKm9nRRD1UIuZ17nw_cHA1UVMp',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const RestroPOS(),
    ),
  );
}

class RestroPOS extends StatelessWidget {
  const RestroPOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Restro POS',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter, 
    );
  }
}