
This document shows an example of how to set up SSO for AWS console access with an 
IAM role, using Stanford production IdP service as identity provider.  

By using AWS SAML integration, you don't need to create AWS accounts for users who need to access AWS console. Instead, You create a new or use an existing Stanford workgroup that contains users who will use the SSO to gain access to your account's AWS console. 

## Using stanford-sso.sh command line tool

The following instructions apply to MacOS. For other platforms, follow the tool links and instructions on tool sites.

1. Install [Jq](http://stedolan.github.io/jq/)

    ```
    $ brew install jq
    ```
    
1. Install and configure [AWS CLI](https://github.com/aws/aws-cli)

  If you have AWSCLI installed and configured, you can skip this step.

    ```
    $ brew install awscli
    ```
    or

    ```
    $ sudo easy_install pip
    $ sudo pip install --upgrade awscli
    ```
    
    ```
    $ aws configure --profile <aws user>
    ```
 You will be prompted for AWS KEY and AWS SECRET for the aws user. The profile name will be used for AWS authentication/authorizatio to make AWS CLI calls. 

1. Clone the repo

    ```
    $ git clone https://github.com/Stanford/AWS-SSO.git
    $ cd AWS-SSO
    ```
    
1. Run help
    
    ```
    $ ./stanford-sso.sh -h
stanford-sso -a <action> -c <config> -n <provider name> -p <permission> -w <workgroupname> [-u <metadata url>] [-d] [-h] [-l <account-label>] [-r <role-name>]

 -a <create|show|delete>: action. create, show or delete SSO setup by this tool.
 -c <aws config>: authenticate using profile defined by configuration.
 -n <provider-name>: the name of the idp provider, for example 'stanford-idp'.
 -p <ReadOnlyAccess|AdministratorAccess|list-policies>: ReadOnlyAccess, AdministratorAccess, or list other valid AWS managed polices.
 -u <url-for-metadata>: optional. metadata url for the idp provider. Default 'https://idp.stanford.edu/metadata.xml'.
 -w <workgroupname>: Stanford workgroup name to link into this saml provider setup. e.g. itlab:anchorage-admin
 -l <account-label>: Account label (alias) This will be the name displayed to users when logging in e.g. its-main-account
 -r <role-name>: This defines the name of the role that will be created e.g. ops-readonly
 -a <create|show|delete>: action. create, show or delete SSO setup by this tool.
 -d     : dryrun. print out the commands
 -h     : Help

    ```

1. Create SAML provider 
 
 Dry-run:
 
    ```
    $ ./stanford-sso.sh -d -a create -c idg-dev -u https://idp-uat.stanford.edu/metadata.xml -l aws-idg-dev -n stanford-idp-uat -p AdministratorAccess -w itservices:idg-aws -r stanford-idp-uat
Getting AWS account number ...
create stanford-idp-uat
Creating saml provider stanford-idp-uat.
aws --profile idg-dev iam create-saml-provider --name=stanford-idp-uat --output=text --saml-metadata-document file:///tmp/samlMetadata.xml
Creating account alias aws-idg-dev
aws --profile idg-dev iam create-account-alias --account-alias aws-idg-dev
Creating role stanford-idp-uat
aws --profile idg-dev iam create-role --role-name stanford-idp-uat --assume-role-policy-document file:///tmp/trust-policy.json
aws --profile idg-dev iam attach-role-policy --role-name stanford-idp-uat --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
Dryrun mode. Nothing is changed.
    ```

 The above command will do a dry-run to show what will be created. __stanford-idp-uat__ is a descriptive name to identify the idp provider you use. You can pass in the medtadata url for the idp provider on the command line (see help). The default metadata is 'https://idp.stanford.edu/metadata.xml'
 
 
 Real run:
 
     ```
     ./stanford-sso.sh  -a create -c idg-dev -u https://idp-uat.stanford.edu/metadata.xml -l aws-idg-dev -n stanford-idp-uat -p AdministratorAccess -w itservices:idg-aws -r stanford-idp-uat
Getting AWS account number ...
create stanford-idp-uat
Creating saml provider stanford-idp-uat.
arn:aws:iam::123456789012:saml-provider/stanford-idp-uat
Creating account alias aws-idg-dev
Creating role stanford-idp-uat
{
    "Role": {
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "sts:AssumeRoleWithSAML",
                    "Principal": {
                        "Federated": "arn:aws:iam::123456789012:saml-provider/stanford-idp-uat"
                    },
                    "Effect": "Allow",
                    "Condition": {
                        "StringEquals": {
                            "SAML:aud": "https://signin.aws.amazon.com/saml"
                        }
                    },
                    "Sid": ""
                }
            ]
        },
        "RoleId": "*********************",
        "CreateDate": "2016-09-13T17:24:23.675Z",
        "RoleName": "stanford-idp-uat",
        "Path": "/",
        "Arn": "arn:aws:iam::123456789012:role/stanford-idp-uat"
    }
}
aws --profile idg-dev iam attach-role-policy --role-name stanford-idp-uat --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

All done! Next step. Submit the following request to https://helpsu.stanford.edu/helpsu/3.0/auth/helpsu-form?pcat=shibboleth to create idp server setup.

When idp server setup is complete, you can login to AWS console SSO through this url:
https://idp.stanford.edu/idp/profile/SAML2/Unsolicited/SSO?providerId=urn:amazon:webservices
    ```

1. Delete SAML provider

    ```
    $ ./stanford-sso.sh -a delete -c <aws profile> -n stanford-idp -p AdministratorAccess -w myworkgroup 
    ```
    
## Manual steps

### identity provider setup

Login to your AWS console.

1. Select IAM service
1. Click 'Identity Providers' 
1. Click 'Create SAML Provider'
    Choose a name that is easy to identify which provider provides SSO, e.g. stanford-idp. 
1. Upload idP-only SAML metadata document from:

       [idp-only metadata](https://idp.stanford.edu/metadata.xml)
   
    Click "Create" button to finish the provider setup.

### Create IAM role using this provider in the trust policy

   When you finish identy provider creation, there is a link to take you
   to create an IAM role, or you you can go back to IAM service, select 
   "Roles->Create New Role".

1. Create role name: e.g. myadminaccount-sso
1. Select __Role for Identity Provider Access__ in the role type selection screen near
   the bottom.
1. Select __Grant Web Single Sign-On (WebSSO) access to SAML providers__
1. Accept the default "Verify Role Trust" policy.
1. Set permissions: assign the role a permission, e.g. Administrator, Power admin user, etc. It depends on your use case.  
1. Click "Create Role" to finish

##  Configure relying party trust between  IdP and AWS

Amazon currently only works with IdP-initiated SSO - our Unsolicited SSO Endpoints 
are not listed in our IdP metadata, but the handlers and decoders appear to be 
enabled.  AWS only uses the metadata for the certificate / entity ID.

You need to submit the request to [HelpSU](https://stanford.service-now.com/it_services?id=sc_cat_item&sys_id=21cfc2684fdf6e0054c23f828110c77e) to complete the setup with the following information.

* The [AWS metadata](https://signin.aws.amazon.com/static/saml-metadata.xml)

* Attribute Resolver Settings

  Replace the account number, role-name, and workgroup with the values you created in the SSO setup steps. You can find the information from AWS console under IAM->Roles, IAM->Identity Provider sections. 
  
        Account number: 123456789012
        Provider name: arn:aws:iam::123456789012:saml-provider/stanford-idp
        Role-name: myadminaccount-sso
        Workgroup: awsworkgroup

##  Create a virtual host to access the your accoount's AWS console

After idp service is updated with your AWS SSO data, you can access AWS console by going to:

        https://idp.stanford.edu/idp/profile/SAML2/Unsolicited/SSO?providerId=urn:amazon:webservices

Note that if you have multiple accounts with the same idp provider, you will see the list of SSO accounts on AWS console. Pick the account number for which you want to login.

You can also create a virtual hostname, e.g.  "my-account-aws-console.stanford.edu"
and redirect it to:

        https://idp.stanford.edu/idp/profile/SAML2/Unsolicited/SSO?providerId=urn:amazon:webservices
        

