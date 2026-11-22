import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/ssh_provider.dart';
import '../models/port_forward_rule.dart';
import '../models/ssh_key.dart';
import '../models/ssh_profile.dart';
import '../services/config_service.dart';
import '../services/ssh_config_import_service.dart';
import '../services/wake_on_lan_service.dart';
import '../utils/jump_host_utils.dart';
import '../utils/session_manager.dart';
import '../utils/ssh_auth_utils.dart';

class ProfileManager extends StatefulWidget {
  const ProfileManager({super.key});

  @override
  State<ProfileManager> createState() => _ProfileManagerState();
}

class _ProfileManagerState extends State<ProfileManager> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _importing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SSHProfile> _filteredSorted(List<SSHProfile> profiles) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<SSHProfile>.from(profiles)
        : profiles
            .where((p) {
              return p.name.toLowerCase().contains(q) ||
                  p.host.toLowerCase().contains(q) ||
                  p.username.toLowerCase().contains(q);
            })
            .toList();
    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'SSH Profiles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Import ~/.ssh/config from connected host',
                      icon: _importing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, color: Colors.orange),
                      onPressed: _importing
                          ? null
                          : () => _importSshConfig(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () => _showProfileDialog(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name, host, user',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
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
                    final visible = _filteredSorted(ssh.profiles);
                    if (visible.isEmpty) {
                      return const Center(
                        child: Text('No profiles match the search'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final profile = visible[index];
                        return ListTile(
                          leading: IconButton(
                            tooltip: profile.isFavorite
                                ? 'Unpin favorite'
                                : 'Pin favorite',
                            icon: Icon(
                              profile.isFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                              color: profile.isFavorite
                                  ? Colors.amber
                                  : Colors.blue,
                            ),
                            onPressed: () {
                              ssh.saveProfile(
                                profile.copyWith(
                                  isFavorite: !profile.isFavorite,
                                ),
                              );
                            },
                          ),
                          title: Text(profile.name),
                          subtitle: Text(
                            'SSH ${profile.host}:${profile.port} · '
                            'Agent ${profile.agentBaseUrl}'
                            '${profile.tunnelAgent ? ' · tunnel' : ''}'
                            '${profile.jumpProfileId != null ? ' · jump' : ''}'
                            '${profile.macAddress != null ? ' · WoL' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Duplicate',
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () =>
                                    _duplicateProfile(context, profile),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showProfileDialog(
                                  context,
                                  profile: profile,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
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

  Future<void> _importSshConfig(BuildContext context) async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    final session = ssh.activeSession;
    if (session == null || !session.isConnected || session.client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect an SSH session first, then import config.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      const importer = SshConfigImportService();
      final remote = await importer.readRemoteConfig(
        client: session.client!,
        username: session.profile.username,
      );
      if (remote == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No OpenSSH config found on the host.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final merged = importer.mergeIntoProfiles(
        existing: ssh.profiles,
        sourcePath: remote.path,
        contents: remote.contents,
        fallbackUsername: session.profile.username,
      );

      for (final profile in merged.profiles) {
        await ssh.saveProfile(profile);
      }

      if (!context.mounted) {
        return;
      }
      final r = merged.result;
      final hint = r.identityHints.isEmpty
          ? ''
          : '\nIdentityFile hints: ${r.identityHints.take(3).join('; ')}';
      final skipped = r.skippedDirectives.isEmpty
          ? ''
          : '\nSkipped: ${r.skippedDirectives.take(5).join(', ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported from ${r.sourcePath}: '
            '${r.created} created, ${r.updated} updated.$hint$skipped',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  void _duplicateProfile(BuildContext context, SSHProfile profile) {
    final copy = SSHProfile(
      name: '${profile.name} (copy)',
      host: profile.host,
      port: profile.port,
      username: profile.username,
      password: profile.password,
      privateKey: profile.privateKey,
      startupCommand: profile.startupCommand,
      agentPort: profile.agentPort,
      useHttps: profile.useHttps,
      allowSelfSignedCerts: profile.allowSelfSignedCerts,
      agentUsername: profile.agentUsername,
      agentPassword: profile.agentPassword,
      sessionManager: profile.sessionManager,
      tunnelAgent: profile.tunnelAgent,
      isFavorite: false,
      jumpProfileId: profile.jumpProfileId,
      macAddress: profile.macAddress,
      localForwards: profile.localForwards
          .map(
            (r) => PortForwardRule(
              label: r.label,
              localPort: r.localPort,
              remoteHost: r.remoteHost,
              remotePort: r.remotePort,
              enabled: r.enabled,
            ),
          )
          .toList(),
    );
    Provider.of<SSHProvider>(context, listen: false).saveProfile(copy);
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
    final agentUsernameController = TextEditingController(
      text: profile?.agentUsername ?? 'opencode',
    );
    final agentPasswordController = TextEditingController(
      text: profile?.agentPassword ?? '',
    );
    final startupCommandController =
        TextEditingController(text: profile?.startupCommand ?? '');
    var useHttps = profile?.useHttps ?? false;
    var allowSelfSignedCerts = profile?.allowSelfSignedCerts ?? false;
    var tunnelAgent = profile?.tunnelAgent ?? false;
    var isFavorite = profile?.isFavorite ?? false;
    var sessionManager = profile?.sessionManager ?? SessionManager.none;
    String? jumpProfileId = profile?.jumpProfileId;
    final macController =
        TextEditingController(text: profile?.macAddress ?? '');
    var localForwards = List<PortForwardRule>.from(
      profile?.localForwards ?? const <PortForwardRule>[],
    );
    String? selectedKeyId = profile?.privateKey != null &&
            !looksLikePemPrivateKey(profile!.privateKey!)
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
            final ssh = Provider.of<SSHProvider>(context, listen: false);
            final jumpCandidates = ssh.profiles
                .where((p) => p.id != profile?.id)
                .toList();
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF16213E),
                  title: Text(profile == null ? 'Add Profile' : 'Edit Profile'),
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
                          decoration: const InputDecoration(labelText: 'Host'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: portController,
                          decoration:
                              const InputDecoration(labelText: 'SSH Port'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: jumpProfileId != null &&
                                  jumpCandidates
                                      .any((p) => p.id == jumpProfileId)
                              ? jumpProfileId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Via jump host',
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None (direct)'),
                            ),
                            ...jumpCandidates.map(
                              (p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text('${p.name} (${p.host})'),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => jumpProfileId = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: macController,
                          decoration: const InputDecoration(
                            labelText: 'MAC address (Wake-on-LAN)',
                            hintText: 'AA:BB:CC:DD:EE:FF',
                          ),
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
                          controller: agentUsernameController,
                          decoration: const InputDecoration(
                            labelText: 'Agent username',
                            hintText: 'opencode',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: agentPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Agent password (OpenCode serve)',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'SSH Username',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'SSH Password (optional with key)',
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
                                child: Text(
                                  '${k.name} (${k.keyType.displayName})',
                                ),
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
                          initialValue: SessionManagerX.selectableValues
                                  .contains(sessionManager)
                              ? sessionManager
                              : SessionManager.none,
                          decoration: const InputDecoration(
                            labelText: 'Session Manager',
                          ),
                          items: SessionManagerX.selectableValues.map((manager) {
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
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Local port forwards',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...localForwards.asMap().entries.map((entry) {
                          final index = entry.key;
                          final rule = entry.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              rule.label.isNotEmpty
                                  ? rule.label
                                  : '${rule.localPort} → '
                                      '${rule.remoteHost}:${rule.remotePort}',
                            ),
                            subtitle: Text(
                              '${rule.localPort} → '
                              '${rule.remoteHost}:${rule.remotePort}'
                              '${rule.enabled ? '' : ' (disabled)'}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  localForwards = List<PortForwardRule>.from(
                                    localForwards,
                                  )..removeAt(index);
                                });
                              },
                            ),
                          );
                        }),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  localForwards = <PortForwardRule>[
                                    ...localForwards,
                                    PortForwardRule.rdpPreset,
                                  ];
                                });
                              },
                              icon: const Icon(Icons.desktop_windows, size: 18),
                              label: const Text('Add RDP'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final added = await _promptPortForward(
                                  dialogContext,
                                );
                                if (added != null) {
                                  setDialogState(() {
                                    localForwards = <PortForwardRule>[
                                      ...localForwards,
                                      added,
                                    ];
                                  });
                                }
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add forward'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Favorite'),
                          value: isFavorite,
                          onChanged: (value) =>
                              setDialogState(() => isFavorite = value),
                        ),
                        SwitchListTile(
                          title: const Text('Tunnel agent over SSH'),
                          subtitle: const Text(
                            'Forward to 127.0.0.1:agentPort on the host '
                            '(OpenCode bound to loopback). Requires SSH session.',
                          ),
                          value: tunnelAgent,
                          onChanged: (value) =>
                              setDialogState(() => tunnelAgent = value),
                        ),
                        SwitchListTile(
                          title: const Text('Use HTTPS for Agent'),
                          value: useHttps,
                          onChanged: (value) => setDialogState(() {
                            useHttps = value;
                            if (!value) {
                              allowSelfSignedCerts = false;
                            }
                          }),
                        ),
                        if (useHttps)
                          SwitchListTile(
                            title: const Text('Allow self-signed cert'),
                            subtitle: const Text(
                              'Only for trusted LAN OpenCode hosts. '
                              'Disables certificate verification for this '
                              'profile host.',
                            ),
                            value: allowSelfSignedCerts,
                            onChanged: (value) => setDialogState(
                              () => allowSelfSignedCerts = value,
                            ),
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
                      onPressed: () async {
                        if (nameController.text.isEmpty ||
                            hostController.text.isEmpty) {
                          return;
                        }
                        final macRaw = macController.text.trim();
                        String? mac;
                        if (macRaw.isNotEmpty) {
                          final parsed = WakeOnLanService.parseMac(macRaw);
                          if (parsed == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid MAC address'),
                              ),
                            );
                            return;
                          }
                          mac = WakeOnLanService.formatMac(parsed);
                        }
                        final agentUser = agentUsernameController.text.trim();
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
                          allowSelfSignedCerts:
                              useHttps && allowSelfSignedCerts,
                          agentUsername:
                              agentUser.isEmpty ? 'opencode' : agentUser,
                          agentPassword: agentPasswordController.text.isEmpty
                              ? null
                              : agentPasswordController.text,
                          sessionManager: sessionManager,
                          tunnelAgent: tunnelAgent,
                          isFavorite: isFavorite,
                          jumpProfileId: jumpProfileId,
                          macAddress: mac,
                          localForwards: localForwards,
                        );
                        if (createsJumpCycle(
                          ssh.profiles,
                          newProfile.id,
                          newProfile.jumpProfileId,
                        )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Jump host would create a cycle'),
                            ),
                          );
                          return;
                        }
                        try {
                          await ssh.saveProfile(newProfile);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
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

  Future<PortForwardRule?> _promptPortForward(BuildContext context) async {
    final labelController = TextEditingController();
    final localController = TextEditingController(text: '3389');
    final remoteHostController = TextEditingController(text: '127.0.0.1');
    final remotePortController = TextEditingController(text: '3389');
    final result = await showDialog<PortForwardRule>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Local port forward'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                ),
              ),
              TextField(
                controller: localController,
                decoration: const InputDecoration(labelText: 'Local port'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: remoteHostController,
                decoration: const InputDecoration(labelText: 'Remote host'),
              ),
              TextField(
                controller: remotePortController,
                decoration: const InputDecoration(labelText: 'Remote port'),
                keyboardType: TextInputType.number,
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
                final local = int.tryParse(localController.text.trim());
                final remote = int.tryParse(remotePortController.text.trim());
                final host = remoteHostController.text.trim();
                if (local == null ||
                    remote == null ||
                    local <= 0 ||
                    remote <= 0 ||
                    host.isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  PortForwardRule(
                    label: labelController.text.trim(),
                    localPort: local,
                    remoteHost: host,
                    remotePort: remote,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    labelController.dispose();
    localController.dispose();
    remoteHostController.dispose();
    remotePortController.dispose();
    return result;
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
