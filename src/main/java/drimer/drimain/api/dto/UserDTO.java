package drimer.drimain.api.dto;

import lombok.Data;

import java.util.Set;

@Data
public class UserDTO {
    private Long id;
    private String username;
    private Set<String> roles; // Role names for simplicity
    // Note: password field intentionally excluded for security
}