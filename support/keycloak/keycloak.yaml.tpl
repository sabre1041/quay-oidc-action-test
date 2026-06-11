apiVersion: k8s.keycloak.org/v2beta1
kind: Keycloak
metadata:
  name: keycloak
  namespace: keycloak-mtls
spec:
  additionalOptions:
    - name: https-client-auth
      value: request
    - name: https-trust-store-file
      value: /etc/client-ca/truststore.p12
    - name: https-trust-store-password
      secret:
        key: truststore-password
        name: client-ca-truststore
  db:
    host: postgresql-db
    passwordSecret:
      key: password
      name: postgresql-db
    usernameSecret:
      key: username
      name: postgresql-db
    vendor: postgres
  hostname:
    hostname: $KEYCLOAK_HOST
  http:
    tlsSecret: keycloak-tls
  ingress:
    enabled: true
  instances: 1
  unsupported:
    podTemplate:
      spec:
        containers:
          - volumeMounts:
              - mountPath: /etc/client-ca
                name: truststore
        volumes:
          - name: truststore
            secret:
              secretName: client-ca-truststore
