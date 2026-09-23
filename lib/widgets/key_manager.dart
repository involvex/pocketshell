import 'package:flutter/material.dart';
import '../models/ssh_key.dart';
import '../services/ssh_key_generator.dart';
import '../services/config_service.dart';
import '../services/secure_storage_service.dart';

class KeyManager extends StatefulWidget {
  const KeyManager({super.key});

  @override
  State<KeyManager> createState() => _KeyManagerState();
}

class _KeyManagerState extends State<KeyManager> {
  List<SSHKey> _keys = <SSHKey>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final keyData = await ConfigService.getSSHKeys();
    final migratedPass =
        await SecureStorageService.migrateKeyPassphrases(keyData);
    final migratedPriv =
        await SecureStorageService.migratePrivateKeys(migratedPass);
    if (!identical(migratedPriv, keyData)) {
      await ConfigService.saveSSHKeys(migratedPriv);
    }
    final keys = <SSHKey>[];
    for (final raw in migratedPriv) {
      final keyId = raw['id'] as String;
      final privateKey = await SecureStorageService.readPrivateKey(keyId) ??
          (raw['privateKey'] as String? ?? '');
      final passphrase = await SecureStorageService.readKeyPassphrase(keyId) ??
          raw['passphrase'] as String?;

      final key = SSHKey.fromJson(raw, privateKeyOverride: privateKey);
      keys.add(
        passphrase == null || passphrase == key.passphrase
            ? key
            : SSHKey(
                id: key.id,
                name: key.name,
                keyType: key.keyType,
                publicKey: key.publicKey,
                privateKey: key.privateKey,
                passphrase: passphrase,
                createdAt: key.createdAt,
              ),
      );
    }
    setState(() {
      _keys = keys;
    });
  }

  Future<void> _saveKeys() async {
    for (final key in _keys) {
      await SecureStorageService.writeKeyPassphrase(key.id, key.passphrase);
      await SecureStorageService.writePrivateKey(key.id, key.privateKey);
    }
    await ConfigService.saveSSHKeys(
      _keys.map((e) => e.toJson(includePrivateKey: false)).toList(),
    );
  }

  Future<void> _generateKey(SSHKeyType keyType, String name) async {
    setState(() => _isLoading = true);

    try {
      final key = await SSHKeyGenerator.generateKey(keyType, name);
      setState(() {
        _keys.add(key);
      });
      await _saveKeys();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showGenerateKeyDialog() {
    var selectedType = SSHKeyType.ed25519;
    final nameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16213E),
              title: const Text('Generate SSH Key'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Key Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SSHKeyType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Key Type'),
                    items: SSHKeyType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Generated keys have no passphrase. Set one afterwards from the key list for protection.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      _generateKey(selectedType, nameController.text);
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _hasPassphrase(SSHKey key) {
    return key.passphrase != null && key.passphrase!.isNotEmpty;
  }

  Future<void> _showSetPassphraseDialog(SSHKey key) async {
    final controller = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text('Set passphrase for ${key.name}'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Passphrase',
              hintText: 'Minimum 8 characters recommended',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null || saved.isEmpty || !mounted) return;
    final updated = SSHKey(
      id: key.id,
      name: key.name,
      keyType: key.keyType,
      publicKey: key.publicKey,
      privateKey: key.privateKey,
      passphrase: saved,
      createdAt: key.createdAt,
    );
    setState(() {
      final index = _keys.indexWhere((k) => k.id == key.id);
      if (index >= 0) _keys[index] = updated;
    });
    await _saveKeys();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Passphrase set for ${key.name}')),
    );
  }

  Future<void> _showKeyDetails(SSHKey key) async {
    final privateKey =
        await SecureStorageService.readPrivateKey(key.id) ?? key.privateKey;
    if (!mounted) return;
    // ignore: unawaited_futures
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text(key.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Type: ${key.keyType.displayName}'),
                const SizedBox(height: 8),
                Text('Created: ${key.createdAt.toLocal()}'),
                const SizedBox(height: 8),
                if (!_hasPassphrase(key))
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.warning_amber,
                            color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No passphrase set. Anyone with access to this device can use this key.',
                            style: TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Public Key:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(
                  key.publicKey,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                const Text('Private Key:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(
                  privateKey,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            if (!_hasPassphrase(key))
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showSetPassphraseDialog(key);
                },
                child: const Text('Set passphrase'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _deleteKey(String id) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Delete Key'),
          content: const Text('Are you sure you want to delete this key?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                setState(() {
                  _keys.removeWhere((k) => k.id == id);
                });
                await SecureStorageService.deletePrivateKey(id);
                await SecureStorageService.deleteKeyPassphrase(id);
                await _saveKeys();
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'SSH Keys',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, color: Colors.green),
                      onPressed: _isLoading ? null : _showGenerateKeyDialog,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _keys.isEmpty
                    ? const Center(child: Text('No keys generated yet'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _keys.length,
                        itemBuilder: (context, index) {
                          final key = _keys[index];
                          final hasPassphrase = _hasPassphrase(key);
                          return ListTile(
                            leading: const Icon(Icons.key, color: Colors.amber),
                            title: Row(
                              children: <Widget>[
                                Expanded(child: Text(key.name)),
                                if (!hasPassphrase)
                                  const Tooltip(
                                    message:
                                        'No passphrase — anyone with device access can use this key',
                                    child: Icon(Icons.warning_amber,
                                        color: Colors.amber, size: 18),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              hasPassphrase
                                  ? key.keyType.displayName
                                  : '${key.keyType.displayName} • No passphrase',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (!hasPassphrase)
                                  IconButton(
                                    icon: const Icon(Icons.lock_open,
                                        size: 20, color: Colors.amber),
                                    tooltip: 'Set passphrase',
                                    onPressed: () =>
                                        _showSetPassphraseDialog(key),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 20),
                                  onPressed: () => _showKeyDetails(key),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  onPressed: () => _deleteKey(key.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
