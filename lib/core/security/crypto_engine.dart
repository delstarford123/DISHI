import 'dart:math';

class CryptoEngine {
  /// Generates a cryptographically secure UUIDv4.
  /// Used for offline identifiers to prevent Data Enumeration attacks.
  static String generateOfflineUuid() {
    final random = Random.secure();
    
    // Generate 16 bytes (128 bits) of random data
    final List<int> bytes = List.generate(16, (_) => random.nextInt(256));
    
    // Set the version to 4 (UUIDv4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    
    // Set the variant to RFC4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    
    // Convert to hex string formatted as UUID
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    
    return '\${hex[0]}\${hex[1]}\${hex[2]}\${hex[3]}-\${hex[4]}\${hex[5]}-\${hex[6]}\${hex[7]}-\${hex[8]}\${hex[9]}-\${hex[10]}\${hex[11]}\${hex[12]}\${hex[13]}\${hex[14]}\${hex[15]}';
  }
}
