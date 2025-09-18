package drimer.drimain.api.exception;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.Instant;

@Data
@AllArgsConstructor
public class ApiErrorResponse {
    private String error;
    private String message;
    private Instant timestamp;
    private int status;
}