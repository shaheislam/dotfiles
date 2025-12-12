# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# PERFORMANCE OPTIMIZATION: Kubectl abbreviations are now installed as universal variables
# This eliminates 768 abbr --add calls on every shell startup (~100-200ms savings)
#
# To install the abbreviations (one-time setup):
#   fish -c "source ~/.config/fish/setup/kubectl-abbr-setup.fish"
#
# To reinstall (if you want to update):
#   set -eU _kubectl_abbr_installed
#   fish -c "source ~/.config/fish/setup/kubectl-abbr-setup.fish"

if not set -q _kubectl_abbr_installed
    # Only show message in interactive shells
    if status is-interactive
        echo "kubectl aliases not installed. Run: fish -c 'source ~/.config/fish/setup/kubectl-abbr-setup.fish'"
    end
end
