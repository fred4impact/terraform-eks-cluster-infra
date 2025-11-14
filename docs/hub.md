# GitHub Actions Workflow for EKS Creation Using Terraform

## Workflow File: `.github/workflows/aws-infra-provisioning.yml`

```yaml
name: Infra Provisining for AWS EKS Cluster

on:
  workflow_dispatch:
    inputs:
      tfvars_file:
        description: "The Terraform variables file to use"
        required: true
        default: "dev.tfvars"
      env:
        description: "The environment to deploy to"
        required: true
        default: "development"
      action:
        description: "Terraform actions to perform (plan, apply, destroy)"
        type: choice
        options:
          - plan
          - apply
          - destroy
        required: true
        default: "plan"

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
    environment: ${{ github.event.inputs.env }}

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

## 🐛 Bug Fix: Plan Step Being Skipped

### Problem:
The workflow was skipping the plan step even when "plan" was selected because of a **variable name mismatch**:

- **Input name** (line 14): `actions` (plural) ❌
- **Condition checks** (lines 73, 78, 83): `github.event.inputs.action` (singular) ❌

This mismatch caused the condition `${{ github.event.inputs.action == 'plan' }}` to always evaluate to `false`, so the plan step was skipped.

### Solution:
Changed the input name from `actions` to `action` (singular) to match the condition checks throughout the workflow.

**Before:**
```yaml
actions:  # ❌ Wrong - plural
  description: "Terraform actions to perform..."
```

**After:**
```yaml
action:  # ✅ Correct - singular, matches the condition checks
  description: "Terraform actions to perform..."
```

### Why This Happened:
GitHub Actions workflow inputs are accessed via `github.event.inputs.<input_name>`. The input name must exactly match what you use in the conditions. Since the input was named `actions` but the code checked for `action`, it was looking for a non-existent input, resulting in an empty/null value that never matched 'plan'.

## Review Notes

### ✅ What's Good:
1. **Workflow Structure**: Well-organized with clear steps
2. **Inputs**: Properly configured for `tfvars_file`, `env`, and `action` with defaults
3. **Caching**: Terraform cache is configured to speed up runs
4. **Validation**: Includes format check and validate steps before plan/apply
5. **Conditional Steps**: Uses conditional logic to run plan/apply/destroy based on input
6. **Security**: Uses GitHub secrets for AWS credentials
7. **Environment Support**: Dynamic environment selection based on input

### ⚠️ Issues Fixed:
1. **Variable Name Mismatch**: Fixed `actions` → `action` to match condition checks
2. **Working Directory**: Set to `.` (root) since Terraform files are at the root level

### 📋 Required Setup:
1. **GitHub Secrets**: Make sure these secrets are configured in your repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Environments**: The workflow uses `environment: ${{ github.event.inputs.env }}`. Make sure the environments (e.g., "development", "production") exist in your GitHub repository settings, or modify the default value.

3. **Terraform Backend**: Ensure your `backend.tf` is properly configured for remote state if needed.

### 🚀 Usage:
1. Go to Actions tab in GitHub
2. Select "Infra Provisining for AWS EKS Cluster" workflow
3. Click "Run workflow"
4. Select:
   - `tfvars_file`: Path to your .tfvars file (default: `dev.tfvars`)
   - `env`: Environment to deploy to (default: `development`)
   - `action`: Choose `plan`, `apply`, or `destroy` (default: `plan`)
5. Click "Run workflow"

### 🔍 How to Verify the Fix:
After the fix, when you select "plan" as the action:
- The "Terraform Plan" step should execute ✅
- The "Terraform Apply" step should be skipped (shows as skipped in GitHub Actions UI)
- The "Terraform Destroy" step should be skipped

You can verify by checking the workflow run logs - the plan step should now show output instead of being skipped.
