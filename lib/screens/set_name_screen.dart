import 'package:flutter/material.dart';
import '../services/user_prefs_service.dart';

class SetNameScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const SetNameScreen({super.key, this.onSaved});

  @override
  State<SetNameScreen> createState() => _SetNameScreenState();
}

class _SetNameScreenState extends State<SetNameScreen> {
  final _controller = TextEditingController();
  final _prefsService = UserPrefsService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingName();
  }

  Future<void> _loadExistingName() async {
    final existing = await _prefsService.getDisplayName();
    if (existing != null) {
      _controller.text = existing;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir isim gir')),
      );
      return;
    }
    if (name.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsim en fazla 20 karakter olabilir')),
      );
      return;
    }

    await _prefsService.setDisplayName(name);

    if (!mounted) return;

    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Oyuncu Adın')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Diğer oyuncuların seni tanıyabilmesi için bir isim seç.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              maxLength: 20,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Örn. Ahmet',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }
}