import 'package:material_ui/material_ui.dart';

class SetStateCartPage extends StatelessWidget {
  const SetStateCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart · setState')),
      body: const Center(child: Text('SetStateCartPage')),
    );
  }
}

