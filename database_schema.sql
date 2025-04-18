-- Main queue table for IP blocking requests
CREATE TABLE IF NOT EXISTS queue (
    id SERIAL PRIMARY KEY,
    nsip VARCHAR(255) NOT NULL,
    ip VARCHAR(255) NOT NULL,
    attack_type VARCHAR(50) NOT NULL,
    vserver VARCHAR(255) NOT NULL,
    datasetname VARCHAR(255),
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    active BOOLEAN DEFAULT FALSE,
    deactivated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    block_count INTEGER DEFAULT 0,
    comment TEXT
);

-- Configuration table for caching Netscaler settings
CREATE TABLE IF NOT EXISTS netscaler_config (
    id SERIAL PRIMARY KEY,
    nsip VARCHAR(255) NOT NULL,
    config_key VARCHAR(255) NOT NULL,
    config_key_name VARCHAR(255) NOT NULL,
    config_key_value TEXT NOT NULL,
    last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(nsip, config_key_name)
);

-- Dataset tracking table to avoid constant HTTP requests
CREATE TABLE IF NOT EXISTS netscaler_datasets (
    id SERIAL PRIMARY KEY,
    nsip VARCHAR(255) NOT NULL,
    dataset_name VARCHAR(255) NOT NULL,
    ip_count INTEGER DEFAULT 0,
    max_capacity INTEGER DEFAULT 50000,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(nsip, dataset_name)
);

-- Operational log for tracking actions and errors
CREATE TABLE IF NOT EXISTS operation_log (
    id SERIAL PRIMARY KEY,
    operation_type VARCHAR(50) NOT NULL,
    nsip VARCHAR(255),
    ip VARCHAR(255),
    dataset_name VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_queue_nsip ON queue(nsip);
CREATE INDEX IF NOT EXISTS idx_queue_ip ON queue(ip);
CREATE INDEX IF NOT EXISTS idx_queue_processed ON queue(processed);
CREATE INDEX IF NOT EXISTS idx_queue_timestamp ON queue(timestamp);
CREATE INDEX IF NOT EXISTS idx_queue_active ON queue(active);
CREATE INDEX IF NOT EXISTS idx_queue_expires_at ON queue(expires_at);
CREATE INDEX IF NOT EXISTS idx_queue_dataset ON queue(datasetname);

-- Index for config lookups
CREATE INDEX IF NOT EXISTS idx_config_nsip_key ON netscaler_config(nsip, config_key);

-- Index for dataset tracking
CREATE INDEX IF NOT EXISTS idx_datasets_nsip ON netscaler_datasets(nsip);
CREATE INDEX IF NOT EXISTS idx_datasets_name ON netscaler_datasets(dataset_name);
CREATE INDEX IF NOT EXISTS idx_datasets_count ON netscaler_datasets(ip_count);