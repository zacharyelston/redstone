-- Extract container name from file path
-- This script extracts the container name from Docker logs path
-- or falls back to using the container ID if name can't be determined

function cb_extract_container_name(tag, timestamp, record)
    -- Get container ID from tag or path
    local container_id = nil
    if record["_path"] ~= nil then
        -- Extract from path like /var/lib/docker/containers/<container_id>/<container_id>-json.log
        local path = record["_path"]
        container_id = path:match('/containers/([^/]+)/')
    end
    
    -- If no container ID found, use a default
    if container_id == nil then
        record["container_name"] = "unknown"
        return 2, timestamp, record
    end
    
    -- Try to get the container name via Docker API if running in Docker
    -- As a simple approach, we'll use the shortened container ID for now
    -- This could be extended with docker inspect to get actual names
    local short_id = string.sub(container_id, 1, 12)
    
    -- Set default container_name to the short ID
    record["container_name"] = short_id
    
    -- Map common container IDs to readable names
    -- This is a static mapping based on common services in our stack
    local name_mapping = {
        ["redstone-postgres"] = "postgres",
        ["redstone-redmica"] = "redmica",
        ["redstone-ldap"] = "ldap",
        ["redstone-grafana"] = "grafana",
        ["redstone-prometheus"] = "prometheus",
        ["redstone-loki"] = "loki",
        ["redstone-fluent-bit"] = "fluent-bit",
        ["redstone-redis"] = "redis"
    }
    
    -- Check if there's a container name in the record already
    if record["container_name"] ~= nil then
        local container_name = record["container_name"]
        for prefix, name in pairs(name_mapping) do
            if string.find(container_name, prefix) then
                record["container_name"] = name
                break
            end
        end
    end
    
    return 2, timestamp, record
end
