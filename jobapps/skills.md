# Skills Database

## Technical Skills

### Kubernetes & Container Technologies

- Amazon Elastic Kubernetes Service (EKS)
- Google Kubernetes Engine (GKE)
- Red Hat OpenShift Container Platform
- On-premises Kubernetes clusters on RHEL infrastructure
- Docker containerization and multi-stage builds on RHEL environments
- Kubernetes API development and custom resources
- Helm chart development and management
- Kustomize for configuration management
- Istio service mesh implementation
- Cluster API
- KEDA autoscaling
- Karpenter

### Cloud Platforms

- AWS (10x Certified - All Professional & Specialty levels)
- Google Cloud Platform (GCP)
- Azure (AKS)

### Programming & Scripting

- Python
- Golang
- TypeScript
- Shell scripting (Bash)
- Node.js

### Frameworks

- FastAPI
- Django

### Infrastructure as Code

- Terraform
- Terragrunt
- Ansible
- AWS CDK
- CloudFormation

### CI/CD & DevOps

- GitOps workflows with ArgoCD
- Jenkins pipeline orchestration
- GitHub Actions
- GitLab
- Buildkite
- Make targets & 3-musketeers pattern

### Observability & Monitoring

- Prometheus
- Grafana
- Thanos
- Loki
- Mimir
- Tempo
- OpenTelemetry (OTel)
- NewRelic
- Fluentd/Fluentbit
- Vector
- ELK stack (Elasticsearch, Logstash, Kibana)
- OpenSearch
- Datadog
- CloudWatch
- PagerDuty
- OpsGenie
- Metrics-server
- kube-state-metrics
- CloudHealth
- Kafka
- k6 load testing

### Security & Compliance

- Gatekeeper policy constraints
- Open Policy Agent (OPA)
- Conftest
- CIS Benchmark compliance
- PCI compliance
- Twistlock
- Vault
- External Secrets Operator
- OIDC federated authentication
- AWS IAM & Security

### Networking & Load Balancing

- Nginx Ingress Controller
- HAProxy
- AWS ALB/NLB
- Service mesh (Istio)

### Databases & Data Engineering

- AWS RDS
- AWS DynamoDB
- AWS Aurora
- SQL
- AWS Glue
- AWS Athena
- Python sqlite3
- Python Pandas
- Pyexcel
- MongoDB
- Time-series databases

### Systems & Platforms

- Linux (Ubuntu, CentOS, RHEL)
- Unix (macOS)
- Amazon Machine Images (AMI)

### Testing & Quality

- Python Behave
- Terratest
- Integration testing
- Performance testing
- Load testing with k6

### Project Management Tools

- ServiceNow
- Confluence
- JIRA
- Trello
- Microsoft 365

## Soft Skills

- Project Management
- Team Leadership
- Peer Mentoring
- On-site & Remote Working
- Release Management
- Incident & Problem Management
- Disaster Recovery Planning
- System Architecture
- Stakeholder Coordination
- Cost Optimization
- Security Compliance
- Technical Documentation
- Cross-functional Collaboration

## Key Responsibilities & Achievements

### Platform Engineering & Architecture

- Architected enterprise-scale Kubernetes platform using Cluster API with integrated day-2 operations tooling, providing 50+ development teams with standardized, secure cloud infrastructure
- Delivering EKS as a Platform with integrated day-2 tooling to customers to achieve a unified, pen-tested secure cloud platform across the organisation
- Designed declarative infrastructure provisioning platform using Terraform modules and custom Golang tooling, enabling complete cloud environment deployment through single YAML configurations
- Worked on deploying Prometheus as a vended repository for consumers to utilise a satellite Prometheus with a Thanos sidecar within their EKS cluster to unify platform observability

### Cost Optimization

- Led end-to-end PagerDuty to OpsGenie migration in 6 months, ensuring 100% feature parity while coordinating 20+ stakeholder teams and delivering $150K in annual cost savings
- Implemented standardised compliance testing through Open Policy Agent & Conftest. Moving from multiple runners to a single multi-tenant deployment runner agent against AWS infrastructure, defining permissions based on standardised YAML per team and enforcing against Terraform JSON This saved runner costs by 70% and reduced engineering hours spent
- Deployed Karpenter with AWS Spot Instances to replace cluster-autoscaler in Cluster API managed environments, reducing compute costs by 60%
- Automated lab cluster lifecycle management using Cluster API with evening shutdowns, reducing non-production infrastructure costs by 85%
- Implemented KEDA to optimise sizing of K8s components, specifically relating to Loki queries, saving costs
- Created Grafana dashboard pipeline allowing consumers to self serve dashboards to team specific custom folders via Helm templating and automatically promote to production via pipeline scripting, reducing dashboard support tickets by 90%

### Migration & Modernization

- Successfully migrated 50+ applications from VM-based infrastructure to containerized Kubernetes environments, reducing deployment time from weeks to hours
- Led 12-person engineering team to build containerized MERN stack application using Infrastructure as Code for enterprise digital transformation initiative

### Security & Compliance

