#!/bin/zsh
  
toAddr=$1
subject=$2
body=${@:3}

echo "[$0] toAddr [$toAddr] is omitted, as aws ses sandbox doesn't support sending to other receptants other than its own verifed email identities "

if [[ -z "${AWS_SES_SMTP_USER}" ]];then
        echo "[$0] env var AWS_SES_SMTP_USER must be set. See https://ap-southeast-1.console.aws.amazon.com/ses/home?region=ap-southeast-1#/smtp"
        exit 1
fi

if [[ -z "${AWS_SES_SMTP_PASS}" ]];then
        echo "[$0] env var AWS_SES_SMTP_PASS must be set. See https://ap-southeast-1.console.aws.amazon.com/ses/home?region=ap-southeast-1#/smtp"
        exit 1
fi

toAddr=shwchurch3+aws@gmail.com
fromAddr=beijingshouwangjiaohui@outlook.com
fromName="Beijing Shouwang Church"

if [[ -z "$body" ]];then
        body=$subject
fi

if [[ -z $toAddr || -z $subject ]];then
        echo [$0] example.smtp@gmail.com "Hi test"
        exit 1
fi

aws_server=email-smtp.ap-southeast-1.amazonaws.com:587
openssl s_client -crlf -quiet -starttls smtp -connect $aws_server

encoded_smtp_user=$(echo -n "$AWS_SES_SMTP_USER" | openssl enc -base64)
encoded_smtp_pass=$(echo -n "${AWS_SES_SMTP_PASS}" | openssl enc -base64)

openssl s_client -crlf -quiet -starttls smtp -connect $aws_server  <<EOF
EHLO outlook.com
AUTH LOGIN
${encoded_smtp_user}
${encoded_smtp_pass}
MAIL FROM: $fromAddr
RCPT TO: $toAddr
DATA
From: $fromName <${fromAddr}>
To: ${toAddr}
Subject: $subject

Notification: $body
.
QUIT
EOF

## curl -n --ssl-reqd --mail-from "example.smtp@gmail.com" --mail-rcpt "$toAddr" -T - --url smtps://smtp.gmail.com:465 --user "example.smtp@gmail.com:Smtp(2020)" <<EOF
## From: "Someone" <example.smtp@gmail.com>
## To: $toAddr
## Subject: $subject 


