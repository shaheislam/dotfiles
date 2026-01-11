"""
Role-specific bullets for CV generation.
Each bullet has text and tags for job description matching.
"""

ROLE_BULLETS = {
    'HMRC': [
        {
            'text': 'Worked on deploying Prometheus as a vended repository for consumers to utilise a satellite Prometheus with a Thanos sidecar within their EKS cluster to unify platform observability',
            'tags': ['Prometheus', 'Thanos', 'EKS', 'Observability', 'AWS', 'Kubernetes', 'Monitoring'],
        },
        {
            'text': 'Deployed Thanos chart, alongside additional components such as ruler & compactor with associated bucket, access points and role infra to enable for long term object storage of Prometheus metrics',
            'tags': ['Thanos', 'Prometheus', 'Helm', 'AWS', 'S3', 'Observability', 'Monitoring'],
        },
        {
            'text': 'Leveraging of Prometheus kube state metrics metadata to alert based on team labelling allowing custom receivers to fire',
            'tags': ['Prometheus', 'Kubernetes', 'Alerting', 'kube-state-metrics', 'Monitoring'],
        },
        {
            'text': 'Improved Opensearch performance capabilities by performance testing and optimising JVM heap size to increase garbage collection efficiency',
            'tags': ['OpenSearch', 'Elasticsearch', 'Performance', 'JVM', 'Optimization'],
        },
        {
            'text': 'Implemented custom Prometheus exporters to generate metrics for AWS services into a single monitoring system, allowing Product Owners to streamline platform service offerings',
            'tags': ['Prometheus', 'AWS', 'Golang', 'Monitoring', 'Custom Exporters', 'Observability'],
        },
        {
            'text': 'Ran performance testing for e2e logging solution of Fluentbit, Fluentd and Opensearch to understand performance limitations and configuration settings required to prevent service disruption and cost optimise scaling',
            'tags': ['Fluentbit', 'Fluentd', 'OpenSearch', 'Performance Testing', 'Logging', 'Cost Optimization'],
        },
        {
            'text': 'Monitored and maintained AWS services, including EC2 instances, S3 buckets, and RDS databases, ensuring high availability through Cloudwatch pushing metrics to Prometheus Pushgateway',
            'tags': ['AWS', 'EC2', 'S3', 'RDS', 'CloudWatch', 'Prometheus', 'Monitoring', 'High Availability'],
        },
    ],
    'ITV': [
        {
            'text': 'Delivering EKS as a Platform with integrated day-2 tooling to customers to achieve a unified, pen-tested secure cloud platform across the organisation',
            'tags': ['EKS', 'AWS', 'Kubernetes', 'Platform Engineering', 'Security', 'Cloud Platform'],
        },
        {
            'text': 'Implemented standardised compliance testing through Open Policy Agent & Conftest, moving from multiple runners to a single multi-tenant deployment runner agent against AWS infrastructure, saving runner costs by 70%',
            'tags': ['OPA', 'Conftest', 'Compliance', 'AWS', 'Terraform', 'CI/CD', 'Cost Optimization', 'Security'],
        },
        {
            'text': 'Built an Ansible playbook for PCI compliant security hardening on Amazons CIS Benchmark AMI',
            'tags': ['Ansible', 'Security', 'PCI', 'Compliance', 'CIS Benchmark', 'AWS', 'AMI'],
        },
        {
            'text': 'Architected a series of Lambdas to populate and distribute SSH keys with automated rotation within a 60 day period',
            'tags': ['AWS Lambda', 'Security', 'SSH', 'Automation', 'Key Management', 'Serverless'],
        },
        {
            'text': 'Created DynamoDB tables to dynamically store AMI status for different accounts',
            'tags': ['DynamoDB', 'AWS', 'AMI', 'Database', 'Automation'],
        },
        {
            'text': 'Creating and extending Dockerfiles to perform wrapper execution to prevent developer team intervention and increase guardrails for pipelines, reducing CVEs by 30%',
            'tags': ['Docker', 'Security', 'CI/CD', 'DevOps', 'CVE', 'Containerization'],
        },
        {
            'text': 'Designed automation to evacuate EKS nodes from selected AZs, increasing organisation DR capabilities',
            'tags': ['EKS', 'AWS', 'Disaster Recovery', 'Automation', 'Kubernetes', 'High Availability'],
        },
        {
            'text': 'Designed Python program leveraging Github API and Jinja2 templating to automate release note generation across different internal EKS releases, bringing down release note generation time from 4-6 hours manually, to 15 seconds',
            'tags': ['Python', 'GitHub', 'Jinja2', 'Automation', 'Release Management', 'EKS', 'DevOps'],
        },
        {
            'text': 'Ran AWS Glue to take Kubernetes cluster NFR load testing such as CoreDNS, storing results in S3 for long term performance tracking and visualisation via AWS Athena and Managed Grafana',
            'tags': ['AWS Glue', 'Kubernetes', 'CoreDNS', 'S3', 'Athena', 'Grafana', 'Performance Testing'],
        },
    ],
    'NATIONWIDE_EKS': [
        {
            'text': 'Developed AWS Glue jobs to take Kubernetes cluster non-functional requirement testing and store them in a central database, allowing time series trends to measure component upgrade influence against performance over time',
            'tags': ['AWS Glue', 'Kubernetes', 'Performance Testing', 'Database', 'Time Series', 'NFR'],
        },
        {
            'text': 'Automated infrastructure management and deployment using Terraform and Terragrunt for AWS Cloudwatch & RDS modules for onprem developers via Python Jinja2 wrappers, easing deployment use for customers and eliminating team support tickets by 50% thanks to new developer self serve capabilities',
            'tags': ['Terraform', 'Terragrunt', 'AWS', 'CloudWatch', 'RDS', 'Python', 'Jinja2', 'Automation', 'Self-Service'],
        },
        {
            'text': 'Supporting developer teams with microservice Github Actions to deploy to multiple platforms and enforce pull request policies such as tagging and linting',
            'tags': ['GitHub Actions', 'CI/CD', 'DevOps', 'Microservices', 'Linting'],
        },
        {
            'text': 'Designed multi-stage Buildkite pipeline for cluster build & test stages using Make targets & 3-musketeers pattern',
            'tags': ['Buildkite', 'CI/CD', 'Make', '3-Musketeers', 'Pipeline', 'DevOps'],
        },
    ],
    'NATIONWIDE_OBS': [
        {
            'text': 'Development of monitoring platform, deploying Logstash architecture alongside Beats family to enable centralized application logging within Elasticsearch and visualisation within Kibana to achieve a unified monitoring platform spanned 40+ teams',
            'tags': ['ELK Stack', 'Elasticsearch', 'Logstash', 'Kibana', 'Beats', 'Monitoring', 'Observability'],
        },
        # NOTE: Grafana Labs stack bullet moved to skills.md with [ALWAYS_DFE] marker
        {
            'text': 'Implemented KEDA to optimise sizing of K8s components, specifically relating to Loki queries, saving costs',
            'tags': ['KEDA', 'Kubernetes', 'Autoscaling', 'Loki', 'Cost Optimization'],
        },
        {
            'text': 'Created Grafana dashboard pipeline allowing consumers to self serve dashboards to team specific custom folders via Helm templating and automatically promote to production via pipeline scripting, reducing dashboard support tickets by 90%',
            'tags': ['Grafana', 'Helm', 'CI/CD', 'Automation', 'Self-Service', 'Observability'],
        },
        {
            'text': 'Successful integration of Prometheus & Alertmanager with Pagerduty to improve oncall engineering working methods',
            'tags': ['Prometheus', 'Alertmanager', 'PagerDuty', 'Monitoring', 'On-Call', 'Integration'],
        },
        {
            'text': 'Built a Python script utilising Pyexcel and Pandas to automate the sizing of Elasticsearch clusters, resulting in significant cost savings through automation and reduction of human input in the magnitude of hundreds of hours',
            'tags': ['Python', 'Pandas', 'Elasticsearch', 'Automation', 'Cost Optimization', 'Data Analysis'],
        },
        {
            'text': 'Designed and implemented a more flexible Logstash pipeline which allowed customers to implement their sharding with no dependencies on the monitoring team, improving organisational velocity',
            'tags': ['Logstash', 'ELK Stack', 'Pipeline', 'Self-Service', 'Monitoring'],
        },
    ],
    # These roles have static bullets that should not be removed
    'NATIONWIDE_HUB': [
        {
            'text': 'Alerting system to ETL MongoDB logs via the ELK stack using Python, firing alerts to hubs if there were access attempts. Ran integration testing & a Jenkins pipeline deploying a custom Dockerfile to a multi-tenant K8s cluster',
            'tags': ['ELK Stack', 'Python', 'MongoDB', 'Jenkins', 'Docker', 'Kubernetes', 'Alerting'],
            'static': True,  # Never remove
        },
        {
            'text': 'Led a 12-person strong team of engineers to develop a prototype application for Nationwide',
            'tags': ['Leadership', 'Team Management', 'Engineering'],
            'static': True,  # Never remove
        },
    ],
    'OVO': [
        {
            'text': 'Modelled the degradation of Nissan Leaf batteries through lab testing & MATLAB',
            'tags': ['MATLAB', 'Data Analysis', 'Research', 'Battery'],
            'static': True,  # Never remove
        },
        {
            'text': 'Presented findings for EV battery at Munich conference to over one hundred academics',
            'tags': ['Presentation', 'Research', 'Conference'],
            'static': True,  # Never remove
        },
    ],
}

