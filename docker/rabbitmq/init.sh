#!/bin/sh
set -eu

rabbitmq-server &
server_pid=$!

until rabbitmq-diagnostics -q ping; do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    wait "$server_pid"
  fi
  sleep 1
done

rabbitmq-plugins enable rabbitmq_prometheus

configure_user() {
  username=$1
  password=$2
  if rabbitmqctl list_users -q | awk '{print $1}' | grep -Fxq "$username"; then
    rabbitmqctl change_password "$username" "$password"
  else
    rabbitmqctl add_user "$username" "$password"
  fi

  rabbitmqctl set_permissions -p /torque-os "$username" ".*" ".*" ".*"
}

configure_user os-service "$RABBITMQ_OS_PASSWORD"
configure_user billing-service "$RABBITMQ_BILLING_PASSWORD"
configure_user execution-service "$RABBITMQ_EXECUTION_PASSWORD"

wait "$server_pid"
