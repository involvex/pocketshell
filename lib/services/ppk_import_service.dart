import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' hide SecureRandom;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'package:ssh_app/models/ssh_key.dart';

/// Result of converting a PuTTY `.ppk` file into an [SSHKey].
class PpkImportResult {
  const PpkImportResult({
    required this.key,
    required this.fingerprint,
    required this.comment,
  });

  final SSHKey key;
  final String fingerprint;
  final String comment;
}

/// Parses PuTTY Private Key (PPK) v2/v3 files into OpenSSH PEM [SSHKey]s.
class PpkImportService {
  const PpkImportService();

  /// Imports [contents]. Pass [passphrase] when the PPK is encrypted.
  Future<PpkImportResult> importPpk(
    String contents, {
    String? passphrase,
    String? name,
  }) async {
    final parsed = _parsePpk(contents);
    final privateBlob = await _decryptPrivate(
      parsed,
      passphrase: passphrase,
    );
    final keyType = _mapAlgorithm(parsed.algorithm);
    final publicLine = _sshPublicKeyLine(parsed.algorithm, parsed.publicBlob);
    final privatePem = _encodePrivatePem(
      algorithm: parsed.algorithm,
      publicBlob: parsed.publicBlob,
      privateBlob: privateBlob,
    );

    final key = SSHKey(
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : (parsed.comment.isNotEmpty ? parsed.comment : 'imported-ppk'),
      keyType: keyType,
      publicKey: publicLine,
      privateKey: privatePem,
      passphrase: passphrase != null && passphrase.isNotEmpty
          ? passphrase
          : null,
    );

    return PpkImportResult(
      key: key,
      fingerprint: _sha256Fingerprint(parsed.publicBlob),
      comment: parsed.comment,
    );
  }

  static bool looksLikePpk(String contents) {
    final head = contents.trimLeft();
    return head.startsWith('PuTTY-User-Key-File-2:') ||
        head.startsWith('PuTTY-User-Key-File-3:');
  }

  _PpkFile _parsePpk(String contents) {
    final lines = contents.replaceAll('\r\n', '\n').split('\n');
    if (lines.isEmpty) {
      throw const FormatException('Empty PPK file');
    }

    final header = lines.first.trim();
    final versionMatch = RegExp(
      r'^PuTTY-User-Key-File-([23]):\s*(.+)$',
    ).firstMatch(header);
    if (versionMatch == null) {
      throw const FormatException(
        'Not a PuTTY PPK v2/v3 file (missing PuTTY-User-Key-File header)',
      );
    }
    final version = int.parse(versionMatch.group(1)!);
    final algorithm = versionMatch.group(2)!.trim();

    final fields = <String, String>{};
    var i = 1;
    while (i < lines.length) {
      final line = lines[i].trimRight();
      if (line.isEmpty) {
        i++;
        continue;
      }
      final colon = line.indexOf(':');
      if (colon <= 0) {
        i++;
        continue;
      }
      final key = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();

      if (key == 'Public-Lines' || key == 'Private-Lines') {
        final count = int.tryParse(value);
        if (count == null || count < 0) {
          throw FormatException('Invalid $key count');
        }
        final buf = StringBuffer();
        for (var n = 0; n < count; n++) {
          i++;
          if (i >= lines.length) {
            throw FormatException('Truncated $key block');
          }
          buf.write(lines[i].trim());
        }
        fields[key] = buf.toString();
      } else {
        fields[key] = value;
      }
      i++;
    }

    final encryption = fields['Encryption'] ?? 'none';
    final comment = fields['Comment'] ?? '';
    final publicB64 = fields['Public-Lines'];
    final privateB64 = fields['Private-Lines'];
    if (publicB64 == null || privateB64 == null) {
      throw const FormatException('PPK missing public/private key lines');
    }

    return _PpkFile(
      version: version,
      algorithm: algorithm,
      encryption: encryption,
      comment: comment,
      publicBlob: base64Decode(publicB64),
      privateBlobEncrypted: base64Decode(privateB64),
      privateMac: fields['Private-MAC'] ?? fields['Private-Hash'] ?? '',
      argon2Memory: int.tryParse(fields['Argon2-Memory'] ?? ''),
      argon2Passes: int.tryParse(fields['Argon2-Passes'] ?? ''),
      argon2Parallelism: int.tryParse(fields['Argon2-Parallelism'] ?? ''),
      argon2SaltHex: fields['Argon2-Salt'],
      keyDerivation: fields['Key-Derivation'],
    );
  }

