#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PROVIDERS=(
    "Anthropic|anthropic|ANTHROPIC_API_KEY"
    "OpenAI|openai|OPENAI_API_KEY"
    "Google Gemini|gemini|GEMINI_API_KEY"
    "xAI Grok|grok|XAI_API_KEY"
    "Moonshot Kimi|kimi|MOONSHOT_API_KEY"
    "DeepSeek|deepseek|DEEPSEEK_API_KEY"
    "Qwen / DashScope|qwen|DASHSCOPE_API_KEY"
    "Zhipu GLM|glm|ZHIPU_API_KEY"
)

provider_field() {
    local row="$1"
    local index="$2"
    IFS='|' read -r display kind env_var <<<"$row"

    case "$index" in
        1) printf '%s\n' "$display" ;;
        2) printf '%s\n' "$kind" ;;
        3) printf '%s\n' "$env_var" ;;
    esac
}

lowercase() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

has_keychain_key() {
    local kind="$1"

    command -v security >/dev/null 2>&1 \
        && security find-generic-password -a "api-key" -s "clipai.$kind" >/dev/null 2>&1
}

provider_status() {
    local row="$1"
    local kind env_var
    kind="$(provider_field "$row" 2)"
    env_var="$(provider_field "$row" 3)"

    if [ -n "${!env_var:-}" ]; then
        printf '%s\n' "configured via $env_var"
    elif has_keychain_key "$kind"; then
        printf '%s\n' "configured in Keychain"
    else
        printf '%s\n' "not configured"
    fi
}

any_provider_configured() {
    local row
    for row in "${PROVIDERS[@]}"; do
        if [ "$(provider_status "$row")" != "not configured" ]; then
            return 0
        fi
    done
    return 1
}

print_provider_menu() {
    local i row display env_var status

    echo ""
    echo "Choose a provider to configure:"
    for i in "${!PROVIDERS[@]}"; do
        row="${PROVIDERS[$i]}"
        display="$(provider_field "$row" 1)"
        env_var="$(provider_field "$row" 3)"
        status="$(provider_status "$row")"
        printf '  %d) %s (%s) - %s\n' "$((i + 1))" "$display" "$env_var" "$status"
    done
    echo "  s) Skip for now"
}

save_keychain_key() {
    local kind="$1"
    local api_key="$2"
    local service="clipai.$kind"

    if ! command -v security >/dev/null 2>&1; then
        echo "Could not find the macOS security command. Set the provider environment variable later instead."
        return 0
    fi

    if security add-generic-password -a "api-key" -s "$service" -w "$api_key" -U >/dev/null; then
        echo "API key saved to the macOS Keychain."
    else
        echo "Could not save the API key to Keychain. Set the provider environment variable later instead."
    fi
}

configure_api_key() {
    local prompt choice row display kind env_var status api_key

    echo ""
    echo "API key setup"

    if any_provider_configured; then
        read -r -p "An API key is already configured. Configure or replace a key now? [y/N] " prompt \
            || prompt=""
        case "$(lowercase "$prompt")" in
            y|yes) ;;
            *)
                echo "Skipping API key setup."
                return
                ;;
        esac
    fi

    while true; do
        print_provider_menu
        read -r -p "Provider [s]: " choice || choice="s"
        choice="${choice:-s}"

        case "$(lowercase "$choice")" in
            s|skip)
                echo "Skipping API key setup. You can set an environment variable or run ClipAI later to be prompted."
                return
                ;;
        esac

        if ! [[ "$choice" =~ ^[0-9]+$ ]] \
            || [ "$choice" -lt 1 ] \
            || [ "$choice" -gt "${#PROVIDERS[@]}" ]; then
            echo "Invalid provider choice."
            continue
        fi

        row="${PROVIDERS[$((choice - 1))]}"
        display="$(provider_field "$row" 1)"
        kind="$(provider_field "$row" 2)"
        env_var="$(provider_field "$row" 3)"
        status="$(provider_status "$row")"

        if [ "$status" != "not configured" ]; then
            read -r -p "$display is already $status. Replace it in Keychain? [y/N] " prompt \
                || prompt=""
            case "$(lowercase "$prompt")" in
                y|yes) ;;
                *)
                    echo "Keeping existing $display configuration."
                    return
                    ;;
            esac
        fi

        read -r -s -p "$display API key: " api_key || api_key=""
        echo ""

        if [ -z "$api_key" ]; then
            echo "No key entered. Skipping API key setup."
            return
        fi

        save_keychain_key "$kind" "$api_key"
        echo "Environment override for this provider: $env_var"
        return
    done
}

"$SCRIPT_DIR/install.sh"
configure_api_key

echo ""
echo "Setup complete."
