#!/bin/bash

# Input: Tarball filename
TARBALL_NAME=$1

# 1. Query Nagios status using check_nrpe
NAGIOS_SERVICES=("RabbitMQ" "MySQL")  # Add all monitored services
declare -A SERVICE_STATUSES
OVERALL_STATUS="Good"

for service in "${NAGIOS_SERVICES[@]}"; do
    # Get service status from Nagios
    OUTPUT=$(/usr/lib/nagios/plugins/check_nrpe -H QA_VM_IP -c "check_${service,,}")
    STATUS=$?
    
    # Map to status text
    case $STATUS in
        0) SERVICE_STATUSES["$service"]="OK" ;;
        1) SERVICE_STATUSES["$service"]="WARNING" ;;
        2) 
            SERVICE_STATUSES["$service"]="CRITICAL"
            OVERALL_STATUS="Failed"
            ;;
        *) SERVICE_STATUSES["$service"]="UNKNOWN" ;;
    esac
done

# 2. Prepare JSON for services status
SERVICES_JSON=$(printf '%s\n' "${SERVICES[@]}" | jq -R -n -c '[inputs | {"service":., "status":env.SERVICE_STATUSES[.]}]')

# 3. Insert into MySQL
mysql -u nagios_user -p"your_password" deployment_monitoring <<EOF
INSERT INTO tarball_status (
    tarball_name, 
    overall_status, 
    nagios_status,
    services_status
) VALUES (
    '$TARBALL_NAME',
    '$OVERALL_STATUS',
    '$OVERALL_STATUS',
    '$SERVICES_JSON'
);
EOF

# 4. Trigger rollback if failed
if [ "$OVERALL_STATUS" = "Failed" ]; then
    /usr/local/bin/rollback_tarball.sh "$TARBALL_NAME"
fi