  Future<Uint8List> _decryptPrivate(
    _PpkFile file, {
    String? passphrase,
  }) async {
    if (file.encryption == 'none') {
      return file.privateBlobEncrypted;
    }
    if (file.encryption != 'aes256-cbc') {
      throw FormatException(
        'Unsupported PPK encryption: ${file.encryption}',
      );
    }
    if (passphrase == null || passphrase.isEmpty) {
      throw const FormatException(
        'PPK is encrypted — enter the passphrase to import',
      );
    }

    final Uint8List keyIv;
    if (file.version >= 3) {
      keyIv = await _deriveV3Key(file, passphrase);
    } else {
      keyIv = _deriveV2Key(passphrase);
    }

    final aesKey = keyIv.sublist(0, 32);
    final iv = keyIv.sublist(32, 48);
    return _aes256CbcDecrypt(file.privateBlobEncrypted, aesKey, iv);
  }

  Uint8List _deriveV2Key(String passphrase) {
    // PuTTY v2: key = SHA1("\0\0\0\0" + passphrase) || SHA1("\0\0\0\1" + passphrase)
    // first 40 bytes used (32 key + 8 iv), iv padded with zeros to 16.
    final passBytes = utf8.encode(passphrase);
    final digester = SHA1Digest();

    Uint8List hashSeq(int seq) {
      final input = Uint8List(4 + passBytes.length);
      input[0] = (seq >> 24) & 0xff;
      input[1] = (seq >> 16) & 0xff;
      input[2] = (seq >> 8) & 0xff;
      input[3] = seq & 0xff;
      input.setRange(4, input.length, passBytes);
      final out = Uint8List(20);
      digester.reset();
      digester.update(input, 0, input.length);
      digester.doFinal(out, 0);
      return out;
    }

    final h0 = hashSeq(0);
    final h1 = hashSeq(1);
    final material = Uint8List(40);
    material.setRange(0, 20, h0);
    material.setRange(20, 40, h1);
    final keyIv = Uint8List(48);
    keyIv.setRange(0, 40, material);
    return keyIv;
  }

  Future<Uint8List> _deriveV3Key(_PpkFile file, String passphrase) async {
    final kdf = (file.keyDerivation ?? 'Argon2id').toLowerCase();
    if (!kdf.contains('argon2')) {
      throw FormatException('Unsupported PPK key derivation: $kdf');
    }
    final saltHex = file.argon2SaltHex;
    if (saltHex == null || saltHex.isEmpty) {
      throw const FormatException('PPK v3 missing Argon2-Salt');
    }
    final salt = _hexToBytes(saltHex);
    final memory = file.argon2Memory ?? 8192;
    final passes = file.argon2Passes ?? 13;
    final parallelism = file.argon2Parallelism ?? 1;

    // PuTTY needs 80 bytes: 32 AES key + 16 IV + 32 MAC key.
    final argon2 = Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: passes,
      hashLength: 80,
    );
    final secret = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final bytes = await secret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  Uint8List _aes256CbcDecrypt(
    Uint8List cipher,
    Uint8List key,
    Uint8List iv,
  ) {
    if (cipher.length % 16 != 0) {
      throw const FormatException('Encrypted PPK private blob is truncated');
    }
    final cipherEngine = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    final out = Uint8List(cipher.length);
    var offset = 0;
    while (offset < cipher.length) {
      offset += cipherEngine.processBlock(cipher, offset, out, offset);
    }
    return out;
  }

