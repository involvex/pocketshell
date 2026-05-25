import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:xterm/ui.dart';
import '../providers/ssh_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/ssh_server_form.dart';
import '../widgets/log_viewer.dart';
import '../widgets/profile_manager.dart';
import '../widgets/key_manager.dart';
import '../widgets/keyboard_shortcut_bar.dart';
import '../widgets/connection_modal.dart';
import '../widgets/network_discovery.dart';
import '../widgets/ctrl_button_panel.dart';
import '../widgets/snippet_button_panel.dart';
import '../widgets/sftp_browser.dart';
import '../screens/settings_screen.dart';
import '../screens/snippet_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    await ssh.loadConfig();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final ctrl = HardwareKeyboard.instance.isControlPressed;

      if (ctrl && event.logicalKey == LogicalKeyboardKey.keyN) {
        _showConnectionModal();
      } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyP) {
        _showProfileManager();
      } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyD) {
        _showNetworkDiscovery();
      } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyK) {
        _showKeyManager();
      }
    }
  }

  void _showConnectionModal() async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);

    // If we have a last session saved, try quick-connect using it.
    if (ssh.lastSession != null) {
      final session = ssh.lastSession!;

      // Show a small progress dialog while connecting
      // ignore: unawaited_futures
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF16213E),
          content: Row(
            children: [
              SizedBox(
                  width: 24, height: 24, child: CircularProgressIndicator()),
              SizedBox(width: 16),
              Text('Connecting...'),
            ],
          ),
        ),
      );

      try {
        if (session.isServer) {
          await ssh.startServer(
            port: session.port,
            username: session.username,
            password: session.password ?? '',
            sshKeyType: null,
          );
        } else {
          await ssh.connectClient(
            host: session.host,
            port: session.port,
            username: session.username,
            password: session.password ?? '',
            startupCommand: session.startupCommand,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) Navigator.of(context).pop();
      }

      return;
    }

    // No last session — show the connection modal so the user can enter details.
    // ignore: unawaited_futures
    showDialog<void>(
      context: context,
      builder: (context) => const ConnectionModal(),
    );
  }

  void _showProfileManager() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ProfileManager(),
    );
  }

  void _showNetworkDiscovery() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const NetworkDiscoverySheet(),
    );
  }

  void _showKeyManager() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const KeyManager(),
    );
  }

  void _showSnippetConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SnippetConfigScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()
        ..requestFocus(), // Request focus so keyboard listener receives events
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SSH App'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: 'Manage Snippets',
              onPressed: _showSnippetConfig,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Network Discovery',
              onPressed: _showNetworkDiscovery,
            ),
            IconButton(
              icon: const Icon(Icons.key),
              tooltip: 'Keys',
              onPressed: _showKeyManager,
            ),
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Profiles',
              onPressed: _showProfileManager,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Connect',
              onPressed: _showConnectionModal,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.computer),
              label: 'Client',
            ),
            NavigationDestination(
              icon: Icon(Icons.dns),
              label: 'Server',
            ),
            NavigationDestination(
              icon: Icon(Icons.article),
              label: 'Logs',
            ),
          ],
        ),
        body: Column(
          children: [
            const KeyboardShortcutBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const <Widget>[
                  ClientTab(),
                  ServerTab(),
                  LogViewer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientTab extends StatelessWidget {
  const ClientTab({super.key});

  Widget _buildSessionTabBar(BuildContext context) {
    return Consumer<SSHProvider>(builder: (context, ssh, child) {
      final sessions = ssh.sessions;
      final chips = sessions.map((s) {
        final isActive = ssh.activeSessionId == s.id;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: InputChip(
            selected: isActive,
            avatar: CircleAvatar(
              radius: 4,
              backgroundColor: s.isConnected ? Colors.green : Colors.red,
            ),
            label: Text('${s.name} (${s.profile.host}:${s.profile.port})'),
            onPressed: () => ssh.switchActiveSession(s.id),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => ssh.removeSession(s.id),
          ),
        );
      }).toList();

      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: GestureDetector(
            onTap: () => showDialog<void>(
                context: context, builder: (c) => const ConnectionModal()),
            child: const Chip(label: Icon(Icons.add)),
          ),
        ),
      );

      return Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'SFTP Browser',
            onPressed: () {
              if (ssh.activeSession == null ||
                  !ssh.activeSession!.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Connect to a session first')));
                return;
              }
              showModalBottomSheet(
                  context: context,
                  builder: (_) => SftpBrowser(sessionId: ssh.activeSessionId!));
            },
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SSHProvider, SettingsProvider>(
      builder: (context, ssh, settings, child) {
        final isHacker = settings.appTheme == AppTheme.hacker;

        final terminalTheme = isHacker
            ? const TerminalTheme(
                cursor: Color(0XFFAEAFAD),
                selection: Color(0XFFAEAFAD),
                foreground: Colors.greenAccent,
                background: Color(0XFF000000),
                black: Color(0XFF000000),
                red: Color(0XFFCD3131),
                green: Color(0XFF0DBC79),
                yellow: Color(0XFFE5E510),
                blue: Color(0XFF2472C8),
                magenta: Color(0XFFBC3FBC),
                cyan: Color(0XFF11A8CD),
                white: Color(0XFFE5E5E5),
                brightBlack: Color(0XFF666666),
                brightRed: Color(0XFFF14C4C),
                brightGreen: Color(0XFF23D18B),
                brightYellow: Color(0XFFF5F543),
                brightBlue: Color(0XFF3B8EEA),
                brightMagenta: Color(0XFFD670D6),
                brightCyan: Color(0XFF29B8DB),
                brightWhite: Color(0XFFFFFFFF),
                searchHitBackground: Color(0XFFFFFF2B),
                searchHitBackgroundCurrent: Color(0XFF31FF26),
                searchHitForeground: Color(0XFF000000),
              )
            : TerminalThemes.defaultTheme;

        return Column(
          children: <Widget>[
            _buildSessionTabBar(context),
            Expanded(
              child: Consumer<SSHProvider>(builder: (context, ssh, child) {
                final active = ssh.activeSession;
                if (active == null) {
                  return const Center(
                      child: Text('No session. Click + to connect'));
                }
                if (!active.isConnected) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Not connected'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await ssh.connectSession(active.id);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Reconnect failed: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reconnect'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: () => ssh.removeSession(active.id),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  color: terminalTheme.background,
                  child: TerminalView(
                    active.terminal,
                    padding: const EdgeInsets.all(8),
                    theme: terminalTheme,
                    textStyle: TerminalStyle(
                      fontSize: settings.terminalFontSize,
                      fontFamily: 'monospace',
                    ),
                    autoResize: true,
                  ),
                );
              }),
            ),
            if (ssh.sessions.any((s) => s.isConnected))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CtrlButtonPanel(),
                    SnippetButtonPanel(),
                  ],
                ),
              ),
            if (ssh.sessions.any((s) => s.isConnected))
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final active =
                        Provider.of<SSHProvider>(context, listen: false)
                            .activeSession;
                    if (active != null) {
                      await Provider.of<SSHProvider>(context, listen: false)
                          .disconnectSession(active.id);
                    }
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ServerTab extends StatelessWidget {
  const ServerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, ssh, child) {
        return Column(
          children: <Widget>[
            if (!ssh.isServerRunning)
              const Expanded(child: SSHServerForm())
            else
              Expanded(
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'SSH Server is Running',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Address: ${ssh.serverAddress ?? '0.0.0.0'}:${ssh.serverPort}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () => ssh.stopServer(),
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop Server'),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
