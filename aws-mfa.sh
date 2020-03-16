#!/bin/sh

# Default filename values
MFA_SERIAL_FILE=`echo ${HOME}/.aws/.mfaserial`
Temp_MFA_SERIAL_FILE=`echo ${HOME}/.aws/.mfaserial-temp`
AWS_TOKEN_FILE=`echo ${HOME}/.aws/.awstoken`
AWS_CREDENTIALS_PATH=`echo ${HOME}/.aws/credentials`
DURATION_SECONDS=129600

inputMFASerial() {
   MFA_SERIAL_number=`aws iam list-mfa-devices --output text`;
   echo "$MFA_SERIAL_number" > "$Temp_MFA_SERIAL_FILE";
   echo "`awk '{print $3}' $Temp_MFA_SERIAL_FILE`" >> ${MFA_SERIAL_FILE}
   rm -f $Temp_MFA_SERIAL_FILE
   echo "your mfaserial has been saved"
}


getTempCredential(){
  while true; do
      read -p "Please input your 6 digit MFA token: " token
      case $token in
          [0-9][0-9][0-9][0-9][0-9][0-9] ) MFA_TOKEN=$token; break;;
          * ) echo "Please enter a valid 6 digit pin." ;;
      esac
  done

  authenticationOutput=`aws sts get-session-token --serial-number ${MFA_SERIAL} --token-code ${MFA_TOKEN} --duration-seconds ${DURATION_SECONDS} --output text`

  if [ ! -z "$authenticationOutput" ]; then
        # Save authentication to some file
        echo "$authenticationOutput" > "$AWS_TOKEN_FILE";
        storeTempCredential
        echo '[mfa] profle has been updated! Please add --profile mfa to aws commands you want to run. Eg: aws s3 ls --profile mfa'
  fi

}

storeTempCredential() {

 perl -0777 -i -pe 's/\n+\[mfa\]\naws_access_key_id = [[:upper:][:digit:]]+\naws_secret_access_key = [[:alnum:]+\/]+\naws_session_token = [[:alnum:]+\/]+\n?//igs' ${AWS_CREDENTIALS_PATH}

echo "

[mfa]
aws_access_key_id = `awk '{print $2}' $AWS_TOKEN_FILE `
aws_secret_access_key = `awk '{print $4}' $AWS_TOKEN_FILE`
aws_session_token = `awk '{print $5}' $AWS_TOKEN_FILE` " >> ${AWS_CREDENTIALS_PATH}
}


if [ ! -e $MFA_SERIAL_FILE ]; then
  inputMFASerial
fi

# Retrieve the serial code
MFA_SERIAL=`cat $MFA_SERIAL_FILE`


if [ -e $AWS_TOKEN_FILE ]; then
  authenticationOutput=`cat $AWS_TOKEN_FILE`
  authExpiration=`awk '{print $3}' $AWS_TOKEN_FILE`
  nowTime=`date -u +'%Y-%m-%dT%H:%M:%SZ'`

  if [ "$authExpiration" \< "$nowTime" ]; then
    echo "Your last token has expired"
    getTempCredential
  else
    echo '[mfa] not expired yet! Please add --profile mfa to aws commands you want to run. Eg: aws s3 ls --profile mfa'
  fi
else
  getTempCredential
fi
