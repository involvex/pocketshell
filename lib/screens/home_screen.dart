import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../models/home_toolbar_action.dart';
import '../providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
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
import '../screens/agents_tab.dart';
import '../services/widget_launch_handler.dart';
import '../utils/terminal_style_builder.dart';
import '../utils/terminal_themes.dart';
import '../utils/enter_mapping_input_handler.dart';
import '../utils/terminal_enter_mapping.dart';

enum AppTab { client, server, agents, logs }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.pendingLaunch});

  final WidgetLaunchAction? pendingLaunch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppTab _selectedTab = AppTab.client;
  bool _isFullScreen = false;
  bool _agentsChatOpen = false;
  StreamSubscription<Uri?>? _widgetClickSub;
  final FocusNode _keyboardFocusNode = FocusNode();
  final GlobalKey<AgentsTabState> _agentsTabKey = GlobalKey<AgentsTabState>();

  @override
  void initState() {
    super.initState();
    _loadConfig();
    if (!kIsWeb && Platform.isAndroid) {
      _widgetClickSub = HomeWidget.widgetClicked.listen(_onWidgetClicked);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    unawaited(_widgetClickSub?.cancel());
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final ssh = Provider.of<SSHProvider>(context, listen: false);
    await ssh.loadConfig();
    if (!mounted) {
      return;
    }
    final pending = widget.pendingLaunch;
    if (pending != null) {
      await WidgetLaunchHandler.execute(
        context,
        pending,
        onTabSelected: _selectTab,
      );
    }
  }

  void _selectTab(AppTab tab) {
    if (!mounted) {
      return;
    }
    setState(() => _selectedTab = tab);
  }

  void _onWidgetClicked(Uri? uri) {
    final action = WidgetLaunchHandler.parseUri(uri);
    if (action == null || !mounted) {
      return;
    }
    // ignore: unawaited_futures
    WidgetLaunchHandler.execute(
      context,
      action,
      onTabSelected: _selectTab,
    );
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

  void _handleToolbarAction(HomeToolbarAction action) {
    switch (action) {
      case HomeToolbarAction.connect:
        _showConnectionModal();
      case HomeToolbarAction.profiles:
        _showProfileManager();
      case HomeToolbarAction.snippets:
        _showSnippetConfig();
      case HomeToolbarAction.discovery:
        _showNetworkDiscovery();
      case HomeToolbarAction.keys:
        _showKeyManager();
    }
  }

  List<Widget> _buildAppBarActions(SettingsProvider settings) {
    final List<HomeToolbarAction> unpinned = HomeToolbarActionX.displayOrder
        .where((HomeToolbarAction action) =>
            !settings.isToolbarActionPinned(action))
        .toList();

    final List<Widget> actions = <Widget>[
      Consumer<SSHProvider>(
        builder: (context, ssh, child) {
          if (ssh.sessions.any((s) => s.isConnected) &&
              _selectedTab == AppTab.client) {
            return IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
              tooltip: _isFullScreen ? 'Exit Full Screen' : 'Full Screen',
              onPressed: () => setState(() => _isFullScreen = !_isFullScreen),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ];

    for (final HomeToolbarAction action in HomeToolbarActionX.displayOrder) {
      if (!settings.isToolbarActionPinned(action)) {
        continue;
      }
      actions.add(
        IconButton(
          icon: Icon(action.icon),
          tooltip: action.tooltip,
          onPressed: () => _handleToolbarAction(action),
        ),
      );
    }

    if (unpinned.isNotEmpty) {
      actions.add(
        PopupMenuButton<HomeToolbarAction>(
          tooltip: 'More',
          onSelected: _handleToolbarAction,
          itemBuilder: (BuildContext context) =>
              unpinned.map((HomeToolbarAction action) {
            return PopupMenuItem<HomeToolbarAction>(
              value: action,
              child: ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      );
    }

    actions.add(
      IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Settings',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
      ),
    );

    return actions;
  }

  List<AppTab> _visibleTabs(SettingsProvider settings) {
    return <AppTab>[
      AppTab.client,
      if (settings.showServerTab) AppTab.server,
      AppTab.agents,
      AppTab.logs,
    ];
  }

  void _ensureValidTab(SettingsProvider settings) {
    final tabs = _visibleTabs(settings);
    if (!tabs.contains(_selectedTab)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedTab = AppTab.client);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SSHProvider, SettingsProvider>(
      builder: (context, ssh, settings, child) {
        _ensureValidTab(settings);
        final tabs = _visibleTabs(settings);
        final navIndex = tabs.indexOf(_selectedTab).clamp(0, tabs.length - 1);

        // Automatically exit full screen if no sessions are connected
        if (_isFullScreen && !ssh.sessions.any((s) => s.isConnected)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isFullScreen = false);
          });
        }

        final shouldDelegateAgentsBack =
            _selectedTab == AppTab.agents && _agentsChatOpen;

        return PopScope(
          canPop: !shouldDelegateAgentsBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && shouldDelegateAgentsBack) {
              _agentsTabKey.currentState?.handleBack();
            }
          },
          child: KeyboardListener(
            focusNode: _keyboardFocusNode,
            onKeyEvent: _handleKeyEvent,
            child: Scaffold(
              appBar: AppBar(
                actions: _buildAppBarActions(settings),
              ),
              bottomNavigationBar: _isFullScreen
                  ? null
                  : NavigationBar(
                      selectedIndex: navIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedTab = tabs[index];
                        });
                      },
                      destinations: tabs.map((tab) {
                        return switch (tab) {
                          AppTab.client => const NavigationDestination(
                              icon: Icon(Icons.computer),
                              label: 'Client',
                            ),
                          AppTab.server => const NavigationDestination(
                              icon: Icon(Icons.dns),
                              label: 'Server',
                            ),
                          AppTab.agents => const NavigationDestination(
                              icon: Icon(Icons.smart_toy),
                              label: 'Agents',
                            ),
                          AppTab.logs => const NavigationDestination(
                              icon: Icon(Icons.article),
                              label: 'Logs',
                            ),
                        };
                      }).toList(),
                    ),
              body: Column(
                children: [
                  if (!_isFullScreen)
                    KeyboardShortcutBar(
                      forceShowOnMobile: context
                          .watch<SettingsProvider>()
                          .showMobileShortcutBar,
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab.index,
                      children: <Widget>[
                        ClientTab(isFullScreen: _isFullScreen),
                        const ServerTab(),
                        AgentsTab(
                          key: _agentsTabKey,
                          onChatOpenChanged: (open) {
                            if (_agentsChatOpen != open) {
                              setState(() => _agentsChatOpen = open);
                            }
                          },
                        ),
                        const LogViewer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ClientTab extends StatefulWidget {
  final bool isFullScreen;
  const ClientTab({required this.isFullScreen, super.key});

  @override
  State<ClientTab> createState() => _ClientTabState();
}

class _ClientTabState extends State<ClientTab> {
  final Map<String, TerminalController> _controllers =
      <String, TerminalController>{};
  final Map<String, EnterMappingInputHandler> _enterHandlers =
      <String, EnterMappingInputHandler>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TerminalController _controllerFor(
    String sessionId,
    bool sendMouseTaps,
  ) {
    final existing = _controllers[sessionId];
    if (existing != null) {
      existing.setPointerInputs(
        sendMouseTaps
            ? const PointerInputs({PointerInput.tap})
            : const PointerInputs.none(),
      );
      return existing;
    }
    final controller = TerminalController(
      pointerInputs: sendMouseTaps
          ? const PointerInputs({PointerInput.tap})
          : const PointerInputs.none(),
    );
    _controllers[sessionId] = controller;
    return controller;
  }

  void _applyEnterMapping(Terminal terminal, TerminalEnterSends mapping) {
    final existing = _enterHandlers[identityHashCode(terminal).toString()];
    if (existing != null) {
      existing.mapping = mapping;
      terminal.inputHandler = existing;
      return;
    }
    final handler = EnterMappingInputHandler(mapping: mapping);
    _enterHandlers[identityHashCode(terminal).toString()] = handler;
    terminal.inputHandler = handler;
  }

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
              final sessionId = ssh.activeSessionId!;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('SFTP')),
                    body: SftpBrowser(sessionId: sessionId),
                  ),
                ),
              );
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
        ssh.setTerminalEnterSends(settings.terminalEnterSends);

        final activeIds = ssh.sessions.map((s) => s.id).toSet();
        _controllers.removeWhere((id, controller) {
          if (activeIds.contains(id)) {
            return false;
          }
          controller.dispose();
          return true;
        });

        final terminalTheme = settings.appTheme == AppTheme.hacker &&
                settings.terminalColorTheme == TerminalColorTheme.standard
            ? TerminalColorTheme.hacker.toTerminalTheme()
            : settings.terminalColorTheme.toTerminalTheme();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
          children: <Widget>[
            if (!widget.isFullScreen) _buildSessionTabBar(context),
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
                        if (active.lastError != null) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              active.lastError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
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

                _applyEnterMapping(
                  active.terminal,
                  settings.terminalEnterSends,
                );
                final controller = _controllerFor(
                  active.id,
                  settings.sendMouseTaps,
                );

                return Container(
                  color: terminalTheme.background,
                  child: _TerminalLongPressHost(
                    onLongPress: () {
                      active.terminal.keyInput(
                        TerminalKey.f10,
                        shift: true,
                      );
                    },
                    child: TerminalView(
                      active.terminal,
                      controller: controller,
                      padding: const EdgeInsets.all(8),
                      theme: terminalTheme,
                      textStyle:
                          TerminalStyleBuilder.buildTerminalStyle(settings),
                      autoResize: true,
                      onSecondaryTapDown: (_, __) {
                        active.terminal.keyInput(
                          TerminalKey.f10,
                          shift: true,
                        );
                      },
                    ),
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
            if (ssh.sessions.any((s) => s.isConnected) && !widget.isFullScreen)
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
        ),
        );
      },
    );
  }
}

/// Detects long-press via [Listener] (avoids gesture-arena conflicts with
/// xterm's selection long-press) and sends a context-menu key.
class _TerminalLongPressHost extends StatefulWidget {
  const _TerminalLongPressHost({
    required this.onLongPress,
    required this.child,
  });

  final VoidCallback onLongPress;
  final Widget child;

  @override
  State<_TerminalLongPressHost> createState() => _TerminalLongPressHostState();
}

class _TerminalLongPressHostState extends State<_TerminalLongPressHost> {
  static const Duration _longPressDuration = Duration(milliseconds: 550);
  static const double _moveSlop = 18;

  int? _pointer;
  Offset? _downPosition;
  bool _fired = false;

  void _cancel() {
    _pointer = null;
    _downPosition = null;
    _fired = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointer = event.pointer;
        _downPosition = event.localPosition;
        _fired = false;
        Future<void>.delayed(_longPressDuration, () {
          if (!mounted || _pointer != event.pointer || _fired) {
            return;
          }
          _fired = true;
          widget.onLongPress();
        });
      },
      onPointerMove: (event) {
        if (_pointer != event.pointer || _downPosition == null) {
          return;
        }
        if ((event.localPosition - _downPosition!).distance > _moveSlop) {
          _cancel();
        }
      },
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: widget.child,
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
