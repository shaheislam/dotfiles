# Skills Database

## Technical Skills

### Kubernetes & Container Technologies

- Amazon Elastic Kubernetes Service (EKS)
- Azure Kubernetes Service (AKS)
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
- Azure Cloud Platform
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

- Architected enterprise-scale Kubernetes platform using Cluster API with integrated day-2 operations tooling, providing 50+ development teams with standardized, secure cloud infrastructure [Tags: Kubernetes, Cluster API, Platform Engineering, Architecture, Cloud Infrastructure, DevOps, AWS, Azure]
- Delivering EKS as a Platform with integrated day-2 tooling to customers to achieve a unified, pen-tested secure cloud platform across the organisation [Tags: EKS, AWS, Kubernetes, Platform Engineering, Security, Cloud Platform]
- Designed declarative infrastructure provisioning platform using Terraform modules and custom Golang tooling, enabling complete cloud environment deployment through single YAML configurations [Tags: Terraform, IaC, Golang, Infrastructure, Automation, DevOps, Cloud]
- Worked on deploying Prometheus as a vended repository for consumers to utilise a satellite Prometheus with a Thanos sidecar within their EKS cluster to unify platform observability [Tags: Prometheus, Thanos, Observability, Monitoring, EKS, Kubernetes, AWS]

### Cost Optimization

- Led end-to-end PagerDuty to OpsGenie migration in 6 months, ensuring 100% feature parity while coordinating 20+ stakeholder teams and delivering $150K in annual cost savings [Tags: Migration, Cost Optimization, PagerDuty, OpsGenie, Leadership, Project Management]
- Implemented standardised compliance testing through Open Policy Agent & Conftest. Moving from multiple runners to a single multi-tenant deployment runner agent against AWS infrastructure, defining permissions based on standardised YAML per team and enforcing against Terraform JSON This saved runner costs by 70% and reduced engineering hours spent [Tags: OPA, Conftest, Compliance, Cost Optimization, AWS, Terraform, CI/CD, Security]
- Deployed Karpenter with AWS Spot Instances to replace cluster-autoscaler in Cluster API managed environments, reducing compute costs by 60% [Tags: Karpenter, AWS, Spot Instances, Kubernetes, Cost Optimization, Cluster API, Autoscaling]
- Automated lab cluster lifecycle management using Cluster API with evening shutdowns, reducing non-production infrastructure costs by 85% [Tags: Automation, Cluster API, Cost Optimization, Kubernetes, Infrastructure Management]
- Implemented KEDA to optimise sizing of K8s components, specifically relating to Loki queries, saving costs [Tags: KEDA, Kubernetes, Autoscaling, Loki, Observability, Cost Optimization]
- Created Grafana dashboard pipeline allowing consumers to self serve dashboards to team specific custom folders via Helm templating and automatically promote to production via pipeline scripting, reducing dashboard support tickets by 90% [Tags: Grafana, Observability, Helm, CI/CD, Automation, Self-Service]

### Migration & Modernization

- Successfully migrated 50+ applications from VM-based infrastructure to containerized Kubernetes environments, reducing deployment time from weeks to hours [Tags: Migration, Kubernetes, Containerization, Docker, Infrastructure, DevOps]
- Led 12-person engineering team to build containerized MERN stack application using Infrastructure as Code for enterprise digital transformation initiative [Tags: Leadership, MERN, Docker, IaC, Digital Transformation, Team Management]

### Security & Compliance

- Implemented Twingate across AWS & Azure estate to achieve Zero-Trust-Network-Access across hybrid cloud architecture. [Tags: Security, Zero Trust, AWS, Azure, Networking, Cloud Security, Twingate]
- Built an Ansible playbook for PCI compliant security hardening on Amazons CIS Benchmark AMI [Tags: Ansible, Security, PCI Compliance, CIS Benchmark, AWS, AMI, Infrastructure]
- Architected a series of Lambdas to populate and distribute SSH keys with automated rotation within a 60 day period [Tags: AWS Lambda, Security, SSH, Automation, Key Management]
- Implemented OIDC federated authentication for service repositories with External Secrets Operator integration, eliminating manual secret management across 50+ microservices [Tags: OIDC, Security, Kubernetes, External Secrets, Authentication, Microservices]
- Implemented Gatekeeper policy enforcement with Python Behave testing framework, preventing unauthorized root access and achieving 100% penetration test compliance [Tags: Gatekeeper, Security, Python, Testing, Kubernetes, Compliance, OPA]

### Monitoring & Observability

