# Global Claude Code Rules - DevOps Engineer

## Core Professional Principles

### 1. Infrastructure as Code (IaC) Standards
- **ALWAYS** use Terraform for infrastructure provisioning
- **ALWAYS** follow the principle of immutable infrastructure
- **ALWAYS** version control all infrastructure definitions
- **ALWAYS** use proper state management (remote state, state locking)
- **ALWAYS** implement resource tagging strategies for cost management and organization

### 2. Multi-Cloud Best Practices
- **ALWAYS** design for cloud-agnostic patterns where possible
- **ALWAYS** use cloud-native services when they provide clear advantages
- **ALWAYS** implement proper cross-cloud networking and security
- **ALWAYS** consider data sovereignty and compliance requirements
- **ALWAYS** optimize for cost across different cloud providers

### 3. Security-First Approach
- **NEVER** hardcode secrets, API keys, or sensitive data in code
- **ALWAYS** use proper secret management (Azure Key Vault, AWS Secrets Manager, etc.)
- **ALWAYS** implement least privilege access principles
- **ALWAYS** use managed identities and service principals appropriately
- **ALWAYS** ensure network security with proper firewall rules and NSGs

## Cloud Platform Expertise

### Azure Best Practices
- **Resource Groups**: Organize by environment, application, or lifecycle
- **Managed Identities**: Use system-assigned for single resources, user-assigned for multiple
- **App Service**: Leverage deployment slots for blue-green deployments
- **Key Vault**: Store secrets, certificates, and keys with proper access policies
- **Monitor**: Use Application Insights and Log Analytics for observability
- **Networking**: Implement hub-spoke topology for enterprise scenarios

### AWS Best Practices
- **Account Strategy**: Use AWS Organizations for multi-account setup
- **IAM**: Follow principle of least privilege with roles and policies
- **VPC**: Design proper subnet architecture with public/private separation
- **CloudFormation/CDK**: Use for infrastructure provisioning
- **CloudWatch**: Implement comprehensive logging and monitoring
- **S3**: Use appropriate storage classes and lifecycle policies

### Terraform Standards
- **Module Structure**: Create reusable, composable modules
- **State Management**: Use remote state with proper backend configuration
- **Variable Management**: Use .tfvars files and environment-specific configurations
- **Version Constraints**: Pin provider and module versions
- **Resource Naming**: Follow consistent naming conventions
- **Documentation**: Maintain comprehensive README files for modules

## Development and Automation

### Python DevOps Patterns
- **Virtual Environments**: Always use venv/virtualenv for isolation
- **Dependencies**: Use requirements.txt and/or pyproject.toml
- **Configuration**: Use environment variables and config files
- **Logging**: Implement structured logging with proper levels
- **Error Handling**: Use try-except blocks with specific exception handling
- **Testing**: Write unit tests for automation scripts and modules

### CI/CD Pipeline Standards
- **Version Control**: Use Git with proper branching strategies (GitFlow, GitHub Flow)
- **Pipeline as Code**: Define pipelines in YAML (Azure DevOps, GitHub Actions)
- **Artifact Management**: Use proper artifact stores and registries
- **Environment Promotion**: Implement progressive deployment strategies
- **Testing**: Include unit, integration, and security testing in pipelines
- **Rollback Strategy**: Always have a rollback plan and mechanism

### Container and Orchestration
- **Docker**: Use multi-stage builds and minimal base images
- **Kubernetes**: Follow security best practices and resource limits
- **Helm**: Use for package management and templating
- **Image Security**: Scan images for vulnerabilities
- **Registry**: Use private registries for production workloads

## Monitoring and Observability

### Logging Standards
- **Structured Logging**: Use JSON format for machine readability
- **Log Levels**: Implement appropriate logging levels (DEBUG, INFO, WARN, ERROR)
- **Centralized Logging**: Use ELK stack, Splunk, or cloud-native solutions
- **Log Retention**: Implement appropriate retention policies
- **Sensitive Data**: Never log secrets or sensitive information

### Monitoring and Alerting
- **Metrics**: Implement the four golden signals (latency, traffic, errors, saturation)
- **Dashboards**: Create actionable dashboards for different audiences
- **Alerting**: Set up meaningful alerts with proper thresholds
- **SLI/SLO**: Define and monitor service level indicators and objectives
- **Runbooks**: Create runbooks for common operational procedures

