# docker-aws-secrets-downloader

## Script Usage
```
./download-decrypt-secrets.sh <DynamoTableName> <SecretKey or RepoName> <SecretName>
```

Where:
* `DynamoTableName` is either the table used for storage of build secrets or the cluster's secrets table
* `SecretKey` or `RepoName` is either `cluster` (for the cluster secrets) or the repo name previously used to store the secrets via Orca
* `SecretName` is the secret to query for. Ex: `DATADOG_ACCESS_KEY` or `SUMO_API_KEY`

## DynamoDB JSON Format
The script utilizes JQ to parse the JSON returned from DynamoDB. The following format must be used for all secrets:

```
"[repo_name|cluster]": {
	"secret_name": {
		"type": "[file|env|invoke|rsa]",
		"path": "[DATADOG_KEY|/root/.dockercfg]",
		"permissions": "644",
		"contents": "DDKEY|{\"registry\":\"https://someregistry\"}|<privatekey>"
	}
}
```

* The top-level property is either the literal value `cluster` or the unique name of the project's repository (`demo-project`).
* The secret_name is the name used to query for the secret later via this script (see the CLI argument)
* "type" can be:
  * `file` if the decrypted secret contents should be saved to a file
  * `env` if the decrypted secret contents should be written to an environment variable
  * `invoke` if the decrypted secret contents should be printed out to the console (useful when this script is invoked from other scripts)
  * `rsa` if the decrypted secret contents are an RSA private key (this will cause them to be base64 decoded)
* "path" is only used when "type" is `file`, `rsa`, or `env` and represents the location or environment variable name which the secret will be saved under.
* "permissions" is only used when "type" is `file` and represents the set of permissions to apply to the file.
* "contents" is the unencrypted secret string.
  * If the "type" is `file` and the contents span multiple lines or contain JSON, it must be escaped (to create a valid string).
  * If the "type" is `rsa`, the contents should be the base64 string representing the unencrypted private key.

## Examples

The following secrets JSON blob would be used for the cluster:

```
{
    "cluster": {
        "TWISTLOCK_KEY": {
        	"type": "invoke",
        	"contents": "twistylockykey"
        },
        "SYSDIG_KEY": {
        	"type": "file",
        	"path": "/root/.sysdig",
        	"permissions": "644",
        	"contents": "jhlsa84iuk293"
        },
        "DATADOG_KEY": {
        	"type": "file",
        	"path": "/root/.datadog",
        	"permissions": "644",
        	"contents": "abcdef123ghij"
        },
        "SUMO_ACCESS_KEY": {
        	"type": "file",
        	"path": "/root/.sumologic",
        	"permissions": "644",
        	"contents": "ID=ourid\nSECRET=oursecret"
        },
        "FLIGHT_DIRECTOR": {
        	"type": "file",
        	"path": "/root/.flight-director",
        	"permissions": "644",
        	"contents": "/FD/GITHUB_CLIENT_ID clientid\n/FD/GITHUB_CLIENT_SECRET clientsecret\n/FD/GITHUB_ALLOWED_TEAMS org/team org/otherteam"
        },
        "HUD": {
        	"type": "file",
        	"path": "/root/.hud",
        	"permissions": "644",
        	"contents": "/HUD/client-id clientid\n/HUD/client-secret clientsecret"
        },
        "MARATHON": {
        	"type": "file",
        	"path": "/root/.marathon",
        	"permissions": "644",
        	"contents": "/marathon/username a-username\n/marathon/password a-password"
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
        	"contents": "somesecretstuff"
        },
        "NPM_CONFIG": {
        	"type": "file",
        	"path": "/root/.npmrc",
        	"permissions": "644",
        	"contents": "registry=https://registry.npmjs.org/\nnpm.example.com/:_password=kajs93o2==\nnpm.example.com/:username=user\nnpm.example.com/:email=user@example.com\nnpm.example.com/:always-auth=true"
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