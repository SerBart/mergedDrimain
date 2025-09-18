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
    
    private Set<String> roles; // Role names
}