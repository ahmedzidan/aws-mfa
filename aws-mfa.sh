#!/usr/bin/env bash

# Default filename values
profile="default"
while getopts "p:" option; do
  case "${option}" in
    p) profile="${OPTARG}" ;;
    *)
        echo "Usage: ${0} [-p] <profile>" >&2
        exit 1
        ;;
 esac
done
MFA_SERIAL_FILE="${HOME}/.aws/.${profile}-serial"
AWS_TOKEN_FILE="${HOME}/.aws/.${profile}-awstoken"
AWS_CREDENTIALS_PATH="${HOME}/.aws/credentials"
DURATION_SECONDS=129600

inputMFASerial() {
   aws iam list-mfa-devices --output text --profile "${1}" | awk '{print $3}' > "${MFA_SERIAL_FILE}"
   echo "your mfaserial has been saved"
}


getTempCredential(){
  profile="${1}"
  new_profile="${profile}-mfa"
  while true; do
      read -p "Please input your 6 digit MFA token: " token
      case $token in
          [0-9][0-9][0-9][0-9][0-9][0-9] ) MFA_TOKEN=$token; break;;
          * ) echo "Please enter a valid 6 digit pin." ;;
      esac
  done

  authenticationOutput=$(aws sts get-session-token --serial-number "${MFA_SERIAL}" --token-code ${MFA_TOKEN} --duration-seconds ${DURATION_SECONDS} --output text --profile "${profile}")
  if [ ! -z "$authenticationOutput" ]; then
        # Save authentication to some file
        echo "$authenticationOutput" > "$AWS_TOKEN_FILE";
        storeTempCredential ${new_profile}
        echo "[ ${new_profile} ] profle has been updated! Please add --profile ${new_profile} to aws commands you want to run. Eg: aws s3 ls --profile ${new_profile}"
  fi

}

storeTempCredential() {
 new_profile="${1}"
 perl -0777 -i -pe "s/\n+\[${new_profile}\]\naws_access_key_id = [[:upper:][:digit:]]+\naws_secret_access_key = [[:alnum:]+\/]+\naws_session_token = [[:alnum:]+\/]+\n?//igs" ${AWS_CREDENTIALS_PATH}

echo "

[${new_profile}]
aws_access_key_id = $(awk '{print $2}' "$AWS_TOKEN_FILE" )
aws_secret_access_key = $(awk '{print $4}' "$AWS_TOKEN_FILE")
aws_session_token = $(awk '{print $5}' "$AWS_TOKEN_FILE") " >> "${AWS_CREDENTIALS_PATH}"
}



if [ ! -e "$MFA_SERIAL_FILE" ]; then
  inputMFASerial "${profile}"
fi

# Retrieve the serial code
MFA_SERIAL=$(cat "$MFA_SERIAL_FILE")
#
#
if [ -e "${AWS_TOKEN_FILE}" ]; then
  authenticationOutput=$(cat "$AWS_TOKEN_FILE")
  authExpiration=$(awk '{print $3}' "$AWS_TOKEN_FILE")
  nowTime=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  if [ "$authExpiration" \< "$nowTime" ]; then
    echo "Your last token has expired"
    getTempCredential "${profile}"
  else
    echo "[${profile}-mfa] not expired yet! Please add --profile ${profile}-mfa to aws commands you want to run. Eg: aws s3 ls --profile ${profile}-mfa"
  fi
else
  getTempCredential "${profile}"
fi
