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
    final migrated =
        await SecureStorageService.migrateKeyPassphrases(keyData);
    if (!identical(migrated, keyData)) {
      await ConfigService.saveSSHKeys(migrated);
    }
    final keys = <SSHKey>[];
    for (final raw in migrated) {
      final key = SSHKey.fromJson(raw);
      final passphrase =
          await SecureStorageService.readKeyPassphrase(key.id) ??
              key.passphrase;
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
    }
    await ConfigService.saveSSHKeys(_keys.map((e) => e.toJson()).toList());
  }

  Future<void> _generateKey(SSHKeyType keyType, String name) async {
    setState(() => _isLoading = true);

    try {
      final key = SSHKeyGenerator.generateKeySync(keyType, name);
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

  void _showKeyDetails(SSHKey key) {
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
                  key.privateKey,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
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
              onPressed: () {
                setState(() {
                  _keys.removeWhere((k) => k.id == id);
                });
                _saveKeys();
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
                          return ListTile(
                            leading: const Icon(Icons.key, color: Colors.amber),
                            title: Text(key.name),
                            subtitle: Text(key.keyType.displayName),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
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
