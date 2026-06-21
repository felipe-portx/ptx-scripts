#!/bin/bash

# Disabling 'set -e' globally so we can manually catch and log the exit codes safely
set +e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' utility is required but not installed. Please install it first."
    exit 1
fi

echo "Fetching AWS temporary credentials from ptx..."

# Create a temporary file to capture any underlying system/tool errors (stderr)
ERR_TMP=$(mktemp)

# 1. Capture stdout into the variable, and redirect stderr to our temp file
creds_json=$(ptx aws-credential-process 2>"$ERR_TMP")
EXIT_CODE=$?

# 2. Check if the ptx command itself crashed or failed
if [ $EXIT_CODE -ne 0 ]; then
    if [ -s "$ERR_TMP" ]; then
        echo "❌ Error: 'ptx' command failed with exit code $EXIT_CODE."
        echo "📋 'ptx' Error Log:"
        cat "$ERR_TMP"
        rm -f "$ERR_TMP"
        exit 1
    else
        echo "📋 'ptx' Notice: You must be logged in to use this script."
        echo "🏃 Running ptx login ..."
        
        # Trigger login
        ptx login
        if [ $? -ne 0 ]; then
            echo "❌ Error: Login process failed or was aborted."
            rm -f "$ERR_TMP"
            exit 1
        fi
        
        # RETRY: Attempt to fetch credentials again after successful login
        echo "🔄 Retrying credential fetch..."
        creds_json=$(ptx aws-credential-process 2>"$ERR_TMP")
        if [ $? -ne 0 ]; then
            echo "❌ Error: 'ptx' failed to fetch credentials even after a successful login."
            if [ -s "$ERR_TMP" ]; then cat "$ERR_TMP"; fi
            rm -f "$ERR_TMP"
            exit 1
        fi
    fi
fi
rm -f "$ERR_TMP"

# 3. Check if the returned JSON is empty, literally "null", or an empty object "{}"
if [ -z "$creds_json" ] || [ "$creds_json" = "null" ] || [ "$creds_json" = "{}" ]; then
    echo "❌ Error: 'ptx' returned a blank, null, or empty JSON response."
    echo "📋 Raw output received: '$creds_json'"
    exit 1
fi

# 4. Parse fields (handles flat layout OR nested .Credentials block automatically)
if echo "$creds_json" | jq -e '.Credentials' >/dev/null 2>&1; then
    ACCESS_KEY=$(echo "$creds_json" | jq -r '.Credentials.AccessKeyId')
    SECRET_KEY=$(echo "$creds_json" | jq -r '.Credentials.SecretAccessKey')
    SESSION_TOKEN=$(echo "$creds_json" | jq -r '.Credentials.SessionToken')
else
    ACCESS_KEY=$(echo "$creds_json" | jq -r '.AccessKeyId')
    SECRET_KEY=$(echo "$creds_json" | jq -r '.SecretAccessKey')
    SESSION_TOKEN=$(echo "$creds_json" | jq -r '.SessionToken')
fi

# 5. Final validation to make sure keys aren't empty strings or "null" texts
if [ -z "$ACCESS_KEY" ] || [ "$ACCESS_KEY" = "null" ] || [ -z "$SESSION_TOKEN" ] || [ "$SESSION_TOKEN" = "null" ]; then
    echo "❌ Error: Could not parse valid AWS keys out of the JSON payload."
    echo "📋 Raw output received: $creds_json"
    exit 1
fi

# 6. Apply keys to the AWS CLI profile
aws configure set aws_access_key_id "$ACCESS_KEY" --profile ptx-session
aws configure set aws_secret_access_key "$SECRET_KEY" --profile ptx-session
aws configure set aws_session_token "$SESSION_TOKEN" --profile ptx-session

echo "✅ Success! The 'ptx-session' profile has been updated and is ready to use."

echo ""
echo "⚠️ ===================================== IMPORTANT REMINDER ===================================== ⚠️"
echo "  To use these credentials, you MUST append the profile flag to your commands:"
echo "  👉  aws s3 ls --profile ptx-session"
echo ""
echo "  💡 PRO-TIP: Lock your current terminal tab to this profile so you can skip typing the flag:"
echo "  👉  export AWS_PROFILE=ptx-session"
echo "===================================================================================================="
echo ""