-- Energy readings collected from Raspberry Pi / machine meters
CREATE TABLE IF NOT EXISTS energy_readings (
    id BIGSERIAL PRIMARY KEY,
    maszyna_id BIGINT NOT NULL REFERENCES maszyny(id) ON DELETE CASCADE,
    device_id VARCHAR(120) NOT NULL,
    recorded_at TIMESTAMP NOT NULL,
    power_kw NUMERIC(12,3),
    energy_kwh_total NUMERIC(14,3),
    voltage_v NUMERIC(10,2),
    current_a NUMERIC(10,2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_energy_readings_maszyna_recorded_at ON energy_readings(maszyna_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_energy_readings_device_id ON energy_readings(device_id);
CREATE INDEX IF NOT EXISTS idx_energy_readings_recorded_at ON energy_readings(recorded_at);

