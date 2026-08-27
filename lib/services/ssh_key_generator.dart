import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' hide SecureRandom;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import '../models/ssh_key.dart';

class SSHKeyGenerator {
  /// Generates a real cryptographic SSH key pair.
  static Future<SSHKey> generateKey(SSHKeyType keyType, String name) async {
    final secureRandom = _createSecureRandom();

    switch (keyType) {
      case SSHKeyType.rsa2048:
        return _generateRSAKey(name, 2048, secureRandom);
      case SSHKeyType.rsa4096:
        return _generateRSAKey(name, 4096, secureRandom);
      case SSHKeyType.ed25519:
        return _generateEd25519Key(name);
      case SSHKeyType.ecdsa256:
        return _generateECKey(name, 'secp256r1', secureRandom);
      case SSHKeyType.ecdsa384:
        return _generateECKey(name, 'secp384r1', secureRandom);
      case SSHKeyType.ecdsa521:
        return _generateECKey(name, 'secp521r1', secureRandom);
    }
  }

  static SecureRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] = random.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  // ---------------------------------------------------------------------------
  // RSA
  // ---------------------------------------------------------------------------

  static Future<SSHKey> _generateRSAKey(
    String name,
    int bitSize,
    SecureRandom secureRandom,
  ) async {
    final keyParams =
        RSAKeyGeneratorParameters(BigInt.from(65537), bitSize, 64);
    final generator = RSAKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, secureRandom));
    final keyPair = generator.generateKeyPair();

    final publicKey = keyPair.publicKey;
    final privateKey = keyPair.privateKey;

    return SSHKey(
      name: name,
      keyType: bitSize == 2048 ? SSHKeyType.rsa2048 : SSHKeyType.rsa4096,
      publicKey: _encodeRSASshPublicKey(publicKey),
      privateKey: _encodeRSAPrivateKeyPem(privateKey),
    );
  }

  static String _encodeRSASshPublicKey(RSAPublicKey publicKey) {
    final buffer = BytesBuilder();
    _writeSshString(buffer, _bigIntToBytes(publicKey.publicExponent!));
    _writeSshString(buffer, _bigIntToBytes(publicKey.modulus!));
    return 'ssh-rsa ${base64Encode(buffer.toBytes())}';
  }

  static String _encodeRSAPrivateKeyPem(RSAPrivateKey privateKey) {
    final n = privateKey.n!;
    final e = privateKey.publicExponent!;
    final d = privateKey.privateExponent!;
    final p = privateKey.p!;
    final q = privateKey.q!;
    final dP = d.remainder(p - BigInt.from(1));
    final dQ = d.remainder(q - BigInt.from(1));
    final qInv = q.modInverse(p);

    final asn1 = ASN1Sequence(elements: [
      ASN1Integer(BigInt.from(0)), // version
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

  // ---------------------------------------------------------------------------
  // Ed25519
  // ---------------------------------------------------------------------------

  static Future<SSHKey> _generateEd25519Key(String name) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final extracted = await keyPair.extract();

    final privateKeyBytes = extracted.bytes;
    final publicKeyBytes = extracted.publicKey.bytes;

    return SSHKey(
      name: name,
      keyType: SSHKeyType.ed25519,
      publicKey: 'ssh-ed25519 ${base64Encode(publicKeyBytes)}',
      privateKey: _encodeEd25519PrivateKeyPem(
        privateKeyBytes,
        publicKeyBytes,
      ),
    );
  }

  static String _encodeEd25519PrivateKeyPem(
    List<int> privateKeyBytes,
    List<int> publicKeyBytes,
  ) {
    final buffer = BytesBuilder();

    // OpenSSH magic
    buffer.add(Uint8List.fromList('openssh-key-v1\u0000'.codeUnits));
    _writeSshString(buffer, Uint8List.fromList('none'.codeUnits)); // cipher
    _writeSshString(buffer, Uint8List.fromList('none'.codeUnits)); // kdf
    _writeSshString(buffer, Uint8List(0)); // kdf options
    buffer.add(_uint32ToBytes(1)); // number of keys

    // Public key
    final pubKeySsh = BytesBuilder();
    _writeSshString(pubKeySsh, Uint8List.fromList('ssh-ed25519'.codeUnits));
    _writeSshString(pubKeySsh, Uint8List.fromList(publicKeyBytes));
    _writeSshString(buffer, pubKeySsh.toBytes());

    // Private section (checkint1 == checkint2 for unencrypted)
    final checkint = _randomUint32();
    buffer.add(_uint32ToBytes(checkint));
    buffer.add(_uint32ToBytes(checkint));
    _writeSshString(buffer, Uint8List.fromList('ssh-ed25519'.codeUnits));
    _writeSshString(buffer, Uint8List.fromList(publicKeyBytes));
    _writeSshString(buffer, Uint8List.fromList(privateKeyBytes));
    _writeSshString(buffer, Uint8List(0)); // comment

    // Padding to block size
    final totalLen = buffer.toBytes().length;
    final paddingNeeded = 8 - (totalLen % 8);
    if (paddingNeeded < 8) {
      for (var i = 0; i < paddingNeeded; i++) {
        buffer.add([(i + 1) & 0xff]);
      }
    }

    return _wrapPem('OPENSSH PRIVATE KEY', buffer.toBytes());
  }

  // ---------------------------------------------------------------------------
  // ECDSA
  // ---------------------------------------------------------------------------

  static Future<SSHKey> _generateECKey(
    String name,
    String curveName,
    SecureRandom secureRandom,
  ) async {
    final domainParams = ECDomainParameters(curveName);
    final keyParams = ECKeyGeneratorParameters(domainParams);
    final generator = ECKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, secureRandom));
    final keyPair = generator.generateKeyPair();

    final ecPublicKey = keyPair.publicKey;
    final ecPrivateKey = keyPair.privateKey;

    final publicKeyBytes = _ecPointToUncompressed(
      ecPublicKey.Q!,
      domainParams,
    );

    return SSHKey(
      name: name,
      keyType: _curveNameToKeyType(curveName),
      publicKey: _encodeECDSASshPublicKey(curveName, publicKeyBytes),
      privateKey: _encodeECDSAPrivateKeyPem(
        ecPrivateKey.d!,
        publicKeyBytes,
      ),
    );
  }

  static Uint8List _ecPointToUncompressed(
    ECPoint point,
    ECDomainParameters params,
  ) {
    final x = point.x!.toBigInteger()!;
    final y = point.y!.toBigInteger()!;
    final byteLen = (params.curve.fieldSize + 7) ~/ 8;
    final buffer = Uint8List(1 + byteLen * 2);
    buffer[0] = 0x04;
    _bigIntToBytesInto(x, buffer, 1, byteLen);
    _bigIntToBytesInto(y, buffer, 1 + byteLen, byteLen);
    return buffer;
  }

  static String _encodeECDSASshPublicKey(
    String curveName,
    Uint8List publicKeyBytes,
  ) {
    final sshCurveName = _curveNameToSshCurveName(curveName);
    final buffer = BytesBuilder();
    _writeSshString(
      buffer,
      Uint8List.fromList('ecdsa-sha2-$sshCurveName'.codeUnits),
    );
    _writeSshString(buffer, Uint8List.fromList(sshCurveName.codeUnits));
    _writeSshString(buffer, publicKeyBytes);
    return 'ecdsa-sha2-$sshCurveName ${base64Encode(buffer.toBytes())}';
  }

  static String _encodeECDSAPrivateKeyPem(
    BigInt privateKey,
    Uint8List publicKeyUncompressed,
  ) {
    // SEC1 ECPrivateKey structure:
    // SEQUENCE { INTEGER(1), INTEGER(d), TAGGED[0] { BIT STRING(publicKey) } }
    final privateKeyInt = ASN1Integer(privateKey);
    final pubKeyAsn1 = ASN1BitString(stringValues: publicKeyUncompressed);
    final taggedContent = pubKeyAsn1.encodedBytes!;
    final taggedBytes = _asn1TaggedObject(0, taggedContent, constructed: true);
    final tagged = ASN1Object.fromBytes(taggedBytes);

    final seq = ASN1Sequence(elements: [
      ASN1Integer(BigInt.from(1)), // version
      privateKeyInt,
      tagged,
    ]);
    return _wrapPem('EC PRIVATE KEY', seq.encodedBytes!);
  }

  // ---------------------------------------------------------------------------
  // ASN.1 helpers
  // ---------------------------------------------------------------------------

  /// Manually constructs a context-specific tagged ASN.1 object.
  ///
  /// pointycastle 4.x does not provide an [ASN1TaggedObject] class, so we
  /// encode the TLV manually: `[0xA0 | tagNumber] [length] [valueBytes]`.
  static Uint8List _asn1TaggedObject(
    int tagNumber,
    Uint8List valueBytes, {
    bool constructed = false,
  }) {
    final tagByte = 0xA0 | tagNumber | (constructed ? 0x20 : 0);
    final lengthBytes = _asn1EncodeLength(valueBytes.length);
    final result = Uint8List(1 + lengthBytes.length + valueBytes.length);
    result[0] = tagByte;
    result.setRange(1, 1 + lengthBytes.length, lengthBytes);
    result.setRange(
      1 + lengthBytes.length,
      result.length,
      valueBytes,
    );
    return result;
  }

  static Uint8List _asn1EncodeLength(int length) {
    if (length < 0x80) {
      return Uint8List(1)..[0] = length;
    } else if (length < 0x100) {
      return Uint8List(2)..[0] = 0x81; //..[1] = length;
    } else if (length < 0x10000) {
      final bytes = Uint8List(3);
      bytes[0] = 0x82;
      bytes[1] = (length >> 8) & 0xff;
      bytes[2] = length & 0xff;
      return bytes;
    } else {
      final bytes = Uint8List(5);
      bytes[0] = 0x84;
      bytes.buffer.asByteData().setInt32(1, length, Endian.big);
      return bytes;
    }
  }

  // ---------------------------------------------------------------------------
  // General helpers
  // ---------------------------------------------------------------------------

  static Uint8List _bigIntToBytes(BigInt number) {
    final hex = number.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    final bytes = <int>[];
    for (var i = 0; i < padded.length; i += 2) {
      bytes.add(int.parse(padded.substring(i, i + 2), radix: 16));
    }
    var start = 0;
    while (start < bytes.length - 1 && bytes[start] == 0) {
      start++;
    }
    return Uint8List.fromList(bytes.sublist(start));
  }

  static void _bigIntToBytesInto(
    BigInt number,
    Uint8List buffer,
    int offset,
    int byteLength,
  ) {
    final bytes = _bigIntToBytes(number);
    final start = offset + byteLength - bytes.length;
    buffer.setRange(start, start + bytes.length, bytes);
  }

  static void _writeSshString(BytesBuilder buffer, Uint8List data) {
    buffer.add(_uint32ToBytes(data.length));
    buffer.add(data);
  }

  static Uint8List _uint32ToBytes(int value) {
    return Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  static int _randomUint32() {
    final random = Random.secure();
    return random.nextInt(0x100000000);
  }

  static String _wrapPem(String label, Uint8List derBytes) {
    final b64 = base64Encode(derBytes);
    final buffer = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < b64.length; i += 64) {
      final end = min(i + 64, b64.length);
      buffer.writeln(b64.substring(i, end));
    }
    buffer.write('-----END $label-----');
    return buffer.toString();
  }

  static SSHKeyType _curveNameToKeyType(String curveName) {
    return switch (curveName) {
      'secp256r1' => SSHKeyType.ecdsa256,
      'secp384r1' => SSHKeyType.ecdsa384,
      'secp521r1' => SSHKeyType.ecdsa521,
      _ => throw ArgumentError('Unknown curve: $curveName'),
    };
  }

  static String _curveNameToSshCurveName(String curveName) {
    return switch (curveName) {
      'secp256r1' => 'nistp256',
      'secp384r1' => 'nistp384',
      'secp521r1' => 'nistp521',
      _ => throw ArgumentError('Unknown curve: $curveName'),
    };
  }
}
