package drimer.drimain.security;

import java.lang.annotation.*;

/**
 * Annotation for rate limiting on endpoints.
 * Example: @RateLimit(requests = 5, timeWindow = 60) - 5 requests per 60 seconds
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RateLimit {
    /**
     * Number of requests allowed within the time window
     */
    int requests() default 10;

    /**
     * Time window in seconds
     */
    int timeWindow() default 60;

    /**
     * Identifier to use for rate limiting (e.g., "ip", "user")
     * Default is IP address
     */
    String identifier() default "ip";
}

