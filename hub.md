# GitHub Actions Workflow for EKS Creation Using Terraform

## Workflow File: `.github/workflows/terraform.yml`

```yaml
name: 'EKS-Creation-Using-Terraform'

on:
  workflow_dispatch:
    inputs:
      tfvars_file:
        description: 'Path to the .tfvars file'
        required: true
        default: 'dev.tfvars'
      action:
        type: choice
        description: 'Terraform Action'
        options:
          - plan
          - apply
          - destroy
        required: true
        default: 'apply'

env:
  AWS_REGION: us-east-1
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

permissions:
  contents: read

jobs:
  terraform:
    name: Terraform ${{ github.event.inputs.action }}
    runs-on: ubuntu-latest
    environment: production

    defaults:
      run:
        shell: bash
        working-directory: .

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: true

      # Optional: Enable caching to speed up init
      - name: Cache Terraform
        uses: actions/cache@v4
        with:
          path: |
            ~/.terraform.d/plugin-cache
            .terraform
          key: ${{ runner.os }}-terraform-${{ hashFiles('**/*.tf') }}
          restore-keys: |
            ${{ runner.os }}-terraform-

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check -diff

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        if: ${{ github.event.inputs.action == 'plan' }}
        run: |
          terraform plan -var-file=${{ github.event.inputs.tfvars_file }} -input=false

      - name: Terraform Apply
        if: ${{ github.event.inputs.action == 'apply' }}
        run: |
          terraform apply -auto-approve -var-file=${{ github.event.inputs.tfvars_file }} -input=false

      - name: Terraform Destroy
        if: ${{ github.event.inputs.action == 'destroy' }}
        run: |
          terraform destroy -auto-approve -var-file=${{ github.event.inputs.tfvars_file }} -input=false
```

## Review Notes

### ✅ What's Good:
1. **Workflow Structure**: Well-organized with clear steps
2. **Inputs**: Properly configured for `tfvars_file` and `action` with defaults
3. **Caching**: Terraform cache is configured to speed up runs
4. **Validation**: Includes format check and validate steps before plan/apply
5. **Conditional Steps**: Uses conditional logic to run plan/apply/destroy based on input
6. **Security**: Uses GitHub secrets for AWS credentials

### ⚠️ Issues Fixed:
1. **Working Directory**: Changed from `eks` to `.` (root) since your Terraform files are at the root level, not in an `eks` subdirectory
2. **Missing Checkout Step**: Added the checkout step which is required to access the repository code
3. **Missing Destroy Step**: Added the destroy step to handle the destroy action option

### 📋 Required Setup:
1. **GitHub Secrets**: Make sure these secrets are configured in your repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Environment**: The workflow uses `environment: production`. Make sure this environment exists in your GitHub repository settings, or remove this line if you don't need environment protection.

3. **Terraform Backend**: Ensure your `backend.tf` is properly configured for remote state if needed.

### 🚀 Usage:
1. Go to Actions tab in GitHub
2. Select "EKS-Creation-Using-Terraform" workflow
3. Click "Run workflow"
4. Select:
   - `tfvars_file`: Path to your .tfvars file (default: `dev.tfvars`)
   - `action`: Choose `plan`, `apply`, or `destroy`
5. Click "Run workflow"

