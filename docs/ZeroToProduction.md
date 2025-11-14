# From Zero to Production: Building a Secure EKS Cluster with Terraform That Actually Works

*Published on [Date] | 15 min read*

---

## 🎯 Introduction

In today's cloud-native world, Kubernetes has become the de facto standard for container orchestration. However, setting up a production-ready EKS cluster that's both secure and scalable can be a daunting task. Many tutorials show you the basics, but they often miss the crucial components needed for real-world deployments.

In this comprehensive guide, I'll walk you through building a **production-grade EKS cluster** using Terraform that includes:
- Multi-AZ high availability setup
- Secure networking with public/private subnets
- ALB Controller for ingress management
- Bastion host for secure access
- DevOps tools integration (Jenkins, SonarQube, Nexus)
- Complete CI/CD pipeline infrastructure

Let's dive deep into how each component flows together to create a robust, enterprise-ready Kubernetes environment.

---

## 🏗️ Architecture Overview

Before we start coding, let's understand the overall architecture and how components interact:

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Cloud                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   Public Subnet │    │  Public Subnet  │                    │
│  │   (us-east-1a)  │    │   (us-east-1b)  │                    │
│  │                 │    │                 │                    │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │                    │
│  │ │ Bastion     │ │    │ │ Internet    │ │                    │
│  │ │ Host        │ │    │ │ Gateway     │ │                    │
│  │ └─────────────┘ │    │ └─────────────┘ │                    │
│  └─────────────────┘    └─────────────────┘                    │
│           │                       │                            │
│           └───────────────────────┼────────────────────────────┘
│                                   │                            │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │  Private Subnet │    │  Private Subnet │                    │
│  │   (us-east-1a)  │    │   (us-east-1b)  │                    │
│  │                 │    │                 │                    │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │                    │
│  │ │ EKS Worker  │ │    │ │ EKS Worker  │ │                    │
│  │ │ Node Group  │ │    │ │ Node Group│ │                    │
│  │ └─────────────┘ │    │ └─────────────┘ │                    │
│  └─────────────────┘    └─────────────────┘                    │
│           │                       │                            │
│           └───────────────────────┼────────────────────────────┘
│                                   │                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    EKS Control Plane                        │ │
│  │              (AWS Managed - Multi-AZ)                      │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Prerequisites

Before we start, ensure you have the following tools installed:

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://terraform.io

# Install AWS CLI
brew install awscli     # macOS
# or download from https://aws.amazon.com/cli/

# Install kubectl
brew install kubectl    # macOS  
# or download from https://kubernetes.io/docs/tasks/tools/

# Configure AWS credentials
aws configure
```

---

## 🚀 Step 1: Project Structure and Foundation

Our Terraform project follows a modular approach for better maintainability and reusability:

```
terraform-eks-cluster-infra/
├── main.tf                 # Main configuration
├── variables.tf            # Variable definitions
├── outputs.tf              # Output values
├── providers.tf            # Provider configuration
├── dev.tfvars              # Environment-specific values
├── modules/
│   ├── vpc/               # VPC and networking
│   ├── eks/               # EKS cluster and node groups
│   └── alb-controller/    # ALB Controller setup
└── docs/
    └── ZeroToProduction.md # This blog post
