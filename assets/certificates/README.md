# Supplemental HTTPS root certificate

`SSLcom-TLS-Root-2022-RSA.pem` is the public **SSL.com TLS RSA Root CA 2022**
certificate. Some Android TV trust stores lack this root, causing AGE search
requests to fail TLS verification even when the server sends its intermediate.

- Official repository: https://www.ssl.com/repository/
- Download: https://repo-certs.ssl.com/repo/certs/SSLcom-TLS-Root-2022-RSA.pem
- Also verified against the Mozilla-derived bundle at https://curl.se/ca/cacert.pem
- Certificate SHA-256 (DER):
  `8F:AF:7D:2E:2C:B4:70:9B:B8:E0:B3:36:66:BF:75:A5:DD:45:B5:DE:48:0F:8E:A8:D4:BF:E6:BE:BC:17:F2:ED`
- Validity: 2022-08-25 through 2046-08-19

The app loads this packaged asset before creating network clients. Its dedicated
SecurityContext retains platform trust roots and adds this root for both
HttpClient and the public-target SecureSocket connection path. It does not
modify the device trust store, disable TLS validation, or pin AGE's rotating
leaf certificate. This file contains no private key.

When replacing or removing the root, verify the official certificate, review
current CA trust status, and update the fingerprint regression test. Do not
download trust roots dynamically at application startup.