- Development of monitoring platform, deploying Logstash architecture alongside Beats family to enable centralized application logging within Elasticsearch and visualisation within Kibana to achieve a unified monitoring platform spanned 40+ teams [Tags: ELK Stack, Elasticsearch, Logstash, Kibana, Monitoring, Observability, Beats]
- Developed Node.js middleware application integrating ServiceNow incident data with real-time market-location-based status updates, enabling executive leadership monitoring across global operations [Tags: Node.js, ServiceNow, Integration, Monitoring, JavaScript, API Development]
- Deployed Thanos chart, alongside additional components such as ruler & compactor with associated bucket, access points and role infra to enable for long term object storage of Prometheus metrics [Tags: Thanos, Prometheus, Observability, Object Storage, AWS S3, Monitoring, Helm]
- Leveraging of Prometheus kube state metrics metadata to alert based on team labelling allowing custom receivers to fire [Tags: Prometheus, Kubernetes, Monitoring, Alerting, kube-state-metrics, Observability]
- Improved Opensearch performance capabilities by performance testing and optimising JVM heap size to increase garbage collection efficiency [Tags: OpenSearch, Performance, JVM, Optimization, Elasticsearch, Monitoring]
- Implemented custom Prometheus exporters to generate metrics for AWS services into a single monitoring system, allowing Product Owners to streamline platform service offerings [Tags: Prometheus, AWS, Monitoring, Golang, Custom Exporters, Observability]
- Ran performance testing for e2e logging solution of Fluentbit, Fluentd and Opensearch to understand performance limitations and configuration settings required to prevent service disruption and cost optimise scaling [Tags: Performance Testing, Fluentbit, Fluentd, OpenSearch, Logging, Cost Optimization]
- Monitored and maintained AWS services, including EC2 instances, S3 buckets, and RDS databases, ensuring high availability through Cloudwatch pushing metrics to Prometheus Pushgateway [Tags: AWS, CloudWatch, Prometheus, EC2, S3, RDS, Monitoring, High Availability]
- Implemented the Grafana Labs stack of Loki, Mimir & Tempo, performing load testing across the components to size resources appropriately leveraging k6s [Tags: Grafana, Loki, Mimir, Tempo, k6, Load Testing, Observability]
- Successful integration of Prometheus & Alertmanager with Pagerduty to improve oncall engineering working methods [Tags: Prometheus, Alertmanager, PagerDuty, Monitoring, On-Call, Integration]
- Built a Python script utilising Pyexcel and Pandas to automate the sizing of Elasticsearch clusters, resulting in significant cost savings through automation and reduction of human input in the magnitude of hundreds of hours [Tags: Python, Pandas, Elasticsearch, Automation, Cost Optimization, Data Analysis]
- Designed and implemented a more flexible Logstash pipeline which allowed customers to implement their sharding with no dependencies on the monitoring team, improving organisational velocity [Tags: Logstash, ELK Stack, Pipeline, Self-Service, Monitoring]
- Ran AWS Glue to take Kubernetes cluster NFR load testing such as CoreDNS, storing results in a central object storage such as S3 for long term performance tracking and visualisation via AWS Athena and Managed Grafana, providing long term visibility to product ownership of performance over release iterations [Tags: AWS Glue, Kubernetes, CoreDNS, S3, Athena, Grafana, Performance Testing, Data Engineering]

### Automation & DevOps

- Created DynamoDB tables to dynamically store AMI status for different accounts [Tags: DynamoDB, AWS, AMI, Infrastructure, Database, Automation]
- Creating and extending Dockerfiles to perform wrapper execution to prevent developer team intervention and increase guardrails for pipelines, reducing CVEs by 30% [Tags: Docker, Security, CI/CD, DevOps, Containerization, CVE]
- Designed automation to evacuate EKS nodes from selected AZs, increasing organisation DR capabilities [Tags: EKS, AWS, Disaster Recovery, Automation, Kubernetes, High Availability]
- Engineered automated disaster recovery testing framework using Point-in-Time Recovery (PITR), reducing manual testing effort by 80% and ensuring 4-hour recovery objectives [Tags: Disaster Recovery, PITR, Automation, Testing, RTO, Backup]
- Automated CoreDNS performance validation post-cluster deployment, ensuring 99.9% DNS resolution SLA compliance across customer microservice deployments [Tags: CoreDNS, Kubernetes, DNS, Performance, Automation, SLA, Monitoring]
- Designed Python program leveraging Github API and Jinja2 templating to automate release note generation across different internal EKS releases, bringing down release note generation time from 4-6 hours manually, to 15 seconds [Tags: Python, GitHub API, Jinja2, Automation, Release Management, EKS, DevOps]
- Architected declarative infrastructure provisioning system using custom tooling and Terraform modules, enabling teams to define complete cloud environments in a single YAML configuration file [Tags: Terraform, IaC, YAML, Cloud Infrastructure, Automation, DevOps]
- Implemented GitOps-based deployment pipeline with automated validation, rendering, and provisioning of infrastructure components including Kubernetes clusters, databases, storage accounts, and identity management [Tags: GitOps, ArgoCD, CI/CD, Kubernetes, Infrastructure, Automation, Azure]
- Leveraged deployment patterns using a combination of Make targets and chained Github Actions workflows, passing data through artifact uploads [Tags: GitHub Actions, Make, CI/CD, DevOps, Automation, Artifacts]
- Created restore container workflows for postgresql and file storage in backup subscriptions to main subscription, using service principals with strict RBAC in place via PIM [Tags: PostgreSQL, Azure, Backup, RBAC, PIM, Disaster Recovery, Security]
- Built enterprise backup solution for Azure storage accounts, PostgreSQL databases, and key vaults with automated scheduling and monitoring, achieving 99.99% backup success rate [Tags: Azure, Backup, PostgreSQL, Key Vault, Automation, Monitoring, Disaster Recovery]
- Created DR Testing workflows to use PITR recovery to restore corrupted Databases from Azure Storage Accounts [Tags: Disaster Recovery, PITR, Azure, Database, Testing, Storage]
- Created OIDC Federated Credentials workflow for service repositories to integrate deployments with External Secrets Operator reducing overhead of secrets management [Tags: OIDC, External Secrets, Kubernetes, Security, GitOps, Secret Management]

### Research & Innovation

- Neural Network Modeling of Battery Degradation - Developed machine learning models to predict lithium-ion battery capacity fade using supervised learning algorithms and time-series analysis, achieving 92% prediction accuracy for capacity retention over 1000+ charge cycles [Tags: Machine Learning, Neural Networks, Python, Data Science, Research, Time Series]

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
