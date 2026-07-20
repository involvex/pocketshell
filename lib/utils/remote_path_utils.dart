abstract final class RemotePath {
  static String normalize(String path) {
    var p = path.replaceAll(r'\', '/');
    if (p.length > 1 && p.endsWith('/')) {
      final drive = RegExp(r'^[A-Za-z]:/$').hasMatch(p);
      if (!drive) p = p.substring(0, p.length - 1);
    }
    if (p.isEmpty) return '/';
    return p;
  }

  static bool isRoot(String path) {
    final p = normalize(path);
    if (p == '/' || p == '.') return true;
    return RegExp(r'^[A-Za-z]:/$').hasMatch(p);
  }

  static String join(String base, String name) {
    final b = normalize(base);
    var n = name.replaceAll(r'\', '/');
    if (n == '..') return parent(b);
    if (n.startsWith('/')) {
      if (RegExp(r'^[A-Za-z]:/').hasMatch(b)) {
        n = n.substring(1);
      } else {
        // Absolute unix path — ignore base.
        return normalize(n);
      }
    }
    if (RegExp(r'^[A-Za-z]:/').hasMatch(n)) return normalize(n);
    if (b == '/') return '/$n';
    if (RegExp(r'^[A-Za-z]:/$').hasMatch(b)) return '$b$n';
    return '$b/$n';
  }

  static String parent(String path) {
    final p = normalize(path);
    if (isRoot(p)) return p;
    final i = p.lastIndexOf('/');
    if (i <= 0) return '/';
    // Keep "C:/" when stripping the last segment of "C:/Users".
    if (RegExp(r'^[A-Za-z]:/').hasMatch(p) && i == 2) {
      return p.substring(0, 3); // "C:/"
    }
    return p.substring(0, i);
  }
}
