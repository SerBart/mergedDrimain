package drimer.drimain.security;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * Rate limiting interceptor to prevent abuse.
 * Tracks requests per IP or user and rejects when limit exceeded.
 */
@Slf4j
@Component
public class RateLimitInterceptor implements HandlerInterceptor {

    // Simple in-memory cache for rate limiting
    // In production, use Redis or similar distributed cache
    private static final Map<String, RateLimitInfo> REQUEST_CACHE = new ConcurrentHashMap<>();
    private static final long CLEANUP_INTERVAL = TimeUnit.MINUTES.toMillis(10);
    private static long lastCleanup = System.currentTimeMillis();

    /**
     * Rate limit entry point
     */
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        // Cleanup old entries periodically
        if (System.currentTimeMillis() - lastCleanup > CLEANUP_INTERVAL) {
            cleanupOldEntries();
            lastCleanup = System.currentTimeMillis();
        }

        // Get client identifier (IP address)
        String clientId = getClientIp(request);
        
        // Check rate limit (default: 100 requests per minute per IP)
        if (!isAllowed(clientId, 100, 60)) {
            log.warn("Rate limit exceeded for IP: {}", clientId);
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", "60");
            response.setContentType("application/json");
            response.getWriter().write("{\"error\": \"Too many requests. Please try again later.\"}");
            return false;
        }

        return true;
    }

    /**
     * Check if request is allowed based on rate limit
     */
    private synchronized boolean isAllowed(String clientId, int maxRequests, int timeWindowSeconds) {
        long now = System.currentTimeMillis();
        long timeWindowMs = TimeUnit.SECONDS.toMillis(timeWindowSeconds);

        RateLimitInfo info = REQUEST_CACHE.getOrDefault(clientId, new RateLimitInfo());
        
        // Remove old timestamps outside the window
        info.timestamps.removeIf(timestamp -> now - timestamp > timeWindowMs);

        // Check if limit exceeded
        if (info.timestamps.size() >= maxRequests) {
            return false;
        }

        // Add current timestamp
        info.timestamps.add(now);
        REQUEST_CACHE.put(clientId, info);
        return true;
    }

    /**
     * Get client IP address (handles proxies)
     */
    private String getClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }
        
        return request.getRemoteAddr();
    }

    /**
     * Cleanup old entries from cache
     */
    private synchronized void cleanupOldEntries() {
        long now = System.currentTimeMillis();
        long maxAge = TimeUnit.MINUTES.toMillis(15);
        
        REQUEST_CACHE.entrySet().removeIf(entry -> {
            RateLimitInfo info = entry.getValue();
            return info.timestamps.stream()
                    .noneMatch(timestamp -> now - timestamp < maxAge);
        });
        
        log.debug("Rate limit cache cleanup completed. Entries: {}", REQUEST_CACHE.size());
    }

    /**
     * Inner class to store rate limit information
     */
    private static class RateLimitInfo {
        java.util.List<Long> timestamps = new java.util.concurrent.CopyOnWriteArrayList<>();
    }
}

