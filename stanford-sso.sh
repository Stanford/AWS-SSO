#!/bin/bash
#  Copyright 2015
#  The Board of Trustees of the Leland Stanford Junior University

set -e
shopt -s extglob # enables pattern lists like +(...|...)
# Default variables
init() {
  # Script name
  script=$(basename "${BASH_SOURCE[0]}" .sh)

  # Script actions
  actionsRegexp='+(create|delete|show)'
  
  # Dryrun flag. Default not run-run.
  dryrun=0

  # Metadata URL
  metadataUrl='https://idp.stanford.edu/metadata.xml'
}

# Create saml provider
create_saml_provider() {
  samlMetadata=$(curl -s -k $metadataUrl | tee /tmp/samlMetadata.xml)
  if ! [[ "$samlMetadata" =~ "entityID=\"https://" ]];
  then
    echo "$samlMetadata"
    echo "Invalid metadata"
    exit 1
  fi

  echo "Creating saml provider $name."
  cmd="aws --profile $profile iam create-saml-provider --name=$name --output=text --saml-metadata-document file:///tmp/samlMetadata.xml"
  [ $dryrun -eq 0 ] && $cmd || echo $cmd 

  # If no account alias, create one
  accountAlias=$(aws --profile itlab  iam list-account-aliases | jq --raw-output '.AccountAliases[]')
  if [ -z "$accountAlias" ]; 
  then
    echo "Creating account alias ${script}-${profile}"
    cmd="aws --profile $profile iam create-account-alias --account-alias ${script}-${profile}"
    [ $dryrun -eq 0 ] && $cmd || echo $cmd 
  fi
}

# Show SAML provider
show_saml_provider() {
  aws --profile $profile iam get-saml-provider --saml-provider-arn=$samlProviderArn
}

# Delete SAML provider
delete_saml_provider() {
  echo "Deleting saml provider $name."
  cmd="aws --profile $profile iam delete-saml-provider --saml-provider-arn=$samlProviderArn"
  [ $dryrun -eq 0 ] && $cmd || echo $cmd 
 
  # Also remove alias we created
  accountAlias=$(aws --profile itlab  iam list-account-aliases | jq --raw-output '.AccountAliases[]')
  if [ "$accountAlias" = "${script}-${profile}" ];
  then
    cmd="aws --profile $profile iam delete-account-alias --account-alias ${script}-${profile}"
    [ $dryrun -eq 0 ] && $cmd || echo $cmd 
  fi
}

# Create role
create_role() {
  cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$accountId:saml-provider/$name"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
EOF

  # Create role and assume idp trust policy
  echo "Creating role $roleName"
  cmd1="aws --profile $profile iam create-role --role-name $roleName --assume-role-policy-document file:///tmp/trust-policy.json"
  # Grant access 
  cmd2="aws --profile $profile iam attach-role-policy --role-name $roleName --policy-arn $policyArn"
  [ $dryrun -eq 0 ] && $cmd1 && $cmd2 || echo $cmd1 && echo $cmd2 
}
  
# Delete role - only delete role created with this script. 
delete_role() {
  echo "Deleting role $roleName"
  cmd1="aws --profile $profile iam detach-role-policy --role-name $roleName --policy-arn=$policyArn"
  cmd2="aws --profile $profile iam delete-role --role-name $roleName"
  [ $dryrun -eq 0 ] && $cmd1 && $cmd2 || echo $cmd1 && echo $cmd2
}

# Output
print_info() {
  if [ $action = 'create' ]; then
    echo ""
    echo "All done! Next step. Submit the following request to https://helpsu.stanford.edu/helpsu/3.0/auth/helpsu-form?pcat=shibboleth to create idp server setup."
    echo ""
    echo "When idp server setup is complete, you can login to AWS console SSO through this url:"
    echo "https://idp.stanford.edu/idp/profile/SAML2/Unsolicited/SSO?providerId=urn:amazon:webservices"
    echo ""
  elif [ $action = 'delete' ]; then
    echo "All done! Next step. Submit the following request to https://helpsu.stanford.edu/helpsu/3.0/auth/helpsu-form?pcat=shibboleth to remove idp server setup."
  fi
  cat <<EOF
      Account number: $accountId
      Provider name: arn:aws:iam::$accountId:saml-provider/$name
      Role-name: $roleName
      Workgroup: $workgroup
EOF
}

