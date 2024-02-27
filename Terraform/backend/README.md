# Create backend

Note: S3 bucket names must be globally unique

```bash
terraform init
terraform plan
terraform apply
```

# Use the backend

Uncomment out the backend section in main\.tf

```hcl
backend "s3" {
    bucket         = "tfstate-12345678"
    key            = "backend/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
}
```

Run terraform init again

```bash
terraform init
```
