#!/usr/bin/env python3
"""
CV Optimization Pipeline
Combines all CV generation tools for maximum effectiveness
"""

import subprocess
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple
import argparse


class CVOptimizer:
    """Master CV optimization orchestrator"""

    def __init__(self):
        """Initialize optimizer"""
        self.base_dir = Path.home() / "dotfiles"
        self.jobapps_dir = self.base_dir / "jobapps"
        self.scripts_dir = self.base_dir / "scripts" / "cv"
        self.output_dir = self.jobapps_dir / "generated"

        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def generate_optimization_report(self, job_path: str, cv_path: str) -> Dict:
        """Generate comprehensive CV optimization report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'job_file': job_path,
            'cv_file': cv_path,
            'analysis': {},
            'scores': {},
            'recommendations': [],
            'selected_bullets': []
        }

        print("🔍 Analyzing job description...")
        # Run job analyzer
        result = subprocess.run(
            ['python', str(self.scripts_dir / 'job-analyzer.py'), job_path],
            capture_output=True,
            text=True
        )

        if result.stdout:
            report['analysis']['job'] = result.stdout

        print("📊 Generating CV variants...")
        # Generate multiple CV versions
        variants = self.generate_cv_variants(job_path, cv_path)
        report['variants'] = variants

        print("✨ Creating optimization report...")
        # Generate recommendations
        report['recommendations'] = self.generate_recommendations(report)

        return report

    def generate_cv_variants(self, job_path: str, cv_path: str) -> List[Dict]:
        """Generate multiple CV variants with different strategies"""
        variants = []

        strategies = [
            {
                'name': 'technology_focused',
                'description': 'Emphasizes technical skills and certifications',
                'script': 'cv-generator-enhanced.py',
                'params': ['--focus', 'technology']
            },
            {
                'name': 'leadership_focused',
                'description': 'Highlights team leadership and project management',
                'script': 'cv-generator-enhanced.py',
                'params': ['--focus', 'leadership']
            },
            {
                'name': 'impact_focused',
                'description': 'Prioritizes quantifiable achievements and cost savings',
                'script': 'cv-generator-enhanced.py',
                'params': ['--focus', 'impact']
            }
        ]

        for strategy in strategies:
            output_name = f"cv_{strategy['name']}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

            # Generate variant
            result = subprocess.run(
                ['python', str(self.scripts_dir / strategy['script']),
                 '--job', job_path,
                 '--cv', cv_path,
                 '--output', output_name] + strategy.get('params', []),
                capture_output=True,
                text=True
            )

            variant = {
                'strategy': strategy['name'],
                'description': strategy['description'],
                'output_file': f"{output_name}.pdf",
                'success': result.returncode == 0
            }

            if result.stdout:
                # Extract scoring information
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Score:' in line:
                        variant['top_score'] = line

            variants.append(variant)

        return variants

    def generate_recommendations(self, report: Dict) -> List[str]:
        """Generate actionable recommendations"""
        recommendations = []

        # Analyze job requirements vs CV content
        if 'kubernetes' in report.get('analysis', {}).get('job', '').lower():
            recommendations.append(
                "🎯 Job emphasizes Kubernetes - ensure Cluster API and EKS experience is prominent"
            )

        if 'terraform' in report.get('analysis', {}).get('job', '').lower():
            recommendations.append(
                "🏗️ Infrastructure as Code is key - highlight Terraform module development"
            )

        # Check for missing keywords
        recommendations.append(
            "💡 Consider adding these keywords to improve ATS matching: "
            "DevOps, CI/CD, Automation, Monitoring, Security"
        )

        # Suggest certification emphasis
        recommendations.append(
            "📜 Your AWS certifications are a strong differentiator - ensure they're prominently displayed"
        )

        return recommendations

    def create_html_report(self, report: Dict) -> str:
        """Create HTML visualization of optimization report"""
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>CV Optimization Report</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }}
        h1 {{ color: #2c3e50; }}
        h2 {{ color: #34495e; border-bottom: 2px solid #ecf0f1; padding-bottom: 10px; }}
        .metric {{ display: inline-block; margin: 10px; padding: 15px; background: #ecf0f1; border-radius: 5px; }}
        .metric-value {{ font-size: 24px; font-weight: bold; color: #3498db; }}
        .recommendation {{ background: #f1f8ff; border-left: 4px solid #0366d6; padding: 10px; margin: 10px 0; }}
        .variant {{ border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }}
        .success {{ background: #d4edda; }}
        .warning {{ background: #fff3cd; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }}
        th {{ background: #f8f9fa; }}
    </style>
</head>
<body>
    <h1>🎯 CV Optimization Report</h1>
    <p>Generated: {report['timestamp']}</p>

    <h2>📊 CV Variants Generated</h2>
    <div class="variants">
"""

        for variant in report.get('variants', []):
            status_class = 'success' if variant['success'] else 'warning'
            html += f"""
        <div class="variant {status_class}">
            <h3>{variant['strategy'].replace('_', ' ').title()}</h3>
            <p>{variant['description']}</p>
            <p>📄 File: {variant['output_file']}</p>
        </div>
"""

        html += """
    </div>

    <h2>💡 Recommendations</h2>
    <div class="recommendations">
"""

        for rec in report.get('recommendations', []):
            html += f'        <div class="recommendation">{rec}</div>\n'

        html += """
    </div>

    <h2>🔍 Job Analysis</h2>
    <pre>{}</pre>
</body>
</html>
""".format(report.get('analysis', {}).get('job', 'No analysis available'))

        return html

    def save_report(self, report: Dict, format: str = 'json') -> str:
        """Save optimization report"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        if format == 'json':
            output_file = self.output_dir / f"cv_optimization_report_{timestamp}.json"
            with open(output_file, 'w') as f:
                json.dump(report, f, indent=2, default=str)
        elif format == 'html':
            output_file = self.output_dir / f"cv_optimization_report_{timestamp}.html"
            html = self.create_html_report(report)
            with open(output_file, 'w') as f:
                f.write(html)

        return str(output_file)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='CV Optimization Pipeline')
    parser.add_argument('--job', default='~/dotfiles/jobapps/jobdesciption.md',
                       help='Job description file')
    parser.add_argument('--cv', default='~/dotfiles/jobapps/CV.tex',
                       help='CV template file')
    parser.add_argument('--format', choices=['json', 'html'], default='html',
                       help='Report format')
    parser.add_argument('--open', action='store_true',
                       help='Open report after generation')

    args = parser.parse_args()

    # Expand paths
    job_path = str(Path(args.job).expanduser())
    cv_path = str(Path(args.cv).expanduser())

    # Run optimizer
    optimizer = CVOptimizer()
    report = optimizer.generate_optimization_report(job_path, cv_path)

    # Save report
    report_file = optimizer.save_report(report, args.format)
    print(f"✅ Report saved: {report_file}")

    if args.open:
        subprocess.run(['open', report_file])

    return 0


if __name__ == '__main__':
    main()