- Implemented Twingate across AWS & GCP estate to achieve Zero-Trust-Network-Access across hybrid cloud architecture.
- Built an Ansible playbook for PCI compliant security hardening on Amazons CIS Benchmark AMI
- Architected a series of Lambdas to populate and distribute SSH keys with automated rotation within a 60 day period
- Implemented OIDC federated authentication for service repositories with External Secrets Operator integration, eliminating manual secret management across 50+ microservices
- Implemented Gatekeeper policy enforcement with Python Behave testing framework, preventing unauthorized root access and achieving 100% penetration test compliance

### Monitoring & Observability

- Development of monitoring platform, deploying Logstash architecture alongside Beats family to enable centralized application logging within Elasticsearch and visualisation within Kibana to achieve a unified monitoring platform spanned 40+ teams
- Developed Node.js middleware application integrating ServiceNow incident data with real-time market-location-based status updates, enabling executive leadership monitoring across global operations
- Deployed Thanos chart, alongside additional components such as ruler & compactor with associated bucket, access points and role infra to enable for long term object storage of Prometheus metrics
- Leveraging of Prometheus kube state metrics metadata to alert based on team labelling allowing custom receivers to fire
- Improved Opensearch performance capabilities by performance testing and optimising JVM heap size to increase garbage collection efficiency
- Implemented custom Prometheus exporters to generate metrics for AWS services into a single monitoring system, allowing Product Owners to streamline platform service offerings
- Ran performance testing for e2e logging solution of Fluentbit, Fluentd and Opensearch to understand performance limitations and configuration settings required to prevent service disruption and cost optimise scaling
- Monitored and maintained AWS services, including EC2 instances, S3 buckets, and RDS databases, ensuring high availability through Cloudwatch pushing metrics to Prometheus Pushgateway
- Implemented the Grafana Labs stack of Loki, Mimir & Tempo, performing load testing across the components to size resources appropriately leveraging k6s
- Successful integration of Prometheus & Alertmanager with Pagerduty to improve oncall engineering working methods
- Built a Python script utilising Pyexcel and Pandas to automate the sizing of Elasticsearch clusters, resulting in significant cost savings through automation and reduction of human input in the magnitude of hundreds of hours
- Designed and implemented a more flexible Logstash pipeline which allowed customers to implement their sharding with no dependencies on the monitoring team, improving organisational velocity
- Ran AWS Glue to take Kubernetes cluster NFR load testing such as CoreDNS, storing results in a central object storage such as S3 for long term performance tracking and visualisation via AWS Athena and Managed Grafana, providing long term visibility to product ownership of performance over release iterations

### Automation & DevOps

- Created DynamoDB tables to dynamically store AMI status for different accounts
- Creating and extending Dockerfiles to perform wrapper execution to prevent developer team intervention and increase guardrails for pipelines, reducing CVEs by 30%
- Designed automation to evacuate EKS nodes from selected AZs, increasing organisation DR capabilities
- Engineered automated disaster recovery testing framework using Point-in-Time Recovery (PITR), reducing manual testing effort by 80% and ensuring 4-hour recovery objectives
- Automated CoreDNS performance validation post-cluster deployment, ensuring 99.9% DNS resolution SLA compliance across customer microservice deployments
- Designed Python program leveraging Github API and Jinja2 templating to automate release note generation across different internal EKS releases, bringing down release note generation time from 4-6 hours manually, to 15 seconds
- Architected declarative infrastructure provisioning system using custom tooling and Terraform modules, enabling teams to define complete cloud environments in a single YAML configuration file
- Implemented GitOps-based deployment pipeline with automated validation, rendering, and provisioning of infrastructure components including Kubernetes clusters, databases, storage accounts, and identity management
- Leveraged deployment patterns using a combination of Make targets and chained Github Actions workflows, passing data through artifact uploads
- Created restore container workflows for postgresql and file storage in backup subscriptions to main subscription, using service principals with strict RBAC in place via PIM
- Built enterprise backup solution for Azure storage accounts, PostgreSQL databases, and key vaults with automated scheduling and monitoring, achieving 99.99% backup success rate
- Created DR Testing workflows to use PITR recovery to restore corrupted Databases from Azure Storage Accounts
- Created OIDC Federated Credentials workflow for service repositories to integrate deployments with External Secrets Operator reducing overhead of secrets management

### Research & Innovation

- Neural Network Modeling of Battery Degradation - Developed machine learning models to predict lithium-ion battery capacity fade using supervised learning algorithms and time-series analysis, achieving 92% prediction accuracy for capacity retention over 1000+ charge cycles

## Certifications

- AWS Certified Fellow - All 10 AWS Certifications at Professional & Specialty Level
- AWS Certified Professional Architect
- AWS Certified Specialty Security Engineer
- AWS Certified Specialty Network Engineer
- AWS Certified Specialty Machine Learning Engineer
- AWS Certified Specialty Data Analytics
- AWS Certified Specialty Database
- AWS Certified Solutions Architect Associate
- AWS Certified Developer Associate
- AWS Certified SysOps Administrator Associate
- AWS Certified Cloud Practitioner
- HashiCorp Certified: Terraform Associate

## Education

- MEng Systems Engineering - University of Warwick (2013-2017)

## Security Clearance

- SC Clearance (UK)
