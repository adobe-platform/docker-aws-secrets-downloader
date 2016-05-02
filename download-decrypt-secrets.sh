#!/bin/bash

# Usage: ./download-decrypt-secrets [options]
# -r|--region    (optional) If not provided, the region will be looked up via AWS metadata (EC2-only).
# -t|--table     The DynamoDB table to query.
# -k|--key       The table key to use. Ex: "secrets" or "configs"
# -n|--name      (optional) The name of the secret or config. Ex: SUMO_LOGIC_KEY. If none is provided, a list of all secrets or configs is returned
# -f|--format    (optional) Can be "plain". If provided, will print the raw plaintext secret without metadata."

function usage {
    echo "usage: $0 [options]"
    echo "       -r|--region    (optional) If not provided, the region will be looked up via AWS metadata (EC2-only)."
    echo "       -t|--table     The DynamoDB table to query."
    echo "       -k|--key       The table key to use. Ex: \"secrets\" or \"configs\""
    echo "       -n|--name      (optional) The name of the secret or config. Ex: SUMO_LOGIC_KEY. If none is provided, a list of all secrets or configs is returned"
    echo "       -f|--format    (optional) Can be \"plain\". If provided, will print the raw plaintext secret without metadata."
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
    -f|--format)
    FORMAT="$2"
    shift;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

if [ -z "$TABLE" ]; then
    echo "DynamoDB table name is required."
    usage
fi

if [ -z "$REGION" ]; then
    AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    REGION=${AZ%?}
fi

if [ -z "$KEY" ]; then
    echo "Key is required. Use either \"secrets\" or \"configs\"."
    usage
fi

# Save the key to a JSON file required by aws cli
echo "{\"SecretKey\": {\"S\": \"$KEY\"}}" > key.json

SECRETJSON=`aws dynamodb get-item --table-name $TABLE --key file://key.json --output json --region $REGION`
rm key.json

# If no name is specified, print all available
if [ -z "$NAME" ]; then
    SECRETKEYS=`echo $SECRETJSON | jq -r '.Item.SecretVal.M | keys | sort[]'`
    echo "$SECRETKEYS"
    exit 0
fi

# If requesting a config, print and exit
if [[ "$KEY" = "configs" ]]; then
    SECRETVAL=`echo "$SECRETJSON" | jq -M '.Item.SecretVal.M["'$NAME'"].S' | sed 's/^.\(.*\).$/\1/'`
    
    if [[ "$FORMAT" = "plain" ]]; then
        echo "$NAME $SECRETVAL"
    elif [[ -z "$FORMAT" ]]; then
        echo "$NAME $SECRETVAL"
    fi

    exit 0
fi

SECRETVAL=`echo "$SECRETJSON" | jq -M '.Item.SecretVal.M["'$NAME'"].M.contents.S' | sed 's/^.\(.*\).$/\1/'`
SECRETTYPE=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$NAME'"].M.type.S'`
SECRETPATH=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$NAME'"].M.path.S'`
SECRETPERMISSIONS=`echo "$SECRETJSON" | jq -r '.Item.SecretVal.M["'$NAME'"].M.permissions.S'`

if [ "$SECRETVAL" = "null" ] || [ "$SECRETTYPE" = "null" ]; then
    echo "No secret or invalid type found for $KEY"
    exit 1
fi
echo "$SECRETVAL" | base64 -d > blob.json

DECRYPTED=`aws kms decrypt --ciphertext-blob fileb://blob.json --query Plaintext --output text --region $REGION | base64 -d`
rm blob.json

if [[ "$FORMAT" = "plain" ]]; then
    echo "$DECRYPTED"
    exit 0
fi

if [ "$SECRETTYPE" = "invoke" ]; then
    echo "$NAME $SECRETTYPE $DECRYPTED"
elif [[ "$SECRETTYPE" = "etcd" ]]; then
    echo "$NAME $SECRETTYPE $SECRETPATH $DECRYPTED"
elif [[ "$SECRETTYPE" = "file" ]]; then
    echo "$NAME $SECRETTYPE $SECRETPATH $SECRETPERMISSIONS $DECRYPTED"
elif [[ "$SECRETTYPE" = "rsa" ]]; then
    # RSA keys are base64'd before encrypting
    echo "$NAME $SECRETTYPE $SECRETPATH $SECRETPERMISSIONS"
    echo "$DECRYPTED" | base64 -d
else
    echo "Invalid secret type"
    exit 1
fi

exit 0
