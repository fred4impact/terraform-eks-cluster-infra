# 🚀 EKS Cluster Infrastructure with Terraform

This repository provides a complete infrastructure-as-code (IaC) setup using **Terraform** to provision an **Amazon EKS (Elastic Kubernetes Service)** cluster.
 The setup includes all necessary AWS resources to deploy and manage a production-ready Kubernetes environment on AWS, following industry best practices.

---

## 📌 Purpose

The goal of this repository is to:

- Automate the provisioning of a secure, scalable, and production-grade EKS cluster.
- Enable DevOps teams to consistently deploy Kubernetes clusters with minimal manual effort.
- Integrate with a **jump server (bastion host)** for controlled access to private EKS nodes.

- Serve as a base for deploying containerized applications via CI/CD pipelines.

---

## 🧱 Provisioned Resources

The Terraform configuration includes the following AWS resources:

### 🔧 Core Infrastructure
- **VPC**: Custom Virtual Private Cloud with public and private subnets across multiple Availability Zones.
- **Internet Gateway** and **NAT Gateway** for outbound internet access.
- **Route Tables**: Proper routing for public and private subnet traffic.

### 📦 Compute & Networking
- **EKS Cluster**: Fully managed Kubernetes control plane.
- **Node Groups**: Auto-scaling groups of EC2 worker nodes, deployed in private subnets.
- **Security Groups**: Fine-grained access control for EKS components and Bastion.

### 🛡️ Access & Security
- **IAM Roles**:
  - EKS Cluster Role
  - EKS Node Group Role
  - OIDC
  - ALB Controller
- **Key Pair** for SSH access via Jump Server.

### 🔐 Bastion Host (Jump Server)
- Deployed in a public subnet.
- Acts as a gateway to access private resources like EKS worker nodes.
- Enforces secure access through SSH and public key authentication.

---

## 🎯 Benefits

| Feature                          | Benefit                                                                 |
|----------------------------------|-------------------------------------------------------------------------|
| 🔄 **Automated Provisioning**    | Reduces human error and ensures consistency across environments.        |
                |
| 🌍 **High Availability**         | Multi-AZ deployment ensures fault tolerance and uptime.                 |
| ☁️ **Fully Managed Kubernetes**  | Leverages AWS EKS to offload control plane operations.                 |
| 📦 **Modular Structure**         | Easy to extend and maintain over time.                                 |

---

## 🔐 Accessing the EKS Cluster Using a Jump Server

1. **SSH into the Bastion Host**:
   ```bash
   ssh -i <your-key>.pem ec2-user@<bastion-host-public-ip>

   **From the Bastion, access private resources:

    Use kubectl, AWS CLI, or SSH to interact with the worker nodes or services.

Configure kubectl:

    Ensure your kubeconfig is set up to point to the EKS cluster:

``` 
aws eks --region <region> update-kubeconfig --name <eks-cluster-name>

Now you can interact with the EKS cluster:

kubectl get nodes
```



 ## Customize terraform.tfvars:

  -   Define values like region, cluster name, node size, key pair name, etc.
    
  - Initialize and Apply Terraform:   

``` 
terraform init
terraform plan
terraform apply
``` 



### This project is open-source and available under the MIT License.
🙋‍♂️ Support & Contribution

### Feel free to open an issue or fork the repo and submit a pull request if you'd like to contribute!
