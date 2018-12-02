# asg-ddns AWS lambda Makefile
#
# Dependencies:
# - awscli
# - zip
# - terraform
#

# Build variable
LAMBDA_NAME=asg_ddns_lambda
SOURCE=asg_ddns
PACKAGE=$(SOURCE).zip
REGION=eu-west-1

.PHONY: package deploy release

all: build deploy release

# Package the lambda in a zip file
package:
	(cd $(SOURCE) && zip -x "*.pyc" -r ../$(PACKAGE) *)

# Deploy the lambda function with terraform
deploy:
	terraform apply -auto-approve

# Release the lambda function
release:
	aws lambda update-function-code --region $(REGION) --function-name $(LAMBDA_NAME) --zip-file fileb://$(PACKAGE)

# Remove files generated during building
clean:
	-rm -rf *.zip
	-rm -rf *.tfstate*
	-rm -rf .terraform/