# Role metadata
ROLE_METADATA = {
    'DFE': {
        'title': 'Department for Education',
        'dates': 'May 2024 - Present',
        'default_job_title': 'Senior Site Reliability Engineer',
        'min_bullets': 3,
        'priority': 1,  # Highest priority for bullet allocation
    },
    'HMRC': {
        'title': 'HMRC',
        'dates': 'January 2023 - March 2024',
        'default_job_title': 'Senior Site Reliability Engineer',
        'min_bullets': 3,
        'priority': 2,
    },
    'ITV': {
        'title': 'ITV',
        'dates': 'June 2022 - Jan 2023',
        'default_job_title': 'Site Reliability Engineer',
        'min_bullets': 3,
        'priority': 3,
    },
    'NATIONWIDE_EKS': {
        'title': 'Nationwide Building Society',
        'dates': 'September 2017 - July 2022',
        'sub_dates': '2020 - July 2022',
        'default_job_title': 'Site Reliability Engineer - Enterprise Kubernetes Team',
        'min_bullets': 3,
        'priority': 4,
    },
    'NATIONWIDE_OBS': {
        'title': '',  # Continuation of Nationwide
        'dates': '',
        'sub_dates': '2018 - 2020',
        'default_job_title': 'Platform Engineer - Observability & Monitoring Team',
        'min_bullets': 3,
        'priority': 5,
    },
    'NATIONWIDE_HUB': {
        'title': '',  # Continuation of Nationwide
        'dates': '',
        'sub_dates': 'September 2017 - 2018',
        'default_job_title': 'Platform Engineer - Nationwide Digital Hub',
        'min_bullets': 2,
        'priority': 6,
        'static': True,  # Bullets cannot be removed
    },
    'OVO': {
        'title': 'OVO Energy & Warwick Manufacturing Group',
        'dates': 'July 2016 - June 2017',
        'default_job_title': 'Research Analyst',
        'min_bullets': 2,
        'priority': 7,
        'static': True,  # Bullets cannot be removed
    },
}

def get_all_role_bullets():
    """Get all bullets from all roles as a flat list with role attribution."""
    all_bullets = []
    for role, bullets in ROLE_BULLETS.items():
        for bullet in bullets:
            all_bullets.append({
                'text': bullet['text'],
                'tags': bullet['tags'],
                'role': role,
                'static': bullet.get('static', False),
            })
    return all_bullets

def get_role_bullets(role):
    """Get bullets for a specific role."""
    return ROLE_BULLETS.get(role, [])