```

### Why This Structure Matters

The modular approach provides several benefits:
- **Reusability**: Each module can be used in different environments
- **Maintainability**: Changes to one component don't affect others
- **Testing**: Individual modules can be tested in isolation
- **Team Collaboration**: Different team members can work on different modules

---

## 🌐 Step 2: VPC and Networking Foundation

The VPC module is the foundation of our infrastructure. Let's examine how it creates a secure, multi-AZ network:

### VPC Module (`modules/vpc/vpc.tf`)

```hcl
# VPC with DNS support enabled
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.env}-main"
  }
}
```

**Why DNS support matters**: EKS requires DNS resolution for service discovery and internal communication between pods.

### Multi-AZ Subnet Strategy

```hcl
# Private subnets for EKS worker nodes
resource "aws_subnet" "private_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.zone1

  tags = {
    Name = "${var.env}-private-${var.zone1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_zone2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.zone2

  tags = {
    Name = "${var.env}-private-${var.zone2}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
```

**The Flow**: 
1. **Private subnets** host EKS worker nodes for security
2. **Kubernetes tags** enable automatic load balancer creation
3. **Multi-AZ deployment** ensures high availability

### Internet Connectivity Strategy

```hcl
# NAT Gateway for private subnet internet access
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone1.id

  tags = {
    Name = "${var.env}-nat"
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.env}-private-rt"
  }
}
```

**Why NAT Gateway**: Private subnets need internet access for:
- Pulling container images from Docker Hub
- Installing packages and updates
- Accessing AWS services (ECR, CloudWatch, etc.)

---

## 🏢 Step 3: EKS Cluster and Node Groups

The EKS module creates the Kubernetes control plane and worker nodes:

### EKS Cluster Configuration

```hcl
resource "aws_eks_cluster" "eks" {
  name    = "${var.env}-${var.eks_name}"
  version = var.eks_version

  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids = [
      var.private_subnet1_id,
      var.private_subnet2_id
    ]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
}
```

**Key Configuration Decisions**:
- **`endpoint_public_access = true`**: Allows kubectl access from anywhere
- **`endpoint_private_access = false`**: We'll use bastion host for private access
- **Private subnets only**: Worker nodes are isolated for security

### IAM Roles and Security

```hcl
# EKS Cluster Role
resource "aws_iam_role" "eks" {
  name = "${var.env}-${var.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Node Group Role
resource "aws_iam_role" "nodes" {
  name = "${var.env}-${var.eks_name}-eks-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
```

**Security Flow**:
1. **EKS service** assumes the cluster role to manage the control plane
2. **EC2 instances** (worker nodes) assume the node role
3. **Least privilege principle** is applied through specific policy attachments

### OIDC Provider for Service Accounts

```hcl
# OIDC Provider for pod identity
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}
```

**Why OIDC Matters**: This enables Kubernetes service accounts to assume IAM roles, allowing pods to access AWS services securely without storing credentials.

---

## 🚪 Step 4: ALB Controller Integration

The ALB Controller enables Kubernetes to automatically provision AWS Application Load Balancers:

### IAM Policy for ALB Controller

```hcl
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}
```

### Service Account with IAM Role

```hcl
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}
```

**The Flow**:
1. **Service account** is created in the `kube-system` namespace
2. **IAM role annotation** links the service account to AWS permissions
3. **ALB Controller pods** use this service account to create load balancers
4. **Ingress resources** automatically trigger ALB creation

---

## 🔐 Step 5: Bastion Host for Secure Access

The bastion host provides secure access to private resources:

### Bastion Host Configuration

```hcl
resource "aws_instance" "dev" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = var.key_pair_name
  subnet_id     = aws_subnet.public_zone1.id

  vpc_security_group_ids = [aws_security_group.dev.id]

  tags = {
    Name = "${var.env}-bastion"
  }
}
```

### Security Group for DevOps Tools

```hcl
resource "aws_security_group" "dev" {
  name_prefix = "${var.project_name}-dev-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Nexus"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Access Flow**:
1. **SSH to bastion** from your local machine
2. **Install kubectl** on the bastion host
3. **Configure kubectl** to access the EKS cluster
4. **Deploy applications** and manage the cluster

---

## 🔄 Step 6: How Everything Flows Together

Let's trace the complete flow from infrastructure creation to application deployment:

### Phase 1: Infrastructure Provisioning

```bash
# 1. Initialize Terraform
terraform init

# 2. Plan the deployment
terraform plan -var-file="dev.tfvars"

# 3. Apply the configuration
terraform apply -var-file="dev.tfvars"
```

**What happens during `terraform apply`**:

1. **VPC Module**:
   - Creates VPC with DNS support
   - Provisions public and private subnets across 2 AZs
   - Sets up Internet Gateway and NAT Gateway
   - Configures route tables for traffic flow

2. **EKS Module**:
   - Creates IAM roles for cluster and nodes
   - Provisions EKS control plane in private subnets
   - Sets up OIDC provider for service account authentication
   - Creates auto-scaling node groups

3. **ALB Controller Module**:
   - Creates IAM policy for load balancer management
   - Sets up service account with IAM role binding
   - Prepares for ALB Controller deployment

### Phase 2: Cluster Access and Configuration

```bash
# 1. SSH to bastion host
ssh -i ec2-aws-key.pem ec2-user@<bastion-public-ip>

# 2. Configure kubectl
aws eks --region us-east-1 update-kubeconfig --name dev-bilarn-cluster

# 3. Verify cluster access
kubectl get nodes
```

### Phase 3: Application Deployment

```yaml
# Example: Deploy an application with ingress
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: my-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

**The Complete Flow**:
1. **Ingress resource** is created in Kubernetes
2. **ALB Controller** detects the ingress
3. **Controller** creates an Application Load Balancer
4. **ALB** is configured with target groups pointing to EKS nodes
5. **Traffic flows**: Internet → ALB → EKS Nodes → Pods

---

## 🛡️ Security Considerations

### Network Security
- **Private subnets** isolate worker nodes from direct internet access
- **Security groups** restrict traffic to necessary ports only
- **NAT Gateway** provides controlled outbound access

### Access Control
- **Bastion host** provides secure entry point
- **IAM roles** follow least privilege principle
- **OIDC provider** enables secure service account authentication

### Data Protection
- **EKS control plane** is AWS-managed and encrypted
- **Worker node storage** can be encrypted with EBS encryption
- **Container images** are stored in private ECR repositories

---

## 📈 Scaling and High Availability

### Auto-scaling Node Groups
```hcl
resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = [var.private_subnet1_id, var.private_subnet2_id]

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }
}
```

**Scaling Flow**:
1. **Kubernetes scheduler** detects insufficient resources
2. **Cluster Autoscaler** (if deployed) triggers node group scaling
3. **AWS Auto Scaling Group** adds new EC2 instances
4. **New nodes** join the cluster automatically

### Multi-AZ Deployment
- **Control plane** spans multiple AZs (AWS-managed)
- **Worker nodes** distributed across 2 AZs
- **Load balancers** automatically distribute traffic

---

## 🔧 DevOps Tools Integration

### Jenkins Pipeline
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t my-app .'
            }
        }
        stage('Test') {
            steps {
                sh 'docker run my-app npm test'
            }
        }
        stage('Deploy') {
            steps {
                sh 'kubectl apply -f k8s/'
            }
        }
    }
}
```

