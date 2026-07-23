import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ssh_app/models/ssh_key.dart';
import 'package:ssh_app/models/ssh_profile.dart';
import 'package:ssh_app/providers/ssh_provider.dart';
import 'package:ssh_app/services/config_service.dart';
import 'package:ssh_app/utils/session_manager.dart';
import 'package:ssh_app/utils/ssh_auth_utils.dart';

class ConnectionModal extends StatefulWidget {
  const ConnectionModal({super.key});

  @override
  State<ConnectionModal> createState() => _ConnectionModalState();
}

class _ConnectionModalState extends State<ConnectionModal> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _startupCommandController = TextEditingController();
  bool _isLoading = false;
  SessionManager _sessionManager = SessionManager.none;
  String? _selectedKeyId;
  List<SSHKey> _keys = <SSHKey>[];

  @override
  void initState() {
    super.initState();
    _loadLastSession();
    unawaited(_loadKeys());
  }

  Future<void> _loadKeys() async {
    final raw = await ConfigService.getSSHKeys();
    if (!mounted) return;
    setState(() {
      _keys = raw.map(SSHKey.fromJson).toList();
    });
  }

  void _loadLastSession() {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    if (ssh.lastSession != null) {
      final session = ssh.lastSession!;
      _hostController.text = session.host;
      _portController.text = session.port.toString();
      _usernameController.text = session.username;
      _passwordController.text = session.password ?? '';
      _startupCommandController.text = session.startupCommand ?? '';
      _sessionManager = session.sessionManager;
      final keyRef = session.privateKey;
      if (keyRef != null && !looksLikePemPrivateKey(keyRef)) {
        _selectedKeyId = keyRef;
      }
    } else {
      _hostController.text = 'localhost';
      _usernameController.text = 'user';
    }
  }

  Future<void> _connect(SSHProvider ssh) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final profile = SSHProfile(
      name: 'Last Session',
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? 22,
      username: _usernameController.text,
      password: _passwordController.text.isEmpty
          ? null
          : _passwordController.text,
      privateKey: _selectedKeyId,
      startupCommand: _startupCommandController.text.isNotEmpty
          ? _startupCommandController.text
          : null,
      sessionManager: _sessionManager,
    );

    await ssh.saveLastSession(profile);

    try {
      final entry = ssh.createSessionFromProfile(profile, name: profile.name);
      await ssh.connectSession(entry.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ssh = Provider.of<SSHProvider>(context, listen: false);

    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      title: const Text('SSH Connection'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'localhost or IP address',
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '22',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) return 'Required';
                    final port = int.tryParse(value);
                    if (port == null || port < 1 || port > 65535) {
                      return 'Invalid port';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'root',
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password (optional with key)',
                  ),
                  obscureText: true,
                  validator: (value) {
                    final hasPassword = value != null && value.isNotEmpty;
                    final hasKey = _selectedKeyId != null;
                    if (!hasPassword && !hasKey) {
                      return 'Password or SSH key required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedKeyId != null &&
                          _keys.any((k) => k.id == _selectedKeyId)
                      ? _selectedKeyId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'SSH Key (optional)',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (password only)'),
                    ),
                    ..._keys.map(
                      (k) => DropdownMenuItem<String?>(
                        value: k.id,
                        child: Text(
                          '${k.name} (${k.keyType.displayName})',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedKeyId = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SessionManager>(
                  key: ValueKey(_sessionManager),
                  initialValue: _sessionManager,
                  decoration: const InputDecoration(
                    labelText: 'Session Manager',
                  ),
                  items: SessionManager.values.map((manager) {
                    return DropdownMenuItem(
                      value: manager,
                      child: Text(manager.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sessionManager = value);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _startupCommandController,
                  decoration: const InputDecoration(
                    labelText: 'Startup Command (optional)',
                    hintText: 'Overrides session manager when set',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _connect(ssh),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _startupCommandController.dispose();
    super.dispose();
  }
}
