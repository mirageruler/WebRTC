.PHONY: test-1-case-2

# TODO: modify this as the folder structure changes
run-test-1-case-2:
	terraform init -backend-config=backend.tfvars
	yes yes | terraform apply -var-file=ap-dev-2.tfvars

# TODO: modify this as the folder structure changes
destroy-test-1-case-2:
	yes yes | terraform destroy -var-file=ap-dev-2.tfvars
