// CV Template - Typst Version
// Equivalent to CV.tex + resume.cls
// Placeholders use <<NAME>> syntax for job titles
// Bullet injection uses // MARKER_START and // MARKER_END comments

#import "cv-helpers.typ": section, job, job-continuation, skill-category, education, certifications

// Document setup - matches LaTeX resume.cls settings
#set document(title: "CV - Mohammed Islam", author: "Mohammed Islam")
#set page(
  paper: "us-letter",
  margin: (left: 0.75in, right: 0.75in, top: 0.6in, bottom: 0.6in),
  numbering: none,
)
// Use "New Computer Modern" to match LaTeX's default font
// Falls back to Typst's default serif if not installed
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: false, leading: 0.52em)

// Bullet list styling - matches LaTeX $\cdot$ bullet
#set list(indent: 0em, marker: [·], body-indent: 0.5em, spacing: 0em)  // Compressed like LaTeX's -0.5em itemsep

// ============================================
// HEADER
// ============================================

#align(center)[
  #text(size: 18pt, weight: "bold")[MOHAMMED ISLAM - SC CLEARED]
]

#v(12pt)  // \bigskip equivalent

#align(center)[
  +44 751 234 9133 #h(0.5em) $diamond.stroked.small$ #h(0.5em) mohammed.islam9494\@gmail.com
]

// ============================================
// PROFILE
// ============================================

#section("Profile")[
  Platform engineer with a strong background in enterprise-level Kubernetes support, Kubernetes release management, observability & monitoring, & feature development.
]

// ============================================
// EDUCATION
// ============================================

#section("Education")[
  #education(
    "University of Warwick",
    "September 2013 - August 2017",
    "Department of Engineering - MEng Systems Engineering"
  )
]

// ============================================
// CERTIFICATIONS
// ============================================

#section("Certifications")[
  *AWS x10* - All AWS Certs at Speciality & Professional level - *Hashicorp x1* - Terraform Associate
]

// ============================================
// SKILLS
// ============================================

#section("Skills")[
  #skill-category("Soft Skills")[
    Project Management, Team Work, Peer Mentoring, On-site & Remote Working, Release Management, Incident & Problem Management, Disaster Recovery Planning, System Architecture
  ]

  #skill-category("Observability & Monitoring")[
    Cloudwatch, Datadog, Pagerduty, Elasticsearch, Opensearch, Fluentd, Logstash, Beats, Metrics-server, Prometheus, Grafana, Thanos, Loki, Mimir, Tempo
  ]

  #skill-category("Scripting, Programming & Other Languages")[
    Python, Shell (Bash), Golang
  ]

  #skill-category("Configuration Management & DevOps Tools")[
    Confluence, Service Now, JIRA, Trello, Jenkins, Gitlab, Git, Twistlock, Vault, NGINX, AWS, Kubernetes, Helm, Gatekeeper, OPA, Conftest, Kustomize, Terraform, Terragrunt, Docker, Azure, AKS, KEDA, Karpenter
  ]
]

// ============================================
// EXPERIENCE
// ============================================

#section("Experience")[

  // --- PMI ---
  #job("Phillip Morris International", "June 2024 - Present", title: [{{PMI_JOB_TITLE}}])[
    // PMI_BULLETS_START
    // PMI_BULLETS_END
  ]

  // --- HMRC ---
  #job("HMRC", "January 2023 - March 2024", title: [{{HMRC_JOB_TITLE}}])[
    // HMRC_BULLETS_START
    // HMRC_BULLETS_END
  ]

  // --- ITV ---
  #job("ITV", "June 2022 - Jan 2023", title: [{{ITV_JOB_TITLE}}])[
    // ITV_BULLETS_START
    // ITV_BULLETS_END
  ]

  // --- Nationwide (multiple roles) ---
  #job("Nationwide Building Society", "September 2017 - July 2022", title: [{{NATIONWIDE_EKS_JOB_TITLE}}], title-dates: "2020 - July 2022")[
    // NATIONWIDE_EKS_BULLETS_START
    // NATIONWIDE_EKS_BULLETS_END
  ]

  #job-continuation([{{NATIONWIDE_OBS_JOB_TITLE}}], "2018 - 2020")[
    // NATIONWIDE_OBS_BULLETS_START
    // NATIONWIDE_OBS_BULLETS_END
  ]

  #job-continuation("Platform Engineer - Nationwide Digital Hub", "September 2017 - 2018")[
    - Alerting system to ETL MongoDB logs via the ELK stack using Python, firing alerts to hubs if there were access attempts. Ran integration testing & a Jenkins pipeline deploying a custom Dockerfile to a multi-tenant K8s cluster
    - Led a 12-person strong team of engineers to develop a prototype application for Nationwide
  ]

  // --- OVO Energy ---
  #job("OVO Energy & Warwick Manufacturing Group", "July 2016 - June 2017", title: "Research Analyst")[
    - Modelled the degradation of Nissan Leaf batteries through lab testing & MATLAB
    - Presented findings for EV battery at Munich conference to over one hundred academics
  ]
]
