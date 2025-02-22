# Print the SQL query to create the Kafka endpoint in Materialize
output "mz_kafka_endpoint_sql" {
  value = <<EOF
    -- Create the private link endpoint in Materialize
    CREATE CONNECTION privatelink_svc TO AWS PRIVATELINK (
        SERVICE NAME '${aws_vpc_endpoint_service.mz_kafka_lb_endpoint_service.service_name}',
        AVAILABILITY ZONES (${length(var.mz_supported_regions) > 0 ? "" : join(", ", [for s in data.aws_subnet.mz_kafka_subnet : format("%q", s.availability_zone_id)])})
    );

    -- Get the allowed principals for the VPC endpoint service
    SELECT principal
    FROM mz_aws_privatelink_connections plc
    JOIN mz_connections c ON plc.id = c.id
    WHERE c.name = 'privatelink_svc';

    -- IMPORTANT: Get the allowed principals, then add them to the VPC endpoint service

    -- Create the connection to the Kafka cluster
    CREATE CONNECTION kafka_connection TO KAFKA (
        BROKERS (
        ${join(",\n", [for broker in var.mz_kafka_brokers : "'${broker.broker_ip}:${var.mz_kafka_cluster_port}' USING AWS PRIVATELINK privatelink_svc (${length(var.mz_supported_regions) > 0 ? "" : format("AVAILABILITY ZONE '%s', ", data.aws_subnet.mz_kafka_subnet[broker.subnet_id].availability_zone_id)}PORT ${9000 + broker.broker_id})"])}
        ),
        -- Authentication details
        -- Depending on the authentication method the Kafka cluster is using
        SASL MECHANISMS = 'SCRAM-SHA-512',
        USERNAME = 'foo',
        PASSWORD = SECRET bar
    );
    EOF
}

# Return the VPC endpoint service name
output "mz_kafka_lb_endpoint_service" {
  value = aws_vpc_endpoint_service.mz_kafka_lb_endpoint_service
}

# Return the AZs for the Kafka subnets in an array
output "mz_kafka_azs" {
  value = [for s in data.aws_subnet.mz_kafka_subnet : s.availability_zone_id]
}
