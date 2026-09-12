import 'dart:io';

void main() async {
  try {
    final socket = await SecureSocket.connect('dishi.delstarfordworks.co.ke', 443);
    final cert = socket.peerCertificate;
    if (cert != null) {
      print('Copy the following bytes into _sslCertBytes in secure_http_client.dart:\n');
      print(cert.der.toList());
    } else {
      print('No certificate found.');
    }
    socket.destroy();
  } catch (e) {
    print('Error: $e');
  }
}
