#!/bin/sh

# Default filename values
MFA_SERIAL_FILE=`echo ${HOME}/.aws/.mfaserial`
AWS_TOKEN_FILE=`echo ${HOME}/.aws/.awstoken`
AWS_CREDENTIALS_PATH=`echo ${HOME}/.aws/credentials`
DURATION_SECONDS=129600

inputMFASerial() {
echo "Tip - You can get your ARN for MFA device here: https://console.aws.amazon.com/iam/home#/security_credentials"
while true; do
    read -p "Please input your MFA ARN: " mfa
    case $mfa in
        "") echo "Please input a valid value.";;
        * ) echo $mfa > $MFA_SERIAL_FILE; break;;
    esac
done
}


getTempCredential(){
  while true; do
      read -p "Please input your 6 digit MFA token: " token
      case $token in
          [0-9][0-9][0-9][0-9][0-9][0-9] ) MFA_TOKEN=$token; break;;
          * ) echo "Please enter a valid 6 digit pin." ;;
      esac
  done

  # Run the awscli command
  # shellcheck disable=SC2006
  authenticationOutput=`aws sts get-session-token --serial-number ${MFA_SERIAL} --token-code ${MFA_TOKEN} --duration-seconds ${DURATION_SECONDS}`

  # Save authentication to some file
  echo "$authenticationOutput" > "$AWS_TOKEN_FILE";
  storeTempCredential
}

storeTempCredential() {

 perl -0777 -i -pe 's/\n+\[mfa\]\naws_access_key_id = [[:upper:][:digit:]]+\naws_secret_access_key = [[:alnum:]+\/]+\naws_session_token = [[:alnum:]+\/]+\n?//igs' ${AWS_CREDENTIALS_PATH}

 echo "

[mfa]
aws_access_key_id = `echo ${authenticationOutput} | jq -r '.Credentials.AccessKeyId'`
aws_secret_access_key = `echo ${authenticationOutput} | jq -r '.Credentials.SecretAccessKey'`
aws_session_token = `echo ${authenticationOutput} | jq -r '.Credentials.SessionToken'` " >> ${AWS_CREDENTIALS_PATH}
}


if [ ! -e $MFA_SERIAL_FILE ]; then
  inputMFASerial
fi

# Retrieve the serial code
MFA_SERIAL=`cat $MFA_SERIAL_FILE`


if [ -e $AWS_TOKEN_FILE ]; then
  authenticationOutput=`cat $AWS_TOKEN_FILE`
  authExpiration=`echo $authenticationOutput | jq -r '.Credentials.Expiration'`
  nowTime=`date -u +'%Y-%m-%dT%H:%M:%SZ'`

  if [ "$authExpiration" \< "$nowTime" ]; then
    echo "Your last token has expired"
    getTempCredential
  fi
else
  getTempCredential
fi

echo '[mfa] profile updated! Please add --profile mfa to aws commands you want to run. Eg: aws s3 ls --profile mfa'
