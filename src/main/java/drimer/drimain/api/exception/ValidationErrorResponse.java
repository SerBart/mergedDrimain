package drimer.drimain.api.exception;

import java.time.Instant;
import java.util.List;

public record ValidationErrorResponse(
        String error,
        String message,
        Instant timestamp,
        int status,
        List<String> fieldErrors
) {}