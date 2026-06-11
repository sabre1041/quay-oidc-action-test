apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: keycloak-tls
  namespace: keycloak-mtls
spec:
  dnsNames:
    - $KEYCLOAK_HOST
  duration: 2160h
  isCA: false
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt-cluster-issuer
  renewBefore: 360h
  secretName: keycloak-tls
  usages:
    - server auth
