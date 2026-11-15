/// Permission bits (low 9 bits of a Unix file mode).
const int kSftpModePermissionMask = 0x1FF;

/// Parses a Unix mode from an octal string (e.g. `644`, `0755`).
int? parseSftpOctalMode(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final String digits = trimmed.startsWith('0') && trimmed.length > 1
      ? trimmed.substring(1)
      : trimmed;
  if (!RegExp(r'^[0-7]+$').hasMatch(digits)) {
    return null;
  }
  return int.parse(digits, radix: 8);
}

/// Formats permission bits as a zero-padded octal string (without type prefix).
String formatSftpPermissionOctal(int mode) {
  final int perms = mode & kSftpModePermissionMask;
  return perms.toRadixString(8).padLeft(3, '0');
}

/// Returns the 9 permission bits; [index] 0 = owner read … 8 = other execute.
bool sftpModeHasPermission(int mode, int index) {
  if (index < 0 || index > 8) {
    return false;
  }
  final int bit = 1 << (8 - index);
  return (mode & kSftpModePermissionMask & bit) != 0;
}

/// Sets or clears one permission bit; preserves type bits in [mode].
int setSftpModePermission(int mode, int index, bool enabled) {
  final int bit = 1 << (8 - index);
  final int typeBits = mode & ~kSftpModePermissionMask;
  var perms = mode & kSftpModePermissionMask;
  if (enabled) {
    perms |= bit;
  } else {
    perms &= ~bit;
  }
  return typeBits | perms;
}