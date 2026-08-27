import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkDiscoveryService {
  static final NetworkInfo _networkInfo = NetworkInfo();

  static Future<String?> getLocalIP() async {
    return _networkInfo.getWifiIP();
  }

  static Future<String?> getWifiName() async {
    return _networkInfo.getWifiName();
  }

  /// Scans the local network for hosts with SSH (port 22) open.
  ///
  /// [timeoutMs] - connection timeout per host
  /// [maxConcurrent] - max concurrent connection attempts
  /// [subnet] - optional CIDR subnet (e.g., "192.168.1.0/24"), auto-detected if null
  /// [port] - port to scan (default 22)
  static Future<List<String>> scanNetwork({
    int timeoutMs = 500,
    int maxConcurrent = 50,
    String? subnet,
    int port = 22,
  }) async {
    if (timeoutMs <= 0 || maxConcurrent <= 0) {
      throw ArgumentError('timeoutMs and maxConcurrent must be positive');
    }

    String targetSubnet;
    if (subnet != null) {
      targetSubnet = subnet;
    } else {
      final String? localIP = await getLocalIP();
      if (localIP == null) return <String>[];

      // Detect IPv4 vs IPv6
      if (localIP.contains(':')) {
        // IPv6 - /64 prefix typical for local networks
        final parts = localIP.split(':');
        if (parts.length >= 4) {
          targetSubnet = '${parts[0]}:${parts[1]}:${parts[2]}:${parts[3]}::/64';
        } else {
          return <String>[];
        }
      } else {
        // IPv4 - assume /24
        final parts = localIP.split('.');
        if (parts.length != 4) return <String>[];
        targetSubnet = '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
      }
    }

    final hosts = _expandSubnet(targetSubnet);
    if (hosts.isEmpty) return <String>[];

    final results = <String>[];
    final futures = <Future<String?>>[];

    for (final host in hosts) {
      futures.add(_checkPort(host, port, timeoutMs));

      if (futures.length >= maxConcurrent) {
        final batchResults = await Future.wait(futures);
        futures.clear();
        for (final result in batchResults) {
          if (result != null) {
            results.add(result);
          }
        }
      }
    }

    // Process remaining futures
    if (futures.isNotEmpty) {
      final batchResults = await Future.wait(futures);
      for (final result in batchResults) {
        if (result != null) {
          results.add(result);
        }
      }
    }

    return results;
  }

  /// Expands a CIDR subnet into a list of host IPs (excludes network/broadcast).
  static List<String> _expandSubnet(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return <String>[];

    final prefix = parts[0];
    final prefixLen = int.tryParse(parts[1]);
    if (prefixLen == null) return <String>[];

    if (prefix.contains(':')) {
      // IPv6 - too many addresses, return empty (use targeted scan instead)
      return <String>[];
    }

    // IPv4
    final octets = prefix.split('.');
    if (octets.length != 4) return <String>[];

    final ipInt = (int.parse(octets[0]) << 24) |
        (int.parse(octets[1]) << 16) |
        (int.parse(octets[2]) << 8) |
        int.parse(octets[3]);

    final hostBits = 32 - prefixLen;
    if (hostBits <= 0 || hostBits > 16) {
      // Too many hosts (>65536) or invalid prefix
      return <String>[];
    }

    final hostCount = 1 << hostBits;
    final networkAddr = ipInt & (~((1 << hostBits) - 1));
    final broadcastAddr = networkAddr | ((1 << hostBits) - 1);

    final hosts = <String>[];
    for (var i = 1; i < hostCount - 1; i++) {
      final addr = networkAddr + i;
      if (addr == broadcastAddr) continue;
      final octet0 = (addr >> 24) & 0xFF;
      final octet1 = (addr >> 16) & 0xFF;
      final octet2 = (addr >> 8) & 0xFF;
      final octet3 = addr & 0xFF;
      hosts.add('$octet0.$octet1.$octet2.$octet3');
    }
    return hosts;
  }

  static Future<String?> _checkPort(
      String host, int port, int timeoutMs) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      await socket.close();
      return host;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkPortOpen(String host, int port,
      {int timeoutMs = 2000}) async {
    if (timeoutMs <= 0) throw ArgumentError('timeoutMs must be positive');
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
