#!/bin/bash

# Set project and branch to build
REPO_URLcd ="https://github.com/SWEN-514-FALL-2024/term-project-2241-swen-514-05-team5"
AMPLIFY_BRANCH_NAME="self-creating-amplify"
TERRAFORM_RESOURCE="aws_amplify_branch.main"



# Colors for aesthetics
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"

# Functions to print colored messages
info() {
  echo -e "${BLUE}[INFO]    ${RESET} $1"
}

success() {
  echo -e "${GREEN}[SUCCESS] ${RESET} $1"
}

warning() {
  echo -e "${YELLOW}[WARNING] ${RESET} $1"
}

error() {
  echo -e "${RED}[ERROR]   ${RESET} $1"
}

# Run destroy when script is closed
cleanup() {
  info "Cleaning up: Running terraform destroy..."
  terraform destroy -auto-approve
  success "Terraform destroy completed."
}

# Trap EXIT to ensure `terraform destroy` runs on script exit
trap cleanup EXIT

cd "deployment"

# First check if AWS CLI is already configured and if not then prompt
# -> we do this by checking to see a default profile exists in ~/.aws/
echo -e "${BLUE}Checking AWS configuration...${NC}"
if aws sts get-caller-identity > /dev/null 2>&1; then
  echo -e "${GREEN}AWS CLI is already configured and working.${NC}"
else
  echo -e "${YELLOW}AWS CLI is not fully configured. Running 'aws configure'...${NC}"
  aws configure
fi

if [ -d ".terraform" ] && [ -f ".terraform.lock.hcl" ]; then
  echo -e "${GREEN}Terraform is already initialized. Skipping 'terraform init'.${NC}"
else
  echo -e "${YELLOW}Running terraform init...${NC}"
  terraform init || {error "Error: terraform init failed! Exiting.${NC}"; exit 1; }
fi


info "Initializing Amplify Project..."
amplify init \
  --yes \
  --amplify "{\"projectName\":\"food-in-sight\",\"envName\":\"prod\"}" \
  --frontend "{\"frontend\":\"javascript\",\"framework\":\"react\",\"config\":{\"SourceDir\":\"src\",\"DistributionDir\":\"build\",\"BuildCommand\":\"npm run build\",\"StartCommand\":\"npm start\"}}" \
  --providers "{\"awscloudformation\":{\"configLevel\":\"project\",\"useProfile\":true,\"profileName\":\"default\",\"region\":\"us-east-1\"}}"

success "Amplify Project Created Successfully"

info "Connected Amplify project to github"
if amplify hosting add \
  --platform WEB \
  --framework react \
  --gitHubUrl $REPO_URL \
  --branch AMPLIFY_BRANCH_NAME \
  --enable-auto-build; then
    success "Amplify connected to GitHub successfully."
else
    error "Failed to connect Amplify project to GitHub. Exiting."
    exit 1
fi

AMPLIFY_APP_ID=$(aws amplify list-apps --query "apps[?name=='food-in-sight'].appId | [0]" --output text)

# Setup terraform variables if they dont exist
if [[ ! -f terraform.tfvars ]]; then
    echo -e "${YELLOW}terraform.tfvars file not found.${NC}"
    read -p "Please provide your AWS keypair name (aws_key): " userAwsKey
    if [[ -z "$userAwsKey" ]]; then
        error "AWS Key is required to proceed. Exiting.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Creating terraform.tfvars file with provided AWS Key and default region...${NC}"
    echo "aws_key=\"$userAwsKey\"" > terraform.tfvars
    echo "region=\"us-east-1\"" >> terraform.tfvars
    echo "amplify_id=\"$AMPLIFY_APP_ID\"" >> terraform.tfvars
    echo -e "${GREEN}terraform.tfvars file created successfully.${NC}"
else
    echo -e "${GREEN}terraform.tfvars already exists. Skipping creation.${NC}"
fi

# Terraform Plan
info "Planning Terraform changes..."
if terraform plan; then
  success "Terraform plan completed."
else
  error "Terraform plan failed. Exiting."
  exit 1
fi

# Terraform Apply
info "Applying Terraform changes..."
if terraform apply -var="branch_name=${AMPLIFY_BRANCH_NAME}" -auto-approve; then
  success "Terraform apply completed."
else
  error "Terraform apply failed. Exiting."
  exit 1
fi

#Finally build so that everything gets brought in!:
if aws amplify start-job \
    --app-id  ${AMPLIFY_APP_ID}\
    --branch-name ${AMPLIFY_BRANCH_NAME} \
    --job-type RELEASE; then
      success "Frontend build starting. Please allow 1-3 minutes for it to finish"
else
  error "The build was unable to start. Exiting"
fi


# Loop until closed
info "Terraform apply completed. Press Ctrl+C to exit and clean up resources."
while :; do sleep 1; done