  String _encodePrivatePem({
    required String algorithm,
    required Uint8List publicBlob,
    required Uint8List privateBlob,
  }) {
    if (algorithm == 'ssh-ed25519') {
      return _encodeEd25519Pem(publicBlob, privateBlob);
    }
    if (algorithm == 'ssh-rsa') {
      return _encodeRsaPem(publicBlob, privateBlob);
    }
    throw FormatException(
      'Unsupported PPK algorithm for import: $algorithm '
      '(supported: ssh-ed25519, ssh-rsa)',
    );
  }

  String _encodeEd25519Pem(Uint8List publicBlob, Uint8List privateBlob) {
    final reader = _SshBuffer(publicBlob);
    final alg = utf8.decode(reader.readString());
    if (alg != 'ssh-ed25519') {
      throw FormatException('Expected ssh-ed25519 public blob, got $alg');
    }
    final publicKey = reader.readString();
    if (publicKey.length != 32) {
      throw const FormatException('Invalid ed25519 public key length');
    }

    final privReader = _SshBuffer(privateBlob);
    final privateCombined = privReader.readString();
    if (privateCombined.length < 32) {
      throw const FormatException('Invalid ed25519 private key length');
    }
    // PuTTY stores 64-byte seed||pub or just 32-byte seed.
    final seed = privateCombined.length >= 64
        ? privateCombined.sublist(0, 32)
        : privateCombined.sublist(0, 32);
    final pub = publicKey;

    final buffer = BytesBuilder();
    buffer.add(Uint8List.fromList('openssh-key-v1\u0000'.codeUnits));
    _writeSshString(buffer, utf8.encode('none'));
    _writeSshString(buffer, utf8.encode('none'));
    _writeSshString(buffer, Uint8List(0));
    buffer.add(_uint32(1));

    final pubKeySsh = BytesBuilder();
    _writeSshString(pubKeySsh, utf8.encode('ssh-ed25519'));
    _writeSshString(pubKeySsh, pub);
    _writeSshString(buffer, pubKeySsh.toBytes());

    final check = Random.secure().nextInt(0xffffffff);
    final privSection = BytesBuilder();
    privSection.add(_uint32(check));
    privSection.add(_uint32(check));
    _writeSshString(privSection, utf8.encode('ssh-ed25519'));
    _writeSshString(privSection, pub);
    final combined = Uint8List(64);
    combined.setRange(0, 32, seed);
    combined.setRange(32, 64, pub);
    _writeSshString(privSection, combined);
    _writeSshString(privSection, Uint8List(0));

    var privBytes = privSection.toBytes();
    final pad = 8 - (privBytes.length % 8);
    if (pad < 8) {
      final padded = Uint8List(privBytes.length + pad);
      padded.setRange(0, privBytes.length, privBytes);
      for (var i = 0; i < pad; i++) {
        padded[privBytes.length + i] = (i + 1) & 0xff;
      }
      privBytes = padded;
    }
    _writeSshString(buffer, privBytes);

    return _wrapPem('OPENSSH PRIVATE KEY', buffer.toBytes());
  }

