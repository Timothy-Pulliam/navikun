# Prerequisites

You will need to upload an SSH key to AWS IAM in order to authenticate to the Code Commit repository

```
# generate RSA key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/codecommit_rsa
# upload to AWS IAM
aws iam upload-ssh-public-key --user-name USER-NAME --ssh-public-key-body "$(cat ~/.ssh/codecommit_rsa.pub)"
```

Optionally, you can configure your client to use this key by adding the following to your `~/.ssh/config`

```
Host git-codecommit.*.amazonaws.com
  User USER-NAME
  IdentityFile ~/.ssh/codecommit_rsa
```

# Build a Code Pipeline

This Terraform module creates the following

- Elastic Container Repository

* Code Commit Repository

- Cloud Watch Group for build logs

* S3 Bucket for Artificat Store

* Code Build Project

* Code Pipeline
