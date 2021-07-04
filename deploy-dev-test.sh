#!/bin/bash
#fail on error
########### source ./setup.sh
set -e 

# navigate to the dev-test config directory
cd dev-test/

#apply the configuration with the tfvars file
terraform apply -input=false -auto-approve -var-file=dev-test.tfvars