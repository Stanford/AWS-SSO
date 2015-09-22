
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
    $ ./stanford-sso.sh
    ```

1. Create SAML provider 
 
 Dry-run:
 
    ```
    $ ./stanford-sso.sh -d -a create -c <aws profile> -n stanford-idp -p AdministratorAccess -w myworkgroup 
    ```

 The above command will do a dry-run to show what will be created. __stanford-idp__ is a descriptive name to identify the idp provider you use. You can pass in the medtadata url for the idp provider on the command line (see help). The default metadata is 'https://idp.stanford.edu/metadata.xml'
 
 
 Real run:
 
     ```
     $ ./stanford-sso.sh -a create -c <aws profile> -n stanford-idp -p AdministratorAccess -w myworkgroup
     All done! Next step. Submit the following request to https://helpsu.stanford.edu/helpsu/3.0/auth/helpsu-form?pcat=shibboleth to create idp server setup.

     When idp server setup is complete, you can login to AWS console SSO through this url:
     https://idp.stanford.edu/idp/profile/SAML2/Unsolicited/SSO?providerId=urn:amazon:webservices

           Account number: 123456789012
           Provider name: arn:aws:iam::123456789012:saml-provider/stanford-idp
           Role-name: AdministratorAccess-generatedby-stanford-sso
           Workgroup: myworkgroup
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

You need to submit the request to [HelpSU](https://helpsu.stanford.edu/helpsu/3.0/auth/helpsu-form?pcat=shibboleth) to complete the setup with the following information.

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
        

