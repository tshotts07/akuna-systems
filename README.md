# Akuna Systems — Infrastructure as Code

Terraform configuration for a production-oriented web service deployed on AWS.

The design focuses on the four areas required by the assessment: **networking, compute, monitoring, and CI/CD**.

## Architecture

The service uses an Application Load Balancer as its public entry point and runs containerized application tasks on Amazon ECS Fargate in private subnets.

```text
                         Internet
                            |
                            v
                Application Load Balancer
                   Public Subnets
                    /          \
                   /            \
                  v              v
             ECS Fargate    ECS Fargate
             Private AZ 1   Private AZ 2
                  |              |
                  +-------+------+
                          |
                     CloudWatch

Container Images ---> Amazon ECR
```

The infrastructure spans two availability zones to improve availability.

## Networking

The Terraform configuration creates:

* A dedicated VPC
* Two public subnets across separate availability zones
* Two private subnets across separate availability zones
* An Internet Gateway
* NAT gateways for outbound access from private subnets
* Public and private route tables
* Security groups restricting application traffic

The Application Load Balancer is deployed in the public subnets, while the ECS tasks run in private subnets and do not receive public IP addresses.

The ECS security group only accepts application traffic from the load balancer security group.

## Compute

The application runs using **Amazon ECS with AWS Fargate**.

The compute layer includes:

* ECS cluster
* ECS task definition
* ECS service
* Two minimum running application tasks
* Application Load Balancer
* Target group and health checks
* Amazon ECR repository for container images

The service listens on port `8080`, while the load balancer provides the public HTTP entry point.

ECS Service Auto Scaling can scale the service between **2 and 6 tasks**, targeting approximately **60% average CPU utilization**.

## Monitoring

Amazon CloudWatch provides application logging and operational monitoring.

The configuration includes:

* ECS container logs stored in CloudWatch Logs
* 30-day log retention
* High CPU utilization alarm
* Application Load Balancer target 5xx error alarm
* ECS CPU-based automatic scaling

These provide basic visibility into application health and service load.

## CI/CD

GitHub Actions is used to model the CI/CD workflow.

On pushes and pull requests to `main`, the workflow:

1. Checks Terraform formatting
2. Initializes Terraform
3. Runs `terraform validate`

Infrastructure deployment is modeled as a manually triggered workflow that:

1. Authenticates to AWS using a GitHub OIDC IAM role
2. Runs `terraform plan`
3. Runs `terraform apply`

The AWS role itself is assumed to be provisioned separately and is not included in this assessment repository.

No long-lived AWS access keys are stored in the repository.

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml
├── main.tf
├── outputs.tf
├── providers.tf
├── variables.tf
└── README.md
```

## Configuration

The AWS deployment region is configurable through:

```hcl
variable "aws_region" {
  description = "AWS region used to deploy infrastructure"
  type        = string
  default     = "us-east-1"
}
```

The default region is `us-east-1`.

## Outputs

Terraform exposes several useful deployment values:

* Application Load Balancer DNS name
* ECR repository URL
* ECS cluster name
* ECS service name

## Validation

Format the Terraform configuration with:

```bash
terraform fmt -recursive
```

Initialize Terraform without configuring a remote backend:

```bash
terraform init -backend=false
```

Validate the configuration:

```bash
terraform validate
```

## Assumptions and Scope

This repository demonstrates the infrastructure design requested by the assessment rather than deploying a complete production application.

The configuration assumes:

* A containerized web application exists
* The application listens on port `8080`
* The application exposes a `/health` endpoint
* The container image supports the configured health check
* An AWS account and appropriate permissions are available for deployment
* A GitHub OIDC deployment role would be configured separately for the deployment workflow

A full production implementation could additionally include HTTPS with ACM, DNS through Route 53, secret management, a remote Terraform state backend, deployment environments, and more extensive alerting.

## Technology

* Terraform
* AWS VPC
* Amazon ECS
* AWS Fargate
* Amazon ECR
* Application Load Balancer
* Amazon CloudWatch
* GitHub Actions