# Valid managed policy name
validate_policy() {
  policyArn=$(aws --profile $profile iam list-policies | jq --raw-output --arg p "$permission" '.Policies[] | select(.PolicyName == $p).Arn')
  if [ -z "$policyArn" ];
  then
    aws --profile $profile iam list-policies | jq --arg p "$permission" --raw-output '.Policies[].PolicyName' | sort 
    echo "Valid policies are shown as above."
    exit 1
  else
    roleName=${permission}-generatedby-${script}
  fi
}

# Docs
help(){
  echo "stanford-sso -a <action> -c <config> [-n <name>] -p <permissino> [-d]"
  echo ""
  echo " -a <create|show|delete>: action. create, show or delete SSO setup by this tool."
  echo " -c <aws config>: authenticate using profile defined by configuration."
  echo " -n <provider-name>: the name of the idp provider, for example 'stanford-idp'."
  echo " -p <ReadOnlyAccess|AdministratorAccess|list-policies>: ReadOnlyAccess, AdministratorAccess, or list other valid AWS managed polices."
  echo " -u <url-for-metadata>: optional. metadata url for the idp provider. Default 'https://idp.stanford.edu/metadata.xml'."
  echo " -w <workgroupname>: Stanford workgroup name to link into this saml provider setup. e.g. itlab:anchorage-admin" 
  echo " -d     : dryrun. print out the commands"
  echo " -h     : Help"
}

# Main

# Set default values
init

while getopts "a:c:p:n:u:w:hd" OPTION
do
  case $OPTION in
    a)
      action=$OPTARG
      case $action in
        $actionsRegexp) 
           ;;
        *)
          echo "Unsupported action $action."
          exit 1
      esac
      ;;
    c)
      profile=$OPTARG
      ;;
    p)
      permission=$OPTARG
      ;;
    n)
      name=$OPTARG
      ;;
    u)
      metadataUrl=$OPTARG
      if ! [[ "$metadataUrl" =~ "https" ]]; 
      then
        echo "metadata url should contain https."
        echo "e.g. https://idp.stanford.edu/metadata.xml"
        exit 1
      fi
      ;;
    w)
      workgroup=$OPTARG
      ;;
    d)
      dryrun=1
      ;;
    [h?])
      help
      exit
      ;;
  esac
done

if [[ -z $action || -z $profile || -z $name ]]; then
  help
  echo "-a, -c, and -n  are required."
  exit 1
elif [[ $action =~ ^(create|delete)$ && -z $permission && -z $workgroup ]]; then
  echo "create or delete requires access permission and workgroup name."
  exit 1
fi

echo "Getting AWS account number ..."
accountId=$(aws --profile $profile iam get-user | jq '.User.Arn' | grep -Eo '[[:digit:]]{12}')
if [ -z "$accountId" ]; then
  echo "Cannot find AWS account number."
  exit 1
fi


# Get saml provider arn
echo "$action $name"
samlProviderArn=$(aws --profile $profile iam list-saml-providers | jq --raw-output ".SAMLProviderList[] | select(.Arn == \"arn:aws:iam::$accountId:saml-provider/$name\") | .Arn")

# Call functions based on action 
case $action in
  'create')
    if  [ "$samlProviderArn" == "arn:aws:iam::$accountId:saml-provider/$name" ];
    then
     show_saml_provider
     echo "SAML provider $name is already setup."
     exit 0
    else
      validate_policy && create_saml_provider && create_role
    fi
    ;;
  'show')
    if  [ "$samlProviderArn" != "arn:aws:iam::$accountId:saml-provider/$name" ];
    then
      echo "SAML provider $name doesn't exist."
      exit 1
    else
      show_saml_provider
    fi
    ;; 
  'delete')
    if  [ "$samlProviderArn" != "arn:aws:iam::$accountId:saml-provider/$name" ];
    then
      echo "SAML provider $name doesn't exist."
      exit 1
    else
      validate_policy && delete_saml_provider && delete_role
    fi
    ;; 
esac

[ $dryrun -eq 1 ] && echo "Dryrun mode. Nothing is changed." || print_info 

# Cleanup
rm -rf /tmp/trust-policy.json
rm -rf /tmp/samlMetadata.xml

exit 0
