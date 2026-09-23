import '../../core/network/saved_credentials.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await SavedCredentials.read();
      if (!mounted) return;
      if (saved != null) {
        _user.text = saved.username;
        _password.text = saved.password;
      }
    } catch (_) {
      if (mounted) _error = 'Lecture des identifiants impossible. Saisissez-les à nouveau.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forget() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await SavedCredentials.clear();
      if (!mounted) return;
      _user.clear();
      _password.clear();
      setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = 'Effacement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy || _loading) return;
    if (_user.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Renseignez votre identifiant et votre mot de passe.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await MobileSession.login(_user.text.trim(), _password.text);
      if (!mounted) { MobileSession.clear(); return; }
      try {
        await SavedCredentials.save(_user.text.trim(), _password.text);
      } catch (_) {
        if (!mounted) { MobileSession.clear(); return; }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Identifiants non enregistrés'),
            content: const Text('La connexion a réussi, mais le téléphone ne peut pas mémoriser les identifiants. Il faudra les saisir à nouveau.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Continuer'))],
          ),
        );
      }
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
                Image.asset('assets/branding/vescope_icon.png', height: 112,
                  semanticLabel: 'Logo VE-SCOPE'),
                const SizedBox(height: 16),
                Text('VE-SCOPE', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Connectez-vous avec les identifiants du site de supervision.',
                  textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(controller: _user, enabled: !_busy && !_loading,
                  autocorrect: false, enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Identifiant')),
                const SizedBox(height: 16),
                TextField(controller: _password, enabled: !_busy && !_loading,
                  obscureText: true, autocorrect: false, enableSuggestions: false,
                  onSubmitted: (_) => _connect(),
                  decoration: const InputDecoration(labelText: 'Mot de passe')),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 24),
                FilledButton(onPressed: _busy || _loading ? null : _connect,
                  child: Text(_loading ? 'Chargement…' : _busy ? 'Connexion…' : 'Se connecter')),
                const SizedBox(height: 16),
                TextButton(onPressed: _busy || _loading ? null : _forget,
                  child: const Text('Effacer les identifiants')),
                const Text('Vos identifiants sont mémorisés de façon sécurisée sur ce téléphone.',
                  textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