## Project Architecture Patterns

### Microservices Best Practices
- **Service Boundaries**: Define clear service boundaries and responsibilities
- **API Design**: Use RESTful APIs with proper versioning
- **Data Management**: Implement database per service pattern
- **Communication**: Use asynchronous messaging where appropriate
- **Circuit Breakers**: Implement fault tolerance patterns
- **Service Discovery**: Use proper service discovery mechanisms

### Database and Data Management
- **Schema Migration**: Use version-controlled database migrations
- **Backup Strategy**: Implement automated backup and recovery procedures
- **Performance**: Monitor and optimize database performance
- **Security**: Implement database encryption and access controls
- **Compliance**: Ensure data handling meets regulatory requirements

## Operational Excellence

### Incident Management
- **Response Procedures**: Have clear incident response procedures
- **Communication**: Establish clear communication channels during incidents
- **Post-Mortem**: Conduct blameless post-mortems for learning
- **Documentation**: Maintain incident logs and resolution procedures
- **Prevention**: Implement preventive measures based on lessons learned

### Capacity Planning and Scaling
- **Auto-scaling**: Implement horizontal and vertical scaling strategies
- **Load Testing**: Perform regular load testing and capacity planning
- **Resource Optimization**: Monitor and optimize resource utilization
- **Cost Management**: Implement cost monitoring and optimization strategies
- **Performance Benchmarking**: Establish and monitor performance baselines

### Disaster Recovery and Business Continuity
- **Backup Strategy**: Implement comprehensive backup strategies
- **Recovery Testing**: Regularly test disaster recovery procedures
- **RTO/RPO**: Define and monitor recovery time and point objectives
- **Multi-Region**: Consider multi-region deployments for critical systems
- **Documentation**: Maintain up-to-date disaster recovery documentation

## Technology-Specific Guidelines

### Python Development
- **Code Style**: Follow PEP 8 style guidelines
- **Type Hints**: Use type hints for better code clarity
- **Virtual Environments**: Always use virtual environments
- **Package Management**: Use pip with requirements.txt or poetry
- **Testing**: Use pytest for testing with proper fixtures
- **Documentation**: Use docstrings and maintain README files

### Infrastructure Tools
- **Terraform**: Use modules, remote state, and proper variable management
- **Ansible**: Use playbooks with proper inventory management
- **Docker**: Follow security best practices and image optimization
- **Kubernetes**: Use namespaces, resource quotas, and security contexts
- **Helm**: Use values files for environment-specific configurations

### Cloud Services Integration
- **Azure**: Leverage ARM templates, Azure CLI, and PowerShell
- **AWS**: Use CloudFormation, AWS CLI, and SDKs appropriately
- **Monitoring**: Integrate with cloud-native monitoring solutions
- **Identity**: Use cloud identity services for authentication and authorization
- **Networking**: Implement proper network segmentation and security

## Communication and Documentation

### Technical Documentation
- **Architecture Diagrams**: Maintain up-to-date system architecture diagrams
- **API Documentation**: Use OpenAPI/Swagger for API documentation
- **Runbooks**: Create detailed operational runbooks
- **Decision Records**: Document architectural decisions and rationale
- **Change Logs**: Maintain comprehensive change logs

### Team Collaboration
- **Code Reviews**: Conduct thorough code reviews with constructive feedback
- **Knowledge Sharing**: Share knowledge through documentation and presentations
- **Standards**: Establish and maintain team coding and operational standards
- **Mentoring**: Provide guidance and mentoring to junior team members
- **Cross-Training**: Ensure knowledge is shared across team members

## Continuous Learning and Improvement

### Technology Evolution
- **Stay Current**: Keep up with latest developments in cloud and DevOps technologies
- **Experimentation**: Regularly experiment with new tools and technologies
- **Community**: Participate in DevOps and cloud communities
- **Certification**: Maintain relevant cloud and technology certifications
- **Best Practices**: Continuously refine and improve operational practices

### Process Improvement
- **Automation**: Continuously identify opportunities for automation
- **Efficiency**: Look for ways to improve development and deployment efficiency
- **Quality**: Implement measures to improve code and infrastructure quality
- **Feedback**: Gather and act on feedback from stakeholders
- **Metrics**: Use metrics to drive continuous improvement initiatives
