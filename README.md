# Build the Docker Image

```bash
docker build -t navi-kun:latest .
docker run -d -p 8080:8080 navi-kun:latest
```

# Deploy Infrastructure via Cloudformation

```bash
aws cloudformation create-stack --stack-name my-vpc-ecr-stack --template-body file://infra.yaml --capabilities CAPABILITY_IAM
```

This will create the following:

- VPC
- Subnet
- Internet Gateway
- Security Group (allows incoming internet traffic over port 80:443)
- Container Repository
- S3 Bucket
