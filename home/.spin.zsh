  export PATH="/opt/rubies/*/lib/ruby/gems/*/gems/*/bin:$PATH"
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
  alias token='bundle config --global PKGS__SHOPIFY__IO "token:$(gsutil cat gs://dev-tokens/cloudsmith/shopify/gems/latest)"'
  alias mycli='mycli -u root -P $MYSQL_PORT'
