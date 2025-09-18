package drimer.drimain.api.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

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

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleOther(Exception ex) {
        ApiErrorResponse resp = new ApiErrorResponse(
                "InternalError",
                ex.getMessage(),
                Instant.now(),
                HttpStatus.INTERNAL_SERVER_ERROR.value()
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(resp);
    }
}