import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
	site: 'https://aimux.dev',
	integrations: [
		starlight({
			title: 'aimux',
			description: 'Terminal-agnostic AI agent multiplexer — run parallel agents in any terminal',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/shaheislam/aimux' },
			],
			customCss: ['./src/styles/custom.css'],
			sidebar: [
				{
					label: 'Getting Started',
					items: [
						{ label: 'Installation', slug: 'getting-started/installation' },
						{ label: 'Quick Start', slug: 'getting-started/quick-start' },
						{ label: 'Core Concepts', slug: 'getting-started/concepts' },
					],
				},
				{
					label: 'Commands',
					items: [
						{ label: 'aimux new', slug: 'commands/new' },
						{ label: 'aimux run', slug: 'commands/run' },
						{ label: 'aimux status', slug: 'commands/status' },
						{ label: 'aimux kill', slug: 'commands/kill' },
						{ label: 'aimux attach', slug: 'commands/attach' },
						{ label: 'aimux queue', slug: 'commands/queue' },
						{ label: 'aimux daemon', slug: 'commands/daemon' },
						{ label: 'aimux notify', slug: 'commands/notify' },
						{ label: 'aimux log', slug: 'commands/log' },
						{ label: 'aimux merge', slug: 'commands/merge' },
						{ label: 'aimux pr', slug: 'commands/pr' },
						{ label: 'aimux init', slug: 'commands/init' },
						{ label: 'aimux doctor', slug: 'commands/doctor' },
					],
				},
				{
					label: 'Workflows',
					items: [
						{ label: 'Parallel Agents', slug: 'workflows/parallel-agents' },
						{ label: 'Autonomous Tickets', slug: 'workflows/autonomous-tickets' },
						{ label: 'Batch Execution', slug: 'workflows/batch-execution' },
						{ label: 'CI/CD Integration', slug: 'workflows/ci-cd' },
						{ label: 'Team Workflows', slug: 'workflows/team' },
					],
				},
				{
					label: 'Configuration',
					items: [
						{ label: 'Config Reference', slug: 'configuration/reference' },
						{ label: 'Providers', slug: 'configuration/providers' },
						{ label: 'Notifications', slug: 'configuration/notifications' },
					],
				},
				{
					label: 'Guides',
					items: [
						{ label: 'Custom Providers', slug: 'guides/custom-providers' },
						{ label: 'Migration', slug: 'guides/migration' },
					],
				},
			],
		}),
	],
});
