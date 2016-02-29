#!/bin/bash
if [ $# -ne 3 ]; then
    echo "Usage: $0 <DynamoTableName> <SecretKey or RepoName> <SecretName>"
    exit 0
fi

# Save the key to a JSON file required by aws cli
echo "{\"SecretKey\": {\"S\": \"$2\"}}" > key.json

SECRETJSON=`aws dynamodb get-item --table-name $1 --key file://key.json --profile behance-dev --output json`
SECRETVAL=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$3'"].M.contents.S'`
SECRETTYPE=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$3'"].M.type.S'`

if [ "$SECRETVAL" = "null" ] || [ "$SECRETTYPE" = "null" ]; then
    echo "No secret or invalid type found for $3"
    exit 1
fi  

echo "$SECRETVAL" | base64 -D > blob.json

DECRYPTED=`aws kms decrypt --ciphertext-blob fileb://blob.json --query Plaintext --output text --region us-west-2 --profile behance-dev | base64 -D`
rm key.json
rm blob.json

if [ "$SECRETTYPE" = "invoke" ]; then
    echo "$DECRYPTED"
elif [[ "$SECRETTYPE" = "file" ]]; then
    SECRETLOCATION=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$3'"].M.location.S'`
    echo "$DECRYPTED" > $SECRETLOCATION
    echo "Secret saved to file: $SECRETLOCATION"
elif [[ "$SECRETTYPE" = "rsa" ]]; then
    # RSA keys are base64'd before encrypting
    echo "$DECRYPTED" | base64 -D > $SECRETLOCATION
    echo "Saved as RSA key"
else
    echo "Invalid secret type"
    exit 1
fi

exit 0