import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ssh_provider.dart';
import '../models/ssh_key.dart';
import '../models/ssh_profile.dart';
import '../services/config_service.dart';
import '../utils/session_manager.dart';
import '../utils/ssh_auth_utils.dart';

class ProfileManager extends StatefulWidget {
  const ProfileManager({super.key});

  @override
  State<ProfileManager> createState() => _ProfileManagerState();
}

class _ProfileManagerState extends State<ProfileManager> {
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
                      'SSH Profiles',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () => _showProfileDialog(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<SSHProvider>(
                  builder: (context, ssh, child) {
                    if (ssh.profiles.isEmpty) {
                      return const Center(
                        child: Text('No profiles saved yet'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: ssh.profiles.length,
                      itemBuilder: (context, index) {
                        final profile = ssh.profiles[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.computer,
                            color: Colors.blue,
                          ),
                          title: Text(profile.name),
                          subtitle: Text(
                            'SSH ${profile.host}:${profile.port} · Agent ${profile.agentBaseUrl}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showProfileDialog(context,
                                    profile: profile),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                onPressed: () =>
                                    _deleteProfile(context, profile.id),
                              ),
                            ],
                          ),
                          onTap: () => _useProfile(context, profile),
                        );
                      },
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

  void _showProfileDialog(BuildContext context, {SSHProfile? profile}) {
    final nameController = TextEditingController(text: profile?.name ?? '');
    final hostController = TextEditingController(text: profile?.host ?? '');
    final portController =
        TextEditingController(text: profile?.port.toString() ?? '22');
    final agentPortController = TextEditingController(
      text: profile?.agentPort.toString() ?? '5000',
    );
    final usernameController =
        TextEditingController(text: profile?.username ?? '');
    final passwordController =
        TextEditingController(text: profile?.password ?? '');
    final startupCommandController =
        TextEditingController(text: profile?.startupCommand ?? '');
    var useHttps = profile?.useHttps ?? false;
    var sessionManager = profile?.sessionManager ?? SessionManager.none;
    String? selectedKeyId =
        profile?.privateKey != null && !looksLikePemPrivateKey(profile!.privateKey!)
            ? profile.privateKey
            : null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<SSHKey>>(
          future: ConfigService.getSSHKeys().then(
            (raw) => raw.map(SSHKey.fromJson).toList(),
          ),
          builder: (context, snapshot) {
            final keys = snapshot.data ?? <SSHKey>[];
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF16213E),
                  title:
                      Text(profile == null ? 'Add Profile' : 'Edit Profile'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Profile Name',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: hostController,
                          decoration:
                              const InputDecoration(labelText: 'Host'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: portController,
                          decoration:
                              const InputDecoration(labelText: 'SSH Port'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: agentPortController,
                          decoration: const InputDecoration(
                            labelText: 'Agent Port (OpenCode)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: usernameController,
                          decoration:
                              const InputDecoration(labelText: 'Username'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password (optional with key)',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: selectedKeyId != null &&
                                  keys.any((k) => k.id == selectedKeyId)
                              ? selectedKeyId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'SSH Key (optional)',
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None (password only)'),
                            ),
                            ...keys.map(
                              (k) => DropdownMenuItem<String?>(
                                value: k.id,
                                child: Text('${k.name} (${k.keyType.displayName})'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedKeyId = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<SessionManager>(
                          key: ValueKey(sessionManager),
                          initialValue: sessionManager,
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
                            setDialogState(() => sessionManager = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: startupCommandController,
                          decoration: const InputDecoration(
                            labelText: 'Startup Command (optional)',
                            hintText: 'Overrides session manager when set',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Use HTTPS for Agent'),
                          value: useHttps,
                          onChanged: (value) =>
                              setDialogState(() => useHttps = value),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty ||
                            hostController.text.isEmpty) {
                          return;
                        }
                        final newProfile = SSHProfile(
                          id: profile?.id,
                          name: nameController.text,
                          host: hostController.text,
                          port: int.tryParse(portController.text) ?? 22,
                          username: usernameController.text,
                          password: passwordController.text.isEmpty
                              ? null
                              : passwordController.text,
                          privateKey: selectedKeyId,
                          startupCommand:
                              startupCommandController.text.isNotEmpty
                                  ? startupCommandController.text
                                  : null,
                          agentPort:
                              int.tryParse(agentPortController.text) ?? 5000,
                          useHttps: useHttps,
                          sessionManager: sessionManager,
                        );
                        Provider.of<SSHProvider>(context, listen: false)
                            .saveProfile(newProfile);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _deleteProfile(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Delete Profile'),
          content: const Text('Are you sure you want to delete this profile?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<SSHProvider>(context, listen: false)
                    .deleteProfile(id);
                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _useProfile(BuildContext context, SSHProfile profile) async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    Navigator.pop(context);

    try {
      final entry = ssh.createSessionFromProfile(profile, name: profile.name);
      await ssh.connectSession(entry.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
