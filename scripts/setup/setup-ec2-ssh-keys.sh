#!/usr/bin/env bash

# setup-ec2-ssh-keys.sh
# Generates SSH key pair and distributes to all EC2 instances via SSM
# Usage: ./setup-ec2-ssh-keys.sh [profile]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSH_KEY_NAME="shahe-distant-nvim"
SSH_KEY_PATH="$HOME/.ssh/${SSH_KEY_NAME}"
AWS_PROFILE="${1:-}"
REGION="${AWS_REGION:-us-east-1}"
AWS_FLAGS=()

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check dependencies
check_dependencies() {
	local missing_deps=()

	if ! command -v aws &>/dev/null; then
		missing_deps+=("aws-cli")
	fi

	if ! command -v jq &>/dev/null; then
		missing_deps+=("jq")
	fi

	if [ ${#missing_deps[@]} -ne 0 ]; then
		print_error "Missing dependencies: ${missing_deps[*]}"
		print_info "Install with: brew install ${missing_deps[*]}"
		exit 1
	fi
}

# Function to generate SSH key if it doesn't exist
generate_ssh_key() {
	if [ -f "${SSH_KEY_PATH}" ]; then
		print_info "SSH key already exists at ${SSH_KEY_PATH}"
		read -p "Do you want to regenerate it? (y/N): " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			print_info "Using existing key"
			return 0
		fi
		print_warning "Backing up existing key to ${SSH_KEY_PATH}.bak"
		mv "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.bak"
		mv "${SSH_KEY_PATH}.pub" "${SSH_KEY_PATH}.pub.bak"
	fi

	print_info "Generating new SSH key pair..."
	ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -N "" -C "distant-nvim@$(hostname)"
	print_success "SSH key generated at ${SSH_KEY_PATH}"
}

# Function to get AWS profile flags
get_aws_flags() {
	AWS_FLAGS=(--region "$REGION")
	if [ -n "${AWS_PROFILE}" ]; then
		AWS_FLAGS=(--profile "$AWS_PROFILE" "${AWS_FLAGS[@]}")
	fi
}

# Function to get all EC2 instances with SSM
get_ssm_instances() {
	local -a aws_flags
	get_aws_flags
	aws_flags=("${AWS_FLAGS[@]}")

	# Get all running EC2 instances (suppress the info message here)
	local all_instances
	# shellcheck disable=SC2016
	all_instances=$(aws ec2 describe-instances \
		--filters "Name=instance-state-name,Values=running" \
		--query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],Platform]' \
		--output json "${aws_flags[@]}" 2>/dev/null || echo "[]")

	# Get SSM-connected instances
	local ssm_instances
	ssm_instances=$(aws ssm describe-instance-information \
		--query 'InstanceInformationList[*].InstanceId' \
		--output json "${aws_flags[@]}" 2>/dev/null || echo "[]")

	# Process and filter instances - ensure only valid instance IDs
	echo "${all_instances}" | jq -r --argjson ssm "${ssm_instances}" '
        .[] | .[] |
        select(.[0] as $id | $ssm | index($id)) |
        select(.[0] != null and .[0] != "" and (.[0] | startswith("i-"))) |
        {
            id: .[0],
            name: (.[1] // "Unnamed"),
            platform: (.[2] // "linux")
        } |
        "\(.id)|\(.name)|\(.platform)"
    ' | grep -E '^i-[a-f0-9]+\|' | sort | uniq
}

# Function to determine the user for each instance
get_instance_user() {
	local platform="$1"
	case "${platform,,}" in
	windows*)
		echo "Administrator"
		;;
	*)
		# Default to ec2-user, but could be ubuntu, admin, etc.
		echo "ec2-user"
		;;
	esac
}

# Function to add SSH key to a single instance
add_key_to_instance() {
	local instance_id="$1"
	local instance_name="$2"
	local platform="$3"
	local -a aws_flags
	local ssh_key
	get_aws_flags
	aws_flags=("${AWS_FLAGS[@]}")
	ssh_key=$(<"${SSH_KEY_PATH}.pub")

	# Skip Windows instances
	if [[ "${platform,,}" == windows* ]]; then
		print_warning "Skipping Windows instance: ${instance_name} (${instance_id})"
		return 0
	fi

	print_info "Adding SSH key to ${instance_name} (${instance_id})..."

	# Determine likely users to try
	local users=("ec2-user" "ubuntu" "admin" "centos" "fedora")
	local success=false

	for user in "${users[@]}"; do
		# Command to add SSH key
		local command="
            mkdir -p /home/${user}/.ssh && \
            chmod 700 /home/${user}/.ssh && \
            echo '${ssh_key}' >> /home/${user}/.ssh/authorized_keys && \
            chmod 600 /home/${user}/.ssh/authorized_keys && \
            chown -R ${user}:${user} /home/${user}/.ssh && \
            echo 'SSH key added for user: ${user}'
        "

		# Try to add the key
		local result
		result=$(aws ssm send-command \
			--instance-ids "${instance_id}" \
			--document-name "AWS-RunShellScript" \
			--parameters "commands=[\"${command}\"]" \
			--output json "${aws_flags[@]}" 2>/dev/null || echo "{}")

		if [ -n "${result}" ] && [ "${result}" != "{}" ]; then
			local command_id
			command_id=$(echo "${result}" | jq -r '.Command.CommandId // ""')

			if [ -n "${command_id}" ]; then
				# Wait for command to complete
				sleep 2

				# Check command status
				local status
				status=$(aws ssm get-command-invocation \
					--command-id "${command_id}" \
					--instance-id "${instance_id}" \
					--query 'Status' \
					--output text "${aws_flags[@]}" 2>/dev/null || echo "Failed")

				if [ "${status}" == "Success" ]; then
					print_success "Added key for ${user}@${instance_name}"
					success=true
					break
				fi
			fi
		fi
	done

	if [ "${success}" == false ]; then
		print_error "Failed to add key to ${instance_name} (${instance_id})"
		return 1
	fi

	return 0
}

# Function to update SSH config for distant.nvim
update_ssh_config() {
	local config_file="$HOME/.ssh/config.d/ec2-instances.conf"

	print_info "Updating SSH config for distant.nvim..."

	# Create config.d directory if it doesn't exist
	mkdir -p "$HOME/.ssh/config.d"

	# Generate config entries
	{
		echo "# Auto-generated SSH config for EC2 instances"
		echo "# Generated on $(date)"
		echo "# Used with distant.nvim for remote editing"
		echo ""

		# Add entries for each instance
		while IFS='|' read -r id name platform; do
			if [[ "${platform,,}" != windows* ]]; then
				local user
				user=$(get_instance_user "${platform}")
				echo "# ${name}"
				echo "Host ec2-${id}"
				echo "    HostName ${id}"
				echo "    User ${user}"
				echo "    IdentityFile ${SSH_KEY_PATH}"
				echo "    ProxyCommand sh -c \"aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' ${AWS_PROFILE:+--profile ${AWS_PROFILE}} --region ${REGION}\""
				echo "    StrictHostKeyChecking no"
				echo "    UserKnownHostsFile /dev/null"
				echo ""
			fi
		done < <(get_ssm_instances)
	} >"${config_file}"

	print_success "SSH config updated at ${config_file}"
}

# Main execution
main() {
	print_info "EC2 SSH Key Setup for distant.nvim"
	echo "===================================="
	echo

	# Check dependencies
	check_dependencies

	# Set AWS profile if provided
	if [ -n "${1:-}" ]; then
		export AWS_PROFILE="$1"
		print_info "Using AWS profile: ${AWS_PROFILE}"
	fi

	# Generate SSH key
	generate_ssh_key

	# Get instances
	print_info "Fetching EC2 instances with SSM connectivity..."
	local instances
	instances=$(get_ssm_instances)

	if [ -z "${instances}" ]; then
		print_error "No EC2 instances with SSM connectivity found"
		exit 1
	fi

	# Count instances
	local instance_count
	instance_count=$(echo "${instances}" | wc -l)
	print_info "Found ${instance_count} instances with SSM connectivity"
	echo

	# Show instances
	echo "Instances to configure:"
	echo "------------------------"
	while IFS='|' read -r id name platform; do
		echo "  • ${name} (${id}) - Platform: ${platform}"
	done <<<"${instances}"
	echo

	# Confirm
	read -p "Do you want to add SSH keys to all these instances? (y/N): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		print_warning "Operation cancelled"
		exit 0
	fi

	# Add keys to each instance
	local success_count=0
	local fail_count=0

	while IFS='|' read -r id name platform; do
		if add_key_to_instance "${id}" "${name}" "${platform}"; then
			((success_count++)) || true || true
		else
			((fail_count++)) || true || true
		fi
	done <<<"${instances}"

	# Update SSH config
	update_ssh_config

	# Summary
	echo
	echo "===================================="
	print_success "Setup complete!"
	echo "  • Instances configured: ${success_count}"
	if [ ${fail_count} -gt 0 ]; then
		echo "  • Instances failed: ${fail_count}"
	fi
	echo
	print_info "To connect with distant.nvim in Neovim:"
	echo "  :DistantConnect ssh://ec2-<instance-id>"
	echo
	print_info "Or use the helper function:"
	echo "  distant-ssm"
}

# Run main function
main "$@"
