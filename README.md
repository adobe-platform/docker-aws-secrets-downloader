# docker-aws-secrets-downloader

This script and container aid in the download and decryption of secrets and configs stored in DynamoDB. For secrets, the stored value is decrypted with KMS before being returned. Config values are returned as plaintext without being decrypted (since they are stored in plaintext in DynamoDB). This script can be used to view all of the available secrets and configs and then iterate through each to decrypt and load where needed.

CAUTION: This script or container does not actually place the secrets or configs into etcd, environment variables, or files. It merely returns it for use by a parent script.

## Script Usage
```
./download-decrypt-secrets.sh [options]
    -r|--region    (optional) If not provided, the region will be looked up via AWS metadata (EC2-only).
    -t|--table     The DynamoDB table to query.
    -k|--key       The table key to use. Ex: "secrets" or "configs"
    -n|--name      (optional) The name of the secret or config. Ex: SUMO_LOGIC_KEY. If none is provided, a list of all secrets or configs is returned
    -f|--format    (optional) Can be "plain". If provided, will print the raw plaintext secret without metadata."
```

The script can be run from within a Docker container or stand-alone on either AWS infrastructure or traditional servers.

### Docker Container
```
$ docker pull behance/docker-aws-secrets-downloader
$ docker run docker-aws-secrets-downloader --table SOME_TABLE --key secrets --name SECRET_NAME --format plain
$ yoursecretval
```

### Usage on AWS Infrastructure
Running on AWS means that the region can be determined automatically via the AWS metadata service.

```
$ ./download-decrypt-secrets.sh -t SOME_TABLE -k secrets -n SECRET_NAME
```

### Usage on Traditional Servers
Running on traditional servers means that the region must be provided. Failure to provide the region will result in the script hanging as it attempts to contact the (unavailable) AWS metadata service.

```
$ ./download-decrypt-secrets.sh -t SOME_TABLE -k secrets -n SECRET_NAME -r us-east-1
```

## Running Examples

### List Available Secrets

```
$ ./download-decrypt-secrets.sh --table test-sandbox-ue1-cluster-secrets-table --key secrets
DATADOG_KEY
FD_GITHUB_ALLOWED_TEAMS
FD_GITHUB_CLIENT_ID
FD_GITHUB_CLIENT_SECRET
GIT_PULL_KEY
HUD_GITHUB_CLIENT_ID
HUD_GITHUB_CLIENT_SECRET
MARATHON_PASSWORD
MARATHON_USERNAME
SUMOLOGIC_ACCESS_ID
SUMOLOGIC_SECRET
SYSDIG_KEY
```

### Decrypt Secret with Metadata

```
$ ./download-decrypt-secrets.sh --table test-sandbox-ue1-cluster-secrets-table --key secrets --name DATADOG_KEY
DATADOG_KEY etcd /ddapikey abcdef12345ghijk
```

### Decrypt Secret without Metadata (Plaintext)

```
$ ./download-decrypt-secrets.sh --table test-sandbox-ue1-cluster-secrets-table --key secrets --name DATADOG_KEY --format plain
abcdef12345ghijk
```

### List Available Configs

```
$ ./download-decrypt-secrets.sh --table test-sandbox-ue1-cluster-secrets-table --key configs
/test/valueone
/test/valuetwo
```

### Display Config with Metadata

```
$ ./download-decrypt-secrets.sh --table test-sandbox-ue1-cluster-secrets-table --key configs --name /test/valueone
/test/valueone configvalue
```

### Display Config without Metadata (Plaintext)

```
$ ./download-decrypt-secrets.sh --table test-sandbox-ue1-cluster-secrets-table --key configs --name /test/valueone --format plain
configvalue
```

## DynamoDB JSON Format
The script utilizes JQ to parse the JSON returned from DynamoDB. The following format must be used for all secrets:

```
"[repo_name|cluster]": {
	"secret_name": {
        "type": "[file|env|invoke|rsa]",
        "path": "[DATADOG_KEY|/root/.dockercfg]",
        "permissions": "644",
        "contents": "base64 encoded secret contents"
    }
}
```

* The top-level property is either the literal value `cluster` or the unique name of the project's repository (`demo-project`).
* The secret_name is the name used to query for the secret later via this script (see the CLI argument)

### Properties

#### type

* The type of secret that this is.
* _Required_: Yes
* _Type_: String
* _Allowed Values_: "file", "env", "invoke", "rsa", "etcd"

#### path

