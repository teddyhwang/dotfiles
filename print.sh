#!/bin/zsh

export C_DEFAULT="\x1B[39m"
export C_GREEN="\x1B[32m"
export C_RED="\x1B[31m"
export C_LIGHTGRAY="\x1B[90m"
export C_ORANGE="\x1B[33m"
export C_BLUE="\x1B[34m"
export C_CYAN="\x1B[36m"

print_success() {
  echo -e "${C_GREEN}$1${C_DEFAULT}"
}

print_error() {
  echo -e "${C_RED}$1${C_DEFAULT}"
}

print_warning() {
  echo -e "${C_ORANGE}$1${C_DEFAULT}"
}

print_info() {
  echo -e "${C_LIGHTGRAY}$1${C_DEFAULT}"
}

print_status() {
  echo -e "${C_BLUE}$1${C_DEFAULT}"
}

print_progress() {
  echo -e "${C_CYAN}$1${C_DEFAULT}"
}
