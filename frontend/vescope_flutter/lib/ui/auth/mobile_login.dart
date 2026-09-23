import 'package:flutter/material.dart';
import '../../core/network/mobile_session.dart';

class MobileLogin extends StatefulWidget {
  const MobileLogin({super.key, required this.onConnected});
  final VoidCallback onConnected;
  @override
  State<MobileLogin> createState() => _MobileLoginState();
}

class _MobileLoginState extends State<MobileLogin> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    if (_user.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Renseignez votre identifiant et votre mot de passe.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await MobileSession.login(_user.text.trim(), _password.text);
      if (!mounted) { MobileSession.clear(); return; }
      _password.clear();
      widget.onConnected();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Connexion impossible. Vérifiez Internet et réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bolt, size: 72, color: Color(0xFF58B0FF)),
                const SizedBox(height: 16),
                Text('VE-SCOPE', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Connectez-vous avec les identifiants du site de supervision.',
                  textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(controller: _user, enabled: !_busy,
                  autocorrect: false, enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Identifiant')),
                const SizedBox(height: 16),
                TextField(controller: _password, enabled: !_busy,
                  obscureText: true, autocorrect: false, enableSuggestions: false,
                  onSubmitted: (_) => _connect(),
                  decoration: const InputDecoration(labelText: 'Mot de passe')),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 24),
                FilledButton(onPressed: _busy ? null : _connect,
                  child: Text(_busy ? 'Connexion…' : 'Se connecter')),
                const SizedBox(height: 16),
                const Text('Le mot de passe reste uniquement en mémoire pendant cette session.',
                  textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
