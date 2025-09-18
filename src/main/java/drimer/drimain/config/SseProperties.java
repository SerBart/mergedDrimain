package drimer.drimain.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "app.sse")
public class SseProperties {
    
    private int maxClients = 100;
    private long heartbeatIntervalSeconds = 30;
    private long clientTimeoutSeconds = 300; // 5 minutes
    
    // Getters and setters
    public int getMaxClients() {
        return maxClients;
    }

    public void setMaxClients(int maxClients) {
        this.maxClients = maxClients;
    }

    public long getHeartbeatIntervalSeconds() {
        return heartbeatIntervalSeconds;
    }

    public void setHeartbeatIntervalSeconds(long heartbeatIntervalSeconds) {
        this.heartbeatIntervalSeconds = heartbeatIntervalSeconds;
    }

    public long getClientTimeoutSeconds() {
        return clientTimeoutSeconds;
    }

    public void setClientTimeoutSeconds(long clientTimeoutSeconds) {
        this.clientTimeoutSeconds = clientTimeoutSeconds;
    }
}