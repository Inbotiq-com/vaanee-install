# Aggregates installer step modules.
# Keep function signatures stable for install.sh main flow.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=steps/system.sh
source "$SCRIPT_DIR/steps/system.sh"
# shellcheck source=steps/input_and_validation.sh
source "$SCRIPT_DIR/steps/input_and_validation.sh"
# shellcheck source=steps/files_and_migrations.sh
source "$SCRIPT_DIR/steps/files_and_migrations.sh"
# shellcheck source=steps/runtime.sh
source "$SCRIPT_DIR/steps/runtime.sh"
