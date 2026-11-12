import 'package:material_ui/material_ui.dart';

class RiverpodCartPage extends StatelessWidget {
  const RiverpodCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart · Riverpod')),
      body: const Center(child: Text('RiverpodCartPage')),
    );
  }
}