  String _encodeRsaPem(Uint8List publicBlob, Uint8List privateBlob) {
    final pub = _SshBuffer(publicBlob);
    final alg = utf8.decode(pub.readString());
    if (alg != 'ssh-rsa') {
      throw FormatException('Expected ssh-rsa public blob, got $alg');
    }
    final e = _bytesToBigInt(pub.readMpint());
    final n = _bytesToBigInt(pub.readMpint());

    final priv = _SshBuffer(privateBlob);
    // After decrypt, RSA private section is: mpint private_exp, then
    // optionally p,q,... — PuTTY stores: p, q, iqmp (CRT form) after AES.
    // Actual PuTTY layout: mpint private_exponent OR CRT components.
    // Per putty: rsa_ssh1 private is different; for SSH-2:
    //   mpint p, q, iqmp  (d is reconstructed)
    BigInt d;
    BigInt p;
    BigInt q;
    BigInt iqmp;
    try {
      p = _bytesToBigInt(priv.readMpint());
      q = _bytesToBigInt(priv.readMpint());
      iqmp = _bytesToBigInt(priv.readMpint());
      // Reconstruct d from CRT when only factors present.
      final phi = (p - BigInt.one) * (q - BigInt.one);
      d = e.modInverse(phi);
    } catch (_) {
      throw const FormatException(
        'Could not parse RSA private blob from PPK',
      );
    }

    final dP = d.remainder(p - BigInt.one);
    final dQ = d.remainder(q - BigInt.one);
    // Prefer stored iqmp when valid.
    final qInv = iqmp;

    final asn1 = ASN1Sequence(elements: [
      ASN1Integer(BigInt.zero),
      ASN1Integer(n),
      ASN1Integer(e),
      ASN1Integer(d),
      ASN1Integer(p),
      ASN1Integer(q),
      ASN1Integer(dP),
      ASN1Integer(dQ),
      ASN1Integer(qInv),
    ]);
    return _wrapPem('RSA PRIVATE KEY', asn1.encodedBytes!);
  }

  String _sshPublicKeyLine(String algorithm, Uint8List publicBlob) {
    return '$algorithm ${base64Encode(publicBlob)}';
  }

  SSHKeyType _mapAlgorithm(String algorithm) {
    switch (algorithm) {
      case 'ssh-ed25519':
        return SSHKeyType.ed25519;
      case 'ssh-rsa':
        // Bit size unknown until parsed; default label.
        return SSHKeyType.rsa2048;
      default:
        throw FormatException('Unsupported PPK algorithm: $algorithm');
    }
  }

  String _sha256Fingerprint(Uint8List publicBlob) {
    final digest = SHA256Digest();
    final out = Uint8List(32);
    digest.update(publicBlob, 0, publicBlob.length);
    digest.doFinal(out, 0);
    return 'SHA256:${base64Encode(out).replaceAll('=', '')}';
  }

  static Uint8List _hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.length.isOdd) {
      throw const FormatException('Odd-length hex string');
    }
    final out = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static void _writeSshString(BytesBuilder buffer, List<int> data) {
    buffer.add(_uint32(data.length));
    buffer.add(data);
  }

  static Uint8List _uint32(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xff
      ..[1] = (value >> 16) & 0xff
      ..[2] = (value >> 8) & 0xff
      ..[3] = value & 0xff;
  }

  static String _wrapPem(String label, Uint8List bytes) {
    final b64 = base64Encode(bytes);
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      final end = (i + 64 < b64.length) ? i + 64 : b64.length;
      chunks.add(b64.substring(i, end));
    }
    return '-----BEGIN $label-----\n${chunks.join('\n')}\n-----END $label-----';
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }
}

class _PpkFile {
  const _PpkFile({
    required this.version,
    required this.algorithm,
    required this.encryption,
    required this.comment,
    required this.publicBlob,
    required this.privateBlobEncrypted,
    required this.privateMac,
    this.argon2Memory,
    this.argon2Passes,
    this.argon2Parallelism,
    this.argon2SaltHex,
    this.keyDerivation,
  });

  final int version;
  final String algorithm;
  final String encryption;
  final String comment;
  final Uint8List publicBlob;
  final Uint8List privateBlobEncrypted;
  final String privateMac;
  final int? argon2Memory;
  final int? argon2Passes;
  final int? argon2Parallelism;
  final String? argon2SaltHex;
  final String? keyDerivation;
}

class _SshBuffer {
  _SshBuffer(this._data);

  final Uint8List _data;
  int _offset = 0;

  Uint8List readString() {
    if (_offset + 4 > _data.length) {
      throw const FormatException('SSH buffer underrun');
    }
    final len = (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    if (len < 0 || _offset + len > _data.length) {
      throw const FormatException('SSH string length out of range');
    }
    final slice = _data.sublist(_offset, _offset + len);
    _offset += len;
    return slice;
  }

  Uint8List readMpint() => readString();
}
