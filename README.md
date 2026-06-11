# keycloak-quarkus-mtls

Demonstrating the use of Quarkus OIDC mTLS using Keycloak

## Prerequisites

Ensure that the following are installed and available locally

* `openssl`
* `envsubst`
* OpenShift Command Line Interface (CLI)
* Java JDK 21

## Certificate Creation

Execute the following command to generate the required certificates


1. Create CA Private Key

```shell
openssl genrsa -out support/certs/ca-key.pem 4096
````

2. Create CA Certificate

```shell
openssl req -new -x509 -days 3650 -key support/certs/ca-key.pem -out support/certs/ca-cert.pem \
  -subj "/C=US/O=MyCompany/CN=MyCompany Root CA"
```

3. Create Client CA Private Key

```shell
openssl genrsa -out support/certs/client-key.pem 4096
```

4. Create Client CSR

```shell
openssl req -new -key support/certs/client-key.pem -out support/certs/client.csr \
  -subj "/C=US/O=MyCompany/CN=keycloak-quarkus-mtls"
```

5. Generate the Client Certificate

```shell
openssl x509 -req -days 730 -in support/certs/client.csr \
  -CA support/certs/ca-cert.pem -CAkey support/certs/ca-key.pem -CAcreateserial \
  -out support/certs/client-cert.pem
```

6. Generate a Java Truststore containing the CA to be used by Keycloak

```shell
keytool -importcert -file support/certs/ca-cert.pem -alias my-client-ca \
  -keystore support/certs/keycloak-truststore.p12 -storetype PKCS12 \
  -storepass changeit -noprompt
```

7. Generate a Java Truststore containing the Certificate to be used by the Quarkus App

```shell
openssl pkcs12 -export -in support/certs/client-cert.pem -inkey support/certs/client-key.pem \
    -out support/certs/quarkus-truststore.p12 -name quarkus -passout pass:changeit
```

## OpenShift Deployment

1. Login to the OpenShift cluster using the CLI

2. Apply Manifests

Execute the following to create a new namespace called `keycloak-tls`, deploy the Keycloak Operator and PostgreSQL

```shell
oc apply -f support/keycloak
```

3. Add the Truststore to the namespace as a Secret

```shell
oc create secret -n keycloak-mtls generic client-ca-truststore \
  --from-file=truststore.p12=support/certs/keycloak-truststore.p12 \
  --from-literal=truststore-password=changeit
```

4. Create a Certificate for Keycloak to use for HTTPS Requests

A standard TLS certificate is needed to terminate HTTPS requests in Keycloak. Since Client Certificates will be used as part of this implementation, any Ingress/Route that is used in this solution will need to utilize _Passthrough_ termination (To by configured later within the `Keycloak` CR). This certificate can be created manually or via an external process (such as `cert-manager`) as described in the next two options


4.1. `cert-manager`

4.1.1. Deploy the `cert-manager` operator

```shell
oc apply -f support/cert-manager/operator
```

4.1.2. Create the `ClusterIssuer`

Once the `cert-manager` Operator has been installed, add the `ClusterIssuer` that will use _ACME_ and an _HTTP-01_ challenge

```shell
oc apply -f support/cert-manager/instance/clusterissuer.yaml
```

4.1.3. Create the `Certificate`

```shell
KEYCLOAK_HOST=keycloak-mtls.apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }') envsubst < support/cert-manager/instance/certificate.yaml.tpl | oc apply -f-
```

4.2.1. Manual Certificate Creation

```shell
oc create secret tls keycloak-tls -n keycloak-mtls --cert=path/to/cert/file --key=path/to/key/file 
```

5. Deploy Keycloak by applying the `Keycloak` CR:

```shell
KEYCLOAK_HOST=keycloak-mtls.apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }') envsubst < support/keycloak/keycloak.yaml.tpl | oc apply -f-
```

## Keycloak Configuration

1. Obtain the password for the `temp-admin` username by locating the `keycloak-temp-admin` Secret in the `` Secret

```shell
oc extract -n keycloak-mtls secret/keycloak-initial-admin --keys=password --to=-
```

2. Navigate to Keycloak

```shell
echo https://$(oc get keycloak -n keycloak-mtls keycloak -o jsonpath='{ .spec.hostname.hostname }')
```

3. Create a new Realm called `quarkus-mtls`

Click **Manage Realms** -> **Create Realm**

4. Create a test User

Create a new user called `test-user` for the purpose of testing authentication

* Click **Users**
* Click **Create new user**
* Enter the username `test-user` along with an _email_, _first name_, _last name_. Click **Create**
* Set a password by clicking **Credentials** -> **Set password**. Enter a desired password, uncheck _Temporary_ and click **Save**

5. Create a Client for the Quarkus App

* Click **Clients** -> **Create client**
* Enter a client ID of `quarkus`. Click **Next**
* Enable the **Client authentication** option. Check the **Service account roles** Click **Next**
* Enter `http://localhost:8080/` in the _Valid redirect URI's_ field. Click **Save**

6. Enable mTLS authentication for the Client

* Click the **Credentials** tab within the `quarkus` Client
* Click the _Client Authenticator_ dropdown and select **X509 Certificate**
* Extract the DN from the client certificate

```shell
openssl x509 -in support/certs/client-cert.pem -noout -subject -nameopt RFC2253 | sed 's/^subject=//'
```

* Enter the returned value into the _Subject DN_ field
* Click **Save** and then **Yes** to confirm changes

## Run the Quarkus App

1. Build the Quarkus App

```shell
./mvnw clean install
```

2. Run the Quarkus App

```shell
java -jar target/quarkus-app/quarkus-run.jar -Dquarkus.oidc.auth-server-url=https://$(oc get keycloak -n keycloak-mtls keycloak -o jsonpath='{ .spec.hostname.hostname }')/realms/quarkus-mtls
```

3. Launch the Quarkus App

Navigate to [http://localhost:8080](http://localhost:8080)

Login with the Keycloak user created previously

Once authenticated, you will be presented with a simple webpage with a link that provides details related to the authenticated user. All facilitated via Quarkus mTLS client authentication!
