package drimer.drimain.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ChangePasswordRequest {

    @NotBlank(message = "Aktualne hasło jest wymagane")
    private String currentPassword;

    @NotBlank(message = "Nowe hasło jest wymagane")
    @Size(min = 8, max = 128, message = "Nowe hasło musi mieć od 8 do 128 znaków")
    private String newPassword;

    @NotBlank(message = "Potwierdzenie nowego hasła jest wymagane")
    private String confirmNewPassword;
}