* Where the secret should be saved. If the type is "file" or "rsa", this is a path. If the type is "env" this is a environment variable name.
* _Required_: Conditional. Required if type is "file", "rsa", "env", or "etcd".
* _Type_: String
* _Examples_: "/root/.sampleconfig", "SAMPLE_SECRET", "/root/.ssh/userkey", "/FD/sampleetcdval"

#### permissions

* The Linux permissions set for the file or private key.
* _Required_: No. Used only if type is "file" or "rsa". If none is provided then, default is used.
* _Default_: "644"
* _Type_: String
* _Examples_: "644", "755", "600"

#### contents

* The base64 encoded string representing the encrypted secret. To obtain this, the plaintext secret must first be encoded with KMS.
* _Allowed Values_: _any valid base64 string_
* _Required_: Yes
* _Type_: String

## Examples

The following secrets JSON blob would be used for the cluster:

```
{
    "cluster": {
        "TWISTLOCK_KEY": {
        	"type": "invoke",
        	"contents": "dHdpc3R5bG9ja3lrZXk="
        },
        "SYSDIG_KEY": {
        	"type": "file",
        	"path": "/root/.sysdig",
        	"permissions": "644",
        	"contents": "amhsc2E4NGl1azI5Mw=="
        },
        "DATADOG_KEY": {
        	"type": "file",
        	"path": "/root/.datadog",
        	"permissions": "644",
        	"contents": "YWJjZGVmMTIzZ2hpag=="
        },
        "SUMO_ACCESS_KEY": {
        	"type": "file",
        	"path": "/root/.sumologic",
        	"permissions": "644",
        	"contents": "SUQ9b3VyaWRcblNFQ1JFVD1vdXJzZWNyZXQ="
        },
        "FLIGHT_DIRECTOR": {
        	"type": "file",
        	"path": "/root/.flight-director",
        	"permissions": "644",
        	"contents": "L0ZEL0dJVEhVQl9DTElFTlRfSUQgY2xpZW50aWRcbi9GRC9HSVRIVUJfQ0xJRU5UX1NFQ1JFVCBjbGllbnRzZWNyZXRcbi9GRC9HSVRIVUJfQUxMT1dFRF9URUFNUyBvcmcvdGVhbSBvcmcvb3RoZXJ0ZWFt"
        },
        "HUD": {
        	"type": "file",
        	"path": "/root/.hud",
        	"permissions": "644",
        	"contents": "L0hVRC9jbGllbnQtaWQgY2xpZW50aWRcbi9IVUQvY2xpZW50LXNlY3JldCBjbGllbnRzZWNyZXQ="
        },
        "MARATHON": {
        	"type": "file",
        	"path": "/root/.marathon",
        	"permissions": "644",
        	"contents": "L21hcmF0aG9uL3VzZXJuYW1lIGEtdXNlcm5hbWVcbi9tYXJhdGhvbi9wYXNzd29yZCBhLXBhc3N3b3Jk"
        },
        "GIT_PULL_KEY": {
        	"type": "rsa",
        	"path": "/root/.gitkey",
        	"permissions": "600",
        	"contents": "U29tZSByZWFsbHkgc2VjcmV0IFJTQSBrZXkgaGVyZQ==..."
        }
    }
}
```

The following secrets JSON blob would be used for a customer config:

```
{
    "my_awesome_project": {
        "SOMESECRET": {
        	"type": "invoke",
        	"contents": "c29tZXNlY3JldHN0dWZm"
        },
        "NPM_CONFIG": {
        	"type": "file",
        	"path": "/root/.npmrc",
        	"permissions": "644",
        	"contents": "cmVnaXN0cnk9aHR0cHM6Ly9yZWdpc3RyeS5ucG1qcy5vcmcvXG5ucG0uZXhhbXBsZS5jb20vOl9wYXNzd29yZD1rYWpzOTNvMj09XG5ucG0uZXhhbXBsZS5jb20vOnVzZXJuYW1lPXVzZXJcbm5wbS5leGFtcGxlLmNvbS86ZW1haWw9dXNlckBleGFtcGxlLmNvbVxubnBtLmV4YW1wbGUuY29tLzphbHdheXMtYXV0aD10cnVl"
        },
        "GIT_PULL_KEY": {
        	"type": "rsa",
        	"path": "/root/.gitkey",
        	"permissions": "600",
        	"contents": "U29tZSByZWFsbHkgc2VjcmV0IFJTQSBrZXkgaGVyZQ==..."
        },
        "SUPER_SECRET_ENV": {
        	"type": "env",
        	"path": "SUPER_SECRET_ENV",
        	"contents": "c2VjcmV0dmFs"
        }
    }
}
```