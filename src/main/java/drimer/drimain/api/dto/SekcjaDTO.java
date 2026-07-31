package drimer.drimain.api.dto;

import lombok.Data;

@Data
public class SekcjaDTO {
    private Long id;
    private String nazwa;
    private DzialDTO dzial;
    private Long maszynaId;
    private String maszynaNazwa;
}

