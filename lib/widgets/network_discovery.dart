import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/ssh_profile.dart';
import '../providers/ssh_provider.dart';
import '../services/network_discovery_service.dart';
import '../services/wake_on_lan_service.dart';

class NetworkDiscoverySheet extends StatefulWidget {
  const NetworkDiscoverySheet({super.key});

  @override
  State<NetworkDiscoverySheet> createState() => _NetworkDiscoverySheetState();
}

class _NetworkDiscoverySheetState extends State<NetworkDiscoverySheet> {
  final _hostController = TextEditingController();
  final _macController = TextEditingController();
  String? _localIP;
  bool _waking = false;

  @override
  void initState() {
    super.initState();
    _loadLocalIP();
  }

  Future<void> _loadLocalIP() async {
    final ip = await NetworkDiscoveryService.getLocalIP();
    setState(() {
      _localIP = ip;
    });
  }

  Future<void> _scanNetwork(SSHProvider ssh) async {
    await ssh.scanNetwork();
  }

  Future<void> _checkHost(SSHProvider ssh) async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    await ssh.discoverHost(host);
    _hostController.clear();
  }

  Future<void> _wakeMac(String mac, {String? profileName}) async {
    setState(() => _waking = true);
    try {
      await const WakeOnLanService().sendMagicPacket(macAddress: mac);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileName == null
                ? 'Wake packet sent to $mac'
                : 'Woke $profileName ($mac)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wake-on-LAN failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _waking = false);
      }
    }
  }

  Future<void> _wakeFromField() async {
    final mac = _macController.text.trim();
    if (mac.isEmpty) return;
    await _wakeMac(mac);
  }

  List<SSHProfile> _profilesWithMac(SSHProvider ssh) {
    return ssh.profiles
        .where((p) => p.macAddress != null && p.macAddress!.isNotEmpty)
        .toList();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Network Discovery',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_localIP != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Your IP: $_localIP',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Check specific host',
                          hintText: '192.168.1.100',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<SSHProvider>(
                      builder: (context, ssh, child) {
                        return ElevatedButton(
                          onPressed: () => _checkHost(ssh),
                          child: const Text('Check'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _macController,
                        decoration: const InputDecoration(
                          labelText: 'Wake-on-LAN MAC',
                          hintText: 'AA:BB:CC:DD:EE:FF',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _waking ? null : _wakeFromField,
                      child: _waking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Wake'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Consumer<SSHProvider>(
                  builder: (context, ssh, child) {
                    return Row(
                      children: <Widget>[
                        ElevatedButton.icon(
                          onPressed:
                              ssh.isScanning ? null : () => _scanNetwork(ssh),
                          icon: ssh.isScanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                              ssh.isScanning ? 'Scanning...' : 'Auto Scan'),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${ssh.discoveredHosts.length} hosts found',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Consumer<SSHProvider>(
                builder: (context, ssh, _) {
                  final withMac = _profilesWithMac(ssh);
                  if (withMac.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Saved profiles with MAC',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ),
                        ...withMac.map(
                          (p) => ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.power_settings_new,
                              color: Colors.orange,
                            ),
                            title: Text(p.name),
                            subtitle: Text(p.macAddress!),
                            trailing: TextButton(
                              onPressed: _waking
                                  ? null
                                  : () => _wakeMac(
                                        p.macAddress!,
                                        profileName: p.name,
                                      ),
                              child: const Text('Wake'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(),
              Expanded(
                child: Consumer<SSHProvider>(
                  builder: (context, ssh, child) {
                    if (ssh.discoveredHosts.isEmpty) {
                      return Center(
                        child: Text(
                          ssh.isScanning
                              ? 'Scanning network...'
                              : 'No SSH servers found',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: ssh.discoveredHosts.length,
                      itemBuilder: (context, index) {
                        final host = ssh.discoveredHosts[index];
                        return ListTile(
                          leading:
                              const Icon(Icons.computer, color: Colors.green),
                          title: Text(host),
                          subtitle: const Text('Port 22 (SSH)'),
                          trailing: IconButton(
                            icon: const Icon(Icons.content_copy, size: 20),
                            onPressed: () {
                              _hostController.text = host;
                            },
                          ),
                          onTap: () {
                            _hostController.text = host;
                          },
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

  @override
  void dispose() {
    _hostController.dispose();
    _macController.dispose();
    super.dispose();
  }
}
