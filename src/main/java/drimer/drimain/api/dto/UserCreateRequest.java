package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.Set;

@Data
public class UserCreateRequest {
    @NotBlank
    private String username;
    
    @NotBlank
    private String password;

    @NotBlank
    private String email;

    private Set<String> roles; // Role names

    // New: assign user to department
    private Long dzialId;

    // New: per-user modules access
    private Set<String> modules;
}