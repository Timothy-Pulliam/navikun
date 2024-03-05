all: init plan build

init:
	terraform init -reconfigure -upgrade

plan:
	terraform plan -out tfplan.binary -refresh=true -var-file=$$(terraform workspace show).tfvars

json: plan
	terraform show -json tfplan.binary > tfplan.json

apply:
	terraform apply -auto-approve tfplan.binary

docs:
	terraform-docs markdown . > tfdocs.md

lint:
	terraform fmt -recursive
	tflint

cost: json
	infracost breakdown --path tfplan.json --usage-file infracost-usage.yml  --sync-usage-file --show-skipped

scan: json
	checkov -f tfplan.json

destroy:
	terraform destroy -auto-approve -var-file=$$(terraform workspace show).tfvars

graph:
	terraform graph | dot -Tpng > tfstate.png