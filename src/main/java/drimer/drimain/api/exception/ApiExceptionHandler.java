package drimer.drimain.api.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiErrorResponse> handleIllegal(IllegalArgumentException ex) {
        ApiErrorResponse resp = new ApiErrorResponse(
                "IllegalArgument",
                ex.getMessage(),
                Instant.now(),
                HttpStatus.BAD_REQUEST.value()
        );
        return ResponseEntity.badRequest().body(resp);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ApiErrorResponse> handleResponseStatus(ResponseStatusException ex) {
        HttpStatus status = HttpStatus.resolve(ex.getStatusCode().value());
        if (status == null) status = HttpStatus.BAD_REQUEST;
        ApiErrorResponse resp = new ApiErrorResponse(
                status.is4xxClientError() ? "BadRequest" : "Error",
                ex.getReason() != null ? ex.getReason() : ex.getMessage(),
                Instant.now(),
                status.value()
        );
        return ResponseEntity.status(status).body(resp);
    }

    // NOTE: Handle validation errors with detailed field error information
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ValidationErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        List<String> errors = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.toList());
        
        ValidationErrorResponse resp = new ValidationErrorResponse(
                "ValidationError",
                "Validation failed",
                Instant.now(),
                HttpStatus.BAD_REQUEST.value(),
                errors
        );
        return ResponseEntity.badRequest().body(resp);
    }

    // NOTE: Handle security access denied exceptions from @PreAuthorize
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiErrorResponse> handleAccessDenied(AccessDeniedException ex) {
        ApiErrorResponse resp = new ApiErrorResponse(
                "AccessDenied",
                "Access denied",
                Instant.now(),
                HttpStatus.FORBIDDEN.value()
        );
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(resp);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleOther(Exception ex) {
        if (ex instanceof ResponseStatusException rse) {
            return handleResponseStatus(rse);
        }
        ApiErrorResponse resp = new ApiErrorResponse(
                "InternalError",
                ex.getMessage(),
                Instant.now(),
                HttpStatus.INTERNAL_SERVER_ERROR.value()
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(resp);
    }
}