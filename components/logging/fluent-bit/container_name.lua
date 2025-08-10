-- Simplified container name extraction function
function cb_extract_container_name(tag, timestamp, record)
    -- Get container ID from tag
    local container_id = nil
    
    -- Extract container ID from tag path
    -- Docker logs typically have tag like 'docker.var.lib.docker.containers.CONTAINER_ID.CONTAINER_ID-json.log'
    if tag ~= nil then
        -- Match the container ID from the tag
        container_id = string.match(tag, "containers%.([^%.]+)")
    end
    
    -- Default value if container ID not found
    if container_id == nil then
        record["container_id"] = "unknown"
        record["container_name"] = "unknown"
        record["service"] = "unknown"
        record["component"] = "unknown"
        return 2, timestamp, record
    end
    
    -- Use short ID for readability
    local short_id = string.sub(container_id, 1, 12)
    
    -- Map of known container IDs to service names
    -- Using short IDs (first 12 characters) of running containers
    local id_mapping = {
        -- Main services from container IDs
        ["7cea4de0f2fe"] = "redmica-init",
        ["86fa1bcdcedc"] = "redmica",
        ["596cc118cee8"] = "postgres",
        ["44c7aa6a51bb"] = "grafana",
        ["ec125c1128dc"] = "fluent-bit",
        ["0cdd369fc8e7"] = "redis",
        ["a2b2768b150d"] = "prometheus",
        ["b6ff33df84c8"] = "ldap",
        ["8f48af8e07b1"] = "loki"
    }
    
    -- Known service name to component mapping
    local component_mapping = {
        ["postgres"] = "database",
        ["redmica"] = "application",
        ["ldap"] = "authentication",
        ["grafana"] = "monitoring",
        ["prometheus"] = "monitoring",
        ["loki"] = "logging",
        ["fluent-bit"] = "logging",
        ["redis"] = "cache"
    }
    
    -- Extract service name from container ID
    record["container_id"] = short_id
    record["container_name"] = "container-" .. short_id
    
    -- Try to identify the service from the container ID mapping
    local service_name = id_mapping[short_id] or "unknown"
    
    -- Set the service and component fields
    record["service"] = service_name
    record["component"] = component_mapping[service_name] or "unknown"
    
    return 2, timestamp, record
end