### SonarQube Quality Gates
- **Code quality analysis** integrated into CI/CD pipeline
- **Quality gates** prevent deployment of low-quality code
- **Security scanning** identifies vulnerabilities

### Nexus Artifact Management
- **Docker images** stored in private ECR repositories
- **Application artifacts** managed in Nexus
- **Version control** ensures reproducible deployments

---

## 🚀 Deployment Commands

Here's the complete deployment sequence:

```bash
# 1. Clone the repository
git clone <your-repo>
cd terraform-eks-cluster-infra

# 2. Configure AWS credentials
aws configure

# 3. Create SSH key pair (if not exists)
aws ec2 create-key-pair --key-name ec2-aws-key --query 'KeyMaterial' --output text > ec2-aws-key.pem
chmod 400 ec2-aws-key.pem

# 4. Initialize and deploy
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"

# 5. Access the cluster
ssh -i ec2-aws-key.pem ec2-user@<bastion-ip>
aws eks --region us-east-1 update-kubeconfig --name dev-bilarn-cluster
kubectl get nodes

# 6. Deploy ALB Controller (if needed)
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-bilarn-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

---

## 🧪 Testing Your Setup

### Verify Cluster Health
```bash
# Check node status
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info
```

### Test Load Balancer Integration
```bash
# Deploy a test application
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx-test
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test
            port:
              number: 80
EOF
```

---

## 🎯 Best Practices Implemented

### Infrastructure as Code
- **Version controlled** Terraform configurations
- **Modular design** for reusability
- **Environment-specific** variable files

### Security First
- **Private subnets** for worker nodes
- **Bastion host** for secure access
- **IAM roles** with least privilege
- **Security groups** with minimal required access

### High Availability
- **Multi-AZ deployment** across availability zones
- **Auto-scaling** node groups
- **Load balancer** integration for traffic distribution

### DevOps Integration
- **CI/CD tools** (Jenkins, SonarQube, Nexus)
- **Container registry** (ECR) integration
- **Automated deployment** capabilities

---

## 🔍 Troubleshooting Common Issues

### Cluster Access Issues
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check EKS cluster status
aws eks describe-cluster --name dev-bilarn-cluster --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --name dev-bilarn-cluster --region us-east-1
```

### Networking Issues
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Verify route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"

# Test connectivity from bastion
ssh -i ec2-aws-key.pem ec2-user@<bastion-ip>
ping <worker-node-private-ip>
```

### ALB Controller Issues
```bash
# Check ALB Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify service account
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml

# Check IAM role
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole
```

---

## 🎉 Conclusion

You've now built a **production-ready EKS cluster** that includes:

✅ **Secure networking** with multi-AZ VPC  
✅ **High availability** with auto-scaling node groups  
✅ **Load balancer integration** via ALB Controller  
✅ **Secure access** through bastion host  
✅ **DevOps tools** integration  
✅ **Infrastructure as Code** with Terraform  

This setup provides a solid foundation for running containerized applications in production. The modular design makes it easy to extend and customize for your specific needs.

### Next Steps

1. **Deploy your applications** using the provided ingress examples
2. **Set up monitoring** with Prometheus and Grafana
3. **Configure backup** strategies for persistent data
4. **Implement CI/CD pipelines** using the integrated tools
5. **Add security scanning** to your deployment process

Remember, this is a starting point. Production environments often require additional components like:
- **Service mesh** (Istio, Linkerd)
- **Advanced monitoring** (ELK stack, DataDog)
- **Security tools** (Falco, OPA Gatekeeper)
- **Backup solutions** (Velero)

Happy deploying! 🚀

---

*This blog post demonstrates a real-world EKS setup that balances security, scalability, and maintainability. The complete code is available in the [terraform-eks-cluster-infra](https://github.com/your-username/terraform-eks-cluster-infra) repository.*

---

**Tags**: #Kubernetes #EKS #Terraform #AWS #DevOps #Infrastructure #CloudNative #Security 