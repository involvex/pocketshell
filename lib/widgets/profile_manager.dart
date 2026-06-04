import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ssh_provider.dart';
import '../models/ssh_profile.dart';

class ProfileManager extends StatelessWidget {
  const ProfileManager({super.key});

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
                          leading: Icon(
                            profile.isServer ? Icons.dns : Icons.computer,
                            color: Colors.blue,
                          ),
                          title: Text(profile.name),
                          subtitle: Text('${profile.host}:${profile.port}'),
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
    final usernameController =
        TextEditingController(text: profile?.username ?? '');
    final passwordController =
        TextEditingController(text: profile?.password ?? '');
    final startupCommandController =
        TextEditingController(text: profile?.startupCommand ?? '');
    final isServer = profile?.isServer ?? false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text(profile == null ? 'Add Profile' : 'Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Profile Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(labelText: 'Host'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: portController,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: startupCommandController,
                  decoration: const InputDecoration(
                    labelText: 'Startup Command (optional)',
                    hintText: 'e.g., ls -la, pwd',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Server Profile'),
                  value: isServer,
                  onChanged: (value) {},
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
                  password: passwordController.text,
                  isServer: isServer,
                  startupCommand: startupCommandController.text.isNotEmpty
                      ? startupCommandController.text
                      : null,
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
      if (profile.isServer) {
        await ssh.startServer(
          port: profile.port,
          username: profile.username,
          password: profile.password ?? '',
        );
      } else {
        final entry = ssh.createSessionFromProfile(profile, name: profile.name);
        await ssh.connectSession(entry.id);
      }
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
