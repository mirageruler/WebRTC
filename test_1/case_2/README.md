# How to run the test-1 case-2 terraform script

- Customize the variables in the `ap-dev-2.tfvars` file if needed. Pay close attention to `eks_cluster_auth_users`, `profile` (this is your aws account profile name in your credential file), and the container image(s) link(s)
- Review all the variables default values and descriptions in the `variables.tf` file to understand more about the meaning of variables declared in file `ap-dev-2.tfvars`
- Run `make run-test-1-case-2`
- Wait for all resources to be provisioned, then wait for a few minutes for the workload to be done by the two Go servers, then go the bucket (see the variable `bucket_name` in file `ap-dev-2.tfvars`) in region (region refered to variable `region` in file `ap-dev-2.tfvars`) and view the txt file (the name of the file is the formatted date time in UTC that the file is generated) content you should see logs written as the result of testing the two Go servers.


## To destroy all provisioned resources

- simply run `make destroy-test-1-case-2`
