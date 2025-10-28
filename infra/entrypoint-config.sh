set -e
: "${SIMULATION_HOST:=}"

cat > /usr/share/nginx/html/config.js <<EOF
window.RUNTIME_CONFIG = {
  SIMULATION_HOST: "${SIMULATION_HOST}"
};
EOF

echo "[config] wrote /usr/share/nginx/html/config.js"