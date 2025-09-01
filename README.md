# Personal Infrastructure as Code

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-7B42BC.svg)](https://terraform.io/)
[![Configuration](https://img.shields.io/badge/Config-Ansible-EE0000.svg)](https://ansible.com/)
[![Monitoring](https://img.shields.io/badge/Monitoring-Grafana-FF6C2C.svg)](https://grafana.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A complete Infrastructure as Code solution for personal development and production environments. This project automates the provisioning, configuration, and monitoring of cloud infrastructure using modern DevOps practices.

## Project Overview

This repository contains everything needed to provision and manage personal cloud infrastructure across multiple environments. It demonstrates real-world DevOps practices including infrastructure provisioning, configuration management, monitoring, and automated deployments.

### What This Project Does

- **Infrastructure Provisioning**: Automated VPS/cloud server creation using Terraform
- **Configuration Management**: Server setup and application deployment using Ansible
- **Monitoring Stack**: Complete observability with Prometheus, Grafana, and Loki
- **CI/CD Pipeline**: Automated testing and deployment workflows
- **Security Hardening**: Automated security configurations and SSL management
- **Backup Automation**: Scheduled backups with retention policies
- **Multi-Environment Support**: Separate dev, staging, and production environments

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Development   │    │     Staging     │    │   Production    │
│   Environment   │    │   Environment   │    │   Environment   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────▼───────────────────────┐
         │              Management Layer                 │
         │  ┌─────────────┐  ┌─────────────┐            │
         │  │  Terraform  │  │   Ansible   │            │
         │  │ (Provision) │  │ (Configure) │            │
         │  └─────────────┘  └─────────────┘            │
         └───────────────────────────────────────────────┘
                                 │
         ┌───────────────────────▼───────────────────────┐
         │             Monitoring Stack                  │
         │  ┌─────────┐ ┌─────────┐ ┌─────────┐         │
         │  │Prometheus│ │ Grafana │ │   Loki  │         │
         │  └─────────┘ └─────────┘ └─────────┘         │
         └───────────────────────────────────────────────┘
```

## Technology Stack

### Infrastructure
- **Terraform**: Infrastructure provisioning and management
- **Ansible**: Configuration management and application deployment
- **DigitalOcean/AWS/Vultr**: Cloud providers (configurable)

### Monitoring & Observability
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation and analysis
- **Node Exporter**: System metrics collection

### Security & Networking
- **Let's Encrypt**: Automated SSL certificate management
- **Nginx**: Reverse proxy and load balancing
- **UFW**: Firewall configuration
- **Fail2ban**: Intrusion prevention

### CI/CD
- **GitHub Actions**: Automated workflows
- **Docker**: Containerization
- **Terraform Cloud**: State management
- **Ansible Vault**: Secrets management

## Quick Start

### Prerequisites
- Terraform >= 1.0
- Ansible >= 2.9
- Docker >= 20.0
- Cloud provider account (DigitalOcean/AWS/Vultr)
- Domain name (optional, for SSL)

### 1. Clone and Setup
```bash
git clone https://github.com/your-username/personal-infrastructure
cd personal-infrastructure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml
```

### 2. Configure Variables
Edit `terraform/terraform.tfvars`:
```hcl
# Cloud Provider Settings
cloud_provider = "digitalocean"  # or "aws", "vultr"
region = "sgp1"
instance_size = "s-1vcpu-1gb"

# Domain Settings (optional)
domain_name = "yourdomain.com"
enable_ssl = true

# Environment
environment = "development"  # or "staging", "production"
```

Edit `ansible/group_vars/all.yml`:
```yaml
# Application Settings
apps_to_deploy:
  - name: "personal-website"
    port: 3000
    domain: "{{ domain_name }}"
  - name: "api-service"
    port: 8080
    domain: "api.{{ domain_name }}"

# Monitoring Settings
enable_monitoring: true
grafana_admin_password: "{{ vault_grafana_password }}"
```

### 3. Deploy Infrastructure
```bash
# Initialize Terraform
cd terraform
terraform init

# Plan and apply infrastructure
terraform plan
terraform apply

# Configure servers with Ansible
cd ../ansible
ansible-playbook -i inventory/hosts playbooks/site.yml
```

### 4. Access Services
- **Grafana Dashboard**: `https://monitor.yourdomain.com`
- **Your Applications**: `https://yourdomain.com`
- **Prometheus**: `https://prometheus.yourdomain.com`

## Project Structure

```
personal-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── compute/          # Server provisioning
│   │   ├── networking/       # VPC, security groups
│   │   └── monitoring/       # Monitoring infrastructure
│   ├── environments/
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
│   └── terraform.tfvars.example
├── ansible/
│   ├── playbooks/
│   │   ├── site.yml         # Main playbook
│   │   ├── monitoring.yml   # Monitoring setup
│   │   └── security.yml     # Security hardening
│   ├── roles/
│   │   ├── common/          # Base server configuration
│   │   ├── docker/          # Docker installation
│   │   ├── nginx/           # Web server setup
│   │   ├── monitoring/      # Prometheus/Grafana
│   │   └── security/        # Security hardening
│   └── inventory/
├── monitoring/
│   ├── grafana/
│   │   └── dashboards/      # Custom dashboards
│   ├── prometheus/
│   │   └── rules/           # Alerting rules
│   └── docker-compose.yml   # Local monitoring stack
├── scripts/
│   ├── backup.sh           # Automated backup script
│   ├── deploy.sh           # Deployment automation
│   └── health-check.sh     # System health monitoring
└── .github/
    └── workflows/
        ├── terraform.yml    # Infrastructure CI/CD
        ├── ansible.yml      # Configuration CI/CD
        └── security.yml     # Security scanning
```

## Features in Detail

### Infrastructure Provisioning
- Multi-cloud support (DigitalOcean, AWS, Vultr)
- Network security configuration
- Load balancer setup
- DNS management
- SSL certificate automation

### Configuration Management
- Automated server hardening
- Application deployment
- Database setup and configuration
- Backup configuration
- Log rotation and management

### Monitoring and Alerting
- System metrics collection
- Application performance monitoring
- Custom dashboards for each service
- Slack/Discord alerting integration
- Log aggregation and analysis

### Security
- Automated security updates
- Firewall configuration
- Intrusion detection
- SSL/TLS encryption
- Secrets management

### Backup and Recovery
- Automated daily backups
- Database dump automation
- Configuration backup
- Disaster recovery procedures

## Environments

### Development
- Single lightweight server
- Basic monitoring
- Shared resources
- Rapid iteration focus

### Staging
- Production-like environment
- Full monitoring stack
- Performance testing
- Pre-production validation

### Production
- High availability setup
- Complete monitoring and alerting
- Automated backups
- Security hardening

## Getting Started Guide

### Phase 1: Basic Infrastructure (Week 1)
1. Set up Terraform for basic VPS provisioning
2. Create Ansible playbooks for basic server configuration
3. Implement basic security hardening

### Phase 2: Application Deployment (Week 2)
1. Add Docker containerization
2. Implement application deployment automation
3. Set up Nginx reverse proxy with SSL

### Phase 3: Monitoring (Week 3)
1. Deploy Prometheus and Grafana
2. Create custom dashboards
3. Set up basic alerting

### Phase 4: Advanced Features (Week 4)
1. Implement backup automation
2. Add multi-environment support
3. Create comprehensive CI/CD pipeline

## Benefits for Your Portfolio

### Personal Benefits
- **Automated Infrastructure**: Deploy new projects instantly
- **Cost Management**: Automated resource scaling
- **Peace of Mind**: Monitoring and backup automation
- **Learning**: Hands-on experience with production tools

### Portfolio Benefits
- **Real Infrastructure**: Show actual running infrastructure
- **Production Skills**: Demonstrate real-world DevOps practices
- **Scalability**: Show understanding of multi-environment setups
- **Best Practices**: Security, monitoring, and automation

## Contributing

This project serves as both a personal infrastructure solution and a learning resource. Contributions that improve automation, security, or monitoring are welcome.

### Development Workflow
1. Test changes in development environment
2. Validate in staging environment
3. Deploy to production with proper rollback procedures

## Future Enhancements

- **Kubernetes Migration**: Container orchestration for complex applications
- **GitOps Integration**: ArgoCD or Flux for application deployment
- **Service Mesh**: Istio for microservices communication
- **Advanced Monitoring**: Distributed tracing with Jaeger
- **Cost Optimization**: Automated resource scaling based on usage

## Disclaimer

This project is designed for personal and educational use. Ensure you understand the costs associated with cloud resources before deployment. Always follow security best practices when managing production infrastructure.
