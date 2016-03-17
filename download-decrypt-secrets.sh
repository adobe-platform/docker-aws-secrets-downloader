#!/bin/bash

# Usage: ./download-decrypt-secrets [options]
# -r|--region     Pass a region to use. If none is provided, the region will be looked up via AWS metadata
# -k|--key        The secret key to use. Either "cluster" or the name of the application.
# -t|--table      The DynamoDB table to query.
# -n|--name       The name of the secret.

function usage {
    echo "usage: $0 [options]"
    echo "       -r|--region    (optional) If not provided, the region will be looked up via AWS metadata (EC2-only)."
    echo "       -k|--key       (optional) The secret table key to use. Either \"cluster\" or the name of the application. If none is provided, \"cluster\" is used."
    echo "       -t|--table     The DynamoDB table to query."
    echo "       -n|--name      The name of the secret. Ex: SUMO_LOGIC_KEY"
    exit 1
}

while [[ $# > 1 ]]
do
key="$1"

case $key in
    -r|--region)
    REGION="$2"
    shift;;
    -k|--key)
    KEY="$2"
    shift;;
    -n|--name)
    NAME="$2"
    shift;;
    -t|--table)
    TABLE="$2"
    shift;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

if [ -z "$NAME" ]; then
    echo "Secret name is required."
    usage
fi

if [ -z "$TABLE" ]; then
    echo "DynamoDB table name is required."
    usage
fi

if [ -z "$REGION" ]; then
    AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    REGION=${AZ%?}
fi

if [ -z "$KEY" ]; then
    KEY="cluster"
fi

# Save the key to a JSON file required by aws cli
echo "{\"SecretKey\": {\"S\": \"$KEY\"}}" > key.json

SECRETJSON=`aws dynamodb get-item --table-name $TABLE --key file://key.json --output json --region $REGION`
SECRETVAL=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$NAME'"].M.contents.S'`
SECRETTYPE=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$NAME'"].M.type.S'`

if [ "$SECRETVAL" = "null" ] || [ "$SECRETTYPE" = "null" ]; then
    echo "No secret or invalid type found for $KEY"
    exit 1
fi

echo "$SECRETVAL" | base64 -d > blob.json

DECRYPTED=`aws kms decrypt --ciphertext-blob fileb://blob.json --query Plaintext --output text --region $REGION | base64 -d`
rm key.json
rm blob.json

if [ "$SECRETTYPE" = "invoke" ]; then
    echo "$DECRYPTED"
elif [[ "$SECRETTYPE" = "file" ]]; then
    echo "$DECRYPTED"
elif [[ "$SECRETTYPE" = "rsa" ]]; then
    # RSA keys are base64'd before encrypting
    echo "$DECRYPTED" | base64 -d
else
    echo "Invalid secret type"
    exit 1
fi

exit 0