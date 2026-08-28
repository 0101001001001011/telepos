// Reading the three things SPIFFE actually is: a name, a certificate that
// carries one, and a token that carries one.
//
// Run with: dart run example/rk_spiffe_example.dart

import 'package:rk_spiffe/rk_spiffe.dart';

void main() {
  // 1. A name. Every failure says which clause of the grammar was broken,
  //    and nothing is thrown at you.
  switch (SpiffeId.parse('spiffe://shop-42.telepos/till/17/terminal/3')) {
    case SpiffeOk(value: final id):
      print('trust domain: ${id.trustDomain}');
      print('segments:     ${id.segments}');
    case SpiffeErr(error: final error):
      print('not an id: $error');
  }

  for (final candidate in <String>[
    'spiffe://Shop-42.telepos/till/17', // uppercase trust domain
    'spiffe://shop-42.telepos/till//17', // an empty segment
    'spiffe://shop-42.telepos:443/till', // a port
    'https://shop-42.telepos/till/17', // the wrong scheme entirely
  ]) {
    print('$candidate -> ${SpiffeId.parse(candidate).errorOrNull}');
  }

  // 2. A certificate. `parseUnverifiedPem` reads the document and applies the
  //    leaf rules of the X509-SVID specification. It verifies nothing: no
  //    signature is checked and no chain is walked, which is why the name of
  //    the entry point says so.
  const pem = '-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n';
  switch (X509Svid.parseUnverifiedPem(pem)) {
    case SpiffeOk(value: final svid):
      print('${svid.id} until ${svid.notAfter}');
      // Hand these bytes to whatever owns trust in your system — in this
      // author's packages that is rk_pki — and ask it whether to believe them.
      print('${svid.certificate.der.length} bytes to verify elsewhere');
    case SpiffeErr(error: final error):
      print('not an SVID: $error');
  }

  // 3. A token. Same rule: claims are checked, the signature is handed back
  //    for somebody with a trust bundle to check.
  switch (JwtSvid.parseUnverified('eyJhbGciOiJub25lIn0.e30.')) {
    case SpiffeOk(value: final svid):
      print('${svid.id} for ${svid.audience}');
      print(
        'verify ${svid.signature.length} bytes over "${svid.signingInput}"',
      );
    case SpiffeErr(error: final error):
      print('not a JWT-SVID: $error');
  }
}
